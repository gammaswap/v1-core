// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "./BaseLongStrategy.sol";

/// @title Base Rebalance Strategy abstract contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Common internal functions used by all strategy implementations that need rebalance loan collateral
/// @dev This contract inherits from BaseLongStrategy and should be inherited by strategies that need to rebalance collateral
abstract contract BaseRebalanceStrategy is BaseLongStrategy {

    error InvalidDeltasLength();
    error InvalidRatioLength();

    /// @dev Calculate quantities to trade to rebalance collateral to desired `ratio`
    /// @param tokensHeld - loan collateral to rebalance
    /// @param reserves - reserve token quantities in CFMM
    /// @param ratio - desired ratio of collateral
    /// @return deltas - amount of collateral to trade to achieve desired `ratio`
    function _calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) internal virtual view returns(int256[] memory deltas);

    /// @dev Calculate quantities to trade to be able to close the `liquidity` amount
    /// @param tokensHeld - tokens held as collateral for liquidity to pay
    /// @param reserves - reserve token quantities in CFMM
    /// @param liquidity - amount of liquidity to pay
    /// @param collateralId - index of tokensHeld array to rebalance to (e.g. the collateral of the chosen index will be completely used up in repayment)
    /// @return deltas - amounts of collateral to trade to be able to repay `liquidity`
    function _calcDeltasToClose(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity, uint256 collateralId) internal virtual view returns(int256[] memory deltas);

    /// @dev Calculate quantities to trade to rebalance collateral so that after withdrawing `amounts` we achieve desired `ratio`
    /// @param amounts - amounts that will be withdrawn from collateral
    /// @param tokensHeld - loan collateral to rebalance
    /// @param reserves - reserve token quantities in CFMM
    /// @param ratio - desired ratio of collateral after withdrawing `amounts`
    /// @return deltas - amount of collateral to trade to achieve desired `ratio`
    function _calcDeltasForWithdrawal(uint128[] memory amounts, uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) internal virtual view returns(int256[] memory deltas);

    /// @dev Check if loan is undercollateralized
    /// @param collateral - liquidity invariant collateral
    /// @param liquidity - liquidity invariant debt
    function checkMargin(uint256 collateral, uint256 liquidity) internal override virtual view {
        if(!hasMargin(collateral, liquidity, _ltvThreshold())) revert Margin(); // revert if collateral below ltvThreshold
    }

    /// @dev Withdraw loan collateral
    /// @param _loan - loan whose collateral will be rebalanced
    /// @param deltas - collateral amounts being bought or sold (>0 buy, <0 sell), index matches tokensHeld[] index. Only n-1 tokens can be traded
    /// @return tokensHeld - loan collateral after rebalancing
    /// @return tokenChange - change in token amounts
    function rebalanceCollateral(LibStorage.Loan storage _loan, int256[] memory deltas, uint128[] memory reserves) internal virtual returns(uint128[] memory tokensHeld, int256[] memory tokenChange) {
        // Calculate amounts to swap from deltas and available loan collateral
        (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(_loan, deltas, reserves);

        // Swap tokens
        swapTokens(_loan, outAmts, inAmts);

        // Update loan collateral tokens after swap
        (tokensHeld,tokenChange) = updateCollateral(_loan);
    }

    /// @dev Withdraw loan collateral
    /// @param _loan - loan whose collateral will bee withdrawn
    /// @param loanLiquidity - total liquidity debt of loan
    /// @param amounts - amounts of collateral to withdraw
    /// @param to - address that will receive collateral withdrawn
    /// @return tokensHeld - remaining loan collateral after withdrawal
    function withdrawCollateral(LibStorage.Loan storage _loan, uint256 loanLiquidity, uint128[] memory amounts, address to) internal virtual returns(uint128[] memory tokensHeld) {
        if(amounts.length != _loan.tokensHeld.length) revert InvalidAmountsLength();

        // Withdraw collateral tokens from loan
        sendTokens(_loan, to, amounts);

        // Update loan collateral token amounts after withdrawal
        (tokensHeld,) = updateCollateral(_loan);

        // Revert if collateral invariant is below threshold after withdrawal
        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        checkMargin(collateral, loanLiquidity);
    }
}
