// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {AaveETHManager, IAEth, IWETH, IERC20, Pool, IWrappedTokenGatewayV3} from "../src/AAVEETHManager.sol";

contract AaveETHManagerTest is Test {
    AaveETHManager public aaveManager;
    address user = address(1); // Test user
    address constant aEthAddress = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8;
    address constant poolAddress = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant wethaddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant gatewaywethaddress =
        0xA434D495249abE33E031Fe71a969B81f3c07950D;

    function setUp() public {
        vm.createSelectFork(
            "https://eth-mainnet.g.alchemy.com/v2/h3C4fdzbM6xyo_vdxqqxD2Ro1X_3xmgA"
        );

        aaveManager = new AaveETHManager(aEthAddress, poolAddress);
        vm.deal(user, 10 ether); // Provide ETH to the test user
        console.log("Setup complete. User ETH balance:", user.balance);
    }

    function testDepositETH() public {
        vm.startPrank(user);
        uint256 depositAmount = 1 ether;

        // Step 1: Wrap ETH into WETH
        IWETH(wethaddress).deposit{value: depositAmount}();
        uint256 wethBalance = IERC20(wethaddress).balanceOf(user);
        console.log("WETH balance after deposit:", wethBalance);

        // Step 2: Approve WETH for the Pool
        IERC20(wethaddress).approve(poolAddress, depositAmount);
        console.log("WETH approved for Pool");

        // Step 3: Deposit WETH into Aave Pool
        // aaveManager.depositETH{value: depositAmount}();
        try Pool(poolAddress).supply(wethaddress, depositAmount, user, 0) {
            console.log("Supply successful");
        } catch {
            console.log("Supply failed");
        }

        // Step 4: Check cETH balance
        uint256 cEthBalance = IAEth(aEthAddress).balanceOf(user);
        console.log("cETH balance after deposit:", cEthBalance);
        assert(cEthBalance > 0);

        vm.stopPrank();
    }

    function testWithdrawETH() public {
        vm.startPrank(user);
        uint256 depositAmount = 1 ether;

        // Step 1: Wrap ETH into WETH
        IWETH(wethaddress).deposit{value: depositAmount}();
        uint256 wethBalance = IERC20(wethaddress).balanceOf(user);
        console.log("WETH balance after deposit:", wethBalance);

        // Step 2: Approve WETH for the Aave Pool
        IERC20(wethaddress).approve(poolAddress, depositAmount);
        console.log("WETH approved for Pool");

        // Step 3: Deposit WETH into Aave Pool
        try Pool(poolAddress).supply(wethaddress, depositAmount, user, 0) {
            console.log("Supply to Aave Pool successful");
        } catch {
            console.log("Supply to Aave Pool failed");
            revert("Supply to Aave Pool failed");
        }
        // aaveManager.depositETH{value: depositAmount}();

        uint256 aEthBalance = IAEth(aEthAddress).balanceOf(user);
        console.log("aETH balance after deposit:", aEthBalance);
        assert(aEthBalance > 0); // Ensure aETH is credited

        // Step 4: Withdraw WETH from Aave Pool
        uint256 userBalanceBefore = user.balance;
        console.log("User ETH balance before withdrawal:", userBalanceBefore);

        try Pool(poolAddress).withdraw(wethaddress, depositAmount, user) {
            console.log("Withdrawal from Aave Pool successful");
        } catch {
            console.log("Withdrawal from Aave Pool failed");
            revert("Withdrawal from Aave Pool failed");
        }
        // aaveManager.withdrawETH(depositAmount);

        // Step 5: Unwrap WETH back into ETH
        uint256 wethBalanceAfterWithdraw = IERC20(wethaddress).balanceOf(user);
        console.log(
            "WETH balance after withdrawal from Pool:",
            wethBalanceAfterWithdraw
        );
        assert(wethBalanceAfterWithdraw >= depositAmount); // Ensure WETH is available
        // IERC20(aEthAddress).approve(
        //     gatewaywethaddress,
        //     wethBalanceAfterWithdraw
        // );
        // IWrappedTokenGatewayV3(gatewaywethaddress).withdrawETH(
        //     poolAddress,
        //     wethBalanceAfterWithdraw,
        //     user
        // );
        // console.log("Unwrapped WETH into ETH");

        // uint256 userBalanceAfter = user.balance;
        // console.log("User ETH balance after unwrapping:", userBalanceAfter);

        // // Check that the user's ETH balance increased after unwrapping
        // assert(userBalanceAfter > userBalanceBefore);

        vm.stopPrank();
    }
}
