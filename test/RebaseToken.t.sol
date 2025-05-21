// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
/*
    Test suite for RebaseToken and Vault contracts.
    Uses Foundry's forge-std/Test.sol for testing utilities.
*/

import {Test, console} from "forge-std/Test.sol";

import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";

import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success,) = payable(address(vault)).call{value: 1e18}("");
        if (!success) {}
        vm.stopPrank();
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        // 2. check our rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("starting Balance: ", startBalance);
        assertEq(startBalance, amount);
        // 3. warp the time and check balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        console.log("middle balance: ", middleBalance);
        assertGt(middleBalance, startBalance);
        // 4. warp the time again by the same amount and check the balance
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        console.log("ending balance: ", endBalance);
        assertGt(endBalance, middleBalance);
        assertApproxEqAbs(endBalance - middleBalance, middleBalance - startBalance, 1);
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        uint256 startBalance = rebaseToken.balanceOf(user);
        vm.warp(block.timestamp + 1 hours);
        uint256 balanceAfterTimePassed = rebaseToken.balanceOf(user);
        assertGt(balanceAfterTimePassed, startBalance);
        vm.stopPrank();
    }

    function testTransfer(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        bool success = rebaseToken.transfer(user, amount);
        assertEq(success, true);
        vm.stopPrank();
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testOwnerCanSetInterestRate(uint256 newInterestRate) public {
        vm.startPrank(owner);
        uint256 currentRate = rebaseToken.getUserInterestRate(owner);
        if (currentRate <= 1e19) {
            vm.stopPrank();
            return;
        }

        // Only allow decreasing the interest rate, as per contract restriction
        newInterestRate = bound(newInterestRate, 1e19, currentRate - 1);
        rebaseToken.setInterestRate(newInterestRate);
        console.log("newInterestRate: ", newInterestRate);
        uint256 interestRateNow = rebaseToken.getUserInterestRate(owner);
        console.log("interestRateNow: ", interestRateNow);
        assertEq(newInterestRate, interestRateNow);
        vm.stopPrank();
    }

    function testCannotCallMintAndBurn() public {
        vm.startPrank(user);
        vm.expectRevert();
        rebaseToken.mint(user, 100);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint256).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.principleBalanceOf(user), amount);

        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principleBalanceOf(user), amount);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

}
