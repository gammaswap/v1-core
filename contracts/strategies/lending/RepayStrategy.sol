// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/strategies/lending/IRepayStrategy.sol";
import "../base/BaseRepayStrategy.sol";

/// @title Repay Strategy abstract contract implementation of IRepayStrategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice All external functions are locked to avoid reentrancy
/// @dev Defines external functions for concrete contract implementations to allow external accounts to repay liquidity loans
/// @dev Inherits BaseRebalanceStrategy because RepayStrategy needs to rebalance collateral to repay a loan
abstract contract RepayStrategy is IRepayStrategy, BaseRepayStrategy {

    error ExternalCollateralRef();
    error ZeroRepayLiquidity();
    error BadDebt();

    /// @dev Calculate remaining collateral after rebalancing. Used for calculating remaining partial collateral
    /// @param collateral - collateral amounts before collateral changes
    /// @param deltas - collateral changes
    /// @param padding - padding to add from previous padding subtraction
    /// @return remaining - remaining collateral after collateral changes
    function remainingCollateral(uint128[] memory collateral, int256[] memory deltas, uint128 padding) internal virtual view returns(uint128[] memory) {
        uint256 tokenCount = deltas.length;
        for(uint256 i = 0; i < tokenCount;) {
            int256 delta = deltas[i];
            if(delta > 0) {
                collateral[i] += uint128(uint256(delta));
            } else if(delta < 0) {
                uint128 _delta = uint128(uint256(-delta));
                if(_delta > collateral[i]) { // in case rounding issue
                    collateral[i] = 0;
                } else {
                    unchecked {
                        collateral[i] -= _delta;
                    }
                }
            }
            collateral[i] += padding;
            unchecked {
                ++i;
            }
        }
        return collateral;
    }

    /// @dev Calculate pro rata collateral portion of total loan's collateral that corresponds to `liquidity` portion of `totalLiquidityDebt`
    /// @param tokensHeld - loan total collateral available to pay loan
    /// @param liquidity - liquidity that we'll pay using loan collateral
    /// @param totalLiquidityDebt - total liquidity debt of loan
    /// @param padding - padding to avoid rounding issues
    /// @return collateral - collateral portion of total collateral that will be used to pay `liquidity`
    function proRataCollateral(uint128[] memory tokensHeld, uint256 liquidity, uint256 totalLiquidityDebt, uint128 padding) internal virtual view returns(uint128[] memory) {
        uint256 tokenCount = tokensHeld.length;
        for(uint256 i = 0; i < tokenCount;) {
            tokensHeld[i] = uint128(GSMath.min(uint256(tokensHeld[i]) * liquidity / totalLiquidityDebt, tokensHeld[i] - padding));
            unchecked {
                ++i;
            }
        }
        return tokensHeld;
    }

    /// @dev Rebalance collateral to be able to pay liquidity debt
    /// @param _loan - loan whose collateral will be rebalanced
    /// @param collateral - collateral tokens that will be rebalanced
    /// @param collateralId - index of tokensHeld/collateral array to rebalance to (e.g. the collateral of the chosen index will be completely used up in repayment)
    /// @param payLiquidity - liquidity that will be paid with the rebalanced collateral
    /// @return deltas - array of collateral amounts that changed in collateral array (<0 means collateral was sold, >0 means collateral was bought)
    function _rebalanceCollateralToClose(LibStorage.Loan storage _loan, uint128[] memory collateral, uint256 collateralId, uint256 payLiquidity) internal virtual returns(int256[] memory deltas) {
        int256[] memory _deltas = _calcDeltasToClose(collateral, s.CFMM_RESERVES, payLiquidity, collateralId - 1);
        if(isDeltasValid(_deltas)) {
            (, deltas) = rebalanceCollateral(_loan, _deltas, s.CFMM_RESERVES);
        }
    }

    /// @dev See {IRepayStrategy-_repayLiquiditySetRatio}.
    function _repayLiquiditySetRatio(uint256 tokenId, uint256 payLiquidity, uint256[] calldata ratio) external virtual lock returns(uint256 liquidityPaid, uint256[] memory amounts) {
        if(payLiquidity == 0) revert ZeroRepayLiquidity();

        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        uint128[] memory tokensHeld = _loan.tokensHeld;
        {
            // Cap liquidity repayment at total liquidity debt
            uint256 liquidityToCalculate;
            (liquidityPaid, liquidityToCalculate) = payLiquidity >= loanLiquidity ? (loanLiquidity, loanLiquidity + minPay()) : (payLiquidity, payLiquidity);

            int256[] memory deltas = _calcDeltasToCloseSetRatio(tokensHeld, s.CFMM_RESERVES, liquidityToCalculate,
                isRatioValid(ratio) ? ratio : GammaSwapLibrary.convertUint128ToRatio(tokensHeld));
            if(isDeltasValid(deltas)) {
                (tokensHeld,) = rebalanceCollateral(_loan, deltas, s.CFMM_RESERVES);
                updateIndex();
            }
            amounts = calcTokensToRepay(getLPReserves(s.cfmm,false), liquidityToCalculate, tokensHeld, false);
        }

        // Repay liquidity debt with reserve tokens, must check against available loan collateral
        repayTokens(_loan, amounts); // convert LP Tokens to liquidity to check how much got back
        // with this strategy we don't request for payment, we assume collateral vault sent payment already

        updateIndex();

        // Update loan collateral after repayment
        (tokensHeld,) = updateCollateral(_loan);

        // Subtract loan liquidity repaid from total liquidity debt in pool and loan
        uint256 remainingLiquidity;
        (liquidityPaid, remainingLiquidity) = payLoan(_loan, liquidityPaid, loanLiquidity);// don't want to do this twice

        checkCollateral(_loan, tokenId, tokensHeld, remainingLiquidity);

        emit LoanUpdated(tokenId, tokensHeld, uint128(remainingLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.REPAY_LIQUIDITY_SET_RATIO);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.REPAY_LIQUIDITY_SET_RATIO);
    }

    /// @dev See {IRepayStrategy-_repayLiquidity}.
    function _repayLiquidity(uint256 tokenId, uint256 payLiquidity, uint256 collateralId, address to) external virtual lock returns(uint256 liquidityPaid, uint256[] memory amounts) {
        if(payLiquidity == 0) revert ZeroRepayLiquidity();

        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        uint128[] memory collateral = _loan.tokensHeld;
        {
            // Cap liquidity repayment at total liquidity debt
            uint256 liquidityToCalculate;
            (liquidityPaid, liquidityToCalculate) = payLiquidity >= loanLiquidity ? (loanLiquidity, loanLiquidity + minPay()) : (payLiquidity, payLiquidity);

            if(collateralId > 0) {
                collateral = proRataCollateral(collateral, liquidityToCalculate, loanLiquidity, 1);
                collateral = remainingCollateral(collateral, _rebalanceCollateralToClose(_loan, collateral, collateralId, liquidityToCalculate), 1);
                updateIndex();
            }
            amounts = calcTokensToRepay(getLPReserves(s.cfmm,false), liquidityToCalculate, collateral, false);
        }

        // Repay liquidity debt with reserve tokens, must check against available loan collateral
        repayTokens(_loan, amounts); // convert LP Tokens to liquidity to check how much got back
        // with this strategy we don't request for payment, we assume collateral vault sent payment already

        updateIndex();

        // Update loan collateral after repayment
        (uint128[] memory tokensHeld, int256[] memory deltas) = updateCollateral(_loan);

        // Subtract loan liquidity repaid from total liquidity debt in pool and loan
        uint256 remainingLiquidity;
        (liquidityPaid, remainingLiquidity) = payLoan(_loan, liquidityPaid, loanLiquidity);// don't want to do this twice

        if(collateralId > 0 && to != address(0)) {
            tokensHeld = withdrawCollateral(_loan, remainingCollateral(collateral, deltas, 0), to);
        }

        checkCollateral(_loan, tokenId, tokensHeld, remainingLiquidity);

        emit LoanUpdated(tokenId, tokensHeld, uint128(remainingLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.REPAY_LIQUIDITY);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.REPAY_LIQUIDITY);
    }

    /// @dev See {IRepayStrategy-_repayLiquidityWithLP}.
    function _repayLiquidityWithLP(uint256 tokenId, uint256 collateralId, address to) external virtual override lock returns(uint256 liquidityPaid, uint128[] memory tokensHeld) {

        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        // Subtract loan liquidity repaid from total liquidity debt in pool and loan
        uint256 remainingLiquidity;
        (liquidityPaid, remainingLiquidity) = payLoan(_loan, type(uint256).max, loanLiquidity);

        // Check pro rata collateral that is now free to withdraw
        tokensHeld = _loan.tokensHeld;
        if(to != address(0)) {
            // Get pro rata collateral of liquidity paid to withdraw
            tokensHeld = proRataCollateral(tokensHeld, liquidityPaid, loanLiquidity, 0);
            if(collateralId > 0) { // If collateralId was chosen, rebalance to one of the amounts and withdraw
                unchecked {
                    collateralId -= 1;
                }
                // Swap the one amount to get the other one
                int256[] memory deltas = new int256[](tokensHeld.length);
                deltas[collateralId] = -int256(uint256(tokensHeld[collateralId]));
                (, deltas) = rebalanceCollateral(_loan, deltas, s.CFMM_RESERVES);
                tokensHeld = remainingCollateral(tokensHeld, deltas, 0);
            }
            // Withdraw, check margin
            tokensHeld = withdrawCollateral(_loan, tokensHeld, to);
        }

        checkCollateral(_loan, tokenId, tokensHeld, remainingLiquidity);

        emit LoanUpdated(tokenId, tokensHeld, uint128(remainingLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.REPAY_LIQUIDITY_WITH_LP);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.REPAY_LIQUIDITY_WITH_LP);
    }

    function checkCollateral(LibStorage.Loan storage _loan, uint256 tokenId, uint128[] memory tokensHeld, uint256 remainingLiquidity) internal virtual {
        uint256 loanCollateral = calcInvariant(s.cfmm, tokensHeld) + onLoanUpdate(_loan, tokenId);//this calls outside contract can affect market but it won't affect invariantCalc since it's happening after the fact
        checkMargin(loanCollateral, remainingLiquidity); // this makes it a requirement to pay in full if undercollateralized
    }
}
