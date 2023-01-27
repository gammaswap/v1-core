// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

/// @title Interface for Refunds abstract contract
/// @author Daniel D. Alcarraz
/// @dev Interface used to clear tokens from a contract
interface IRefunds {
    /// @dev Withdraw ERC20 tokens from contract
    /// @param token - address of ERC20 token that will be withdrawn
    /// @param to - destination address where withdrawn quantity will be sent to
    /// @param minAmt - threshold balance before token can be withdrawn
    function clearToken(address token, address to, uint256 minAmt) external;
}
