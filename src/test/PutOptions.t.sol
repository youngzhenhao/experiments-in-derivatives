// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7 <0.9.0;

import "ds-test/test.sol";
import "./mocks/MockV3Aggregator.sol";
import "./mocks/MockERC20.sol";
import "../PutOptions.sol";

contract DaiEthOptionsTest is DSTest {
    PutOptions internal option;
    MockERC20 internal dai;
    address writer;
    address buyer;

    function setUp() public {
        dai = new MockERC20("DAI COIN", "DAI");
        option = new PutOptions(address(dai));
    }

    function testWriteCallOption() public {}
}
