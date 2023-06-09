// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/strategies/lending/IRepayStrategy.sol";
import "./BaseRepayStrategy.sol";
import "../BaseRebalanceStrategy.sol";

/// @title Long Strategy abstract contract implementation of ILongStrategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice All external functions are locked to avoid reentrancy
/// @dev Only defines common functions that would be used by all concrete contracts that borrow and repay liquidity
abstract contract RepayStrategy is IRepayStrategy, BaseRepayStrategy, BaseRebalanceStrategy {

    error ZeroRepayLiquidity();
    error BadDebt();

    /// @dev Calculate remaining collateral after rebalancing. Used for calculating remaining partial collateral
    /// @param collateral - collateral amounts before collateral changes
    /// @param deltas - collateral changes
    /// @return remaining - remaining collateral after collateral changes
    function remainingCollateral(uint128[] memory collateral, int256[] memory deltas) internal virtual view returns(uint128[] memory) {
        uint256 tokenCount = deltas.length;
        for(uint256 i = 0; i < tokenCount;) {
            int256 delta = deltas[i];
            if(delta > 0) {
                collateral[i] += uint128(uint256(delta));
            } else if(delta < 0) {
                uint128 _delta = uint128(uint256(-delta));
                if(_delta > collateral[i]) { // in case rounding issue
                    collateral[i] = 0;
                } else {
                    collateral[i] -= _delta;
                }
            }
            unchecked {
                ++i;
            }
        }
        return collateral;
    }

    /// @dev Calculate pro rata collateral portion of total loan's collateral that corresponds to `liquidity` portion of `totalLiquidityDebt`
    /// @param tokensHeld - loan total collateral available to pay loan
    /// @param liquidity - liquidity that we'll pay using loan collateral
    /// @param totalLiquidityDebt - total liquidity debt of loan
    /// @param fees - fees to transfer during payment in case token has transfer fees
    /// @return collateral - collateral portion of total collateral that will be used to pay `liquidity`
    function proRataCollateral(uint128[] memory tokensHeld, uint256 liquidity, uint256 totalLiquidityDebt, uint256[] calldata fees) internal virtual view returns(uint128[] memory) {
        uint256 tokenCount = tokensHeld.length;
        bool skipFees = tokenCount != fees.length;
        for(uint256 i = 0; i < tokenCount;) {
            tokensHeld[i] = uint128(Math.min(((tokensHeld[i] * liquidity * 10000 - (skipFees ? 0 : tokensHeld[i] * liquidity * fees[i])) / (totalLiquidityDebt * 10000)), uint256(tokensHeld[i])));
            unchecked {
                ++i;
            }
        }
        return tokensHeld;
    }

    /// @dev Update loan with latest accrued interest and write down debt if there is bad debt
    /// @notice if there is bad debt only accept repayment in full
    /// @notice unlikely to happen but done to avoid a situation where liquidity > 0 but collateral = 0
    /// @notice in such a situation a liquidator would not have any incentive to liquidate and write down the debt
    /// @param _loan - loan to update liquidity debt
    /// @param payLiquidity - amount of liquidity to pay
    /// @return loanLiquidity - updated liquidity debt of loan, including debt write down
    function updatePayableLoan(LibStorage.Loan storage _loan, uint256 payLiquidity)internal virtual returns(uint256 loanLiquidity){
        loanLiquidity = updateLoan(_loan);
        uint256 collateral = calcInvariant(s.cfmm, _loan.tokensHeld);
        uint256 _minBorrow = minBorrow();
        collateral = collateral > _minBorrow ? collateral - _minBorrow : 0;
        if(loanLiquidity > collateral) { // collateral must cover liquidity debt by minBorrow amount
            if(payLiquidity < loanLiquidity && collateral > 0) revert BadDebt(); // only write down if paying in full
            (,loanLiquidity) = writeDown(collateral, loanLiquidity); // also write down if collateral is 0
            _loan.liquidity = uint128(loanLiquidity);
        }
        return loanLiquidity;
    }

    /// @dev See {ILongStrategy-_repayLiquidity}.
    function _repayLiquidity(uint256 tokenId, uint256 payLiquidity, uint256[] calldata fees, uint256 collateralId, address to) external virtual override lock returns(uint256 liquidityPaid, uint256[] memory amounts) {
        if(payLiquidity == 0) revert ZeroRepayLiquidity();

        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updatePayableLoan(_loan, payLiquidity);

        // Cap liquidity repayment at total liquidity debt
        uint256 liquidityToCalculate;
        (liquidityPaid, liquidityToCalculate) = payLiquidity >= loanLiquidity ? (loanLiquidity, loanLiquidity + minBorrow()) : (payLiquidity, payLiquidity);

        uint128[] memory collateral;
        if(collateralId > 0) {
            // rebalance to close, get deltas, call rebalance
            collateral = proRataCollateral(_loan.tokensHeld, liquidityToCalculate, loanLiquidity, fees);
            (, int256[] memory deltas) = rebalanceCollateral(_loan, _calcDeltasToClose(collateral, s.CFMM_RESERVES, liquidityToCalculate, collateralId - 1), s.CFMM_RESERVES);
            collateral = remainingCollateral(collateral,deltas);
            updateIndex();
        }

        // Calculate reserve tokens that liquidity repayment represents
        amounts = addFees(calcTokensToRepay(s.CFMM_RESERVES, liquidityToCalculate), fees);

        // Repay liquidity debt with reserve tokens, must check against available loan collateral
        repayTokens(_loan, amounts);

        // Update loan collateral after repayment
        (uint128[] memory tokensHeld, int256[] memory deltas) = updateCollateral(_loan);

        // Subtract loan liquidity repaid from total liquidity debt in pool and loan
        uint256 remainingLiquidity;
        (liquidityPaid, remainingLiquidity) = payLoan(_loan, liquidityPaid, loanLiquidity);

        if(collateralId > 0 && to != address(0)) {
            // withdraw, check margin
            tokensHeld = withdrawCollateral(_loan, remainingLiquidity, remainingCollateral(collateral, deltas), to);
        }

        // Do not check for loan undercollateralization because repaying debt always improves pool debt health

        emit LoanUpdated(tokenId, tokensHeld, uint128(remainingLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.REPAY_LIQUIDITY);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.REPAY_LIQUIDITY);
    }
}
