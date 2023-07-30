// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title Strategy Events interface
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Events that should be emitted by all strategy implementations (root of all strategy events interfaces)
interface IStrategyEvents {
    enum TX_TYPE {
        DEPOSIT_LIQUIDITY,      // 0
        WITHDRAW_LIQUIDITY,     // 1
        DEPOSIT_RESERVES,       // 2
        WITHDRAW_RESERVES,      // 3
        INCREASE_COLLATERAL,    // 4
        DECREASE_COLLATERAL,    // 5
        REBALANCE_COLLATERAL,   // 6
        BORROW_LIQUIDITY,       // 7
        REPAY_LIQUIDITY,        // 8
        REPAY_LIQUIDITY_SET_RATIO,// 9
        REPAY_LIQUIDITY_WITH_LP,// 10
        LIQUIDATE,              // 11
        LIQUIDATE_WITH_LP,      // 12
        BATCH_LIQUIDATION,      // 13
        SYNC,                   // 14
        EXTERNAL_REBALANCE,     // 15
        EXTERNAL_LIQUIDATION,   // 16
        UPDATE_POOL }           // 17

    /// @dev Event emitted when the Pool's global state variables is updated
    /// @param lpTokenBalance - quantity of CFMM LP tokens deposited in the pool
    /// @param lpTokenBorrowed - quantity of CFMM LP tokens that have been borrowed from the pool (principal)
    /// @param lastBlockNumber - last block the Pool's where updated
    /// @param accFeeIndex - interest of total accrued interest in the GammaPool until current update
    /// @param lpTokenBorrowedPlusInterest - quantity of CFMM LP tokens that have been borrowed from the pool including interest
    /// @param lpInvariant - lpTokenBalance as invariant units
    /// @param borrowedInvariant - lpTokenBorrowedPlusInterest as invariant units
    /// @param cfmmReserves - reserves in CFMM. Used to track price
    /// @param txType - transaction type. Possible values come from enum TX_TYPE
    event PoolUpdated(uint256 lpTokenBalance, uint256 lpTokenBorrowed, uint40 lastBlockNumber, uint80 accFeeIndex,
        uint256 lpTokenBorrowedPlusInterest, uint128 lpInvariant, uint128 borrowedInvariant, uint128[] cfmmReserves, TX_TYPE indexed txType);
}