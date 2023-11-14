// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./BaseLongStrategy.sol";
import "./BaseRebalanceStrategy.sol";

/// @title Abstract base contract for Repay Strategy implementation
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice All functions here are internal, external functions implemented in BaseLongStrategy as part of ILongStrategy implementation
/// @dev Only defines common functions that would be used by all contracts that repay liquidity
abstract contract BaseRepayStrategy is BaseRebalanceStrategy {
    /// @dev Account for paid liquidity debt
    /// @param _loan - loan whose debt was paid
    /// @param liquidity - liquidity invariant paid
    /// @param loanLiquidity - loan liquidity debt
    /// @return liquidityPaid - decrease in liquidity debt
    /// @return remainingLiquidity - outstanding loan liquidity debt after payment
    function payLoan(LibStorage.Loan storage _loan, uint256 liquidity, uint256 loanLiquidity) internal virtual returns(uint256 liquidityPaid, uint256 remainingLiquidity) {
        // Liquidity invariant in CFMM, updated at start of transaction that opens loan. Understated after loan repayment
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;

        // Total CFMM LP tokens in existence, updated at start of transaction that opens loan. Understated after loan repayment
        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;

        (uint256 paidLiquidity, uint256 newLPBalance) = getLpTokenBalance(lastCFMMInvariant, lastCFMMTotalSupply);
        // Take the lowest, if actually paid less liquidity than expected. Only way is there was a transfer fee.
        liquidityPaid = paidLiquidity < liquidity ? GSMath.min(loanLiquidity, paidLiquidity) : liquidity;
        // If more liquidity than stated was actually paid, that goes to liquidity providers
        uint256 lpTokenPrincipal;
        (lpTokenPrincipal, remainingLiquidity) = payLoanLiquidity(liquidityPaid, loanLiquidity, _loan);

        payPoolDebt(liquidityPaid, lpTokenPrincipal, lastCFMMInvariant, lastCFMMTotalSupply, newLPBalance);
    }

    /// @dev Get CFMM LP token balance changes in GammaPool
    /// @param lastCFMMInvariant - liquidity invariant in CFMM during last GammaPool state update
    /// @param lastCFMMTotalSupply - total LP tokens outstanding from CFMM during last GammaPool state update
    /// @return paidLiquidity - amount of liquidity invariant paid calculated from `lpTokenChange`
    /// @return newLPBalance - current CFMM LP token balance in GammaPool
    function getLpTokenBalance(uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) internal view virtual returns(uint256 paidLiquidity, uint256 newLPBalance) {
        // So lp balance is supposed to be greater than before, no matter what since tokens were deposited into the CFMM
        newLPBalance = GammaSwapLibrary.balanceOf(s.cfmm, address(this));
        uint256 lpTokenBalance = s.LP_TOKEN_BALANCE;
        // The change will always be positive, might be greater than expected, which means you paid more. If it's less it will be a small difference because of a fee
        if(newLPBalance <= lpTokenBalance) revert NotEnoughLPDeposit();

        // Liquidity invariant in CFMM, updated at start of transaction that opens loan. Understated after loan repayment
        // Total CFMM LP tokens in existence, updated at start of transaction that opens loan. Understated after loan repayment
        // Irrelevant that lastCFMMInvariant and lastCFMMTotalSupply are outdated because their conversion rate did not change
        // Hence the original lastCFMMTotalSupply and lastCFMMInvariant is still useful for conversions
        unchecked {
            paidLiquidity = newLPBalance - lpTokenBalance;
        }
        paidLiquidity = convertLPToInvariant(paidLiquidity, lastCFMMInvariant, lastCFMMTotalSupply);
    }

    /// @dev Account for paid liquidity debt in pool
    /// @param liquidity - amount of liquidity invariant paid calculated from `lpTokenChange`
    /// @param lpTokenPrincipal - current CFMM LP token balance in GammaPool
    /// @param lastCFMMInvariant - liquidity invariant in CFMM during last GammaPool state update
    /// @param lastCFMMTotalSupply - total LP tokens outstanding from CFMM during last GammaPool state update
    /// @param newLPBalance - current CFMM LP token balance in GammaPool
    function payPoolDebt(uint256 liquidity, uint256 lpTokenPrincipal, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 newLPBalance) internal virtual {
        uint256 borrowedInvariant = s.BORROWED_INVARIANT; // saves gas
        uint256 lpTokenBorrowedPlusInterest = s.LP_TOKEN_BORROWED_PLUS_INTEREST; // saves gas
        uint256 lpTokenBorrowed = s.LP_TOKEN_BORROWED; // saves gas

        // Calculate CFMM LP tokens that were intended to be repaid
        uint256 _lpTokenPaid = convertInvariantToLP(liquidity, lastCFMMTotalSupply, lastCFMMInvariant);

        // Not need to update lastCFMMInvariant and lastCFMMTotalSupply to account for actual repaid amounts which can be greater than what was intended to be repaid
        // That is because they're only used for conversions and repayment does not update their conversion rate.

        // liquidity paid <= loan's liquidity debt and borrowedInvariant = sum(liquidity debt of all loans)
        unchecked {
            borrowedInvariant = borrowedInvariant - GSMath.min(borrowedInvariant, liquidity);
        }

        s.BORROWED_INVARIANT = uint128(borrowedInvariant);

        // Update CFMM LP tokens deposited in GammaPool, this could be higher than expected. Excess CFMM LP tokens accrue to GS LPs
        s.LP_TOKEN_BALANCE = newLPBalance;

        // Update liquidity invariant from CFMM LP tokens deposited in GammaPool
        uint256 lpInvariant = convertLPToInvariant(newLPBalance, lastCFMMInvariant, lastCFMMTotalSupply);
        s.LP_INVARIANT = uint128(lpInvariant);

        unchecked {
            // _lpTokenPaid is derived from lpTokenBorrowedPlusInterest
            s.LP_TOKEN_BORROWED_PLUS_INTEREST = lpTokenBorrowedPlusInterest - GSMath.min(lpTokenBorrowedPlusInterest, _lpTokenPaid);

            // LP_TOKEN_BORROWED = sum(lpTokenPrincipal of all loans)
            lpTokenBorrowed = lpTokenBorrowed - GSMath.min(lpTokenBorrowed, lpTokenPrincipal);
        }

        s.LP_TOKEN_BORROWED = lpTokenBorrowed;

        if(lpTokenBorrowed == 0) {
            s.BORROWED_INVARIANT = 0;
            s.LP_TOKEN_BORROWED_PLUS_INTEREST = 0;
        }
    }

    /// @dev Account for paid liquidity debt in loan
    /// @param liquidity - current CFMM LP token balance in GammaPool
    /// @param loanLiquidity - liquidity invariant in CFMM during last GammaPool state update
    /// @param _loan - amount of liquidity invariant paid calculated from `lpTokenChange`
    /// @return lpTokenPrincipal - total LP tokens outstanding from CFMM during last GammaPool state update
    /// @return remainingLiquidity - current CFMM LP token balance in GammaPool
    function payLoanLiquidity(uint256 liquidity, uint256 loanLiquidity, LibStorage.Loan storage _loan) internal virtual
        returns(uint256 lpTokenPrincipal, uint256 remainingLiquidity) {
        uint256 loanLpTokens = _loan.lpTokens; // Loan's CFMM LP token principal
        uint256 loanInitLiquidity = _loan.initLiquidity; // Loan's liquidity invariant principal

        // Calculate loan's CFMM LP token principal repaid
        lpTokenPrincipal = GSMath.min(loanLpTokens, convertInvariantToLP(liquidity, loanLpTokens, loanLiquidity));

        uint256 initLiquidityPaid = GSMath.min(loanInitLiquidity, liquidity * loanInitLiquidity / loanLiquidity);

        unchecked {
            // Calculate loan's outstanding liquidity invariant principal after liquidity payment
            loanInitLiquidity = loanInitLiquidity - initLiquidityPaid;

            // Update loan's outstanding CFMM LP token principal
            loanLpTokens = loanLpTokens - lpTokenPrincipal;

            // Calculate loan's outstanding liquidity invariant after liquidity payment
            remainingLiquidity = loanLiquidity - GSMath.min(loanLiquidity, liquidity);
        }

        // Can't be less than min liquidity to avoid rounding issues
        if (remainingLiquidity > 0 && remainingLiquidity < minBorrow()) revert MinBorrow();

        // If fully paid, free memory to save gas
        if(remainingLiquidity == 0) { // lpTokens should be zero
            _loan.rateIndex = 0;
            _loan.px = 0;
            _loan.lpTokens = 0;
            _loan.initLiquidity = 0;
            _loan.liquidity = 0;
            if(loanLpTokens > 0) lpTokenPrincipal += loanLpTokens; // cover rounding issues
        } else {
            _loan.lpTokens = uint128(loanLpTokens);
            _loan.initLiquidity = uint128(loanInitLiquidity);
            _loan.liquidity = uint128(remainingLiquidity);
        }
    }

    /// @dev Write down bad debt if any
    /// @param collateralAsLiquidity - loan collateral as liquidity invariant units
    /// @param loanLiquidity - most updated loan liquidity debt
    /// @return writeDownAmt - liquidity debt amount written down
    /// @return adjLoanLiquidity - loan liquidity debt after write down
    function writeDown(uint256 collateralAsLiquidity, uint256 loanLiquidity) internal virtual returns(uint256, uint256) {
        if(collateralAsLiquidity >= loanLiquidity) {
            return(0,loanLiquidity); // Enough collateral to cover liquidity debt
        }

        // Write down pool liquidity debt
        uint256 borrowedInvariant = s.BORROWED_INVARIANT; // Save gas

        // Not enough collateral to cover liquidity loan
        uint256 writeDownAmt;

        // Will always write down
        unchecked {
            writeDownAmt = loanLiquidity - collateralAsLiquidity; // Liquidity shortfall
            borrowedInvariant = borrowedInvariant - GSMath.min(borrowedInvariant, writeDownAmt);
        }

        s.LP_TOKEN_BORROWED_PLUS_INTEREST = convertInvariantToLP(borrowedInvariant, s.lastCFMMTotalSupply, s.lastCFMMInvariant);
        s.BORROWED_INVARIANT = uint128(borrowedInvariant);

        // Loan's liquidity debt is written down to its available collateral liquidity debt
        return(writeDownAmt,collateralAsLiquidity);
    }
}
