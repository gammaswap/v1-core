// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../events/ILongStrategyEvents.sol";

/// @title Interface for Long Strategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used in strategies that borrow and repay liquidity loans
interface ILongStrategy is ILongStrategyEvents {
    /// @dev Deposit more collateral in loan identified by tokenId
    /// @param tokenId - unique id identifying loan
    /// @return tokensHeld - updated collateral token amounts backing loan
    function _increaseCollateral(uint256 tokenId) external returns(uint128[] memory tokensHeld);

    /// @dev Withdraw collateral from loan identified by tokenId
    /// @param tokenId - unique id identifying loan
    /// @param amounts - amounts of collateral tokens requested to withdraw
    /// @param to - destination address of receiver of collateral withdrawn
    /// @return tokensHeld - updated collateral token amounts backing loan
    function _decreaseCollateral(uint256 tokenId, uint128[] calldata amounts, address to) external returns(uint128[] memory tokensHeld);

    /// @dev Borrow liquidity from the CFMM and add it to the debt and collateral of loan identified by tokenId
    /// @param tokenId - unique id identifying loan
    /// @param lpTokens - amount of CFMM LP tokens requested to short
    /// @param ratio - weights of collateral after borrowing liquidity
    /// @return liquidityBorrowed - liquidity amount that has been borrowed
    /// @return amounts - reserves quantities withdrawn from CFMM that correspond to the LP tokens shorted, now used as collateral
    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens, uint256[] calldata ratio) external returns(uint256 liquidityBorrowed, uint256[] memory amounts);

    /// @dev Repay liquidity debt of loan identified by tokenId, debt is repaid using available collateral in loan
    /// @param tokenId - unique id identifying loan
    /// @param liquidity - liquidity debt being repaid, capped at actual liquidity owed. Can't repay more than you owe
    /// @param fees - fee on transfer for tokens[i]. Send empty array if no token in pool has fee on transfer or array of zeroes
    /// @param collateralId - index of collateral token to rebalance to + 1
    /// @param to - if repayment type requires withdrawal, the address that will receive the funds. Otherwise can be zero address
    /// @return liquidityPaid - liquidity amount that has been repaid
    /// @return amounts - collateral amounts consumed in repaying liquidity debt
    function _repayLiquidity(uint256 tokenId, uint256 liquidity, uint256[] calldata fees, uint256 collateralId, address to) external returns(uint256 liquidityPaid, uint256[] memory amounts);

    /// @dev Rebalance collateral amounts of loan identified by tokenId by purchasing or selling some of the collateral
    /// @param tokenId - unique id identifying loan
    /// @param deltas - collateral amounts being bought or sold (>0 buy, <0 sell), index matches tokensHeld[] index. Only n-1 tokens can be traded
    /// @param ratio - weights of collateral after borrowing liquidity
    /// @return tokensHeld - updated collateral token amounts backing loan
    function _rebalanceCollateral(uint256 tokenId, int256[] memory deltas, uint256[] calldata ratio) external returns(uint128[] memory tokensHeld);

    /// @dev Update pool liquidity debt and loan liquidity debt
    /// @param tokenId - (optional) unique id identifying loan
    /// @return loanLiquidityDebt - updated liquidity debt amount of loan
    /// @return poolLiquidityDebt - updated liquidity debt amount of pool
    function _updatePool(uint256 tokenId) external returns(uint256 loanLiquidityDebt, uint256 poolLiquidityDebt);

    /// @dev Calculate quantities to trade to rebalance collateral to desired `ratio`
    /// @param tokensHeld - loan collateral to rebalance
    /// @param reserves - reserve token quantities in CFMM
    /// @param ratio - desired ratio of collateral
    /// @return deltas - amount of collateral to trade to achieve desired `ratio`
    function calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) external view returns(int256[] memory deltas);

    /// @dev Calculate quantities to trade to be able to close the `liquidity` amount
    /// @param tokensHeld - tokens held as collateral for liquidity to pay
    /// @param reserves - reserve token quantities in CFMM
    /// @param liquidity - amount of liquidity to pay
    /// @param collateralId - index of tokensHeld array to rebalance to (e.g. the collateral of the chosen index will be completely used up in repayment)
    /// @return deltas - amounts of collateral to trade to be able to repay `liquidity`
    function calcDeltasToClose(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity, uint256 collateralId) external view returns(int256[] memory deltas);
}
