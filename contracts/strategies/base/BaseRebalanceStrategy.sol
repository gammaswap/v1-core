// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "./BaseLongStrategy.sol";

/// @title Base Rebalance Strategy abstract contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Common internal functions used by all strategy implementations that need rebalance loan collateral
/// @dev This contract inherits from BaseLongStrategy and should be inherited by strategies that need to rebalance collateral
abstract contract BaseRebalanceStrategy is BaseLongStrategy {

    /// @dev Calculate quantities to trade to rebalance collateral to desired `ratio`
    /// @param deltas - amount of collateral to trade to achieve desired final collateral amount
    /// @param tokensHeld - loan collateral to rebalance
    /// @param reserves - reserve token quantities in CFMM
    /// @return collateral - collateral amount
    function _calcCollateralPostTrade(int256[] memory deltas, uint128[] memory tokensHeld, uint128[] memory reserves) internal virtual view returns(uint256 collateral);

    /// @dev Calculate quantities to trade to rebalance collateral to desired `ratio`
    /// @param tokensHeld - loan collateral to rebalance
    /// @param reserves - reserve token quantities in CFMM
    /// @return deltas - amount of collateral to trade to achieve desired `ratio`
    function _calcDeltasForMaxLP(uint128[] memory tokensHeld, uint128[] memory reserves) internal virtual view returns(int256[] memory deltas);

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

    /// @dev Calculate quantities to trade to be able to close the `liquidity` amount
    /// @param tokensHeld - tokens held as collateral for liquidity to pay
    /// @param reserves - reserve token quantities in CFMM
    /// @param liquidity - amount of liquidity to pay
    /// @param ratio - desired ratio of collateral
    /// @return deltas - amounts of collateral to trade to be able to repay `liquidity`
    function _calcDeltasToCloseSetRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity, uint256[] memory ratio) internal virtual view returns(int256[] memory deltas);

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

    /// @dev Check if ratio parameter is valid
    /// @param ratio - ratio parameter to rebalance collateral
    /// @return isValid - true if ratio parameter is valid, false otherwise
    function isRatioValid(uint256[] memory ratio) internal virtual view returns(bool) {
        uint256 len = s.tokens.length;
        if(ratio.length != len) {
            return false;
        }
        for(uint256 i = 0; i < len;) {
            if(ratio[i] < 1000) {
                return false;
            }
            unchecked {
                ++i;
            }
        }
        return true;
    }

    /// @dev Check if deltas parameter is valid
    /// @param deltas - deltas parameter to rebalance collateral
    /// @return isValid - true if ratio parameter is valid, false otherwise
    function isDeltasValid(int256[] memory deltas) internal virtual view returns(bool) {
        uint256 len = s.tokens.length;
        if(deltas.length != len) {
            return false;
        }
        uint256 nonZeroCount = 0;
        for(uint256 i = 0; i < len;) {
            if(deltas[i] != 0) {
                ++nonZeroCount;
            }
            unchecked {
                ++i;
            }
        }
        return nonZeroCount == 1;
    }

    /// @dev Rebalance loan collateral through a swap with the CFMM
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
    /// @param amounts - amounts of collateral to withdraw
    /// @param to - address that will receive collateral withdrawn
    /// @return tokensHeld - remaining loan collateral after withdrawal
    function withdrawCollateral(LibStorage.Loan storage _loan, uint128[] memory amounts, address to) internal virtual returns(uint128[] memory tokensHeld) {
        if(amounts.length != _loan.tokensHeld.length) revert InvalidAmountsLength();

        // Withdraw collateral tokens from loan
        sendTokens(_loan, to, amounts);

        // Update loan collateral token amounts after withdrawal
        (tokensHeld,) = updateCollateral(_loan);
    }
}
