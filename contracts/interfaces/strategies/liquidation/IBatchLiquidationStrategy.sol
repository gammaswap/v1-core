// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../base/ILiquidationStrategy.sol";

/// @title Interface for Batch Liquidation Strategy contracts
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Defines function to liquidate loans in batch
interface IBatchLiquidationStrategy is ILiquidationStrategy {
    /// @dev Function to liquidate multiple loans in batch.
    /// @param tokenIds - list of tokenIds of loans to liquidate
    /// @return totalLoanLiquidity - total loan liquidity liquidated (after write down)
    /// @return refund - amounts from collateral tokens being refunded to liquidator
    function _batchLiquidations(uint256[] calldata tokenIds) external returns(uint256 totalLoanLiquidity, uint128[] memory refund);
}
