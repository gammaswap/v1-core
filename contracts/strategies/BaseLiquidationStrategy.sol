// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../interfaces/strategies/base/ILiquidationStrategy.sol";
import "./lending/BaseRepayStrategy.sol";

/// @title Base Liquidation Strategy abstract contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Only defines common functions that would be used by all concrete contracts that implement a liquidation strategy
abstract contract BaseLiquidationStrategy is ILiquidationStrategy, BaseRepayStrategy {

    error NoLiquidityDebt();
    error NoLiquidityProvided();
    error NotFullLiquidation();
    error InvalidTokenIdsLength();
    error InvalidDeltasLength();
    error HasMargin();

    /// @return - liquidationFee - threshold used to measure the liquidation fee
    function _liquidationFee() internal virtual view returns(uint16);

    /// @return - liquidationFeeAdjustment - threshold used to measure the liquidation fee
    function liquidationFeeAdjustment() internal virtual view returns(uint16) {
        return 1e4 - _liquidationFee();
    }

    /// @dev See {LiquidationStrategy-liquidationFee}.
    function liquidationFee() external override virtual view returns(uint256) {
        return _liquidationFee();
    }

    /// @dev See {ILiquidationStrategy-canLiquidate}.
    function canLiquidate(uint256 liquidity, uint256 collateral) external virtual override view returns(bool) {
        return !hasMargin(collateral, liquidity, _ltvThreshold());
    }

    /// @dev Update loan liquidity and check if can liquidate
    /// @param _loan - loan to liquidate
    /// @param cfmm - adress of CFMM
    /// @return loanLiquidity - most updated loan liquidity debt
    /// @return collateral - loan collateral liquidity invariant units
    /// @return tokensHeld - loan collateral token amounts
    /// @return writeDownAmt - collateral liquidity invariant units written down from loan's debt
    function getLoanLiquidityAndCollateral(LibStorage.Loan storage _loan, address cfmm) internal virtual returns(uint256 loanLiquidity, uint256 collateral, uint128[] memory tokensHeld, uint256 writeDownAmt) {
        // Update loan's liquidity debt and GammaPool's state variables
        loanLiquidity = updateLoan(_loan);

        // Check if loan can be liquidated
        tokensHeld = _loan.tokensHeld; // Saves gas
        collateral = calcInvariant(cfmm, tokensHeld);
        checkMargin(collateral, loanLiquidity);

        // Write down any bad debt
        (writeDownAmt, loanLiquidity) = writeDown(adjustCollateralByLiqFee(collateral), loanLiquidity);
    }

    function adjustCollateralByLiqFee(uint256 collateral) internal virtual returns(uint256) {
        return collateral * liquidationFeeAdjustment() / 10000;
    }

    /// @dev Account for liquidity payments in the loan and pool
    /// @param tokenId - id of loan to liquidate
    /// @param tokensHeld - loan collateral
    /// @param loanLiquidity - most updated total loan liquidity debt
    /// @param lpTokenPrincipalPaid - loan's CFMM LP token principal
    /// @param isFullPayment - true if liquidating in full
    /// @return tokensHeld - remaining collateral
    /// @return refund - refunded amounts
    /// @return loanLiquidity - remaining liquidity debt
    function payLoanAndRefundLiquidator(uint256 tokenId, uint128[] memory tokensHeld, uint256 loanLiquidity, uint256 lpTokenPrincipalPaid, bool isFullPayment)
        internal virtual returns(uint128[] memory, uint256[] memory, uint256) {

        uint256 payLiquidity;
        uint256 currLpBalance = s.LP_TOKEN_BALANCE;
        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;

        {
            // Check deposited CFMM LP tokens
            uint256 lpDeposit = GammaSwapLibrary.balanceOf(s.cfmm, address(this)) - currLpBalance;

            // Revert if no CFMM LP tokens deposited to pay this loan
            if(lpDeposit == 0) revert NoLiquidityProvided();

            // Get liquidity being paid from deposited CFMM LP tokens and refund excess CFMM LP tokens
            (payLiquidity, lpDeposit) = refundOverPayment(loanLiquidity, lpDeposit, lastCFMMTotalSupply, lastCFMMInvariant);

            // Track locally GammaPool's current CFMM LP balance
            currLpBalance = currLpBalance + lpDeposit;
        }

        // Check if must be full liquidation
        if(isFullPayment && payLiquidity < loanLiquidity) revert NotFullLiquidation();

        // Refund collateral to liquidator and get remaining collateral and refunded amounts
        uint256[] memory refund;
        (tokensHeld, refund) = refundLiquidator(payLiquidity, loanLiquidity, tokensHeld);

        {
            if(tokenId > 0) { // if liquidating a specific loan
                LibStorage.Loan storage _loan = s.loans[tokenId];

                // Account for loan's liquidity paid and get CFMM LP token principal paid and remaining loan liquidity
                (lpTokenPrincipalPaid, loanLiquidity) = payLoanLiquidity(payLiquidity, loanLiquidity, _loan);
            }
            payPoolDebt(payLiquidity, lpTokenPrincipalPaid, lastCFMMInvariant, lastCFMMTotalSupply, currLpBalance);
        }

        return(tokensHeld, refund, loanLiquidity);
    }

    /// @dev Refund liquidator with collateral from liquidated loan and return remaining loan collateral
    /// @param payLiquidity - liquidity debt paid by liquidator
    /// @param loanLiquidity - most updated loan liquidity debt before payment
    /// @param tokensHeld - loan collateral amounts
    /// @return tokensHeld - remaining loan collateral amounts
    /// @return refund - loan collateral amounts refunded to liquidator
    function refundLiquidator(uint256 payLiquidity, uint256 loanLiquidity, uint128[] memory tokensHeld) internal virtual returns(uint128[] memory, uint256[] memory) {
        address[] memory tokens = s.tokens; // Saves gas
        uint256[] memory refund = new uint256[](tokens.length);
        uint128 payAmt = 0;
        for (uint256 i; i < tokens.length;) {
            payAmt = uint128(payLiquidity * tokensHeld[i] / loanLiquidity); // Collateral share of liquidated debt
            s.TOKEN_BALANCE[i] = s.TOKEN_BALANCE[i] - payAmt;
            refund[i] = payAmt;
            tokensHeld[i] = tokensHeld[i] - payAmt;

            // Refund collateral share of liquidated debt to liquidator
            GammaSwapLibrary.safeTransfer(tokens[i], msg.sender, refund[i]);
        unchecked {
            ++i;
        }
        }
        return(tokensHeld, refund);
    }

    /// @dev See {BaseLongStrategy-checkMargin}.
    function checkMargin(uint256 collateral, uint256 liquidity) internal virtual override view {
        if(hasMargin(collateral, liquidity, _ltvThreshold())) revert HasMargin(); // Revert if loan has enough collateral
    }

    /// @dev Refund liquidator with collateral from liquidated loan and return remaining loan collateral
    /// @param loanLiquidity - most updated loan liquidity debt before payment
    /// @param lpDeposit - CFMM LP token deposit to pay liquidity debt of loan being liquidated
    /// @param lastCFMMTotalSupply - total supply of LP tokens issued by CFMM
    /// @param lastCFMMInvariant - liquidity invariant in CFMM
    /// @return payLiquidity - loan liquidity that will be repaid after refunding excess CFMM LP tokens
    /// @return payLPDeposit - CFMM LP tokens that will be used to repay liquidity after refunding excess CFMM LP tokens
    function refundOverPayment(uint256 loanLiquidity, uint256 lpDeposit, uint256 lastCFMMTotalSupply, uint256 lastCFMMInvariant) internal virtual returns(uint256, uint256) {
        // convert CFMM LP deposit to liquidity invariant
        uint256 payLiquidity = convertLPToInvariant(lpDeposit, lastCFMMInvariant, lastCFMMTotalSupply);
        if(payLiquidity <= loanLiquidity) return(payLiquidity, lpDeposit); // Paying partially or full

        // Overpayment
        uint256 excessInvariant;
        unchecked {
            excessInvariant = payLiquidity - loanLiquidity; // Excess liquidity deposited
        }

        // Convert excess liquidity deposited back to CFMM LP tokens
        uint256 lpRefund = convertInvariantToLP(excessInvariant, lastCFMMTotalSupply, lastCFMMInvariant);
        GammaSwapLibrary.safeTransfer(s.cfmm, msg.sender, lpRefund); // Refund excess LP tokens

        return(loanLiquidity, lpDeposit - lpRefund);
    }

    /// @dev Increase loan collateral amounts then repay liquidity debt
    /// @param _loan - loan whose collateral will be rebalanced
    /// @param loanLiquidity - liquidity of loan to liquidate (avoids reading from _loan again to save gas)
    /// @param fees - fee on transfer for tokens[i]. Send empty array if no token in pool has fee on transfer or array of zeroes
    /// @return tokensHeld - remaining loan collateral amounts
    function depositCollateralIntoCFMM(LibStorage.Loan storage _loan, uint256 loanLiquidity, uint256[] calldata fees) internal virtual returns(uint128[] memory tokensHeld) {
        updateCollateral(_loan); // Update collateral from token deposits or rebalancing

        // Repay liquidity debt, increase lastCFMMTotalSupply and lastCFMMTotalInvariant
        repayTokens(_loan, addFees(calcTokensToRepay(s.CFMM_RESERVES, loanLiquidity), fees));
        (tokensHeld,) = updateCollateral(_loan); // Update remaining collateral
    }
}
