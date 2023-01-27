// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./ILongStrategyEvents.sol";

/// @title Liquidation Strategy Events Interface
/// @author Daniel D. Alcarraz
/// @dev Events emitted by all liquidation strategy implementations
interface ILiquidationStrategyEvents is ILongStrategyEvents {
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
}