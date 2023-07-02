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
    function _liquidate(uint256 tokenId) external override lock virtual returns(uint256 loanLiquidity) {
        // Check can liquidate loan and get loan with updated loan liquidity
        // No need to check if msg.sender has permission
        LibStorage.Loan storage _loan = _getExistingLoan(tokenId);

        LiquidatableLoan memory _liqLoan;
        {
            int256[] memory deltas;
            (_liqLoan, deltas) = getLiquidatableLoan(_loan, tokenId);
            rebalanceCollateral(_loan, deltas, s.CFMM_RESERVES); // the rebalancing trade will increase the cfmmLiquidityInvariant, which means I'll actually get less LP tokens
        }

        loanLiquidity = _liqLoan.loanLiquidity;

        if(_liqLoan.payableInternalLiquidityPlusFee > 0) {
            uint256 lpDeposit = repayTokens(_loan, calcTokensToRepay(getReserves(s.cfmm), _liqLoan.payableInternalLiquidityPlusFee));
            GammaSwapLibrary.safeTransfer(s.cfmm, msg.sender, lpDeposit * _liqLoan.internalFee / _liqLoan.payableInternalLiquidityPlusFee);
        }

        (uint128[] memory tokensHeld,) = updateCollateral(_loan); // Update remaining collateral

        _liqLoan.writeDownAmt = payLiquidatableLoan(_liqLoan, 0);

        onLoanUpdate(_loan, tokenId);

        emit Liquidation(tokenId, uint128(_liqLoan.collateral), uint128(loanLiquidity - _liqLoan.writeDownAmt), uint128(_liqLoan.writeDownAmt), uint128(_liqLoan.internalFee), TX_TYPE.LIQUIDATE);

        emit LoanUpdated(tokenId, tokensHeld, 0, 0, 0, 0, TX_TYPE.LIQUIDATE);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.LIQUIDATE);
    }

    /// @dev See {LiquidationStrategy-_liquidateWithLP}.
    function _liquidateWithLP(uint256 tokenId) external override lock virtual returns(uint256 loanLiquidity, uint128[] memory refund) {
        // Check can liquidate loan and get loan with updated loan liquidity and collateral
        // No need to check if msg.sender has permission
        LibStorage.Loan storage _loan = _getExistingLoan(tokenId);

        (LiquidatableLoan memory _liqLoan,) = getLiquidatableLoan(_loan, tokenId);
        loanLiquidity = _liqLoan.loanLiquidity;

        _liqLoan.writeDownAmt = payLiquidatableLoan(_liqLoan, 0);

        uint128[] memory tokensHeld;
        (refund, tokensHeld) = refundLiquidator(_liqLoan.payableInternalLiquidityPlusFee, _liqLoan.internalCollateral, _liqLoan.tokensHeld);

        _loan.tokensHeld = tokensHeld; // Update loan collateral

        onLoanUpdate(_loan, tokenId);

        emit Liquidation(tokenId, uint128(_liqLoan.collateral), uint128(loanLiquidity - _liqLoan.writeDownAmt), uint128(_liqLoan.writeDownAmt), uint128(_liqLoan.internalFee), TX_TYPE.LIQUIDATE_WITH_LP);

        emit LoanUpdated(tokenId, tokensHeld, 0, 0, 0, 0, TX_TYPE.LIQUIDATE_WITH_LP);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.LIQUIDATE_WITH_LP);
    }
}
