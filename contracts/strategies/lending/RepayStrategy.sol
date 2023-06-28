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
    /// @return hasWriteDown - updated liquidity debt of loan, including debt write down
    function updatePayableLoan(LibStorage.Loan storage _loan, uint256 payLiquidity) internal virtual
        returns(uint256 loanLiquidity, int256[] memory deltas, bool hasWriteDown){
        loanLiquidity = updateLoan(_loan);
        uint256 _loanLiquidity;
        (_loanLiquidity, deltas) = writeDownPayableLoan(_loan, loanLiquidity, payLiquidity);
        hasWriteDown = _loanLiquidity != loanLiquidity;
        if(hasWriteDown) {
            _loan.liquidity = uint128(_loanLiquidity);
        }
        loanLiquidity = _loanLiquidity;
    }

    /// @dev Calculate written down liquidity debt if it needs to be written down
    /// @param _loan - loan to update liquidity debt
    /// @param loanLiquidity - amount of liquidity debt
    /// @param payLiquidity - amount of liquidity to pay
    /// @return _loanLiquidity - updated liquidity debt of loan, including debt write down
    /// @return deltas - updated liquidity debt of loan, including debt write down
    function writeDownPayableLoan(LibStorage.Loan storage _loan, uint256 loanLiquidity, uint256 payLiquidity) internal virtual
        returns(uint256 _loanLiquidity, int256[] memory deltas) {
        uint256 collateral = calcInvariant(s.cfmm, _loan.tokensHeld);
        uint256 _minBorrow = minBorrow();
        collateral = collateral > _minBorrow ? collateral - _minBorrow : 0;
        _loanLiquidity = loanLiquidity;
        if(_loanLiquidity > collateral) { // Undercollateralized so must pay in full
            if(payLiquidity < _loanLiquidity && collateral > 0) revert BadDebt(); // only write down if paying in full
            deltas = _calcDeltasForMaxLP(_loan.tokensHeld, s.CFMM_RESERVES);
            collateral = _calcMaxCollateral(deltas, _loan.tokensHeld, s.CFMM_RESERVES);
            collateral = collateral > _minBorrow ? collateral - _minBorrow : 0;
            (uint256 writeDownAmt,) = writeDown(collateral, _loanLiquidity); // also write down if collateral is 0
            _loanLiquidity = (_loanLiquidity - writeDownAmt);
            if(writeDownAmt == 0) {// no write down => maybe
                deltas = new int256[](0);
            }
        } else {
            deltas = new int256[](0);
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

    /// @dev See {IRepayStrategy-_repayLiquidityAndWithdraw}.
    function _repayLiquidityAndWithdraw(uint256 tokenId, uint256 payLiquidity, uint256[] calldata fees, uint256 collateralId, address to) external virtual override lock returns(uint256 liquidityPaid, uint256[] memory amounts) {
        if(payLiquidity == 0) revert ZeroRepayLiquidity();

        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);
        if(_loan.refAddr != address(0) && _loan.refTyp == 3) revert ExternalCollateralRef();

        // Update liquidity debt to include accrued interest since last update
        (uint256 loanLiquidity, int256[] memory deltas,) = updatePayableLoan(_loan, payLiquidity);
        // in the above function we should also get the internal and external liquidity we have available to pay

        uint128[] memory collateral;
        {
            // Cap liquidity repayment at total liquidity debt
            uint256 liquidityToCalculate;
            (liquidityPaid, liquidityToCalculate) = payLiquidity >= loanLiquidity ? (loanLiquidity, loanLiquidity + minBorrow()) : (payLiquidity, payLiquidity);

            if(deltas.length > 0) { // there's bad debt, so a write down happened, payLiquidity >= loanLiquidity is true
                (collateral,) = rebalanceCollateral(_loan, deltas, s.CFMM_RESERVES); // rebalance collateral to deposit all of it.
                collateralId = 0; // we will use up all the collateral, we won't get anything back
                // we don't know the actual transfer fees of the loan, and we're going to deposit everything.
                // so we have to write down the debt to zero here regardless
                updateIndex();
                amounts = GammaSwapLibrary.convertUint128ToUint256Array(collateral);
            } else {
                if(collateralId > 0) {
                    // we have enough liquidity in the tokensHeld to make payment
                    // here I would only be able to cover the collateral amount that I can cover, so I have to reduce loanLiquidity to what I can pay
                    // and the rest is left to the externalCollateral
                    collateral = proRataCollateral(_loan.tokensHeld, liquidityToCalculate, loanLiquidity, fees); // discount fees because they will be added later
                    collateral = remainingCollateral(collateral, _rebalanceCollateralToClose(_loan, collateral, collateralId, liquidityToCalculate));
                    updateIndex();
                }
                amounts = addFees(calcTokensToRepay(s.CFMM_RESERVES, liquidityToCalculate),fees);
            }
        }
        // Repay liquidity debt with reserve tokens, must check against available loan collateral
        repayTokens(_loan, amounts);

        // Update loan collateral after repayment
        uint128[] memory tokensHeld;
        (tokensHeld, deltas) = updateCollateral(_loan);

        // Subtract loan liquidity repaid from total liquidity debt in pool and loan
        uint256 remainingLiquidity;
        (liquidityPaid, remainingLiquidity) = payLoan(_loan, liquidityPaid, loanLiquidity);// don't want to do this twice

        if(collateralId > 0 && to != address(0)) {
            // withdraw, check margin
            tokensHeld = withdrawCollateral(_loan, remainingLiquidity, 0, remainingCollateral(collateral, deltas), to);
        }

        // Do not check for loan undercollateralization because repaying debt always improves pool debt health

        emit LoanUpdated(tokenId, tokensHeld, uint128(remainingLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.REPAY_LIQUIDITY);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.REPAY_LIQUIDITY);
    }

    /// @dev See {IRepayStrategy-_repayLiquidityWithLP}.
    function _repayLiquidityWithLP(uint256 tokenId, uint256 payLiquidity, uint256 collateralId, address to) external virtual override lock returns(uint256 liquidityPaid) {
        if(payLiquidity == 0) revert ZeroRepayLiquidity();

        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);
        if(_loan.refAddr != address(0) && _loan.refTyp == 3) revert ExternalCollateralRef();

        // Update liquidity debt to include accrued interest since last update
        (uint256 loanLiquidity,,bool hasWriteDown) = updatePayableLoan(_loan, payLiquidity);
        liquidityPaid = payLiquidity >= loanLiquidity ? loanLiquidity : payLiquidity;

        // Subtract loan liquidity repaid from total liquidity debt in pool and loan
        uint256 remainingLiquidity;
        (liquidityPaid, remainingLiquidity) = payLoan(_loan, liquidityPaid, loanLiquidity);
        if(hasWriteDown && remainingLiquidity > 0) revert BadDebt();

        // Check pro rata collateral that is now free to withdraw
        uint128[] memory tokensHeld = _loan.tokensHeld;
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
            tokensHeld = withdrawCollateral(_loan, remainingLiquidity, 0, tokensHeld, to);
        }
        // If not withdrawing, do not check for loan undercollateralization because repaying debt always improves pool debt health

        emit LoanUpdated(tokenId, tokensHeld, uint128(remainingLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.REPAY_LIQUIDITY_WITH_LP);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.REPAY_LIQUIDITY_WITH_LP);
    }

    /// @dev See {IRepayStrategy-_repayLiquidity}.
    function _repayLiquidity(uint256 tokenId, uint256 payLiquidity, uint256[] calldata fees, uint256[] calldata ratio) external virtual override lock returns(uint256 liquidityPaid, uint256[] memory amounts) {
        if(payLiquidity == 0) revert ZeroRepayLiquidity();

        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);
        if(_loan.refAddr != address(0) && _loan.refTyp == 3) revert ExternalCollateralRef();

        // Update liquidity debt to include accrued interest since last update
        (uint256 loanLiquidity, int256[] memory deltas,) = updatePayableLoan(_loan, payLiquidity);
        // in the above function we should also get the internal and external liquidity we have available to pay

        uint128[] memory tokensHeld;
        {
            // Cap liquidity repayment at total liquidity debt
            uint256 liquidityToCalculate;
            (liquidityPaid, liquidityToCalculate) = payLiquidity >= loanLiquidity ? (loanLiquidity, loanLiquidity + minBorrow()) : (payLiquidity, payLiquidity);

            if(deltas.length > 0) { // there's bad debt, so a write down happened, payLiquidity >= loanLiquidity is true
                (tokensHeld,) = rebalanceCollateral(_loan, deltas, s.CFMM_RESERVES); // rebalance collateral to deposit all of it.
                // we don't know the actual transfer fees of the loan, and we're going to deposit everything.
                // so we have to write down the debt to zero here regardless
                updateIndex();
                amounts = GammaSwapLibrary.convertUint128ToUint256Array(tokensHeld);
            } else {
                rebalanceCollateral(_loan, _calcDeltasToCloseKeepRatio(_loan.tokensHeld, s.CFMM_RESERVES, liquidityToCalculate, ratio), s.CFMM_RESERVES);
                updateIndex();
                amounts = addFees(calcTokensToRepay(s.CFMM_RESERVES, liquidityToCalculate),fees);
            }
        }
        // Repay liquidity debt with reserve tokens, must check against available loan collateral
        repayTokens(_loan, amounts);

        // Update loan collateral after repayment
        (tokensHeld,) = updateCollateral(_loan);

        // Subtract loan liquidity repaid from total liquidity debt in pool and loan
        uint256 remainingLiquidity;
        (liquidityPaid, remainingLiquidity) = payLoan(_loan, liquidityPaid, loanLiquidity);// don't want to do this twice

        // Do not check for loan undercollateralization because repaying debt always improves pool debt health

        emit LoanUpdated(tokenId, tokensHeld, uint128(remainingLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.REPAY_LIQUIDITY);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.REPAY_LIQUIDITY);
    }
}
