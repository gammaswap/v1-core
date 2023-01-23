// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

/// @title Interface for Transfers abstract contract
/// @author Daniel D. Alcarraz
/// @dev Interface used to clear tokens from the GammaPool
interface ITransfers {
    /// @dev Withdraw entire amount from the GammaPool of ERC20 tokens that are not collateral tokens or LP tokens of the GammaPool's cfmm
    /// @param token - address of ERC20 token that is not used as collateral or as an LP token of the GammaPool's cfmm
    /// @param to - destination address where withdrawn quantity will be sent to
    function clearToken(address token, address to) external;
}
