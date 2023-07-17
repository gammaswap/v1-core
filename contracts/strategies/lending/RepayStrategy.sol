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
    /// @return remaining - remaining collateral after collateral changes
    function remainingCollateral(uint128[] memory collateral, int256[] memory deltas) internal virtual view returns(uint128[] memory) {
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
                    collateral[i] -= _delta;
                }
            }
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
    /// @param fees - fees to transfer during payment in case token has transfer fees
    /// @return collateral - collateral portion of total collateral that will be used to pay `liquidity`
    function proRataCollateral(uint128[] memory tokensHeld, uint256 liquidity, uint256 totalLiquidityDebt, uint256[] memory fees) internal virtual view returns(uint128[] memory) {
        uint256 tokenCount = tokensHeld.length;
        bool skipFees = tokenCount != fees.length;
        for(uint256 i = 0; i < tokenCount;) {
            tokensHeld[i] = uint128(Math.min(((tokensHeld[i] * liquidity * 10000 - (skipFees ? 0 : tokensHeld[i] * liquidity * fees[i])) / (totalLiquidityDebt * 10000)), uint256(tokensHeld[i])));
            unchecked {
                ++i;
            }
        }
        return tokensHeld;
    }

    /// @dev Update loan with latest accrued interest and write down debt if there is bad debt
    /// @notice if there is bad debt only accept repayment in full
    /// @notice unlikely to happen but done to avoid a situation where liquidity > 0 but collateral = 0
    /// @notice in such a situation a liquidator would not have any incentive to liquidate and write down the debt
    /// @param _loan - loan to update liquidity debt
    /// @param payLiquidity - amount of liquidity to pay
    /// @return loanLiquidity - updated liquidity debt of loan, including debt write down
    /// @return deltas - updated liquidity debt of loan, including debt write down
    function updatePayableLoan(LibStorage.Loan storage _loan, uint256 payLiquidity) internal virtual
        returns(uint256 loanLiquidity, int256[] memory deltas) {
        loanLiquidity = updateLoan(_loan);
        payLiquidity = payLiquidity >= loanLiquidity ? loanLiquidity : payLiquidity;
        deltas = _calcRebalanceCollateralDeltas(_loan, payLiquidity);
    }

    /// @dev Calculate written down liquidity debt if it needs to be written down
    /// @param _loan - loan to update liquidity debt
    /// @param payLiquidity - amount of liquidity to pay
    /// @return deltas - updated liquidity debt of loan, including debt write down
    function _calcRebalanceCollateralDeltas(LibStorage.Loan storage _loan, uint256 payLiquidity) internal virtual
        returns(int256[] memory deltas) {
        uint128[] memory tokensHeld = _loan.tokensHeld;
        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        uint256 _minBorrow = minBorrow();
        collateral = collateral > _minBorrow ? collateral - _minBorrow : 0;
        if(payLiquidity > collateral) { // Not enough internal collateral
            deltas = _calcDeltasForMaxLP(tokensHeld, s.CFMM_RESERVES);
            collateral = _calcCollateralPostTrade(deltas, tokensHeld, s.CFMM_RESERVES);
            collateral = collateral > _minBorrow ? collateral - _minBorrow : 0;
            if(collateral > payLiquidity) {
                deltas = new int256[](0);
            }
        }
    }

    /// @dev Rebalance collateral to be able to pay liquidity debt
    /// @param _loan - loan whose collateral will be rebalanced
    /// @param collateral - collateral tokens that will be rebalanced
    /// @param collateralId - index of tokensHeld/collateral array to rebalance to (e.g. the collateral of the chosen index will be completely used up in repayment)
    /// @param payLiquidity - liquidity that will be paid with the rebalanced collateral
    /// @return deltas - array of collateral amounts that changed in collateral array (<0 means collateral was sold, >0 means collateral was bought)
    function _rebalanceCollateralToClose(LibStorage.Loan storage _loan, uint128[] memory collateral, uint256 collateralId, uint256 payLiquidity) internal virtual returns(int256[] memory deltas) {
        (, deltas) = rebalanceCollateral(_loan, _calcDeltasToClose(collateral, s.CFMM_RESERVES, payLiquidity, collateralId - 1), s.CFMM_RESERVES);
    }

    /// @dev See {IRepayStrategy-_repayLiquiditySetRatio}.
    function _repayLiquiditySetRatio(uint256 tokenId, uint256 payLiquidity, uint256[] calldata fees, uint256[] calldata ratio) external virtual lock returns(uint256 liquidityPaid, uint256[] memory amounts) {
        if(payLiquidity == 0) revert ZeroRepayLiquidity();

        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt to include accrued interest since last update
        (uint256 loanLiquidity, int256[] memory deltas) = updatePayableLoan(_loan, payLiquidity);
        // in the above function we should also get the internal and external liquidity we have available to pay

        uint128[] memory tokensHeld;
        {
            // Cap liquidity repayment at total liquidity debt
            uint256 liquidityToCalculate;
            (liquidityPaid, liquidityToCalculate) = payLiquidity >= loanLiquidity ? (loanLiquidity, loanLiquidity + minBorrow()) : (payLiquidity, payLiquidity);

            if(deltas.length > 0) { // there's bad debt, so a write down happened, payLiquidity >= loanLiquidity is true
                (tokensHeld,) = rebalanceCollateral(_loan, deltas, s.CFMM_RESERVES); // rebalance collateral to deposit all of it.
                amounts = GammaSwapLibrary.convertUint128ToUint256Array(tokensHeld);// so we have to write down the debt to zero here regardless
                updateIndex();
            } else {
                tokensHeld = _loan.tokensHeld;
                rebalanceCollateral(_loan, _calcDeltasToCloseSetRatio(tokensHeld, s.CFMM_RESERVES, liquidityToCalculate,
                    tokensHeld.length != ratio.length ? GammaSwapLibrary.convertUint128ToUint256Array(tokensHeld) : ratio), s.CFMM_RESERVES);
                updateIndex();
                amounts = addFees(calcTokensToRepay(s.CFMM_RESERVES, liquidityToCalculate),fees);
            }
        }

        // Repay liquidity debt with reserve tokens, must check against available loan collateral
        repayTokens(_loan, amounts); // convert LP Tokens to liquidity to check how much got back
        // with this strategy we don't request for payment, we assume collateral vault sent payment already

        // Update loan collateral after repayment
        (tokensHeld, deltas) = updateCollateral(_loan);

        // Subtract loan liquidity repaid from total liquidity debt in pool and loan
        uint256 remainingLiquidity;
        (liquidityPaid, remainingLiquidity) = payLoan(_loan, liquidityPaid, loanLiquidity);// don't want to do this twice

        checkCollateral(_loan, tokenId, tokensHeld, remainingLiquidity);

        // we check here if debt > 0, then we should be collateralized or collateral should be zero. If collateral not zero, then revert. Ask for full payment

        // Do not check for loan undercollateralization because repaying debt always improves pool debt health

        emit LoanUpdated(tokenId, tokensHeld, uint128(remainingLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.REPAY_LIQUIDITY_SET_RATIO);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.REPAY_LIQUIDITY_SET_RATIO);
    }

    /// @dev See {IRepayStrategy-_repayLiquidity}.
    function _repayLiquidity(uint256 tokenId, uint256 payLiquidity, uint256[] calldata fees, uint256 collateralId, address to) external virtual lock returns(uint256 liquidityPaid, uint256[] memory amounts) {
        if(payLiquidity == 0) revert ZeroRepayLiquidity();

        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt to include accrued interest since last update
        (uint256 loanLiquidity, int256[] memory deltas) = updatePayableLoan(_loan, payLiquidity);
        // in the above function we should also get the internal and external liquidity we have available to pay

        uint128[] memory collateral;
        {
            // Cap liquidity repayment at total liquidity debt
            uint256 liquidityToCalculate;
            (liquidityPaid, liquidityToCalculate) = payLiquidity >= loanLiquidity ? (loanLiquidity, loanLiquidity + minBorrow()) : (payLiquidity, payLiquidity);

            if(deltas.length > 0) { // there's bad debt, so a write down happened, payLiquidity >= loanLiquidity is true
                (collateral,) = rebalanceCollateral(_loan, deltas, s.CFMM_RESERVES); // rebalance collateral to deposit all of it.
                collateralId = 0; // we will use up all the collateral, we won't get anything back
                amounts = GammaSwapLibrary.convertUint128ToUint256Array(collateral);// so we have to write down the debt to zero here regardless
                // we're paying all the debt here no matter what, but we don't have to deposit all the collateral.
                updateIndex();
            } else {
                if(collateralId > 0) {
                    collateral = proRataCollateral(_loan.tokensHeld, liquidityToCalculate, loanLiquidity, fees); // discount fees because they will be added later
                    collateral = remainingCollateral(collateral, _rebalanceCollateralToClose(_loan, collateral, collateralId, liquidityToCalculate));
                    updateIndex();
                }
                amounts = addFees(calcTokensToRepay(getReserves(s.cfmm), liquidityToCalculate),fees);
            }
        }

        // Repay liquidity debt with reserve tokens, must check against available loan collateral
        repayTokens(_loan, amounts); // convert LP Tokens to liquidity to check how much got back
        // with this strategy we don't request for payment, we assume collateral vault sent payment already

        // Update loan collateral after repayment
        uint128[] memory tokensHeld;
        (tokensHeld, deltas) = updateCollateral(_loan);

        // Subtract loan liquidity repaid from total liquidity debt in pool and loan
        uint256 remainingLiquidity;
        (liquidityPaid, remainingLiquidity) = payLoan(_loan, liquidityPaid, loanLiquidity);// don't want to do this twice

        //bool isWithdrawal = collateralId > 0 && to != address(0);
        if(collateralId > 0 && to != address(0)) {
            tokensHeld = withdrawCollateral(_loan, remainingCollateral(collateral, deltas), to);
        }

        checkCollateral(_loan, tokenId, tokensHeld, remainingLiquidity);

        // we check here if debt > 0, then we should be collateralized or collateral should be zero. If collateral not zero, then revert. Ask for full payment

        // Do not check for loan undercollateralization because repaying debt always improves pool debt health

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
            tokensHeld = proRataCollateral(tokensHeld, liquidityPaid, loanLiquidity, new uint256[](0));
            if(collateralId > 0) { // If collateralId was chosen, rebalance to one of the amounts and withdraw
                // Swap the one amount to get the other one
                int256[] memory deltas = new int256[](tokensHeld.length);
                deltas[collateralId - 1] = -int256(uint256(tokensHeld[collateralId - 1]));
                (, deltas) = rebalanceCollateral(_loan, deltas, s.CFMM_RESERVES);
                tokensHeld = remainingCollateral(tokensHeld, deltas);
            }
            // Withdraw, check margin
            tokensHeld = withdrawCollateral(_loan, tokensHeld, to);
        }

        checkCollateral(_loan, tokenId, tokensHeld, remainingLiquidity);
        // If not withdrawing, do not check for loan undercollateralization because repaying debt always improves pool debt health

        emit LoanUpdated(tokenId, tokensHeld, uint128(remainingLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.REPAY_LIQUIDITY_WITH_LP);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.REPAY_LIQUIDITY_WITH_LP);
    }

    function checkCollateral(LibStorage.Loan storage _loan, uint256 tokenId, uint128[] memory tokensHeld, uint256 remainingLiquidity) internal virtual {
        uint256 loanCollateral = calcInvariant(s.cfmm, tokensHeld) + onLoanUpdate(_loan, tokenId);//this calls outside contract can affect market but it won't affect invariantCalc since it's happening after the fact
        if(loanCollateral == 0 && remainingLiquidity > 0) { //close everything else in the loan (loan is paid)
            writeDown(0, remainingLiquidity);
            remainingLiquidity = 0;
            uint256 lpTokens = _loan.lpTokens;
            if(lpTokens < s.LP_TOKEN_BORROWED) {
                unchecked {
                    s.LP_TOKEN_BORROWED -= lpTokens;
                }
            } else {
                s.LP_TOKEN_BORROWED = 0;
            }
            _loan.liquidity = 0;
            _loan.initLiquidity = 0;
            _loan.lpTokens = 0;
            _loan.rateIndex = 0;
            _loan.px = 0;
        }
        checkMargin(loanCollateral, remainingLiquidity); // this makes it a requirement to pay in full if undercollateralized
    }
}
