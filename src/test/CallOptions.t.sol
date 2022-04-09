// SPDX-License-Identifier: MIT
pragma solidity >=0.8.7 <0.9.0;

import "ds-test/test.sol";
import "forge-std/stdlib.sol";

import "./mocks/MockV3Aggregator.sol";
import "./mocks/MockERC20.sol";

import "../CallOptions.sol";

contract CallOptionsTest is DSTest {
    //Setup contracts

    Vm public constant vm = Vm(HEVM_ADDRESS);
    CallOptions public call;
    MockERC20 public dai;
    MockV3Aggregator public mockV3Aggregator;

    //mock price feed
    uint8 public constant DECIMALS = 18;
    int256 public constant INITIAL_ANSWER = 1e18;

    //forge std lib
    using stdStorage for StdStorage;
    StdStorage public stdstore;

    //Events
    event CallOptionOpen(
        address indexed writer,
        uint256 id,
        uint256 expiration,
        uint256 value
    );
    event CallOptionBought(address indexed buyer, uint256 id);

    //Errors
    error Unauthorized();

    function setUp() public {
        dai = new MockERC20("DAI COIN", "DAI");
        call = new CallOptions(address(dai));
        mockV3Aggregator = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);

        // call.Option storage option = call.Option({
        //     writer: msg.sender,
        //     buyer: msg.sender,
        //     strike: 1 ether,
        //     premiumDue: 0.001 ether,
        //     expiration: (uint40(block.timestamp) + 604800),
        //     collateral: 1 ether
        // });

        dai.mint(address(this), 1e8);
        dai.approve(address(this), 1e8);
    }

    receive() external payable {}

    //test dai check
    function test_daiBalance() public {
        uint256 preBal = dai.balanceOf(address(this));
        dai.mint(address(this), 1e8);
        uint256 postBal = dai.balanceOf(address(this));
        assertEq(preBal + 1e8, postBal);
    }

    function test_optionStruct() public {}

    //Create a call option
    function testFail_writeCallOption() public {
        call.writeCallOption{value: 1 ether}(0, 1, 1);
    }

    function test_writeCallOption() public {
        call.writeCallOption{value: 1 ether}(1 ether, 1, 1);
    }

    function test_writeCallOptionId() public {
        uint256 id1 = call.writeCallOption{value: 1 ether}(1 ether, 1, 1);
        uint256 id2 = call.writeCallOption{value: 1 ether}(1 ether, 1, 1);
        assertEq(id1 + 1, id2);
    }

    function test_emitOpenOption() public {
        vm.expectEmit(true, true, false, false);
        emit CallOptionOpen(address(this), 1, 1, 1 ether);
        call.writeCallOption{value: 1 ether}(1 ether, 1, 1);
    }

    function testFail_emitOpenOption() public {
        vm.expectEmit(true, true, false, false);
        emit CallOptionOpen(address(0x1), 1, 1, 1 ether);
        call.writeCallOption{value: 1 ether}(1 ether, 1, 1);
    }

    function test_writeCallOptionWithWrongValue() public {
        vm.expectRevert(Unauthorized.selector);
        call.writeCallOption{value: 1 ether}(1 wei, 1 wei, 60);
    }

    //Buy a Call Option
    function test_buyCallOption() public {
        call.writeCallOption{value: 1 wei}(1 wei, 1 wei, 60);
        dai.approve(address(call), 1e8);
        call.buyCallOption(1);
    }

    function testFail_buyCallOption() public {
        call.writeCallOption{value: 1 wei}(1 wei, 1 wei, 60);
        dai.approve(address(call), 1e8);
        call.buyCallOption(0);
    }

    function test_emitBoughtOption() public {
        call.writeCallOption{value: 1 wei}(1 wei, 1, 1);
        dai.approve(address(call), 1e8);

        //check topic 1, but not data
        vm.expectEmit(true, false, false, false);
        //the event expected
        emit CallOptionBought(address(this), 1);
        //the event we get
        call.buyCallOption(1);
    }

    function test_buyOptionWithWrongId(uint96 _id) public {
        vm.assume(_id > 1);
        vm.expectRevert(Unauthorized.selector);
        call.buyCallOption(_id);
    }

    //Exercise a call option
    function test_exerciseCallOption() public {
        call.writeCallOption{value: 1 wei}(1 wei, 1, 1);
        dai.approve(address(call), 1e8);
        call.buyCallOption(1);

        //change block.timestamp
        vm.warp(90);

        call.exerciseCallOption(1, 1e8);
    }
}
