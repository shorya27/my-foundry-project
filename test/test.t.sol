// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {AaveETHManager, IAEth, IWETH, IERC20, IPoolAaveV3, IWrappedTokenGatewayV3} from "../src/AAVEETHManager.sol";

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
        vm.deal(user, 1 ether); // Provide ETH to the test user
    }

    function testDepositETH() public {
        vm.startPrank(user);
        uint256 depositAmount = 1 ether;

        // Step 3: Deposit WETH into Aave Pool
        aaveManager.depositETH{value: depositAmount}();

        uint256 aEthBalance = IAEth(aEthAddress).balanceOf(user);
        assert(aEthBalance > 0);

        vm.stopPrank();
    }

    function testWithdrawETH() public {
        vm.startPrank(user);
        uint256 depositAmount = 1 ether;

        aaveManager.depositETH{value: depositAmount}();

        uint256 aEthBalance = IERC20(aEthAddress).balanceOf(user);
        assert(aEthBalance > 0); // Ensure aETH is credited

        uint256 userWETHBalanceBefore = IERC20(wethaddress).balanceOf(user);
        IERC20(aEthAddress).transfer(address(aaveManager), aEthBalance);
        aaveManager.withdrawETH(aEthBalance);
        uint256 userWETHBalanceAfter = IERC20(wethaddress).balanceOf(user);
        assert(userWETHBalanceAfter > userWETHBalanceBefore);
        //The user will be left with WETH Tokens in the end Not ETH currency which he/she can redeem for corresponding ETH
        vm.stopPrank();
    }
}
