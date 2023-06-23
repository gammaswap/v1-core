// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../../interfaces/strategies/liquidation/ISingleLiquidationStrategy.sol";
import "../base/BaseLiquidationStrategy.sol";

/// @title Liquidation Strategy abstract contract implementation of ILiquidationStrategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice All external functions are locked to avoid reentrancy
/// @dev Only defines common functions that would be used by all concrete contracts that liquidate loans
abstract contract SingleLiquidationStrategy is ISingleLiquidationStrategy, BaseLiquidationStrategy {

    error ExternalCollateralRef();

    /// @dev See {LiquidationStrategy-_liquidate}.
    function _liquidate(uint256 tokenId, uint256[] calldata fees) external override lock virtual returns(uint256 loanLiquidity) {
        // Check can liquidate loan and get loan with updated loan liquidity
        // No need to check if msg.sender has permission
        LibStorage.Loan storage _loan = _getExistingLoan(tokenId);
        if(_loan.collateralRef != address(0)) revert ExternalCollateralRef();

        LiquidatableLoan memory _liqLoan;
        {
            int256[] memory deltas;
            (_liqLoan, deltas) = getLiquidatableLoan(_loan);
            rebalanceCollateral(_loan, deltas, s.CFMM_RESERVES);
        }

        loanLiquidity = _liqLoan.loanLiquidity;

        // Update loan collateral amounts (e.g. re-balance and/or account for deposited collateral)
        // Repay liquidity debt in full and get back remaining collateral amounts
        repayTokens(_loan, addFees(calcTokensToRepay(getReserves(s.cfmm), loanLiquidity + _liqLoan.fee), fees));
        (uint128[] memory tokensHeld,) = updateCollateral(_loan); // Update remaining collateral

        // Pay loan liquidity in full with collateral amounts and refund remaining collateral to liquidator
        // CFMM LP token principal paid will be calculated during function call, hence pass 0
        payLiquidatableLoan(tokenId, loanLiquidity, 0);

        // we don't call refundLiquidator after paying the loan because deposit of LP tokens before resulted in an
        // LP token refund. This refund is the fee for the liquidator

        emit Liquidation(tokenId, uint128(_liqLoan.collateral), uint128(loanLiquidity), uint128(_liqLoan.writeDownAmt), uint128(_liqLoan.fee), TX_TYPE.LIQUIDATE);

        emit LoanUpdated(tokenId, tokensHeld, 0, 0, 0, 0, TX_TYPE.LIQUIDATE);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.LIQUIDATE);
    }

    /// @dev See {LiquidationStrategy-_liquidateWithLP}.
    function _liquidateWithLP(uint256 tokenId) external override lock virtual returns(uint256 loanLiquidity, uint128[] memory refund) {
        // Check can liquidate loan and get loan with updated loan liquidity and collateral
        // No need to check if msg.sender has permission
        LibStorage.Loan storage _loan = _getExistingLoan(tokenId);
        if(_loan.collateralRef != address(0)) revert ExternalCollateralRef();

        (LiquidatableLoan memory _liqLoan,) = getLiquidatableLoan(_loan);
        loanLiquidity = _liqLoan.loanLiquidity;

        // In this case you send LPs and get more LPs back, what if you send LPs and get tokensHeld back
        // Pay loan liquidity in full or partially with previously deposited CFMM LP tokens and refund remaining liquidated share of collateral to liquidator
        // CFMM LP token principal paid will be calculated during function call, hence pass 0
        payLiquidatableLoan(tokenId, loanLiquidity, 0);

        uint128[] memory tokensHeld;
        (refund, tokensHeld) = refundLiquidator(loanLiquidity + _liqLoan.fee, _liqLoan.collateral, _liqLoan.tokensHeld);

        _loan.tokensHeld = tokensHeld; // Update loan collateral

        emit Liquidation(tokenId, uint128(_liqLoan.collateral), uint128(loanLiquidity), uint128(_liqLoan.writeDownAmt), uint128(_liqLoan.fee), TX_TYPE.LIQUIDATE_WITH_LP);

        emit LoanUpdated(tokenId, tokensHeld, 0, 0, 0, 0, TX_TYPE.LIQUIDATE_WITH_LP);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.LIQUIDATE_WITH_LP);
    }
}
