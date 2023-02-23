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
        tokensHeld = updateCollateral(_loan);

        // Do not check for loan undercollateralization because adding collateral always improves loan health

        emit LoanUpdated(tokenId, tokensHeld, _loan.liquidity, _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.INCREASE_COLLATERAL);

        return tokensHeld;
    }

    /// @dev See {ILongStrategy-_decreaseCollateral}.
    function _decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external virtual override lock returns(uint128[] memory tokensHeld) {
        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Withdraw collateral tokens from loan
        sendTokens(_loan, to, amounts);

        // Update loan collateral token amounts after withdrawal
        tokensHeld = updateCollateral(_loan);

        // Update liquidity debt with accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        // Revert if collateral invariant is below threshold after withdrawal
        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        checkMargin(collateral, loanLiquidity);

        emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.DECREASE_COLLATERAL);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.DECREASE_COLLATERAL);

        return tokensHeld;
    }

    /// @dev See {ILongStrategy-_borrowLiquidity}.
    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual override lock returns(uint256 liquidityBorrowed, uint256[] memory amounts) {
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
        uint128[] memory tokensHeld = updateCollateral(_loan);

        // Add liquidity debt to total pool debt and start tracking loan
        (liquidityBorrowed, loanLiquidity) = openLoan(_loan, lpTokens);

        // Check that loan is not undercollateralized
        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        checkMargin(collateral, loanLiquidity);

        emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.BORROW_LIQUIDITY);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.BORROW_LIQUIDITY);
    }

    /// @dev See {ILongStrategy-_repayLiquidity}.
    function _repayLiquidity(uint256 tokenId, uint256 payLiquidity, uint256[] calldata fees) external virtual override lock returns(uint256 liquidityPaid, uint256[] memory amounts) {
        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        // Cap liquidity repayment at total liquidity debt
        uint256 liquidityToCalculate;
        (liquidityPaid, liquidityToCalculate) = payLiquidity >= loanLiquidity ? (loanLiquidity, loanLiquidity + minBorrow()) : (payLiquidity, payLiquidity);

        // Calculate reserve tokens that liquidity repayment represents
        amounts = addFees(calcTokensToRepay(liquidityToCalculate), fees);

        // Repay liquidity debt with reserve tokens, must check against available loan collateral
        repayTokens(_loan, amounts);

        // Update loan collateral after repayment
        uint128[] memory tokensHeld = updateCollateral(_loan);

        // Subtract loan liquidity repaid from total liquidity debt in pool and loan
        (liquidityPaid, loanLiquidity) = payLoan(_loan, liquidityPaid, loanLiquidity);

        // Do not check for loan undercollateralization because repaying debt always improves pool debt health

        emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.REPAY_LIQUIDITY);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.REPAY_LIQUIDITY);
    }

    /// @dev See {ILongStrategy-_rebalanceCollateral}.
    function _rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external virtual override lock returns(uint128[] memory tokensHeld) {
        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        // Calculate amounts to swap from deltas and available loan collateral
        (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(_loan, deltas);

        // Swap tokens
        swapTokens(_loan, outAmts, inAmts);

        // Update loan collateral tokens after swap
        tokensHeld = updateCollateral(_loan);

        // Check that loan is not undercollateralized after swap
        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        checkMargin(collateral, loanLiquidity);

        emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.REBALANCE_COLLATERAL);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.REBALANCE_COLLATERAL);
    }
}
