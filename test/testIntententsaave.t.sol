// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {aaveIntents} from "../src/AaveIntents.sol";
import {AaveETHManager, IAEth, IWETH, IERC20, IWrappedTokenGatewayV3} from "../src/AAVEETHManager.sol";

contract AaveIntentsTest is Test {
    aaveIntents public intentsEngine;
    AaveETHManager public aaveManager;

    address user = address(1); // Test user address
    address constant aEthAddress = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8; // aave aEth address
    address constant poolAddress = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant wethaddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant gatewaywethaddress =
        0xA434D495249abE33E031Fe71a969B81f3c07950D;

    function setUp() public {
        vm.createSelectFork(
            "https://eth-mainnet.g.alchemy.com/v2/h3C4fdzbM6xyo_vdxqqxD2Ro1X_3xmgA"
        );
        // Deploy AaveETHManager and Intents Engine
        aaveManager = new AaveETHManager(aEthAddress, poolAddress);
        intentsEngine = new aaveIntents(
            payable(address(aaveManager)),
            aEthAddress
        );

        // Provide test user with initial ETH
        vm.deal(user, 1 ether);
    }

    function testDepositIntent() public {
        vm.startPrank(user);

        uint256 depositAmount = 1 ether;

        intentsEngine.command{value: depositAmount}("deposit 1 ETH");

        // Validate aEth balance after deposit
        uint256 useraEthBalance = IAEth(aEthAddress).balanceOf(user);
        assert(useraEthBalance > 0);

        vm.stopPrank();
    }

    function testWrongDepositIntent() public {
        vm.startPrank(user);

        uint256 depositAmount = 1 ether;

        // User executes "deposit" command through intents engine
        vm.expectRevert();
        intentsEngine.command{value: depositAmount}("deposjnc n js 1 ETH");

        vm.stopPrank();
    }

    function testWithdrawIntent() public {
        vm.startPrank(user);

        uint256 depositAmount = 1 ether;

        // User deposits ETH first
        intentsEngine.command{value: depositAmount}("deposit 1 ETH");

        // Verify aEth balance after deposit
        uint256 useraEthBalance = IAEth(aEthAddress).balanceOf(user);
        assert(useraEthBalance > 0);

        // Transfer aEth to Compound Manager to facilitate withdrawal
        IAEth(aEthAddress).transfer(address(aaveManager), useraEthBalance);

        // Get user WETH balance before withdrawal
        uint256 userBalanceBefore = user.balance;
        // User withdraws ETH using intents engine
        intentsEngine.command(
            string(
                abi.encodePacked(
                    "withdraw ",
                    _toString(useraEthBalance),
                    " ETH"
                )
            )
        );

        // Verify user ETH balance increased after withdrawal
        uint256 userBalanceAfter = user.balance;

        assert(userBalanceAfter > userBalanceBefore);

        vm.stopPrank();
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
