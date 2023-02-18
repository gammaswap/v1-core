// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "./ShortStrategyERC4626.sol";

abstract contract ShortStrategySync is ShortStrategyERC4626 {

    /// @dev See {IShortStrategy-_sync}.
    function _sync() external virtual override lock {
        // Do not sync if no first deposit yet
        if(s.totalSupply == 0) {
            revert ZeroShares();
        }

        // Update interest rate and state variables before conversion
        updateIndex();

        // Update CFMM LP token amount tracked by GammaPool and invariant in CFMM belonging to GammaPool
        uint256 lpTokenBalance = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this));
        uint128 lpInvariant = uint128(convertLPToInvariant(lpTokenBalance, s.lastCFMMInvariant, s.lastCFMMTotalSupply));
        s.LP_TOKEN_BALANCE = lpTokenBalance;
        s.LP_INVARIANT = lpInvariant;

        emit PoolUpdated(lpTokenBalance, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST,
            lpInvariant, s.BORROWED_INVARIANT, TX_TYPE.SYNC);
    }
}
