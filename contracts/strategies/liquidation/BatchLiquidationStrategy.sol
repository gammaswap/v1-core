// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../BaseLiquidationStrategy.sol";
import "../../interfaces/strategies/liquidation/IBatchLiquidationStrategy.sol";

/// @title Liquidation Strategy abstract contract implementation of ILiquidationStrategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice All external functions are locked to avoid reentrancy
/// @dev Only defines common functions that would be used by all concrete contracts that liquidate loans
abstract contract BatchLiquidationStrategy is IBatchLiquidationStrategy, BaseLiquidationStrategy {

    /// @dev See {LiquidationStrategy-_batchLiquidations}.
    function _batchLiquidations(uint256[] calldata tokenIds) external override lock virtual returns(uint256 totalLoanLiquidity, uint256 totalCollateral, uint256[] memory refund) {
        if(tokenIds.length == 0) revert InvalidTokenIdsLength(); // Revert if no loan tokenIds are passed

        // Sum up liquidity, collateral, and LP token principal from loans that can be liquidated
        uint256 lpTokenPrincipalPaid;
        uint128[] memory tokensHeld;
        uint256[] memory _tokenIds;
        (totalLoanLiquidity, totalCollateral, lpTokenPrincipalPaid, tokensHeld, _tokenIds) = sumLiquidity(tokenIds);

        if(totalLoanLiquidity == 0) revert NoLiquidityDebt(); // Revert if no loans to liquidate

        uint256 writeDownAmt;
        // Write down bad debt if any
        (writeDownAmt, totalLoanLiquidity) = writeDown(adjustCollateralByLiqFee(totalCollateral), totalLoanLiquidity);

        // Pay total liquidity debts in full with previously deposited CFMM LP tokens and refund remaining collateral to liquidator
        (, refund,) = payLoanAndRefundLiquidator(0, tokensHeld, totalLoanLiquidity, lpTokenPrincipalPaid, true);

        // Store through event tokenIds of loans liquidated in batch and amounts liquidated
        emit Liquidation(0, uint128(totalCollateral), uint128(totalLoanLiquidity), uint128(writeDownAmt), TX_TYPE.BATCH_LIQUIDATION, _tokenIds);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.BATCH_LIQUIDATION);
    }

    /// @dev Aggregate liquidity, collateral amounts, and CFMM LP token principal of loans to liquidate. Skip loans not eligible to liquidate
    /// @param tokenIds - list of tokenIds of loans to liquidate
    /// @return liquidityTotal - loan collateral as liquidity invariant units
    /// @return collateralTotal - most updated loan liquidity debt
    /// @return lpTokensPrincipalTotal - loan liquidity debt after write down
    /// @return tokensHeldTotal - loan liquidity debt after write down
    /// @return _tokenIds - list of tokenIds of loans that will be liquidated (excludes loans that can't be liquidated)
    function sumLiquidity(uint256[] calldata tokenIds) internal virtual returns(uint256 liquidityTotal, uint256 collateralTotal, uint256 lpTokensPrincipalTotal, uint128[] memory tokensHeldTotal, uint256[] memory _tokenIds) {
        address[] memory tokens = s.tokens; // Save gas
        uint128[] memory tokensHeld;
        address cfmm = s.cfmm; // Save gas
        tokensHeldTotal = new uint128[](tokens.length);
        (uint256 accFeeIndex,,) = updateIndex(); // Update GammaPool state variables and get interest rate index
        _tokenIds = new uint256[](tokenIds.length); // Array of ids of loans eligible to liquidate
        for(uint256 i; i < tokenIds.length;) {
            LibStorage.Loan storage _loan = s.loans[tokenIds[i]];
            uint256 liquidity = _loan.liquidity;
            uint256 rateIndex = _loan.rateIndex;
            if(liquidity == 0 || rateIndex == 0) { // Skip loans already paid in full
                unchecked {
                    ++i;
                }
                continue;
            }
            liquidity = liquidity * accFeeIndex / rateIndex; // Update loan's liquidity debt
            tokensHeld = _loan.tokensHeld; // Save gas
            uint256 collateral = calcInvariant(cfmm, tokensHeld);
            if(hasMargin(collateral, liquidity, _ltvThreshold())) { // Skip loans with enough collateral
                unchecked {
                    ++i;
                }
                continue;
            }
            _tokenIds[i] = tokenIds[i]; // Can liquidate loan

            // Aggregate CFMM LP token principals
            lpTokensPrincipalTotal = lpTokensPrincipalTotal + _loan.lpTokens;

            // Clear storage, gas refunds
            _loan.liquidity = 0;
            _loan.initLiquidity = 0;
            _loan.rateIndex = 0;
            _loan.lpTokens = 0;

            // Aggregate collateral invariants
            collateralTotal = collateralTotal + collateral;

            // Aggregate liquidity debts
            liquidityTotal = liquidityTotal + liquidity;

            // Aggregate collateral tokens
            for(uint256 j; j < tokens.length;) {
                tokensHeldTotal[j] = tokensHeldTotal[j] + tokensHeld[j];
                _loan.tokensHeld[j] = 0;
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }
}
