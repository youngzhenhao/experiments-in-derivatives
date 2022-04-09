// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7 <0.9.0;

import "ds-test/test.sol";
import "forge-std/stdlib.sol";
import "./mocks/MockV3Aggregator.sol";
import "./mocks/MockERC20.sol";
import "../CallOptions.sol";

contract DaiEthOptionsTest is DSTest {
    Vm public constant vm = Vm(HEVM_ADDRESS);
    CallOptions public callOption;
    MockERC20 public dai;
    address writer;
    address buyer;

    function setUp() public {
        dai = new MockERC20("DAI COIN", "DAI");
        callOption = new CallOptions(address(dai));

        // callOption.Option memory option = callOption.Option({
        //         writer: msg.sender,
        //         buyer: msg.sender,
        //         strike: 1 ether,
        //         premiumDue: 0.001 ether,
        //         expiration: (uint40(block.timestamp) + 604800),
        //         collateral: 1 ether
        //     });
    }

    function test_WriteCallOptionCount() public {
        callOption.writeCallOption(1, 1, 1);
    }
}
