// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user"); // vytvoreni random fake adresy
    uint256 constant SEND_VALUE = 0.1 ether; // 0.1e18
    uint256 constant START_BALANCE = 10 ether;

    function setUp() external {
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run(); // "returns (FundMe)"

        vm.deal(USER, START_BALANCE); // cheatcode na fake money na adresu usera..
    }

    function testDollarPrice() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwner() public {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testVersion() public {
        uint256 version = fundMe.getVersion();
        assertEq(version, 4);
    }

    function testFundFailsWithoutEnoughEth() public {
        vm.expectRevert(); // the next line should revert
        fundMe.fund(); // send 0eth -> revert (test will pass)
    }

    modifier funded() {
        vm.prank(USER); // next TX will be sent by USER (this is setting USER as msg.sender)
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testFundUpdatesFundedDataStructure() public funded {
        // here is funding happened because of modifier "funded"
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testFunderAddedToArray() public funded {
        address funder = fundMe.getFunder(0);
        assertEq(funder, USER);
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER); // taky plati az pro dalsi TX
        vm.expectRevert(); // plati pro next tx
        //vm.prank(USER); // neni tx
        fundMe.cheaperWithdraw(); //plati pro tohle..
    }

    function testZeroAddressWithdraw() public funded {
        vm.prank(address(0));
        vm.expectRevert();
        fundMe.cheaperWithdraw();
    }

    function testReceiveFunction() public {
        vm.prank(USER);
        (bool callSuccess,) = address(fundMe).call{value: 888000000000000000}("");
        assertTrue(callSuccess);
        assertEq(address(fundMe).balance, 888000000000000000);
    }

    function testFallbackFunction() public {
        //vm.prank(USER);
        (bool callSuccess, bytes memory data) = address(fundMe).call{value: 888000000000000000}("someRandomData");
        console.log(string(data));
        assertTrue(callSuccess);
        assertEq(address(fundMe).balance, 888000000000000000);
        assertEq(fundMe.getAddressToAmountFunded(address(this)), 888000000000000000);
    }

    function testWithdrawWithOneFunder() public funded {
        // Arrange
        uint256 startOwner = fundMe.getOwner().balance;
        uint256 startContract = address(fundMe).balance;
        uint256 startUser = fundMe.getAddressToAmountFunded(USER);

        // Act

        uint256 gasStart = gasleft(); // gasLeft is solidity buidin
        vm.txGasPrice(1); // foundry buidin, could set gasprice (normaly on anvil will be gas price 0)

        vm.prank(fundMe.getOwner());
        fundMe.cheaperWithdraw();

        uint256 gasEnd = gasleft();

        console.log("gas used: ", gasStart - gasEnd);
        console.log("gas price: ", (gasStart - gasEnd) * tx.gasprice); // tx.gasprice  is Solidity buidin

        // Assert
        uint256 endOwner = fundMe.getOwner().balance;
        uint256 endUser = fundMe.getAddressToAmountFunded(USER);
        uint256 endContract = address(fundMe).balance;
        //assertEq(startOwner, 0);
        console.log(startOwner);
        assertEq(startUser, SEND_VALUE);
        assertEq(endContract, 0);
        assertEq(endUser, 0);
        assertEq(endOwner, startOwner + startContract);
        assertEq(endOwner, startOwner + startUser);
    }

    function testWithdrawWithMoreFunders() public funded {
        // one already funded
        uint256 numberOfFunders = 10; // has to be uint160 when then hoaxing address => same bytes value as address type
        uint256 startingFunderIndex = 1;

        for (uint256 i = startingFunderIndex; i < numberOfFunders; i++) {
            // hoax is the same as Prank & Deal
            hoax(address(uint160(i)), SEND_VALUE); // E if not specified,has initial balance of 1^128 = 340282366920938463463,374607431768211456
            //console.log(address(i).balance);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startLength = fundMe.getFundersLenght();

        uint256 startOwner = fundMe.getOwner().balance;
        uint256 startContract = address(fundMe).balance;

        console.log("startContract: ", startContract);

        uint256 gasStart = gasleft();
        vm.txGasPrice(1);
        vm.prank(fundMe.getOwner());
        fundMe.cheaperWithdraw();
        uint256 gasEnd = gasleft();
        console.log("gas used: ", gasStart - gasEnd);
        console.log("gas price: ", (gasStart - gasEnd) * tx.gasprice);

        assertEq(fundMe.getFundersLenght(), 0);
        assertEq(startLength, 10);
        assertEq(address(fundMe).balance, 0);
        assertEq(fundMe.getOwner().balance, startOwner + startContract);
    }
}
