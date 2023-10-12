// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../base/ILongStrategy.sol";

/// @title Interface for Repay Strategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used in strategies that repay liquidity loans
interface IRepayStrategy is ILongStrategy {

    /// @dev Repay liquidity debt of loan identified by tokenId, using CFMM LP token
    /// @param tokenId - unique id identifying loan
    /// @param collateralId - index of collateral token to rebalance to + 1
    /// @param to - if repayment type requires withdrawal, the address that will receive the funds. Otherwise can be zero address
    /// @return liquidityPaid - liquidity amount that has been repaid
    /// @return tokensHeld - remaining token amounts collateralizing loan
    function _repayLiquidityWithLP(uint256 tokenId, uint256 collateralId, address to) external returns(uint256 liquidityPaid, uint128[] memory tokensHeld);

    /// @dev Repay liquidity debt of loan identified by tokenId, debt is repaid using available collateral in loan
    /// @param tokenId - unique id identifying loan
    /// @param liquidity - liquidity debt being repaid, capped at actual liquidity owed. Can't repay more than you owe
    /// @param collateralId - index of collateral token to rebalance to + 1
    /// @param to - if repayment type requires withdrawal, the address that will receive the funds. Otherwise can be zero address
    /// @return liquidityPaid - liquidity amount that has been repaid
    /// @return amounts - collateral amounts consumed in repaying liquidity debt
    function _repayLiquidity(uint256 tokenId, uint256 liquidity, uint256 collateralId, address to) external returns(uint256 liquidityPaid, uint256[] memory amounts);

    /// @dev Repay liquidity debt of loan identified by tokenId, debt is repaid using available collateral in loan
    /// @param tokenId - unique id identifying loan
    /// @param liquidity - liquidity debt being repaid, capped at actual liquidity owed. Can't repay more than you owe
    /// @param ratio - weights of collateral after repaying liquidity
    /// @return liquidityPaid - liquidity amount that has been repaid
    /// @return amounts - collateral amounts consumed in repaying liquidity debt
    function _repayLiquiditySetRatio(uint256 tokenId, uint256 liquidity, uint256[] calldata ratio) external returns(uint256 liquidityPaid, uint256[] memory amounts);
}
