// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../events/ILiquidationStrategyEvents.sol";

/// @title Interface for Liquidation Strategy contract used in all strategies
/// @author Daniel D. Alcarraz
/// @dev Only used to define PoolUpdated event to avoid redefining the event in all strategies
interface ILiquidationStrategy is ILiquidationStrategyEvents {
    /// @notice When calling this function and adding additional collateral it is assumed that you have sent the collateral first
    /// @dev Function to liquidate a loan using its own collateral or depositing additional tokens. Seeks full liquidation
    /// @param tokenId - tokenId of loan being liquidated
    /// @param deltas - amount tokens to trade to re-balance the collateral
    /// @return refund - amounts from collateral tokens being refunded to liquidator
    function _liquidate(uint256 tokenId, int256[] calldata deltas) external returns(uint256[] memory refund);

    /// @dev Function to liquidate a loan using external LP tokens. Allows partial liquidation
    /// @param tokenId - tokenId of loan being liquidated
    /// @return refund - amounts from collateral tokens being refunded to liquidator
    function _liquidateWithLP(uint256 tokenId) external returns(uint256[] memory refund);

    /// @dev Function to liquidate multiple loans in batch.
    /// @param tokenIds - list of tokenIds of loans to liquidate
    /// @return refund - amounts from collateral tokens being refunded to liquidator
    function _batchLiquidations(uint256[] calldata tokenIds) external returns(uint256[] memory refund);
}
