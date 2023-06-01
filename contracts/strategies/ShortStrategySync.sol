// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "./ShortStrategyERC4626.sol";

/// @title Short Strategy Synchronization abstract contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Inherits all functions from ShortStrategy already defined by inheriting ShortStrategyERC4626
/// @dev Only defines function to synchronize LP_TOKEN_BALANCE (deposit without issuing shares)
abstract contract ShortStrategySync is ShortStrategyERC4626 {

    /// @dev See {IShortStrategy-_sync}.
    function _sync() external virtual override lock {
        // Do not sync if no first deposit yet
        if(s.totalSupply == 0) revert ZeroShares();

        // Update interest rate and state variables before conversion
        updateIndex();

        // Update CFMM LP token amount tracked by GammaPool and invariant in CFMM belonging to GammaPool
        uint256 lpTokenBalance = GammaSwapLibrary.balanceOf(s.cfmm, address(this));
        uint128 lpInvariant = uint128(convertLPToInvariant(lpTokenBalance, s.lastCFMMInvariant, s.lastCFMMTotalSupply));
        s.LP_TOKEN_BALANCE = lpTokenBalance;
        s.LP_INVARIANT = lpInvariant;

        emit PoolUpdated(lpTokenBalance, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST,
            lpInvariant, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.SYNC);
    }
}
