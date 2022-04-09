//IN PROGRESS...
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7 <0.9.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./PriceFeedConsumer.sol/";

///@notice A Perpetual Swap: The trader gets futures exposure with no need to roll the position.
///Trader can hold the position as long as they want as long as they have the margin.
///Everyday, traders who are long pay a "funding fee" to those who are short.
///Funding Fee = (mark price - index price)
///Mark price == current perp price. Index price == underlying price.
///In general: If a perp gets more expensive than an underlying, longs will pay high funding fees.
///This leads to longs selling the perp, returning price to neutral.

contract PerpSwapAsFuture {
    PriceFeedConsumer priceFeed;
    IERC20 dai;

    uint256 positionCounter;

    enum PositionState {
        Open,
        Closed
    }

    struct Position {
        address _trader;
        uint256 _amount;
        uint256 _markPrice;
        bool long;
        uint256 timeOfOpen;
        uint256 timeOfClose;
        PositionState positionState;
    }

    event InsuranceDeposit(address sender, uint256 value);

    mapping(uint256 => Position) public idToPosition;
    mapping(address => uint256) public userBalance;

    constructor(address _daiAddr) {
        dai = IERC20(_daiAddr);
    }

    receive() external payable {
        emit InsuranceDeposit(msg.sender, msg.value);
    }

    function getIndexPrice(uint256 _amount) public returns (uint256) {
        uint256 ethPerDai = priceFeed.getPriceFeed(_amount);
        uint256 daiPerEth = 1 / ethPerDai;
        return daiPerEth;
    }

    function fundingFee(uint256 _amount) public returns (uint256) {
        Position memory position;
        uint256 markPrice = position._markPrice;
        uint256 indexPrice = getIndexPrice(_amount);

        //$(mark - index)/contract/day
        //the longs pay the funding fee to the shorts q 24 hrs
        return (markPrice - indexPrice);
    }

    function getTime() public returns (uint256) {
        Position memory position;
        uint256 duration = (position.timeOfClose - position.timeOfOpen);
        return duration;
    }

    function depositMargin() public payable {
        userBalance[msg.sender];
    }

    // function getPerpSwap(uint256 _positionId) public {
    //     Position memory postion = idToPosition[_positionId];
    // }

    function openLongPosition(uint256 _markPrice) public payable {
        //_markPrice = getIndexPrice();

        idToPosition[positionCounter] = Position(
            msg.sender,
            msg.value,
            _markPrice,
            true,
            block.timestamp,
            0,
            PositionState.Open
        );
        uint256 balance = userBalance[msg.sender];
        require(balance >= _markPrice, "Margin must be at least mark price");

        positionCounter++;
    }

    // function openShortPosition(uint256 _positionId) public {
    //     Position memory position = idToPosition[_positionId];
    // }

    // function closeLongPosition(uint256 _positionId) public {
    //     Position memory position = idToPosition[_positionId];

    //     PositionState.Closed;
    // }

    // function closeShortPosition(uint256 _positionId) public {
    //     Position memory position = idToPosition[_positionId];
    // }
}
