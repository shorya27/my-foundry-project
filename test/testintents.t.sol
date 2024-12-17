// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {Intents} from "../src/Intents.sol";
import {AaveETHManager, IAEth, IERC20} from "../src/AAVEETHManager.sol";
import {CompoundETHManager, ICEth} from "../src/CompoundETHManager2.sol";

contract IntentsTest is Test {
    Intents public intentsEngine;
    AaveETHManager public aaveManager;
    CompoundETHManager public compoundManager;

    address user = address(1); // Test user address
    address constant aEthAddress = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8; // Aave aEth address
    address constant poolAddress = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2; // Aave ETH Mainnet Pool Address
    address constant cEthAddress = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5; // Aave aEth address

    function setUp() public {
        vm.createSelectFork(
            "https://eth-mainnet.g.alchemy.com/v2/h3C4fdzbM6xyo_vdxqqxD2Ro1X_3xmgA"
        );

        // Deploy mock managers
        aaveManager = new AaveETHManager(
            address(aEthAddress),
            address(poolAddress)
        );
        compoundManager = new CompoundETHManager(address(cEthAddress));

        // Deploy intents engine
        intentsEngine = new Intents(
            address(aaveManager),
            aEthAddress,
            address(compoundManager),
            cEthAddress
        );

        // Provide test user with initial ETH
        vm.deal(user, 1 ether);
    }

    function testDepositAave() public {
        vm.startPrank(user);

        uint256 depositAmount = 0.5 ether;

        intentsEngine.command{value: depositAmount}("deposit 0.5 ETH aave");

        uint256 useraEthBalance = IAEth(aEthAddress).balanceOf(user);
        console.log("aeth balance:", useraEthBalance);
        assert(useraEthBalance > 0);

        vm.stopPrank();
    }

    function testDepositCompound() public {
        // Start acting as the user
        vm.startPrank(user);

        uint256 depositAmount = 0.5 ether;
        uint256 usercEthBalanceBefore = ICEth(cEthAddress).balanceOf(user);

        // Execute the deposit command
        intentsEngine.command{value: depositAmount}("deposit 0.5 ETH compound");

        // Check the user's cETH balance
        uint256 usercEthBalanceAfter = ICEth(cEthAddress).balanceOf(user);

        // Ensure the balance is greater than 0
        assert(usercEthBalanceAfter > usercEthBalanceBefore);

        // Stop acting as the user
        vm.stopPrank();
    }

    function testWithdrawAave() public {
        vm.startPrank(user);

        uint256 depositAmount = 0.5 ether;

        // Deposit into Aave first
        intentsEngine.command{value: depositAmount}("deposit 0.5 ETH aave");
        uint256 userETHBalancebefore = user.balance;
        // Withdraw from Aave
        uint256 useraEthBalance = IAEth(aEthAddress).balanceOf(user);
        IAEth(aEthAddress).transfer(address(aaveManager), useraEthBalance);

        intentsEngine.command("withdraw 0.5 ETH aave");

        uint256 userETHBalanceafter = user.balance;

        assert(userETHBalanceafter > userETHBalancebefore);

        vm.stopPrank();
    }

    function testWithdrawCompound() public {
        vm.startPrank(user);

        uint256 depositAmount = 0.5 ether;

        // Deposit into Compound first
        intentsEngine.command{value: depositAmount}("deposit 0.5 ETH compound");
        uint256 userCETHBalance = ICEth(cEthAddress).balanceOf(user);
        assert(userCETHBalance > 0);
        uint256 userBalanceBefore = user.balance;
        ICEth(cEthAddress).transfer(address(compoundManager), userCETHBalance);

        intentsEngine.command("withdraw 0.5 ETH compound");

        uint256 userBalanceAfter = user.balance;

        assert(userBalanceAfter > userBalanceBefore);

        vm.stopPrank();
    }

    function testInvalidCommand() public {
        vm.startPrank(user);

        uint256 depositAmount = 0.5 ether;

        // Attempt invalid command
        vm.expectRevert();
        intentsEngine.command{value: depositAmount}("invalid command");

        vm.stopPrank();
    }
}
