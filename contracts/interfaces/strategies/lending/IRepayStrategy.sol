// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../base/ILongStrategy.sol";

/// @title Interface for Long Strategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used in strategies that borrow and repay liquidity loans
interface IRepayStrategy is ILongStrategy {

    /// @dev Repay liquidity debt of loan identified by tokenId, debt is repaid using available collateral in loan
    /// @param tokenId - unique id identifying loan
    /// @param liquidity - liquidity debt being repaid, capped at actual liquidity owed. Can't repay more than you owe
    /// @param fees - fee on transfer for tokens[i]. Send empty array if no token in pool has fee on transfer or array of zeroes
    /// @param collateralId - index of collateral token to rebalance to + 1
    /// @param to - if repayment type requires withdrawal, the address that will receive the funds. Otherwise can be zero address
    /// @return liquidityPaid - liquidity amount that has been repaid
    /// @return amounts - collateral amounts consumed in repaying liquidity debt
    function _repayLiquidity(uint256 tokenId, uint256 liquidity, uint256[] calldata fees, uint256 collateralId, address to) external returns(uint256 liquidityPaid, uint256[] memory amounts);
}
