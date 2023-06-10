// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../base/ILongStrategy.sol";

/// @title Interface for Rebalance Strategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used in strategies that rebalance collateral from liquidity loans
interface IRebalanceStrategy is ILongStrategy {

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

    /// @dev Calculate quantities to trade to rebalance collateral so that after withdrawing `amounts` we achieve desired `ratio`
    /// @param amounts - amounts that will be withdrawn from collateral
    /// @param tokensHeld - loan collateral to rebalance
    /// @param reserves - reserve token quantities in CFMM
    /// @param ratio - desired ratio of collateral after withdrawing `amounts`
    /// @return deltas - amount of collateral to trade to achieve desired `ratio`
    function calcDeltasForWithdrawal(uint128[] memory amounts, uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) external view returns(int256[] memory deltas);
}
