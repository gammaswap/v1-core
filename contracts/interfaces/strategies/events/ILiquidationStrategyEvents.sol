// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "./ILongStrategyEvents.sol";

/// @title Liquidation Strategy Events Interface
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Events emitted by all liquidation strategy implementations
interface ILiquidationStrategyEvents is ILongStrategyEvents {
    /// @dev Event emitted when liquidating through _liquidate or _liquidateWithLP functions
    /// @param tokenId - id identifier of loan being liquidated
    /// @param collateral - collateral of loan being liquidated
    /// @param liquidity - liquidity debt being repaid
    /// @param writeDownAmt - amount of liquidity invariant being written down
    /// @param fee - liquidation fee paid to liquidator in liquidity invariant units
    /// @param txType - type of liquidation. Possible values come from enum TX_TYPE
    event Liquidation(uint256 indexed tokenId, uint128 collateral, uint128 liquidity, uint128 writeDownAmt, uint128 fee, TX_TYPE txType);
}