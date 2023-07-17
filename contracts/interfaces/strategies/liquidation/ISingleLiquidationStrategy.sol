// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../base/ILiquidationStrategy.sol";

/// @title Interface for Liquidation Strategy contract used in all strategies
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used in liquidation strategie sthat liquidate individual loans using its own collateral, or externa CFMM LP deposits
interface ISingleLiquidationStrategy is ILiquidationStrategy {
    /// @notice When calling this function and adding additional collateral it is assumed that you have sent the collateral first
    /// @dev Function to liquidate a loan using its own collateral or depositing additional tokens. Seeks full liquidation
    /// @param tokenId - tokenId of loan being liquidated
    /// @return loanLiquidity - loan liquidity liquidated (after write down)
    /// @return refund - amount of CFMM LP tokens being refunded to liquidator
    function _liquidate(uint256 tokenId) external returns(uint256 loanLiquidity, uint256 refund);

    /// @dev Function to liquidate a loan using external LP tokens. Allows partial liquidation
    /// @param tokenId - tokenId of loan being liquidated
    /// @return loanLiquidity - loan liquidity liquidated (after write down)
    /// @return refund - amounts from collateral tokens being refunded to liquidator
    function _liquidateWithLP(uint256 tokenId) external returns(uint256 loanLiquidity, uint128[] memory refund);
}
