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

    /// @dev Get the amounts that do not have enough collateral to withdraw from the loan's collateral
    /// @param amounts - collateral quantities requested to withdraw and therefore checked against existing collateral in the loan.
    /// @param tokensHeld - collateral quantities in loan
    /// @return hasUnfundedAmounts - if true, we don't have enough collateral to withdraw for at least on token of the CFMM
    /// @return unfundedAmounts - amount requested to withdraw for which there isn't enough collateral to withdraw
    function getUnfundedAmounts(uint128[] memory amounts, uint128[] memory tokensHeld) internal virtual view returns(bool hasUnfundedAmounts, uint128[] memory unfundedAmounts){
        uint256 len = tokensHeld.length;
        unfundedAmounts = new uint128[](len);
        hasUnfundedAmounts = false;
        for(uint256 i = 0; i < len;) {
            if(amounts[i] > tokensHeld[i]) { // if amount requested is higher than existing collateral
                hasUnfundedAmounts = true; // we don't have enough collateral of at least one token to withdraw
                unfundedAmounts[i] = amounts[i]; // amount we are requesting to withdraw for which there isn't enough collateral
            }
            unchecked {
                i++;
            }
        }
    }

    /// @dev Ask for reserve quantities from CFMM if address that will receive withdrawn quantities is CFMM
    /// @param to - address that will receive withdrawn collateral quantities
    /// @return reserves - CFMM reserve quantities
    function _getReserves(address to) internal virtual view returns(uint128[] memory) {
        if(to == s.cfmm) {
            return getReserves(s.cfmm);
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

        if(ratio.length > 0) {
            (tokensHeld,) = rebalanceCollateral(_loan, _calcDeltasForRatio(_loan.tokensHeld, s.CFMM_RESERVES, ratio), s.CFMM_RESERVES);
            // Check that loan is not undercollateralized after swap
            checkMargin(calcInvariant(s.cfmm, tokensHeld) + getExternalCollateral(_loan, tokenId), loanLiquidity);
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
        uint256 externalCollateral = getExternalCollateral(_loan, tokenId);
        if(ratio.length > 0) {
            tokensHeld = _loan.tokensHeld;
            (bool hasUnfundedAmounts, uint128[] memory unfundedAmounts) = getUnfundedAmounts(amounts, tokensHeld);

            if(!hasUnfundedAmounts) {
                // Withdraw collateral tokens from loan
                tokensHeld = withdrawCollateral(_loan, loanLiquidity, externalCollateral, amounts, to);

                // rebalance to ratio
                uint128[] memory _reserves = _getReserves(to);
                (tokensHeld,) = rebalanceCollateral(_loan, _calcDeltasForRatio(tokensHeld, _reserves, ratio), _reserves);

                // Check that loan is not undercollateralized after swap
                checkMargin(calcInvariant(s.cfmm, tokensHeld) + externalCollateral, loanLiquidity);
            } else {
                // rebalance to match ratio after withdrawal
                // TODO: Have to withdraw the funded amount from tokensHeld first
                rebalanceCollateral(_loan, _calcDeltasForWithdrawal(unfundedAmounts, tokensHeld, s.CFMM_RESERVES, ratio), s.CFMM_RESERVES);
                // Withdraw collateral tokens from loan
                tokensHeld = withdrawCollateral(_loan, loanLiquidity, externalCollateral, amounts, to);
            }
        } else {
            tokensHeld = withdrawCollateral(_loan, loanLiquidity, externalCollateral, amounts, to);
        }

        emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.DECREASE_COLLATERAL);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.DECREASE_COLLATERAL);

        return tokensHeld;
    }

    /// @dev See {IBorrowStrategy-_borrowLiquidity}.
    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens, uint256[] calldata ratio) external virtual override lock returns(uint256 liquidityBorrowed, uint256[] memory amounts) {
        // Revert if borrowing all CFMM LP tokens in pool
        if(lpTokens >= s.LP_TOKEN_BALANCE) revert ExcessiveBorrowing();

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
            if(ratio.length != tokensHeld.length) revert InvalidRatioLength();
            //get current reserves without updating
            uint128[] memory _reserves = getReserves(s.cfmm);
            (tokensHeld,) = rebalanceCollateral(_loan, _calcDeltasForRatio(tokensHeld, _reserves, ratio), _reserves);
        }

        // Check that loan is not undercollateralized
        checkMargin(calcInvariant(s.cfmm, tokensHeld) + getExternalCollateral(_loan, tokenId), loanLiquidity);

        emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.BORROW_LIQUIDITY);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.BORROW_LIQUIDITY);
    }
}