// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/strategies/base/ILongStrategy.sol";
import "./BaseLongStrategy.sol";

/// @title Long Strategy abstract contract implementation of ILongStrategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice All external functions are locked to avoid reentrancy
/// @dev Only defines common functions that would be used by all concrete contracts that borrow and repay liquidity
abstract contract LongStrategy is ILongStrategy, BaseLongStrategy {

    error ExcessiveBorrowing();

    // Long Gamma

    /// @dev Calculate quantities to trade to rebalance collateral to desired `ratio`
    /// @param tokensHeld - loan collateral to rebalance
    /// @param reserves - reserve token quantities in CFMM
    /// @param ratio - desired ratio of collateral
    /// @return deltas - amount of collateral to trade to achieve desired `ratio`
    function _calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) internal virtual view returns(int256[] memory deltas);

    /// @dev See {ILongStrategy-calcDeltasForRatio}.
    function calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) external virtual override view returns(int256[] memory deltas) {
        return _calcDeltasForRatio(tokensHeld, reserves, ratio);
    }

    /// @dev Withdraw loan collateral
    /// @param _loan - loan whose collateral will be rebalanced
    /// @param deltas - collateral amounts being bought or sold (>0 buy, <0 sell), index matches tokensHeld[] index. Only n-1 tokens can be traded
    /// @return tokensHeld - loan collateral after rebalancing
    function rebalanceCollateral(LibStorage.Loan storage _loan, int256[] memory deltas) internal virtual returns(uint128[] memory tokensHeld) {
        // Calculate amounts to swap from deltas and available loan collateral
        (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(_loan, deltas);

        // Swap tokens
        swapTokens(_loan, outAmts, inAmts);

        // Update loan collateral tokens after swap
        (tokensHeld,) = updateCollateral(_loan);
    }

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
                i++;
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
    function proRataCollateral(uint128[] memory tokensHeld, uint256 liquidity, uint256 totalLiquidityDebt, uint256[] calldata fees) internal virtual view returns(uint128[] memory) {
        uint256 tokenCount = tokensHeld.length;
        for(uint256 i = 0; i < tokenCount;) {
            tokensHeld[i] = uint128(Math.min(((tokensHeld[i] * liquidity * 10000 - tokensHeld[i] * liquidity * fees[i]) / (totalLiquidityDebt * 10000)), uint256(tokensHeld[i])));
            unchecked {
                i++;
            }
        }
        return tokensHeld;
    }

    /// @dev Withdraw loan collateral
    /// @param _loan - loan whose collateral will bee withdrawn
    /// @param loanLiquidity - total liquidity debt of loan
    /// @param amounts - amounts of collateral to withdraw
    /// @param to - address that will receive collateral withdrawn
    /// @return tokensHeld - remaining loan collateral after withdrawal
    function withdrawCollateral(LibStorage.Loan storage _loan, uint256 loanLiquidity, uint128[] memory amounts, address to) internal virtual returns(uint128[] memory tokensHeld) {
        // Withdraw collateral tokens from loan
        sendTokens(_loan, to, amounts);

        // Update loan collateral token amounts after withdrawal
        (tokensHeld,) = updateCollateral(_loan);

        // Revert if collateral invariant is below threshold after withdrawal
        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        checkMargin(collateral, loanLiquidity);
    }

    /// @dev See {BaseLongStrategy-checkMargin}.
    function checkMargin(uint256 collateral, uint256 liquidity) internal virtual override view {
        if(!hasMargin(collateral, liquidity, ltvThreshold())) { // if collateral is below ltvThreshold revert transaction
            revert Margin();
        }
    }

    /// @notice Assumes that collateral tokens were already deposited but not accounted for
    /// @dev See {ILongStrategy-_increaseCollateral}.
    function _increaseCollateral(uint256 tokenId) external virtual override lock returns(uint128[] memory tokensHeld) {
        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update loan collateral token amounts with tokens deposited in GammaPool
        (tokensHeld,) = updateCollateral(_loan);

        // Do not check for loan undercollateralization because adding collateral always improves loan health

        emit LoanUpdated(tokenId, tokensHeld, _loan.liquidity, _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.INCREASE_COLLATERAL);

        return tokensHeld;
    }

    /// @dev See {ILongStrategy-_decreaseCollateral}.
    function _decreaseCollateral(uint256 tokenId, uint128[] calldata amounts, address to) external virtual override lock returns(uint128[] memory tokensHeld) {
        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt with accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        // Withdraw collateral tokens from loan
        tokensHeld = withdrawCollateral(_loan, loanLiquidity, amounts, to);

        emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.DECREASE_COLLATERAL);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.DECREASE_COLLATERAL);

        return tokensHeld;
    }

    /// @dev See {ILongStrategy-_borrowLiquidity}.
    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens, uint256[] calldata ratio) external virtual override lock returns(uint256 liquidityBorrowed, uint256[] memory amounts) {
        // Revert if borrowing all CFMM LP tokens in pool
        if(lpTokens >= s.LP_TOKEN_BALANCE) {
            revert ExcessiveBorrowing();
        }

        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        // Withdraw reserve tokens from CFMM that lpTokens represent
        amounts = withdrawFromCFMM(s.cfmm, address(this), lpTokens);

        // Add withdrawn tokens as part of loan collateral
        (uint128[] memory tokensHeld,) = updateCollateral(_loan);

        // Add liquidity debt to total pool debt and start tracking loan
        (liquidityBorrowed, loanLiquidity) = openLoan(_loan, lpTokens);

        if(ratio.length > 0) {
            //get current reserves without updating
            tokensHeld = rebalanceCollateral(_loan, _calcDeltasForRatio(tokensHeld, getReserves(s.cfmm), ratio));
        }

        // Check that loan is not undercollateralized
        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        checkMargin(collateral, loanLiquidity);

        emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.BORROW_LIQUIDITY);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.BORROW_LIQUIDITY);
    }

    /// @dev See {ILongStrategy-_repayLiquidity}.
    function _repayLiquidity(uint256 tokenId, uint256 payLiquidity, uint256[] calldata fees, uint256 collateralId, address to) external virtual override lock returns(uint256 liquidityPaid, uint256[] memory amounts) {
        require(payLiquidity > 0);

        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        // Cap liquidity repayment at total liquidity debt
        uint256 liquidityToCalculate;
        (liquidityPaid, liquidityToCalculate) = payLiquidity >= loanLiquidity ? (loanLiquidity, loanLiquidity + minBorrow()) : (payLiquidity, payLiquidity);

        uint128[] memory collateral;
        if(collateralId > 0) {
            // rebalance to close, get deltas, call rebalance
            collateral = proRataCollateral(_loan.tokensHeld, liquidityToCalculate, loanLiquidity, fees);
            rebalanceCollateral(_loan, _calcDeltasToClose(collateral, s.CFMM_RESERVES, liquidityToCalculate, collateralId - 1));
            updateIndex();
        }

        // Calculate reserve tokens that liquidity repayment represents
        amounts = addFees(calcTokensToRepay(s.CFMM_RESERVES, liquidityToCalculate), fees);

        // Repay liquidity debt with reserve tokens, must check against available loan collateral
        repayTokens(_loan, amounts);

        // Update loan collateral after repayment
        (uint128[] memory tokensHeld, int256[] memory deltas) = updateCollateral(_loan);

        // Subtract loan liquidity repaid from total liquidity debt in pool and loan
        (liquidityPaid, loanLiquidity) = payLoan(_loan, liquidityPaid, loanLiquidity);

        if(collateralId > 0 && to != address(0)) {
            // withdraw, check margin
            tokensHeld = withdrawCollateral(_loan, loanLiquidity, remainingCollateral(collateral, deltas), to);
        }

        // Do not check for loan undercollateralization because repaying debt always improves pool debt health

        emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.REPAY_LIQUIDITY);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.REPAY_LIQUIDITY);
    }

    /// @dev See {ILongStrategy-_rebalanceCollateral}.
    function _rebalanceCollateral(uint256 tokenId, int256[] memory deltas, uint256[] calldata ratio) external virtual override lock returns(uint128[] memory tokensHeld) {
        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        if(ratio.length > 0) {
            deltas = _calcDeltasForRatio(_loan.tokensHeld, s.CFMM_RESERVES, ratio);
        }

        tokensHeld = rebalanceCollateral(_loan, deltas);

        // Check that loan is not undercollateralized after swap
        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        checkMargin(collateral, loanLiquidity);

        emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.REBALANCE_COLLATERAL);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.REBALANCE_COLLATERAL);
    }

    /// @dev See {ILongStrategy-_updatePool}
    function _updatePool(uint256 tokenId) external virtual override lock returns(uint256 loanLiquidityDebt, uint256 poolLiquidityDebt) {
        if(tokenId > 0) {
            // Get loan for tokenId, revert if not loan creator
            LibStorage.Loan storage _loan = _getExistingLoan(tokenId);

            // Update pool and loan liquidity debt to include accrued interest since last update
            loanLiquidityDebt = updateLoan(_loan);

            emit LoanUpdated(tokenId, _loan.tokensHeld, uint128(loanLiquidityDebt), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.UPDATE_POOL);
        } else {
            // Update pool liquidity debt to include accrued interest since last update
            updateIndex();
        }

        poolLiquidityDebt = s.BORROWED_INVARIANT;

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, uint128(poolLiquidityDebt), s.CFMM_RESERVES, TX_TYPE.UPDATE_POOL);
    }
}
