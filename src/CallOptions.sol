// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7 <0.9.0;

import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./PriceFeedConsumer.sol";

///@title COVERED OPTIONS
///@author tobias
///@notice This Smart Contract allows for the buying/writing of Covered Calls with ETH as the underlying.
/// As an Example, use Chainlink DAI/ETH Price Feed.
/// Calls: Let you buy an asset at a set price on a specific date.
/// Covered Call: The seller(writer) transfers ETH for collateral and writes a Covered Call. The buyer pays premium w DAI.
/// Covered Call: At expiration, the buyer has right to ETH at strike price if market price is greater than strike price. Settles with DAI.
/// All options have the following properties:
/// Strike price - The price at which the underlying asset can either be bought or sold.
/// Expiry - The date at which the option expires.
/// Premium - The price of the options contract.
/// Probable strategy for option writer:
///1. Covered Calls - You sell upside on an asset while you hold it for yield, which comes from premium (Netural/Bullish on asset).

contract CallOptions is ReentrancyGuard, Ownable {
    ///-----------------------------------------///
    ///--------------STORAGE
    ///----------------------------------------///

    PriceFeedConsumer internal priceFeed;

    IERC20 dai;

    uint256 public optionId;

    mapping(address => address) public tokenToEthFeed;
    mapping(uint256 => Option) public optionIdToOption;
    mapping(address => uint256[]) public tradersPosition;

    ///-----------------------------------------///
    ///--------------ENUMS & STRUCTS
    ///----------------------------------------///

    enum OptionState {
        Open,
        Bought,
        Cancelled,
        Exercised
    }

    enum OptionType {
        Call,
        Put
    }

    struct Option {
        address writer;
        address buyer;
        uint256 strike;
        uint256 premiumDue;
        uint256 expiration;
        uint256 collateral;
        OptionState optionState;
        OptionType optionType;
    }

    ///-----------------------------------------///
    ///--------------ERRORS
    ///----------------------------------------///

    error TransferFailed();
    error OptionNotValid(uint256 _optionId);

    ///-----------------------------------------///
    ///--------------EVENTS
    ///----------------------------------------///

    event CallOptionOpen(
        uint256 id,
        address writer,
        uint256 strike,
        uint256 premium,
        uint256 expiration,
        uint256 value
    );

    event CallOptionBought(address buyer, uint256 id);
    event CallOptionExercised(address buyer, uint256 id);
    event OptionExpiresWorthless(address buyer, uint256 Id);
    event FundsRetrieved(address writer, uint256 id, uint256 value);

    ///-----------------------------------------///
    ///--------------MODIFIERS
    ///----------------------------------------///

    modifier optionExists(uint256 id) {
        if (optionIdToOption[optionId].writer == address(0))
            revert OptionNotValid(optionId);
        _;
    }

    modifier isValidOpenOption(uint256 id) {
        if (
            optionIdToOption[optionId].optionState != OptionState.Open ||
            optionIdToOption[optionId].expiration > block.timestamp
        ) revert OptionNotValid(optionId);
        _;
    }

    ///-----------------------------------------///
    ///--------------CONSTRUCTOR
    ///----------------------------------------///

    ///Kovan DAI Addr: 0x4f96fe3b7a6cf9725f59d353f723c1bdb64ca6aa
    constructor(address _daiAddr) {
        dai = IERC20(_daiAddr);
    }

    ///-----------------------------------------///
    ///--------------CALL OPTION FUNCTIONS
    ///----------------------------------------///

    ///@dev Write a call option against ETH collateral
    function writeCallOption(
        uint256 _strike,
        uint256 _premiumDue,
        uint256 _daysToExpiry
    ) external payable returns (uint256) {
        //To simplify, we only make one strike available, strike is the current marketprice.
        require(msg.value == _strike, "CALL: NO ETH COLLATERAL");

        optionIdToOption[optionId] = Option(
            msg.sender,
            address(0),
            _strike,
            _premiumDue,
            block.timestamp + _daysToExpiry,
            //msg.value is the ETH collateral.
            msg.value,
            OptionState.Open,
            OptionType.Call
        );

        ++optionId;
        tradersPosition[msg.sender].push(optionId);

        emit CallOptionOpen(
            optionId,
            msg.sender,
            _strike,
            _premiumDue,
            block.timestamp + _daysToExpiry,
            msg.value
        );

        return optionId;
    }

    ///@dev Buy an available call option.
    function buyCallOption(uint256 _optionId)
        external
        optionExists(_optionId)
        isValidOpenOption(_optionId)
        nonReentrant
    {
        Option memory option = optionIdToOption[_optionId];

        require(option.optionType == OptionType.Call, "NOT A CALL");
        require(option.optionState == OptionState.Open, "NOT AVAILABLE");

        //buyer pays writer w dai
        bool paid = dai.transferFrom(
            msg.sender,
            option.writer,
            option.premiumDue
        );
        if (!paid) revert TransferFailed();

        optionIdToOption[_optionId].buyer = msg.sender;
        optionIdToOption[_optionId].optionState = OptionState.Bought;
        tradersPosition[msg.sender].push(_optionId);

        emit CallOptionBought(msg.sender, _optionId);
    }

    ///@dev Buyer gets to exercise the option is spot price > strike after expiration.
    function exerciseCallOption(uint256 _optionId, uint256 _amount)
        external
        payable
        optionExists(_optionId)
        nonReentrant
    {
        Option memory option = optionIdToOption[_optionId];

        require(msg.sender == option.buyer, "NOT BUYER");
        require(option.optionState == OptionState.Bought, "NEVER BOUGHT");
        require(option.expiration <= block.timestamp, "CALL NOT EXPIRED");

        //for dai/eth, chainlink returns x amt of eth for 1 dai
        uint256 marketPriceInEth = priceFeed.getPriceFeed(_amount);

        //strike is in eth
        require(marketPriceInEth > option.strike, "NOT GREATER THAN STRIKE");

        //convert price to DAI so can send dai amount to writer
        uint256 strikeInDai = _amount / option.strike;

        //buyer gets right to buy ETH at strike w DAI
        bool paid = dai.transferFrom(msg.sender, option.writer, strikeInDai);
        if (!paid) revert TransferFailed();

        //transfer to msg.sender the writer's ETH collateral
        //recall, for this example msg.value == strike == collateral
        (paid, ) = payable(msg.sender).call{value: option.collateral}("");
        if (!paid) revert TransferFailed();

        optionIdToOption[_optionId].optionState = OptionState.Exercised;

        emit CallOptionExercised(msg.sender, _optionId);
    }

    ///-----------------------------------------///
    ///--------------ADDITIONAL FUNCTIONS
    ///----------------------------------------///

    ///@dev Cancel Option after expiration and if it's worthless
    ///In practice, a function like this would probably get run by the protocol
    function optionExpiresWorthless(uint256 _optionId, uint256 _amount)
        external
        optionExists(_optionId)
    {
        Option memory option = optionIdToOption[_optionId];

        require(option.optionState == OptionState.Bought, "NEVER BOUGHT");
        //etiher writer or buyer can cancel option after expiration if it is worthless
        require(
            optionIdToOption[_optionId].buyer == msg.sender ||
                optionIdToOption[_optionId].buyer == msg.sender,
            "NOT BUYER OR WRITER"
        );
        require(option.expiration < block.timestamp, "NOT EXPIRED");
        require(option.optionType == OptionType.Call, "NOT A Call");

        uint256 marketPriceInEth = priceFeed.getPriceFeed(_amount);

        //For call, if market < strike, call options expire worthless
        require(marketPriceInEth < option.strike, "PRICE NOT LESS THAN STRIKE");

        optionIdToOption[_optionId].optionState = OptionState.Cancelled;

        emit OptionExpiresWorthless(msg.sender, _optionId);
    }

    ///@dev Writer of the call option may collect their ETH collateral after option has expired and if it's worthless.
    function retrieveExpiredFunds(uint256 _optionId) external nonReentrant {
        Option memory option = optionIdToOption[_optionId];

        require(option.optionState == OptionState.Cancelled, "NOT CANCELLED");
        require(msg.sender == option.writer, "NOT WRITER");

        (bool paid, ) = payable(msg.sender).call{value: option.collateral}("");
        if (!paid) revert TransferFailed();

        emit FundsRetrieved(msg.sender, _optionId, option.collateral);
    }
}
