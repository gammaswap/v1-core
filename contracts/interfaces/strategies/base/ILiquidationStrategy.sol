// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./IBaseLongStrategy.sol";

/// @title Interface for Liquidation Strategy contract used in all strategies
/// @author Daniel D. Alcarraz
/// @dev Only used to define PoolUpdated event to avoid redefining the event in all strategies
interface ILiquidationStrategy is IBaseLongStrategy {
    /// @dev Event emitted when liquidating through _liquidate or _liquidateWithLP functions
    /// @param tokenId - id identifier of loan being liquidated
    /// @param collateral - collateral of loan being liquidated
    /// @param liquidity - liquidity debt being repaid
    /// @param typ - type of liquidation (0 without LP, 1 with LP)
    event Liquidation(uint256 indexed tokenId, uint256 collateral, uint256 liquidity, uint8 typ);

    /// @dev Event emitted when liquidating in a batch liquidation
    /// @param liquidityTotal - total liquidity debt of loans being liquidated
    /// @param collateralTotal - total collateral of loans being liquidated
    /// @param lpTokensPrincipalTotal - total lp token principal of loans being liquidated
    /// @param tokensHeldTotal - total collateral in ERC20 tokens from tokens being liquidated
    /// @param tokenIds - list of tokenIds to liquidate
    event BatchLiquidations(uint256 liquidityTotal, uint256 collateralTotal, uint256 lpTokensPrincipalTotal, uint128[] tokensHeldTotal, uint256[] tokenIds);

    /// @dev Event emitted when writing down a loan's debt during liquidation due to bad debt
    /// @param tokenId - tokenId of loan being written down
    /// @param writeDownAmt - amount being written down
    event WriteDown(uint256 indexed tokenId, uint256 writeDownAmt);

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
