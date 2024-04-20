// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./BaseLongStrategy.sol";

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

    /// @return origFee - base origination fee charged to every new loan that is issued
    function originationFee() internal virtual view returns(uint16) {
        return s.origFee;
    }

    /// @dev Calculate and return dynamic origination fee in basis points
    /// @param liquidityBorrowed - new liquidity borrowed from GammaSwap
    /// @param borrowedInvariant - invariant amount already borrowed from GammaSwap (before liquidityBorrowed is applied)
    /// @param lpInvariant - invariant amount available to be borrowed from LP tokens deposited in GammaSwap (before liquidityBorrowed is applied)
    /// @param lowUtilRate - low utilization rate threshold
    /// @param discount - discount in basis points to apply to origination fee
    /// @return origFee - origination fee that will be applied to loan
    function _calcOriginationFee(uint256 liquidityBorrowed, uint256 borrowedInvariant, uint256 lpInvariant, uint256 lowUtilRate, uint256 discount) internal virtual view returns(uint256 origFee) {
        uint256 utilRate = calcUtilizationRate(lpInvariant - liquidityBorrowed, borrowedInvariant + liquidityBorrowed) / 1e16;// convert utilizationRate to integer
        // check if the new utilizationRate is higher than lowUtilRate or less than lowUtilRate. If less than lowUtilRate, take lowUtilRate, if higher than lowUtilRate take higher one
        lowUtilRate = lowUtilRate / 1e4; // convert lowUtilRate to integer

        origFee = _calcDynamicOriginationFee(originationFee(), utilRate, lowUtilRate, s.minUtilRate1, s.minUtilRate2, s.feeDivisor);

        unchecked {
            origFee = origFee - GSMath.min(origFee, discount);
        }
    }

    /// @dev Calculate and return dynamic origination fee in basis points
    /// @param baseOrigFee - base origination fee charge
    /// @param utilRate - current utilization rate of GammaPool
    /// @param lowUtilRate - low utilization rate threshold, used as a lower bound for the utilization rate
    /// @param minUtilRate1 - minimum utilization rate 1 after which origination fee will start increasing exponentially
    /// @param minUtilRate2 - minimum utilization rate 2 after which origination fee will start increasing linearly
    /// @param feeDivisor - fee divisor of formula for dynamic origination fee
    /// @return origFee - origination fee that will be applied to loan
    function _calcDynamicOriginationFee(uint256 baseOrigFee, uint256 utilRate, uint256 lowUtilRate, uint256 minUtilRate1, uint256 minUtilRate2, uint256 feeDivisor) internal virtual view returns(uint256) {
        utilRate = GSMath.max(utilRate, lowUtilRate);
        if(utilRate > minUtilRate2) {
            unchecked {
                baseOrigFee = GSMath.max(utilRate - minUtilRate2, baseOrigFee);
            }
        }
        if(utilRate > minUtilRate1) {
            uint256 diff;
            unchecked {
                diff = utilRate - minUtilRate1;
            }
            baseOrigFee = GSMath.min(GSMath.max(baseOrigFee, (2 ** diff) * 10000 / feeDivisor), 10000);
        }
        return baseOrigFee;
    }

    /// @dev Mint GS LP tokens as origination fees payments to protocol
    /// @param origFeeInv - origination fee in liquidity invariant terms
    /// @param totalInvariant - total liquidity invariant in GammaPool (borrowed and in CFMM)
    function mintOrigFeeToDevs(uint256 origFeeInv, uint256 totalInvariant) internal virtual {
        (address _to, ,uint256 _origFeeShare,) = IGammaPoolFactory(s.factory).getPoolFee(address(this));
        if(_to != address(0) && _origFeeShare > 0) {
            uint256 devShares = origFeeInv * s.totalSupply * _origFeeShare / (totalInvariant * 1000);
            if(devShares > 0) {
                _mint(_to, devShares); // protocol fee is paid as dilution
            }
        }
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
        uint256 liquidityBorrowedExFee = convertLPToInvariantRoundUp(lpTokens, lastCFMMInvariant, lastCFMMTotalSupply, true);

        liquidity = _loan.liquidity;
        uint256 initLiquidity = minBorrow(); // avoid second sload

        // Can't borrow less than minimum liquidity to avoid rounding issues
        if (liquidity == 0 && liquidityBorrowedExFee < initLiquidity) revert MinBorrow();

        uint256 borrowedInvariant = s.BORROWED_INVARIANT;

        // Calculate loan origination fee
        uint256 lpTokenOrigFee = lpTokens * _calcOriginationFee(liquidityBorrowedExFee, borrowedInvariant, s.LP_INVARIANT, s.emaUtilRate, _loan.refFee) / 10000;

        // Pay origination fee share as protocol revenue
        liquidityBorrowed = convertLPToInvariantRoundUp(lpTokenOrigFee, lastCFMMInvariant, lastCFMMTotalSupply, true);
        mintOrigFeeToDevs(liquidityBorrowed, borrowedInvariant + s.LP_INVARIANT);

        // Calculate borrowed liquidity invariant including origination fee
        liquidityBorrowed = liquidityBorrowed + liquidityBorrowedExFee;

        // Add liquidity invariant borrowed including origination fee to total pool liquidity invariant borrowed
        borrowedInvariant = borrowedInvariant + liquidityBorrowed;

        s.BORROWED_INVARIANT = uint128(borrowedInvariant);
        s.LP_TOKEN_BORROWED = s.LP_TOKEN_BORROWED + lpTokens; // Track total CFMM LP tokens borrowed from pool (principal)

        // Update CFMM LP tokens deposited in GammaPool, this could be higher than expected. Excess CFMM LP tokens accrue to GS LPs
        uint256 lpTokenBalance = GammaSwapLibrary.balanceOf(s.cfmm, address(this));
        s.LP_TOKEN_BALANCE = lpTokenBalance;

        // Update liquidity invariant from CFMM LP tokens deposited in GammaPool
        uint256 lpInvariant = convertLPToInvariant(lpTokenBalance, lastCFMMInvariant, lastCFMMTotalSupply);
        s.LP_INVARIANT = uint128(lpInvariant);

        // Add CFMM LP tokens borrowed (principal) plus origination fee to pool's total CFMM LP tokens borrowed including accrued interest
        s.LP_TOKEN_BORROWED_PLUS_INTEREST = s.LP_TOKEN_BORROWED_PLUS_INTEREST + lpTokens + lpTokenOrigFee;

        liquidity = liquidity + liquidityBorrowed;
        if(liquidity < initLiquidity) revert MinBorrow();

        // Update loan's total liquidity debt and principal amounts
        initLiquidity = _loan.initLiquidity;
        _loan.px = updateLoanPrice(liquidityBorrowedExFee, getCurrentCFMMPrice(), initLiquidity, _loan.px);
        _loan.liquidity = uint128(liquidity);
        _loan.initLiquidity = uint128(initLiquidity + liquidityBorrowedExFee);
        _loan.lpTokens = _loan.lpTokens + lpTokens;
    }

    /// @return currPrice - calculates and gets current price at CFMM
    function getCurrentCFMMPrice() internal virtual view returns(uint256);
}
