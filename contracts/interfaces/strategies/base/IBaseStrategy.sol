// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

/// @title Interface for Base Strategy contract used in all strategies
/// @author Daniel D. Alcarraz
/// @dev Only used to define PoolUpdated event to avoid redefining the event in all strategies
interface IBaseStrategy {
    /// @dev Event emitted when the Pool's global state variables is updated
    /// @param lpTokenBalance - LP Tokens of the cfmm deposited in the pool
    /// @param lpTokenBorrowed - LP tokens of the cfmm that have been borrowed from the pool (principal)
    /// @param lastBlockNumber - last block the Pool's where updated
    /// @param accFeeIndex - interest of total accrued interest in the GammaPool until current update
    /// @param lpTokenBorrowedPlusInterest - LP tokens of the cfmm that have been borrowed from the pool including interest
    /// @param lpInvariant - invariant deposited in the pool through LP tokens of the cfmm, maps to lpTokenBalance
    /// @param borrowedInvariant - invariant borrowed from GammaPool including interest, mapx to lpTokenBorrowedPlusInterest
    event PoolUpdated(uint256 lpTokenBalance, uint256 lpTokenBorrowed, uint256 lastBlockNumber, uint256 accFeeIndex,
        uint256 lpTokenBorrowedPlusInterest, uint256 lpInvariant, uint256 borrowedInvariant);
}
