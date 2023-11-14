// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../../strategies/ShortStrategySync.sol";
import "./TestBaseShortStrategy.sol";

contract TestShortStrategySync is TestBaseShortStrategy, ShortStrategySync {

    function _getLatestCFMMReserves(bytes memory) external override(IShortStrategy, TestBaseShortStrategy) pure returns(uint128[] memory cfmmReserves) {
        cfmmReserves = new uint128[](2);
        cfmmReserves[0] = 1;
        cfmmReserves[1] = 2;
    }

    function mintToDevs(uint256 lastFeeIndex, uint256 lastCFMMIndex, uint256 utilizationRate) internal override(BaseStrategy, TestBaseShortStrategy) virtual {
    }

    function _deposit(uint256, address) external override(IShortStrategy, ShortStrategyERC4626) pure returns (uint256){
        return 0;
    }

    function _mint(uint256, address) external override(IShortStrategy, ShortStrategyERC4626) pure returns (uint256){
        return 0;
    }

    function _withdraw(uint256, address, address) external override(IShortStrategy, ShortStrategyERC4626) pure returns (uint256){
        return 0;
    }

    function _redeem(uint256, address, address) external override(IShortStrategy, ShortStrategyERC4626) pure returns (uint256){
        return 0;
    }

    function getTotalAssetsParams2() public virtual view returns(uint256 borrowedInvariant, uint256 lpBalance, uint256 lpBorrowed, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlockNum,
        uint256 lpTokenTotal, uint256 lpTokenBorrowedPlusInterest, uint256 lpInvariant, uint128[] memory tokenBalances) {
        borrowedInvariant = s.BORROWED_INVARIANT;
        lpBalance = s.LP_TOKEN_BALANCE;
        lpBorrowed = s.LP_TOKEN_BORROWED;
        prevCFMMInvariant = s.lastCFMMInvariant;
        prevCFMMTotalSupply = s.lastCFMMTotalSupply;
        lastBlockNum = s.LAST_BLOCK_NUMBER;
        lpTokenBorrowedPlusInterest = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        lpTokenTotal = lpBalance + lpTokenBorrowedPlusInterest;
        lpInvariant = s.LP_INVARIANT;
        tokenBalances = s.TOKEN_BALANCE;
    }
}
