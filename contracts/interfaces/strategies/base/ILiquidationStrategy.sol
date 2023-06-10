// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../events/ILiquidationStrategyEvents.sol";

/// @title Interface for Liquidation Strategy contracts
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Parent interface of every Liquidation strategy
interface ILiquidationStrategy is ILiquidationStrategyEvents {
    /// @return minimum liquidation fee charged during liquidation of a loan
    function liquidationFee() external view returns(uint256);

    /// @dev Check if can liquidate loan based on liquidity debt and collateral
    /// @param liquidity - liquidity debt of loan
    /// @param collateral - liquidity invariant calculated from collateral tokens (`tokensHeld`)
    /// @return canLiquidate - true if loan can be liquidated, false otherwise
    function canLiquidate(uint256 liquidity, uint256 collateral) external view returns(bool);
}
