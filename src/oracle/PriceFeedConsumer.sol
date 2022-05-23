// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7 <0.9.0;

import "chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceFeedConsumer {
    AggregatorV3Interface internal immutable priceFeed;

    ///CHAINLINK PRICEFEEDS FOR EASE OF USE
    ///NETWORK: KOVAN
    ///EX: DAI/ETH Address: 0x22B58f1EbEDfCA50feF632bD73368b2FdA96D541
    ///NETWORK: RINKEBY
    ///EX: DAI/ETH Address: 0x74825DbC8BF76CC4e9494d0ecB210f676Efa001D
    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function getPriceFeed(uint256 _amount) public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return (uint256(price) * _amount) / 1e18;
    }
}
