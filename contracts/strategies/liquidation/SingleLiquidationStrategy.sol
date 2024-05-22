// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../../interfaces/strategies/liquidation/ISingleLiquidationStrategy.sol";
import "../base/BaseLiquidationStrategy.sol";

/// @title Liquidation Strategy abstract contract implementation of ILiquidationStrategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice All external functions are locked to avoid reentrancy
/// @dev Only defines common functions that would be used by all concrete contracts that liquidate loans
abstract contract SingleLiquidationStrategy is ISingleLiquidationStrategy, BaseLiquidationStrategy {

    /// @dev See {LiquidationStrategy-_liquidate}.
    function _liquidate(uint256 tokenId) external override lock beforeLiquidation virtual returns(uint256 loanLiquidity, uint256 refund) {
        // Check can liquidate loan and get loan with updated loan liquidity
        // No need to check if msg.sender has permission
        LibStorage.Loan storage _loan = _getExistingLoan(tokenId);

        uint128[] memory tokensHeld = _loan.tokensHeld;
        LiquidatableLoan memory _liqLoan;
        {
            int256[] memory deltas;
            (_liqLoan, deltas) = getLiquidatableLoan(_loan, tokenId);
            if(isDeltasValid(deltas)) {
                (tokensHeld,) = rebalanceCollateral(_loan, deltas, s.CFMM_RESERVES); // the rebalancing trade will increase the cfmmLiquidityInvariant, which means I'll actually get less LP tokens
                updateIndex();
            }
        }

        loanLiquidity = _liqLoan.loanLiquidity;

        if(_liqLoan.payableInternalLiquidityPlusFee > 0) {
            uint256 lpDeposit = repayTokens(_loan, calcTokensToRepay(getLPReserves(s.cfmm,false), _liqLoan.payableInternalLiquidityPlusFee, tokensHeld, true));
            refund = lpDeposit * _liqLoan.internalFee / _liqLoan.payableInternalLiquidityPlusFee;
            if(refund <= minPay()) {
                refund = 0;
            } else {
                GammaSwapLibrary.safeTransfer(s.cfmm, msg.sender, refund);
            }
            updateIndex();
        }

        (tokensHeld,) = updateCollateral(_loan); // Update remaining collateral

        _liqLoan.writeDownAmt = payLiquidatableLoan(_liqLoan, 0, false);

        onLoanUpdate(_loan, tokenId);

        emit Liquidation(tokenId, uint128(_liqLoan.collateral), uint128(loanLiquidity - _liqLoan.writeDownAmt), uint128(_liqLoan.writeDownAmt), uint128(_liqLoan.internalFee), TX_TYPE.LIQUIDATE);

        emit LoanUpdated(tokenId, tokensHeld, 0, 0, 0, 0, TX_TYPE.LIQUIDATE);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.LIQUIDATE);
    }

    /// @dev See {LiquidationStrategy-_liquidateWithLP}.
    function _liquidateWithLP(uint256 tokenId) external override lock beforeLiquidation virtual returns(uint256 loanLiquidity, uint128[] memory refund) {
        // Check can liquidate loan and get loan with updated loan liquidity and collateral
        // No need to check if msg.sender has permission
        LibStorage.Loan storage _loan = _getExistingLoan(tokenId);

        (LiquidatableLoan memory _liqLoan,) = getLiquidatableLoan(_loan, tokenId);
        loanLiquidity = _liqLoan.loanLiquidity;

        _liqLoan.writeDownAmt = payLiquidatableLoan(_liqLoan, 0, true);

        uint128[] memory tokensHeld;
        (refund, tokensHeld) = refundLiquidator(_liqLoan.payableInternalLiquidityPlusFee, _liqLoan.internalCollateral, _liqLoan.tokensHeld);

        _loan.tokensHeld = tokensHeld; // Update loan collateral

        onLoanUpdate(_loan, tokenId);

        emit Liquidation(tokenId, uint128(_liqLoan.collateral), uint128(loanLiquidity - _liqLoan.writeDownAmt), uint128(_liqLoan.writeDownAmt), uint128(_liqLoan.internalFee), TX_TYPE.LIQUIDATE_WITH_LP);

        emit LoanUpdated(tokenId, tokensHeld, 0, 0, 0, 0, TX_TYPE.LIQUIDATE_WITH_LP);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.LIQUIDATE_WITH_LP);
    }
}
