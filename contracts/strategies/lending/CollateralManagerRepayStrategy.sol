// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/strategies/lending/ICollateralManagerRepayStrategy.sol";
import "../base/BaseRepayStrategy.sol";

/// @title Collateral Manager Repay Strategy abstract contract implementation of ICollateralManagerRepayStrategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice All external functions are locked to avoid reentrancy
/// @dev Defines external functions for concrete contract implementations to allow external accounts to repay liquidity loans
/// @dev Inherits BaseRebalanceStrategy because RepayStrategy needs to rebalance collateral to repay a loan
abstract contract CollateralManagerRepayStrategy is ICollateralManagerRepayStrategy, BaseRepayStrategy {

    error InternalCollateralRef();
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
    /// @param externalCollateral - collateral available in external contract at strike price
    /// @param maxExternalCollateral - max collateral available in external contract
    /// @return loanLiquidity - updated liquidity debt of loan, including debt write down
    /// @return internalLoanLiquidity - liquidity debt that can be paid with available internal collateral at strikePrice of internal collateral
    /// @return maxInternalCollateral - maximum liquidity debt taht can be paid with available internal collateral
    /// @return deltas - updated liquidity debt of loan, including debt write down
    /// @return hasWriteDown - updated liquidity debt of loan, including debt write down
    function updatePayableLoan(LibStorage.Loan storage _loan, uint256 payLiquidity, uint256 externalCollateral, uint256 maxExternalCollateral) internal virtual
        returns(uint256 loanLiquidity, uint256 internalLoanLiquidity, uint256 maxInternalCollateral, int256[] memory deltas, bool hasWriteDown){
        loanLiquidity = updateLoan(_loan);
        payLiquidity = payLiquidity >= loanLiquidity ? loanLiquidity : payLiquidity;
        uint256 _loanLiquidity;
        (_loanLiquidity, internalLoanLiquidity, maxInternalCollateral, deltas) = writeDownPayableLoan(_loan, loanLiquidity, payLiquidity, externalCollateral, maxExternalCollateral);
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
    /// @param externalCollateral - amount of liquidity to pay
    /// @param maxExternalCollateral - max collateral available in external contract
    /// @return _loanLiquidity - updated liquidity debt of loan, including debt write down
    /// @return internalLoanLiquidity - liquidity debt that can be paid with available internal collateral at strikePrice of internal collateral
    /// @return maxInternalCollateral - maximum liquidity debt taht can be paid with available internal collateral
    /// @return deltas - updated liquidity debt of loan, including debt write down
    function writeDownPayableLoan(LibStorage.Loan storage _loan, uint256 loanLiquidity, uint256 payLiquidity, uint256 externalCollateral, uint256 maxExternalCollateral) internal virtual
        returns(uint256 _loanLiquidity, uint256 internalLoanLiquidity, uint256 maxInternalCollateral, int256[] memory deltas) {

        _loanLiquidity = loanLiquidity;

        uint256 _minBorrow = minBorrow();
        uint256 internalCollateral = calcInvariant(s.cfmm, _loan.tokensHeld);

        deltas = _calcDeltasForMaxLP(_loan.tokensHeld, s.CFMM_RESERVES);
        maxInternalCollateral = _calcMaxCollateral(deltas, _loan.tokensHeld, s.CFMM_RESERVES);

        uint256 collateral = internalCollateral + maxExternalCollateral;
        collateral = collateral > _minBorrow ? collateral - _minBorrow : 0;

        if(_loanLiquidity > collateral) { // Undercollateralized so must pay in full
            if(payLiquidity < _loanLiquidity && collateral > 0) revert BadDebt(); // only write down if paying in full
            collateral = maxInternalCollateral + maxExternalCollateral;
            collateral = collateral > _minBorrow ? collateral - _minBorrow : 0;
            (uint256 writeDownAmt,) = writeDown(collateral, _loanLiquidity); // also write down if collateral is 0
            _loanLiquidity = (_loanLiquidity - writeDownAmt);
            if(writeDownAmt == 0 && _loanLiquidity < maxInternalCollateral) {// no write down and has enough internal collateral
                // We're paying in full here so only refer to loanLiquidity
                // do we have enough internalCollateral to pay the loanLiquidity (because we're still paying in full
                deltas = new int256[](0);
                internalLoanLiquidity = internalCollateral * _loanLiquidity / (internalCollateral + externalCollateral);
            }
        } else {
            // do we have enough internalCollateral to pay the loanLiquidity, here we refer to payLiquidity
            maxInternalCollateral = maxInternalCollateral > _minBorrow ? maxInternalCollateral - _minBorrow : 0; // avoid having dust in internal collateral
            if(payLiquidity < maxInternalCollateral) {
                deltas = new int256[](0);
                internalLoanLiquidity = internalCollateral * _loanLiquidity / (internalCollateral + externalCollateral);
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

    /// @dev See {ICollateralManagerRepayStrategy-_repayCollMgrLiquidity}.
    function _repayCollMgrLiquidity(uint256 tokenId, uint256 payLiquidity, uint256[] calldata fees, uint256 collateralId, address to) external virtual override lock returns(uint256 liquidityPaid, uint256[] memory amounts) {
        if(payLiquidity == 0) revert ZeroRepayLiquidity();

        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);
        if(_loan.refAddr == address(0) || _loan.refTyp != 3) revert InternalCollateralRef();

        uint256 externalCollateral = getExternalCollateral(_loan, tokenId);

        // Update liquidity debt to include accrued interest since last update
        (uint256 loanLiquidity, uint256 internalLoanLiquidity, uint256 maxInternalCollateral, int256[] memory deltas,) =
            updatePayableLoan(_loan, payLiquidity, externalCollateral, getMaxExternalCollateral(_loan, tokenId));

        uint128[] memory collateral;
        {
            uint256 liquidityToCalculate;
            (liquidityPaid, liquidityToCalculate) = payLiquidity >= loanLiquidity ? (loanLiquidity, loanLiquidity + minBorrow()) : (payLiquidity, payLiquidity);

            if(deltas.length > 0) { // we're using up all of the internal collateral even if we are not undercollateralized
                (collateral,) = rebalanceCollateral(_loan, deltas, s.CFMM_RESERVES); // rebalance collateral to deposit all of it.
                collateralId = 0; // we will use up all the internal collateral, we won't get anything back
                updateIndex();
                amounts = GammaSwapLibrary.convertUint128ToUint256Array(collateral);
                // Repay liquidity debt with reserve tokens, must check against available loan collateral
                repayTokens(_loan, amounts);
                repayWithExternalCollateral(_loan, tokenId, liquidityPaid - maxInternalCollateral);
            } else {
                // we have enough internal collateral to pay requested liquidity at current prices (deltas = 0), even if we're undercollateralized
                if(collateralId > 0) {
                    collateral = proRataCollateral(_loan.tokensHeld, liquidityToCalculate, internalLoanLiquidity, fees); // discount fees because they will be added later
                    collateral = remainingCollateral(collateral, _rebalanceCollateralToClose(_loan, collateral, collateralId, liquidityToCalculate));
                    updateIndex();
                    // nothing left over to pay
                }
                amounts = addFees(calcTokensToRepay(s.CFMM_RESERVES, liquidityToCalculate),fees);
            }
        }

        // Update loan collateral after repayment
        uint128[] memory tokensHeld;
        (tokensHeld, deltas) = updateCollateral(_loan);

        // Subtract loan liquidity repaid from total liquidity debt in pool and loan
        uint256 remainingLiquidity;
        (liquidityPaid, remainingLiquidity) = payLoan(_loan, liquidityPaid, loanLiquidity);// don't want to do this twice

        if(collateralId > 0 && to != address(0)) {
            // withdraw, check margin
            tokensHeld = withdrawCollateral(_loan, remainingLiquidity, externalCollateral, remainingCollateral(collateral, deltas), to);
        }

        // Do not check for loan undercollateralization because repaying debt always improves pool debt health

        emit LoanUpdated(tokenId, tokensHeld, uint128(remainingLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.REPAY_LIQUIDITY);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.REPAY_LIQUIDITY);/**/
    }

    /// @dev See {IRepayStrategy-_repayCollMgrLiquidityWithLP}.
    function _repayCollMgrLiquidityWithLP(uint256 tokenId, uint256 payLiquidity, uint256 collateralId, address to) external virtual override lock returns(uint256 liquidityPaid) {
        if(payLiquidity == 0) revert ZeroRepayLiquidity();

        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);
        if(_loan.refAddr == address(0) || _loan.refTyp != 3) revert InternalCollateralRef();

        uint256 externalCollateral = getExternalCollateral(_loan, tokenId);

        // Update liquidity debt to include accrued interest since last update
        (uint256 loanLiquidity,,,,bool hasWriteDown) = updatePayableLoan(_loan, payLiquidity,  externalCollateral, getMaxExternalCollateral(_loan, tokenId));
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
            tokensHeld = withdrawCollateral(_loan, remainingLiquidity, externalCollateral, tokensHeld, to);
        }
        // If not withdrawing, do not check for loan undercollateralization because repaying debt always improves pool debt health

        emit LoanUpdated(tokenId, tokensHeld, uint128(remainingLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.REPAY_LIQUIDITY_WITH_LP);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.REPAY_LIQUIDITY_WITH_LP);
    }
}
