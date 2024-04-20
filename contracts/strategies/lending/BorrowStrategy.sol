// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/strategies/lending/IBorrowStrategy.sol";
import "../base/BaseRebalanceStrategy.sol";
import "../base/BaseBorrowStrategy.sol";

/// @title Borrow Strategy abstract contract implementation of IBorrowStrategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice All external functions are locked to avoid reentrancy
/// @dev Defines external functions for concrete contract implementations to allow external accounts to borrow liquidity
/// @dev Inherits BaseRebalanceStrategy because BorrowStrategy needs to rebalance collateral to achieve a desires delta
abstract contract BorrowStrategy is IBorrowStrategy, BaseBorrowStrategy, BaseRebalanceStrategy {

    error ExcessiveBorrowing();

    /// @dev See {IBorrowStrategy-calcDynamicOriginationFee}.
    function calcDynamicOriginationFee(uint256 baseOrigFee, uint256 utilRate, uint256 lowUtilRate, uint256 minUtilRate1, uint256 minUtilRate2, uint256 feeDivisor) external virtual override view returns(uint256 origFee) {
        return _calcDynamicOriginationFee(baseOrigFee, utilRate, lowUtilRate, minUtilRate1, minUtilRate2, feeDivisor);
    }

    /// @dev Get the amounts that do not have enough collateral to withdraw from the loan's collateral
    /// @param amounts - collateral quantities requested to withdraw and therefore checked against existing collateral in the loan.
    /// @param tokensHeld - collateral quantities in loan
    /// @return hasUnfundedAmounts - if true, we don't have enough collateral to withdraw for at least on token of the CFMM
    /// @return unfundedAmounts - amount requested to withdraw for which there isn't enough collateral to withdraw
    /// @return _tokensHeld - amount requested to withdraw for which there isn't enough collateral to withdraw
    function getUnfundedAmounts(uint128[] memory amounts, uint128[] memory tokensHeld) internal virtual view returns(bool, uint128[] memory, uint128[] memory){
        uint256 len = tokensHeld.length;
        if(amounts.length != len) revert InvalidAmountsLength();
        uint128[] memory unfundedAmounts = new uint128[](len);
        bool hasUnfundedAmounts = false;
        for(uint256 i = 0; i < len;) {
            if(amounts[i] > tokensHeld[i]) { // if amount requested is higher than existing collateral
                hasUnfundedAmounts = true; // we don't have enough collateral of at least one token to withdraw
                unfundedAmounts[i] = amounts[i]; // amount we are requesting to withdraw for which there isn't enough collateral
            } else {
                unchecked {
                    tokensHeld[i] -= amounts[i];
                }
            }
            unchecked {
                ++i;
            }
        }
        return(hasUnfundedAmounts, unfundedAmounts, tokensHeld);
    }

    /// @notice We do this because we may withdraw the collateral to the CFMM prior to requesting the reserves
    /// @dev Ask for reserve quantities from CFMM if address that will receive withdrawn quantities is CFMM
    /// @param to - address that will receive withdrawn collateral quantities
    /// @return reserves - CFMM reserve quantities
    function _getReserves(address to) internal virtual view returns(uint128[] memory) {
        if(to == s.cfmm) {
            return getReserves(to);
        }
        return s.CFMM_RESERVES;
    }

    /// @notice Assumes that collateral tokens were already deposited but not accounted for
    /// @dev See {IBorrowStrategy-_increaseCollateral}.
    function _increaseCollateral(uint256 tokenId, uint256[] calldata ratio) external virtual override lock returns(uint128[] memory tokensHeld) {
        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update loan collateral token amounts with tokens deposited in GammaPool
        (tokensHeld,) = updateCollateral(_loan);

        // Update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        if(isRatioValid(ratio)) {
            int256[] memory deltas = _calcDeltasForRatio(_loan.tokensHeld, s.CFMM_RESERVES, ratio);
            if(isDeltasValid(deltas)) {
                (tokensHeld,) = rebalanceCollateral(_loan, deltas, s.CFMM_RESERVES);
            }
            // Check that loan is not undercollateralized after swap
            checkMargin(calcInvariant(s.cfmm, tokensHeld) + onLoanUpdate(_loan, tokenId), loanLiquidity);
        } else {
            onLoanUpdate(_loan, tokenId);
        }
        // If not rebalanced, do not check for undercollateralization because adding collateral always improves loan health

        emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.INCREASE_COLLATERAL);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.INCREASE_COLLATERAL);

        return tokensHeld;
    }

    /// @dev See {IBorrowStrategy-_decreaseCollateral}.
    function _decreaseCollateral(uint256 tokenId, uint128[] memory amounts, address to, uint256[] calldata ratio) external virtual override lock returns(uint128[] memory tokensHeld) {
        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt with accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);
        if(isRatioValid(ratio)) {
            tokensHeld = _loan.tokensHeld;
            bool hasUnfundedAmounts;
            uint128[] memory unfundedAmounts;
            (hasUnfundedAmounts, unfundedAmounts, tokensHeld) = getUnfundedAmounts(amounts, tokensHeld);

            if(!hasUnfundedAmounts) {
                // Withdraw collateral tokens from loan
                tokensHeld = withdrawCollateral(_loan, amounts, to);

                // rebalance to ratio
                uint128[] memory _reserves = _getReserves(to);
                int256[] memory deltas = _calcDeltasForRatio(tokensHeld, _reserves, ratio);
                if(isDeltasValid(deltas)) {
                    (tokensHeld,) = rebalanceCollateral(_loan, deltas, _reserves);
                }
            } else {
                // rebalance to match ratio after withdrawal
                int256[] memory deltas = _calcDeltasForWithdrawal(unfundedAmounts, tokensHeld, s.CFMM_RESERVES, ratio);
                if(isDeltasValid(deltas)) {
                    rebalanceCollateral(_loan, deltas, s.CFMM_RESERVES);
                }
                // Withdraw collateral tokens from loan
                tokensHeld = withdrawCollateral(_loan, amounts, to);
            }
        } else {
            tokensHeld = withdrawCollateral(_loan, amounts, to);
        }

        // Check that loan is not undercollateralized
        checkMargin(calcInvariant(s.cfmm, tokensHeld) + onLoanUpdate(_loan, tokenId), loanLiquidity);

        emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.DECREASE_COLLATERAL);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.DECREASE_COLLATERAL);

        return tokensHeld;
    }

    /// @dev See {IBorrowStrategy-_borrowLiquidity}.
    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens, uint256[] calldata ratio) external virtual override lock returns(uint256 liquidityBorrowed, uint256[] memory amounts, uint128[] memory tokensHeld) {
        // Revert if borrowing all CFMM LP tokens in pool
        if(lpTokens >= s.LP_TOKEN_BALANCE) revert ExcessiveBorrowing();

        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        checkExpectedUtilizationRate(lpTokens, true);

        // Withdraw reserve tokens from CFMM that lpTokens represent
        amounts = withdrawFromCFMM(s.cfmm, address(this), lpTokens);

        // Add withdrawn tokens as part of loan collateral
        (tokensHeld,) = updateCollateral(_loan);

        // Add liquidity debt to total pool debt and start tracking loan
        (liquidityBorrowed, loanLiquidity) = openLoan(_loan, lpTokens);

        if(isRatioValid(ratio)) {
            //get current reserves without updating
            uint128[] memory _reserves = getReserves(s.cfmm);
            int256[] memory deltas = _calcDeltasForRatio(tokensHeld, _reserves, ratio);
            if(isDeltasValid(deltas)) {
                (tokensHeld,) = rebalanceCollateral(_loan, deltas, _reserves);
            }
        }

        // Check that loan is not undercollateralized
        checkMargin(calcInvariant(s.cfmm, tokensHeld) + onLoanUpdate(_loan, tokenId), loanLiquidity);

        emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.BORROW_LIQUIDITY);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.BORROW_LIQUIDITY);
    }
}
