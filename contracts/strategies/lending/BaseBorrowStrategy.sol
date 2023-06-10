// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../BaseLongStrategy.sol";

/// @title Abstract base contract for Borrow Strategy implementation
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice All functions here are internal, external functions implemented in BaseLongStrategy as part of ILongStrategy implementation
/// @dev Only defines common functions that would be used by all contracts that borrow liquidity
abstract contract BaseBorrowStrategy is BaseLongStrategy {
    /// @dev Calculate loan price every time more liquidity is borrowed
    /// @param newLiquidity - new added liquidity debt to loan
    /// @param currPrice - current entry price of loan
    /// @param liquidity - existing liquidity debt of loan
    /// @param lastPx - current entry price of loan
    /// @return px - reserve token amounts in CFMM that liquidity invariant converted to
    function updateLoanPrice(uint256 newLiquidity, uint256 currPrice, uint256 liquidity, uint256 lastPx) internal virtual view returns(uint256) {
        uint256 totalLiquidity = newLiquidity + liquidity;
        uint256 totalLiquidityPx = newLiquidity * currPrice + liquidity * lastPx;
        return totalLiquidityPx / totalLiquidity;
    }

    /// @dev Account for newly borrowed liquidity debt
    /// @param _loan - loan that incurred debt
    /// @param lpTokens - CFMM LP tokens borrowed
    /// @return liquidityBorrowed - increase in liquidity debt
    /// @return liquidity - new loan liquidity debt
    function openLoan(LibStorage.Loan storage _loan, uint256 lpTokens) internal virtual returns(uint256 liquidityBorrowed, uint256 liquidity) {
        // Liquidity invariant in CFMM, updated at start of transaction that opens loan. Overstated after loan opening
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;
        // Total CFMM LP tokens in existence, updated at start of transaction that opens loan. Overstated after loan opening
        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;

        // Calculate borrowed liquidity invariant excluding loan origination fee
        // Irrelevant that lastCFMMInvariant and lastCFMMInvariant are overstated since their conversion rate did not change
        uint256 liquidityBorrowedExFee = convertLPToInvariant(lpTokens, lastCFMMInvariant, lastCFMMTotalSupply);

        // Can't borrow less than minimum liquidity to avoid rounding issues
        if (liquidityBorrowedExFee < minBorrow()) revert MinBorrow();

        // Calculate add loan origination fee to LP token debt
        uint256 lpTokensPlusOrigFee = lpTokens + lpTokens * originationFee() / 10000;

        // Calculate borrowed liquidity invariant including origination fee
        liquidityBorrowed = convertLPToInvariant(lpTokensPlusOrigFee, lastCFMMInvariant, lastCFMMTotalSupply);

        // Add liquidity invariant borrowed including origination fee to total pool liquidity invariant borrowed
        uint256 borrowedInvariant = s.BORROWED_INVARIANT + liquidityBorrowed;

        s.BORROWED_INVARIANT = uint128(borrowedInvariant);
        s.LP_TOKEN_BORROWED = s.LP_TOKEN_BORROWED + lpTokens; // Track total CFMM LP tokens borrowed from pool (principal)

        // Update CFMM LP tokens deposited in GammaPool, this could be higher than expected. Excess CFMM LP tokens accrue to GS LPs
        uint256 lpTokenBalance = GammaSwapLibrary.balanceOf(s.cfmm, address(this));
        s.LP_TOKEN_BALANCE = lpTokenBalance;

        // Update liquidity invariant from CFMM LP tokens deposited in GammaPool
        uint256 lpInvariant = convertLPToInvariant(lpTokenBalance, lastCFMMInvariant, lastCFMMTotalSupply);
        s.LP_INVARIANT = uint128(lpInvariant);

        // Add CFMM LP tokens borrowed (principal) plus origination fee to pool's total CFMM LP tokens borrowed including accrued interest
        s.LP_TOKEN_BORROWED_PLUS_INTEREST = s.LP_TOKEN_BORROWED_PLUS_INTEREST + lpTokensPlusOrigFee;

        // Update loan's total liquidity debt and principal amounts
        uint256 loanLiquidity = _loan.liquidity;
        _loan.px = updateLoanPrice(liquidityBorrowed, getCurrentCFMMPrice(), loanLiquidity, _loan.px);
        liquidity = loanLiquidity + liquidityBorrowed;
        _loan.initLiquidity = _loan.initLiquidity + uint128(liquidityBorrowed);
        _loan.lpTokens = _loan.lpTokens + lpTokens;
        _loan.liquidity = uint128(liquidity);
    }

    /// @return currPrice - calculates and gets current price at CFMM
    function getCurrentCFMMPrice() internal virtual view returns(uint256);
}
