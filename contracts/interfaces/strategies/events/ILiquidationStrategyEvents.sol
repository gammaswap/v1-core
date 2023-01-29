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
    /// @param writeDownAmt - amount of liquidity invariant being written down
    /// @param txType - type of liquidation. Possible values come from enum TX_TYPE
    /// @param tokenIds - list of tokenIds liquidated if batch liquidation
    event Liquidation(uint256 indexed tokenId, uint128 collateral, uint128 liquidity, uint128 writeDownAmt, TX_TYPE txType, uint256[] tokenIds);
}