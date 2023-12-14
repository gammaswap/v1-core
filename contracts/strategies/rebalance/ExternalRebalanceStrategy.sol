// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../../interfaces/strategies/rebalance/IExternalRebalanceStrategy.sol";
import "../base/BaseExternalStrategy.sol";

/// @title External Long Strategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used to rebalance loan collateral with an external swap (flash loan)
abstract contract ExternalRebalanceStrategy is IExternalRebalanceStrategy, BaseExternalStrategy {

    /// @dev See {BaseLongStrategy-checkMargin}.
    function checkMargin(uint256 collateral, uint256 liquidity) internal override virtual view {
        if(!hasMargin(collateral, liquidity, _ltvThreshold())) revert Margin(); // revert if collateral below ltvThreshold
    }

    /// @dev See {IExternalLongStrategy-_rebalanceExternally}.
    function _rebalanceExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external override lock virtual returns(uint256 loanLiquidity, uint128[] memory tokensHeld) {
        // Get loan for tokenId, revert if not loan creator
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        // Update liquidity debt to include accrued interest since last update
        loanLiquidity = updateLoan(_loan);

        address _cfmm = s.cfmm;

        uint256 liquiditySwapped;
        // Calculate amounts to swap from deltas and available loan collateral
        (liquiditySwapped, tokensHeld) = externalSwap(_loan, _cfmm, amounts, lpTokens, to, data);
        _loan.tokensHeld = tokensHeld;

        if(liquiditySwapped > loanLiquidity) {
            uint256 fee = calcExternalSwapFee(liquiditySwapped, loanLiquidity);
            uint256 borrowedInvariant = s.BORROWED_INVARIANT + fee;
            s.LP_TOKEN_BORROWED_PLUS_INTEREST = convertInvariantToLP(borrowedInvariant, s.lastCFMMTotalSupply, s.lastCFMMInvariant);
            s.BORROWED_INVARIANT = uint128(borrowedInvariant);
            loanLiquidity = loanLiquidity + fee;
            _loan.liquidity = uint128(loanLiquidity);
        }

        // Check that loan is not undercollateralized after external swap
        uint256 collateral = calcInvariant(_cfmm, tokensHeld) + onLoanUpdate(_loan, tokenId);
        checkMargin(collateral, loanLiquidity);

        emit ExternalSwap(tokenId, amounts, lpTokens, uint128(liquiditySwapped), TX_TYPE.EXTERNAL_REBALANCE);

        emit LoanUpdated(tokenId, tokensHeld, uint128(loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.EXTERNAL_REBALANCE);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex,
            s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.EXTERNAL_REBALANCE);
    }

    /// @dev See {ExternalBaseStrategy-checkLPTokens}.
    function checkLPTokens(address _cfmm, uint256 prevLpTokenBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) internal virtual override {
        uint256 newLpTokenBalance = GammaSwapLibrary.balanceOf(_cfmm, address(this));
        if(prevLpTokenBalance > newLpTokenBalance) revert WrongLPTokenBalance();

        // Update CFMM LP Tokens in pool and the invariant it represents
        s.LP_TOKEN_BALANCE = newLpTokenBalance;
        s.LP_INVARIANT = uint128(convertLPToInvariant(newLpTokenBalance, lastCFMMInvariant, lastCFMMTotalSupply));
    }
}
