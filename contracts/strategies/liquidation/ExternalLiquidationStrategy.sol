// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../../interfaces/strategies/liquidation/IExternalLiquidationStrategy.sol";
import "../base/BaseLiquidationStrategy.sol";
import "../base/BaseExternalStrategy.sol";

/// @title External Liquidation Strategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used to liquidate loans with an external swap (flash loan)
abstract contract ExternalLiquidationStrategy is IExternalLiquidationStrategy, BaseLiquidationStrategy, BaseExternalStrategy {

    /// @dev See {IExternalLiquidationStrategy-_liquidateExternally}.
    function _liquidateExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external override lock virtual
        returns(uint256, uint128[] memory) {
        // Check can liquidate loan and get loan with updated loan liquidity and collateral
        // No need to check if msg.sender has permission
        LibStorage.Loan storage _loan = _getExistingLoan(tokenId);

        (LiquidatableLoan memory _liqLoan,) = getLiquidatableLoan(_loan, tokenId);

        uint256 liquiditySwapped;
        (liquiditySwapped, _liqLoan.tokensHeld) = externalSwap(_loan, s.cfmm, amounts, lpTokens, to, data); // of the CFMM LP Tokens that we pulled out, more have to come back

        uint256 loanLiquidity = _liqLoan.loanLiquidity;
        if(liquiditySwapped > loanLiquidity) {
            loanLiquidity += calcExternalSwapFee(liquiditySwapped, loanLiquidity) / 2;
            _loan.liquidity = uint128(loanLiquidity);
        }

        // get share of liquidity from external collateral source deposited in to GammaPool
        repayWithExternalCollateral(_loan, tokenId, _liqLoan.payableExternalLiquidity + _liqLoan.externalFee);

        // Pay loan liquidity in full with collateral amounts and refund remaining collateral to liquidator
        // CFMM LP token principal paid will be calculated during function call, hence pass 0
        payLiquidatableLoan(tokenId, loanLiquidity, 0); // so here we expect to pay in CFMM LP tokens the loanLiquidity amount

        uint128[] memory refund;
        (refund, _liqLoan.tokensHeld) = refundLiquidator(_liqLoan.payableInternalLiquidity + _liqLoan.internalFee, _liqLoan.internalCollateral, _liqLoan.tokensHeld);

        _loan.tokensHeld = _liqLoan.tokensHeld; // Clear loan collateral

        emit ExternalSwap(tokenId, amounts, lpTokens, uint128(liquiditySwapped), TX_TYPE.EXTERNAL_LIQUIDATION);

        emit Liquidation(tokenId, uint128(_liqLoan.collateral), uint128(_liqLoan.loanLiquidity), uint128(_liqLoan.writeDownAmt), uint128(_liqLoan.fee), TX_TYPE.EXTERNAL_LIQUIDATION);

        emit LoanUpdated(tokenId, _liqLoan.tokensHeld, 0, 0, 0, 0, TX_TYPE.EXTERNAL_LIQUIDATION);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.EXTERNAL_LIQUIDATION);

        return(_liqLoan.loanLiquidity, refund);
    }

    /// @dev See {ExternalBaseStrategy-checkLPTokens}.
    function checkLPTokens(address _cfmm, uint256 prevLpTokenBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) internal virtual override {
    }
}
