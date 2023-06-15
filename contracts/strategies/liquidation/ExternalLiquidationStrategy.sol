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
    function _liquidateExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external override lock virtual returns(uint256 loanLiquidity, uint256[] memory refund) {
        // Check can liquidate loan and get loan with updated loan liquidity and collateral
        uint128[] memory tokensHeld;
        uint256 writeDownAmt;
        uint256 collateral;

        // No need to check if msg.sender has permission
        LibStorage.Loan storage _loan = _getExistingLoan(tokenId);
        if(_loan.collateralRef != address(0)) revert ExternalCollateralRef();

        (loanLiquidity, collateral, tokensHeld, writeDownAmt) = getLoanLiquidityAndCollateral(_loan, s.cfmm);

        uint256 liquiditySwapped;
        (liquiditySwapped, tokensHeld) = externalSwap(_loan, s.cfmm, amounts, lpTokens, to, data); // of the CFMM LP Tokens that we pulled out, more have to come back

        if(liquiditySwapped > loanLiquidity) {
            loanLiquidity = loanLiquidity + calcExternalSwapFee(liquiditySwapped, loanLiquidity);
        }

        // Pay loan liquidity in full with collateral amounts and refund remaining collateral to liquidator
        // CFMM LP token principal paid will be calculated during function call, hence pass 0
        (tokensHeld, refund,) = payLoanAndRefundLiquidator(tokenId, tokensHeld, loanLiquidity, 0, true);
        _loan.tokensHeld = tokensHeld; // Clear loan collateral

        emit ExternalSwap(tokenId, amounts, lpTokens, uint128(liquiditySwapped), TX_TYPE.EXTERNAL_LIQUIDATION);

        emit Liquidation(tokenId, uint128(collateral), uint128(loanLiquidity), uint128(writeDownAmt), TX_TYPE.EXTERNAL_LIQUIDATION, new uint256[](0));

        emit LoanUpdated(tokenId, tokensHeld, 0, 0, 0, 0, TX_TYPE.EXTERNAL_LIQUIDATION);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.EXTERNAL_LIQUIDATION);
    }

    /// @dev See {ExternalBaseStrategy-checkLPTokens}.
    function checkLPTokens(address _cfmm, uint256 prevLpTokenBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) internal virtual override {
    }
}
