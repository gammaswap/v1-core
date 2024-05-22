// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../../interfaces/strategies/liquidation/IBatchLiquidationStrategy.sol";
import "../base/BaseLiquidationStrategy.sol";

/// @title Batch Liquidation Strategy abstract contract implementation of IBatchLiquidationStrategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice All external functions are locked to avoid reentrancy
/// @dev Defines function to liquidate loans in batch
abstract contract BatchLiquidationStrategy is IBatchLiquidationStrategy, BaseLiquidationStrategy {

    /// @dev Aggregate liquidity, collateral amounts, and CFMM LP token principal of loans to liquidate.
    struct SummedLoans {
        /// @dev aggregated debt in liquidity invariant terms to be liquidated
        uint256 liquidityTotal;
        /// @dev aggregated collateral in liquidity invariant terms available for liquidation
        uint256 collateralTotal;
        /// @dev total loan liquidity debt in terms of LP tokens
        uint256 lpTokensTotal;
        /// @dev total fees paid to liquidator
        uint256 feeTotal;
        /// @dev amount of liquidity written down from loans
        uint256 writeDownAmtTotal;
        /// @dev tokenIds that will be liquidated
        uint256[] tokenIds;
    }

    /// @dev See {LiquidationStrategy-_batchLiquidations}.
    function _batchLiquidations(uint256[] calldata tokenIds) external override lock beforeLiquidation virtual
        returns(uint256 totalLoanLiquidity, uint128[] memory refund) {
        if(tokenIds.length == 0) revert InvalidTokenIdsLength(); // Revert if no loan tokenIds are passed

        // Sum up liquidity, collateral, and LP token principal from loans that can be liquidated
        SummedLoans memory summedLoans;
        (summedLoans, refund) = sumLiquidity(tokenIds);

        totalLoanLiquidity = summedLoans.liquidityTotal;

        if(totalLoanLiquidity == 0) revert NoLiquidityDebt(); // Revert if no loans to liquidate

        // write down if there as anything to write down
        uint256 writeDownAmt = summedLoans.writeDownAmtTotal;
        if(writeDownAmt > 0) writeDown(0, writeDownAmt);

        LiquidatableLoan memory _liqLoan;
        _liqLoan.payableInternalLiquidity = totalLoanLiquidity;
        _liqLoan.loanLiquidity = totalLoanLiquidity;

        // Pay total liquidity debts in full with previously deposited CFMM LP tokens and refund remaining collateral to liquidator
        payLiquidatableLoan(_liqLoan, summedLoans.lpTokensTotal, true);

        (refund,) = refundLiquidator(totalLoanLiquidity, totalLoanLiquidity, refund);

        // Store through event tokenIds of loans liquidated in batch and amounts liquidated
        emit Liquidation(0, uint128(summedLoans.collateralTotal), uint128(totalLoanLiquidity), uint128(writeDownAmt), uint128(summedLoans.feeTotal), TX_TYPE.BATCH_LIQUIDATION);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.BATCH_LIQUIDATION);
    }

    /// @dev Aggregate liquidity, collateral amounts, and CFMM LP token principal of loans to liquidate. Skip loans not eligible to liquidate
    /// @return summedLoans - struct containing loan aggregated information
    /// @return refund - refunds that will be sent back to liquidator
    function sumLiquidity(uint256[] calldata tokenIds) internal virtual returns(SummedLoans memory summedLoans, uint128[] memory refund) {
        address cfmm = s.cfmm; // Save gas
        refund = new uint128[](s.tokens.length);
        (uint256 accFeeIndex,,) = updateIndex(); // Update GammaPool state variables and get interest rate index
        uint256 liqFee = _liquidationFee();
        uint128[] memory reserves = s.CFMM_RESERVES;
        summedLoans.tokenIds = new uint256[](tokenIds.length);
        for(uint256 i; i < tokenIds.length;) {
            LibStorage.Loan storage _loan = s.loans[tokenIds[i]];
            uint256 liquidity = _loan.liquidity;
            {
                uint256 rateIndex = _loan.rateIndex;
                // Skip loans already paid in full or that use external collateral
                if(liquidity == 0 || rateIndex == 0 || _loan.refAddr != address(0)) {
                    unchecked {
                        ++i;
                    }
                    continue;
                }
                liquidity = liquidity * accFeeIndex / rateIndex; // Update loan's liquidity debt
            }
            uint128[] memory tokensHeld = _loan.tokensHeld; // Save gas
            uint256 collateral = calcInvariant(cfmm, tokensHeld);
            if(hasMargin(collateral, liquidity, _ltvThreshold())) { // Skip loans with enough collateral
                unchecked {
                    ++i;
                }
                continue;
            }
            summedLoans.tokenIds[i] = tokenIds[i];
            collateral = _calcMaxCollateralNotMktImpact(tokensHeld, reserves); // without market impact
            summedLoans.collateralTotal += collateral;

            uint256 fee = collateral * liqFee / 10000;
            summedLoans.feeTotal += fee;

            uint256 writeDownAmt;
            unchecked {
                writeDownAmt = collateral < (liquidity + fee) ? liquidity + fee - collateral : 0;
                liquidity -= writeDownAmt;
            }
            summedLoans.writeDownAmtTotal += writeDownAmt;

            // Aggregate liquidity debts
            summedLoans.liquidityTotal += liquidity;

            // Aggregate CFMM LP token principals
            summedLoans.lpTokensTotal += _loan.lpTokens;

            // Clear storage, gas refunds
            _loan.liquidity = 0;
            _loan.initLiquidity = 0;
            _loan.rateIndex = 0;
            _loan.lpTokens = 0;
            _loan.px = 0;

            // Aggregate collateral tokens
            for(uint256 j; j < refund.length;) {
                uint128 refundAmt = uint128(GSMath.min(tokensHeld[j], tokensHeld[j] * (liquidity + fee) / collateral));
                refund[j] = refund[j] + refundAmt;
                unchecked {
                    tokensHeld[j] = tokensHeld[j] - refundAmt;
                    ++j;
                }
            }
            _loan.tokensHeld = tokensHeld;

            emit LoanUpdated(tokenIds[i], tokensHeld, uint128(liquidity), 0, 0, 0, TX_TYPE.BATCH_LIQUIDATION);

            unchecked {
                ++i;
            }
        }
    }

    function _calcMaxCollateralNotMktImpact(uint128[] memory tokensHeld, uint128[] memory reserves) internal virtual returns(uint256);
}
