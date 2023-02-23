// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title External Callee Interface to handle flash loan requests
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used by external addresses performing an external swap/flash loan with the pool's collateral and/or CFMM LP tokens
interface IExternalCallee {
    /// @dev Perform external swap or whatever logic is used with flash loaned funds from GammaPool
    /// @param sender - address that requested the flash loan
    /// @param amounts - collateral token amounts flash loaned from GammaPool
    /// @param lpTokens - quantity of CFMM LP tokens flash loaned
    /// @param data - optional bytes parameter for custom user defined data
    function externalCall(address sender, uint128[] calldata amounts, uint256 lpTokens, bytes calldata data) external;
}
