// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {Test, console} from "forge-std/Test.sol";

interface IAEth {
    function mintOnDeposit(address account, uint256 amount) external payable; //only lending pools can call this so how will we call?? **********

    function redeem(uint256 redeemTokens) external;

    function balanceOf(address owner) external view returns (uint256);

    function transfer(address dst, uint256 amount) external returns (bool);

    function approve(address, uint256) external returns (bool);
}

interface IWrappedTokenGatewayV3 {
    function depositETH(
        address pool,
        address onBehalfOf,
        uint16 referralCode
    ) external payable;

    function withdrawETH(
        address pool,
        uint256 amount,
        address onBehalfOf
    ) external;

    function repayETH(
        address pool,
        uint256 amount,
        address onBehalfOf
    ) external payable;

    function borrowETH(
        address pool,
        uint256 amount,
        uint16 referralCode
    ) external;

    function withdrawETHWithPermit(
        address pool,
        uint256 amount,
        address to,
        uint256 deadline,
        uint8 permitV,
        bytes32 permitR,
        bytes32 permitS
    ) external;
}

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IWETH {
    function deposit() external payable;

    function withdraw(uint256 wad) external;

    function approve(address guy, uint256 wad) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 wad
    ) external returns (bool);
}

interface IPoolAaveV3 {
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    /**
     * @notice Returns the user account data across all the reserves
     * @param user The address of the user
     * @return totalCollateralBase The total collateral of the user in the base currency used by the price feed
     * @return totalDebtBase The total debt of the user in the base currency used by the price feed
     * @return availableBorrowsBase The borrowing power left of the user in the base currency used by the price feed
     * @return currentLiquidationThreshold The liquidation threshold of the user
     * @return ltv The loan to value of The user
     * @return healthFactor The current health factor of the user
     */
    function getUserAccountData(
        address user
    )
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}

contract AaveETHManager {
    address public immutable aEthAddress;
    address public immutable poolAddress;
    address constant wethaddress = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor(address _aEthAddress, address _lendingpool) {
        aEthAddress = _aEthAddress;
        poolAddress = _lendingpool;
    }

    function depositETH() external payable {
        require(msg.value > 0, "Must send ETH");

        IWETH(wethaddress).deposit{value: msg.value}();
        uint256 wethBalance = IERC20(wethaddress).balanceOf(address(this));

        IERC20(wethaddress).approve(poolAddress, wethBalance);

        IERC20(wethaddress).allowance(address(this), poolAddress);

        IPoolAaveV3(poolAddress).supply(
            wethaddress,
            wethBalance,
            msg.sender,
            0
        );
    }

    function withdrawETH(uint256 aWEthAmount) external {
        require(aWEthAmount > 0, "Invalid aEth amount");
        IPoolAaveV3(poolAddress).withdraw(
            wethaddress,
            IERC20(aEthAddress).balanceOf(address(this)),
            address(this)
        );

        IWETH(wethaddress).withdraw(
            IERC20(wethaddress).balanceOf(address(this))
        );
        (bool ok, ) = payable(msg.sender).call{value: address(this).balance}(
            ""
        );
        require(ok, "Withdrawal failed.");
    }

    // function getaEthBalance(address user) external view returns (uint256) {
    //     return aEth.balanceOf(user);
    // }

    receive() external payable {}

    fallback() external payable {}
}
