// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

interface IBaseStrategy {
    event PoolUpdated(uint256 lpTokenBalance, uint256 lpTokenBorrowed, uint256 lastBlockNumber, uint256 accFeeIndex,
        uint256 lpTokenBorrowedPlusInterest, uint256 lpInvariant, uint256 borrowedInvariant);
}
