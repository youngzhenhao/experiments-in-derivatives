//IN PROGRESS...

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7 <0.9.0;

import "solmate/tokens/ERC721.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

//Covered Call with No price oracle needed.
//Write a cover call against ETH collateral.
//Buyer pays premium and minted NFT.
//Buyer can turn NFT no more than 7 days after expiration.
contract FunkyCallOptions is ERC721, ReentrancyGuard {
    uint256 optionId;
    uint256 currentTokenId;

    enum Status {
        Open,
        Bought,
        Closed
    }

    struct Option {
        address owner;
        uint256 collateral;
        uint256 strike;
        uint256 premium;
        uint256 expiry;
        Status status;
    }

    mapping(uint256 => Option) public idToOption;

    error Unathorized();

    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {}

    function writeOption(uint256 _strike, uint256 _premium)
        public
        payable
        returns (uint256)
    {
        require(msg.value > 0 && _strike > 0 && _premium > 0);

        ++optionId;

        idToOption[optionId] = Option(
            msg.sender,
            msg.value,
            _strike,
            _premium,
            block.timestamp + 30 days,
            Status.Open
        );

        return optionId;
    }

    function buyOption(uint256 _optionId) public nonReentrant returns (bool) {
        Option memory option = idToOption[_optionId];
        require(option.expiry > block.timestamp, "EXPIRED");

        //buyer pays premium to writer
        (bool paid, ) = option.owner.call{value: option.premium}("");
        if (!paid) revert Unathorized();

        //option status bought
        idToOption[_optionId].status = Status.Bought;

        //option owner now buyer
        idToOption[_optionId].owner = msg.sender;

        mintToken(msg.sender);

        return true;
    }

    function collect(uint256 _optionId, uint256 _tokenId)
        public
        returns (bool)
    {
        Option memory option = idToOption[_optionId];

        require(option.owner == msg.sender);
        require(option.status == Status.Bought);
        require(option.expiry < block.timestamp);

        _burn(_tokenId);

        require(address(this).balance > option.collateral);

        (bool paid, ) = msg.sender.call{value: option.collateral}("");
        if (!paid) revert Unathorized();

        return true;
    }

    function mintToken(address _to) public payable returns (uint256) {
        uint256 newId = ++currentTokenId;
        _safeMint(_to, newId);
        return newId;
    }

    function tokenURI(uint256 _id)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return Strings.toString(_id);
    }
}
