// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IRefunds.sol";
import "../libraries/GammaSwapLibrary.sol";

/// @title Contract used to handle token transfers by the GammaPool
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Abstract contract meant to be inherited by the GammaPool abstract contract to handle token transfers and clearing
abstract contract Refunds is IRefunds {

    error RestrictedToken();
    error NotEnoughTokens();

    /// @dev Remove excess quantities of ERC20 token
    /// @param token - address of ERC20 token that will be transferred
    /// @param balance - quantity of ERC20 token to be expected to remain in GammaPool, excess will be withdrawn
    /// @param to - destination address where ERC20 token will be sent to
    function skim(address token, uint256 balance, address to) internal virtual {
        uint256 newBalance = IERC20(token).balanceOf(address(this));
        if(newBalance > balance) {
            uint256 excessBalance;
            unchecked {
                excessBalance = newBalance - balance;
            }
            GammaSwapLibrary.safeTransfer(token, to, excessBalance);
        }
    }

    /// @dev See {ITransfers-clearToken}
    function clearToken(address token, address to, uint256 minAmt) external override virtual {
        // Can't clear CFMM LP tokens or collateral tokens
        if(isCFMMToken(token) || isCollateralToken(token)) revert RestrictedToken();

        uint256 tokenBal = IERC20(token).balanceOf(address(this));
        if(tokenBal < minAmt) revert NotEnoughTokens(); // Only clear if past threshold

        // If not CFMM LP token or collateral token send entire amount
        if (tokenBal > 0) GammaSwapLibrary.safeTransfer(token, to, tokenBal);
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
