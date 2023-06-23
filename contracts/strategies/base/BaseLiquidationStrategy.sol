// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../../interfaces/strategies/base/ILiquidationStrategy.sol";
import "./BaseRepayStrategy.sol";

/// @title Base Liquidation Strategy abstract contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Only defines common functions that would be used by all concrete contracts that implement a liquidation strategy
abstract contract BaseLiquidationStrategy is ILiquidationStrategy, BaseRepayStrategy {

    error NoLiquidityDebt();
    error NoLiquidityProvided();
    error NotFullLiquidation();
    error InvalidTokenIdsLength();
    error HasMargin();

    /// @dev loan data used to determine results of liquidation
    struct LiquidatableLoan {
        /// @dev most updated loan liquidity invariant debt
        uint256 loanLiquidity;
        /// @dev loan collateral in liquidity invariant units
        uint256 collateral;
        /// @dev loan collateral token amounts
        uint128[] tokensHeld;
        /// @dev collateral liquidity invariant units written down from loan's debt
        uint256 writeDownAmt;
        /// @dev fee in liquidity invariant units paid for liquidation
        uint256 fee;
    }

    /// @return - liquidationFee - threshold used to measure the liquidation fee
    function _liquidationFee() internal virtual view returns(uint16);

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
    /// @return _liqLoan - loan with most updated data used for liquidation
    /// @return deltas - deltas to rebalance collateral to get max LP deposit
    function getLiquidatableLoan(LibStorage.Loan storage _loan) internal virtual
        returns(LiquidatableLoan memory _liqLoan, int256[] memory deltas) {
        // Update loan's liquidity debt and GammaPool's state variables
        uint256 loanLiquidity = updateLoan(_loan);

        // Check if loan can be liquidated
        uint128[] memory tokensHeld = _loan.tokensHeld; // Saves gas
        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        checkMargin(collateral, loanLiquidity);

        // the loanLiquidity should match the number of tokens we expect to deposit including theliquidation fee
        deltas = _calcDeltasForMaxLP(tokensHeld, s.CFMM_RESERVES);
        collateral = _calcMaxCollateral(deltas, tokensHeld, s.CFMM_RESERVES);

        // we deposit enought to cover the liquidity + the liquidationFee. We send the liquidationFee to the
        // the collateral gives us the maxCollateral that we may deposit, after the writeDown (if any) we calculate
        // exact amounts to cover the liquidity debt + liquidation fee and deposit those amounts
        uint256 fee = collateral * _liquidationFee() / 10000;
        (_liqLoan.writeDownAmt, _liqLoan.loanLiquidity) = writeDown(collateral - fee, loanLiquidity);
        _liqLoan.fee = fee;
        _liqLoan.collateral = collateral;
        _liqLoan.tokensHeld = tokensHeld;
    }

    /// @dev Account for liquidity payments in the loan and pool
    /// @param tokenId - id of loan to liquidate
    /// @param loanLiquidity - most updated total loan liquidity debt
    /// @param lpTokensPaid - loan's CFMM LP token principal
    /// @return loanLiquidity - remaining liquidity debt
    function payLiquidatableLoan(uint256 tokenId, uint256 loanLiquidity, uint256 lpTokensPaid)
        internal virtual returns(uint256) {

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
        if(payLiquidity < loanLiquidity) revert NotFullLiquidation();

        {
            if(tokenId > 0) { // if liquidating a specific loan
                LibStorage.Loan storage _loan = s.loans[tokenId];

                // Account for loan's liquidity paid and get CFMM LP token principal paid and remaining loan liquidity
                (lpTokensPaid, loanLiquidity) = payLoanLiquidity(payLiquidity, loanLiquidity, _loan);
            }
            payPoolDebt(payLiquidity, lpTokensPaid, lastCFMMInvariant, lastCFMMTotalSupply, currLpBalance);
        }

        return loanLiquidity;
    }

    /// @dev Refund liquidator with collateral from liquidated loan and return remaining loan collateral
    /// @param loanLiquidity - most updated loan liquidity debt before payment
    /// @param collateral - liquidity unit value of collateral tokens at current prices
    /// @param tokensHeld - loan collateral amounts
    /// @return refund - loan collateral amounts refunded to liquidator
    /// @return tokensHeld - remaining loan collateral amounts
    function refundLiquidator(uint256 loanLiquidity, uint256 collateral, uint128[] memory tokensHeld)
        internal virtual returns(uint128[] memory, uint128[] memory) {
        address[] memory tokens = s.tokens;
        uint128[] memory refund = new uint128[](tokens.length);
        for(uint256 i = 0; i < tokens.length;) {
            refund[i] = uint128(loanLiquidity * tokensHeld[i] / collateral);
            s.TOKEN_BALANCE[i] = s.TOKEN_BALANCE[i] - refund[i];
            tokensHeld[i] = tokensHeld[i] - refund[i];
            GammaSwapLibrary.safeTransfer(tokens[i], msg.sender, refund[i]);
            unchecked{
                ++i;
            }
        }
        return(refund, tokensHeld);
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
        GammaSwapLibrary.safeTransfer(s.cfmm, msg.sender, lpRefund); // Refund excess LP tokens, includes liquidation fee

        return(loanLiquidity, lpDeposit - lpRefund);
    }
}
