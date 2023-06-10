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
    function _liquidate(uint256 tokenId, int256[] calldata deltas, uint256[] calldata fees) external override lock virtual returns(uint256 loanLiquidity, uint256[] memory refund) {
        // Check can liquidate loan and get loan with updated loan liquidity
        uint256 writeDownAmt;
        uint256 collateral;
        address cfmm = s.cfmm;
        // No need to check if msg.sender has permission
        LibStorage.Loan storage _loan = _getExistingLoan(tokenId);

        if(deltas.length > 0) { // Done here because if pool charges trading fee, it increases the CFMM invariant
            if(deltas.length != _loan.tokensHeld.length) revert InvalidDeltasLength();
            (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(_loan, deltas, getReserves(cfmm));
            swapTokens(_loan, outAmts, inAmts); // Re-balance collateral
        }

        (loanLiquidity, collateral,, writeDownAmt) = getLoanLiquidityAndCollateral(_loan, cfmm);

        // Update loan collateral amounts (e.g. re-balance and/or account for deposited collateral)
        // Repay liquidity debt in full and get back remaining collateral amounts
        uint128[] memory tokensHeld = depositCollateralIntoCFMM(_loan, loanLiquidity + minBorrow(), fees);

        // Pay loan liquidity in full with collateral amounts and refund remaining collateral to liquidator
        // CFMM LP token principal paid will be calculated during function call, hence pass 0
        (tokensHeld, refund,) = payLoanAndRefundLiquidator(tokenId, tokensHeld, loanLiquidity, 0, true);
        _loan.tokensHeld = tokensHeld; // Clear loan collateral

        emit Liquidation(tokenId, uint128(collateral), uint128(loanLiquidity), uint128(writeDownAmt), TX_TYPE.LIQUIDATE, new uint256[](0));

        emit LoanUpdated(tokenId, tokensHeld, 0, 0, 0, 0, TX_TYPE.LIQUIDATE);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.LIQUIDATE);
    }

    /// @dev See {LiquidationStrategy-_liquidateWithLP}.
    function _liquidateWithLP(uint256 tokenId) external override lock virtual returns(uint256 loanLiquidity, uint256[] memory refund) {
        // Check can liquidate loan and get loan with updated loan liquidity and collateral
        uint128[] memory tokensHeld;
        uint256 writeDownAmt;
        uint256 collateral;
        address cfmm = s.cfmm;
        // No need to check if msg.sender has permission
        LibStorage.Loan storage _loan = _getExistingLoan(tokenId);

        (loanLiquidity, collateral, tokensHeld, writeDownAmt) = getLoanLiquidityAndCollateral(_loan, cfmm);

        // Pay loan liquidity in full or partially with previously deposited CFMM LP tokens and refund remaining liquidated share of collateral to liquidator
        // CFMM LP token principal paid will be calculated during function call, hence pass 0
        uint256 _loanLiquidity;
        (tokensHeld, refund, _loanLiquidity) = payLoanAndRefundLiquidator(tokenId, tokensHeld, loanLiquidity, 0, false);
        _loan.tokensHeld = tokensHeld; // Update loan collateral
        loanLiquidity = loanLiquidity - _loanLiquidity;

        emit Liquidation(tokenId, uint128(collateral - calcInvariant(cfmm, tokensHeld)), uint128(loanLiquidity), uint128(writeDownAmt), TX_TYPE.LIQUIDATE_WITH_LP, new uint256[](0));

        emit LoanUpdated(tokenId, tokensHeld, uint128(_loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.LIQUIDATE_WITH_LP);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.LIQUIDATE_WITH_LP);
    }

}
