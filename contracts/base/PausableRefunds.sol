// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "./Refunds.sol";
import "../utils/Pausable.sol";

/// @title Contract used to handle token transfers by the GammaPool where the clearToken function is pausable
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Abstract contract meant to be inherited by the GammaPool abstract contract to handle token transfers and pausable clearing
abstract contract PausableRefunds is Refunds, Pausable {

    /// @dev See {ITransfers-clearToken}
    function clearToken(address token, address to, uint256 minAmt) external override virtual whenNotPaused(23) {
        // Can't clear CFMM LP tokens or collateral tokens
        if(isCFMMToken(token) || isCollateralToken(token)) revert RestrictedToken();

        uint256 tokenBal = IERC20(token).balanceOf(address(this));
        if(tokenBal < minAmt) revert NotEnoughTokens(); // Only clear if past threshold

        // If not CFMM LP token or collateral token send entire amount
        if (tokenBal > 0) GammaSwapLibrary.safeTransfer(token, to, tokenBal);
    }
}
