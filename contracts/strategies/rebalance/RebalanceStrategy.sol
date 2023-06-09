// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../interfaces/strategies/rebalance/IRebalanceStrategy.sol";
import "../BaseRebalanceStrategy.sol";

/// @title Long Strategy abstract contract implementation of ILongStrategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice All external functions are locked to avoid reentrancy
/// @dev Only defines common functions that would be used by all concrete contracts that borrow and repay liquidity
abstract contract RebalanceStrategy is IRebalanceStrategy, BaseRebalanceStrategy {

    /// @dev See {ILongStrategy-calcDeltasForRatio}.
    function calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) external virtual override view returns(int256[] memory deltas) {
        return _calcDeltasForRatio(tokensHeld, reserves, ratio);
    }

    /// @dev See {ILongStrategy-calcDeltasToClose}.
    function calcDeltasToClose(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity, uint256 collateralId)
        external virtual override view returns(int256[] memory deltas) {
        return _calcDeltasToClose(tokensHeld, reserves, liquidity, collateralId);
    }

    /// @dev See {ILongStrategy-calcDeltasForWithdrawal}.
    function calcDeltasForWithdrawal(uint128[] memory amounts, uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) external virtual override view returns(int256[] memory deltas) {
        return _calcDeltasForWithdrawal(amounts, tokensHeld, reserves, ratio);
    }

    /// @dev See {ILongStrategy-_rebalanceCollateral}.
    function _rebalanceCollateral(uint256 tokenId, int256[] memory deltas, uint256[] calldata ratio) external virtual override lock returns(uint128[] memory tokensHeld) {
        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt to include accrued interest since last update
        uint256 loanLiquidity = updateLoan(_loan);

        tokensHeld = _loan.tokensHeld;
        if(ratio.length > 0) {
            if(ratio.length != tokensHeld.length) revert InvalidRatioLength();
            deltas = _calcDeltasForRatio(tokensHeld, s.CFMM_RESERVES, ratio);
        }

        if(deltas.length != tokensHeld.length) revert InvalidDeltasLength();

        (tokensHeld,) = rebalanceCollateral(_loan, deltas, s.CFMM_RESERVES);

        // Check that loan is not undercollateralized after swap
        checkMargin(calcInvariant(s.cfmm, tokensHeld), loanLiquidity);

        emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.REBALANCE_COLLATERAL);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.REBALANCE_COLLATERAL);
    }

    /// @dev See {ILongStrategy-_updatePool}
    function _updatePool(uint256 tokenId) external virtual override lock returns(uint256 loanLiquidityDebt, uint256 poolLiquidityDebt) {
        if(tokenId > 0) {
            // Get loan for tokenId, revert if loan does not exist
            LibStorage.Loan storage _loan = _getExistingLoan(tokenId);

            // Update pool and loan liquidity debt to include accrued interest since last update
            loanLiquidityDebt = updateLoan(_loan);

            emit LoanUpdated(tokenId, _loan.tokensHeld, uint128(loanLiquidityDebt), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.UPDATE_POOL);
        } else {
            // Update pool liquidity debt to include accrued interest since last update
            updateIndex();
        }

        poolLiquidityDebt = s.BORROWED_INVARIANT;

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, uint128(poolLiquidityDebt), s.CFMM_RESERVES, TX_TYPE.UPDATE_POOL);
    }
}
