// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ITransfers.sol";
import "../libraries/GammaSwapLibrary.sol";

/// @title Contract used to handle token transfers by the GammaPool
/// @author Daniel D. Alcarraz
/// @dev Abstract contract meant to be inherited by the GammaPool abstract contract to handle token transfers and clearing
abstract contract Transfers is ITransfers {

    error RestrictedToken();

    /// @dev Remove excess quantities of ERC20 token
    /// @param token - address of ERC20 token that will be transferred
    /// @param balance - quantity of ERC20 token to be expected to remain in GammaPool, excess will be withdrawn
    /// @param to - destination address where ERC20 token will be sent to
    function skim(address token, uint256 balance, address to) internal {
        uint256 newBalance = IERC20(token).balanceOf(address(this));
        if(newBalance > balance) {
            uint256 excessBalance;
            unchecked {
                excessBalance = newBalance - balance;
            }
            GammaSwapLibrary.safeTransfer(IERC20(token), to, excessBalance);
        }
    }

    /// @dev See {ITransfers-clearToken}
    function clearToken(address token, address to) external override {
        if(isCFMMToken(token) || isCollateralToken(token)) { // can't clear CFMM LP tokens or collateral tokens
            revert RestrictedToken();
        }

        uint256 tokenBal = IERC20(token).balanceOf(address(this));
        if (tokenBal > 0) GammaSwapLibrary.safeTransfer(IERC20(token), to, tokenBal); // if not CFMM LP token or collateral token send entire amount
    }

    /// @dev Check if ERC20 token is LP token of the CFMM the GammaPool is made for
    /// @param token - address of ERC20 token that will be checked
    /// @return bool - true if it is LP token of the CFMM the GammaPool is made for, false otherwise
    function isCFMMToken(address token) internal virtual view returns(bool);

    /// @dev Check if ERC20 token is a collateral token of the GammaPool
    /// @param token - address of ERC20 token that will be checked
    /// @return bool - true if it is a collateral token of the GammaPool, false otherwise
    function isCollateralToken(address token) internal virtual view returns(bool);
}
