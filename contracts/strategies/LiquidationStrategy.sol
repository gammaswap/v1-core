// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../interfaces/strategies/base/ILiquidationStrategy.sol";
import "./BaseLongStrategy.sol";

/// @title Liquidation Strategy abstract contract implementation of ILiquidationStrategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice All external functions are locked to avoid reentrancy
/// @dev Only defines common functions that would be used by all concrete contracts that liquidate loans
abstract contract LiquidationStrategy is ILiquidationStrategy, BaseLongStrategy {

    error NoLiquidityProvided();
    error NotFullLiquidation();
    error NoLiquidityDebt();
    error HasMargin();
    error LoanNotExists();

    /// @return - liquidationFeeThreshold - threshold used to measure the liquidation fee
    function liquidationFeeThreshold() internal virtual view returns(uint16);

    /// @dev See {LiquidationStrategy-_liquidate}.
    function _liquidate(uint256 tokenId, int256[] calldata deltas, uint256[] calldata fees) external override lock virtual returns(uint256 loanLiquidity, uint256[] memory refund) {
        // Check can liquidate loan and get loan with updated loan liquidity
        uint256 writeDownAmt;
        uint256 collateral;
        address cfmm = s.cfmm;
        // No need to check if msg.sender has permission
        LibStorage.Loan storage _loan = _getExistingLoan(tokenId);

        if(deltas.length > 0) { // Done here because if pool charges trading fee, it increases the CFMM invariant
            (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(_loan, deltas);
            swapTokens(_loan, outAmts, inAmts); // Re-balance collateral
        }

        (loanLiquidity, collateral,, writeDownAmt) = getLoanLiquidityAndCollateral(_loan, cfmm);

        // Update loan collateral amounts (e.g. re-balance and/or account for deposited collateral)
        // Repay liquidity debt in full and get back remaining collateral amounts
        uint128[] memory tokensHeld = depositCollateralIntoCFMM(_loan, loanLiquidity + minBorrow(), fees);

        // Pay loan liquidity in full with collateral amounts and refund remaining collateral to liquidator
        // CFMM LP token principal paid will be calculated during function call, hence pass 0
        (tokensHeld, refund,) = payLoanAndRefundLiquidator(tokenId, tokensHeld, loanLiquidity, 0, true);
        _loan.tokensHeld = tokensHeld; // Clear loan collateral

        emit Liquidation(tokenId, uint128(collateral), uint128(loanLiquidity), uint128(writeDownAmt), TX_TYPE.LIQUIDATE, new uint256[](0));

        emit LoanUpdated(tokenId, tokensHeld, 0, 0, 0, 0, TX_TYPE.LIQUIDATE);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.LIQUIDATE);
    }

    /// @dev See {LiquidationStrategy-_liquidateWithLP}.
    function _liquidateWithLP(uint256 tokenId) external override lock virtual returns(uint256 loanLiquidity, uint256[] memory refund) {
        // Check can liquidate loan and get loan with updated loan liquidity and collateral
        uint128[] memory tokensHeld;
        uint256 writeDownAmt;
        uint256 collateral;
        address cfmm = s.cfmm;
        // No need to check if msg.sender has permission
        LibStorage.Loan storage _loan = _getExistingLoan(tokenId);

        (loanLiquidity, collateral, tokensHeld, writeDownAmt) = getLoanLiquidityAndCollateral(_loan, cfmm);

        // Pay loan liquidity in full or partially with previously deposited CFMM LP tokens and refund remaining liquidated share of collateral to liquidator
        // CFMM LP token principal paid will be calculated during function call, hence pass 0
        uint256 _loanLiquidity;
        (tokensHeld, refund, _loanLiquidity) = payLoanAndRefundLiquidator(tokenId, tokensHeld, loanLiquidity, 0, false);
        _loan.tokensHeld = tokensHeld; // Update loan collateral
        loanLiquidity = loanLiquidity - _loanLiquidity;

        emit Liquidation(tokenId, uint128(collateral - calcInvariant(cfmm, tokensHeld)), uint128(loanLiquidity), uint128(writeDownAmt), TX_TYPE.LIQUIDATE_WITH_LP, new uint256[](0));

        emit LoanUpdated(tokenId, tokensHeld, uint128(_loanLiquidity), _loan.initLiquidity, _loan.lpTokens, _loan.rateIndex, TX_TYPE.LIQUIDATE_WITH_LP);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.LIQUIDATE_WITH_LP);
    }

    /// @dev See {LiquidationStrategy-_batchLiquidations}.
    function _batchLiquidations(uint256[] calldata tokenIds) external override lock virtual returns(uint256 totalLoanLiquidity, uint256 totalCollateral, uint256[] memory refund) {
        // Sum up liquidity, collateral, and LP token principal from loans that can be liquidated
        uint256 lpTokenPrincipalPaid;
        uint128[] memory tokensHeld;
        uint256[] memory _tokenIds;
        (totalLoanLiquidity, totalCollateral, lpTokenPrincipalPaid, tokensHeld, _tokenIds) = sumLiquidity(tokenIds);

        if(totalLoanLiquidity == 0) { // Revert if no loans to liquidate
            revert NoLiquidityDebt();
        }

        uint256 writeDownAmt;
        // Write down bad debt if any
        (writeDownAmt, totalLoanLiquidity) = writeDown(adjustCollateralByLiqFee(totalCollateral), totalLoanLiquidity);

        // Pay total liquidity debts in full with previously deposited CFMM LP tokens and refund remaining collateral to liquidator
        (, refund,) = payLoanAndRefundLiquidator(0, tokensHeld, totalLoanLiquidity, lpTokenPrincipalPaid, true);

        // Store through event tokenIds of loans liquidated in batch and amounts liquidated
        emit Liquidation(0, uint128(totalCollateral), uint128(totalLoanLiquidity), uint128(writeDownAmt), TX_TYPE.BATCH_LIQUIDATION, _tokenIds);

        emit PoolUpdated(s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LAST_BLOCK_NUMBER, s.accFeeIndex, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.LP_INVARIANT, s.BORROWED_INVARIANT, s.CFMM_RESERVES, TX_TYPE.BATCH_LIQUIDATION);
    }

    /// @dev Update loan liquidity and check if can liquidate
    /// @param _loan - loan to liquidate
    /// @param cfmm - adress of CFMM
    /// @return loanLiquidity - most updated loan liquidity debt
    /// @return collateral - loan collateral liquidity invariant units
    /// @return tokensHeld - loan collateral token amounts
    /// @return writeDownAmt - collateral liquidity invariant units written down from loan's debt
    function getLoanLiquidityAndCollateral(LibStorage.Loan storage _loan, address cfmm) internal virtual returns(uint256 loanLiquidity, uint256 collateral, uint128[] memory tokensHeld, uint256 writeDownAmt) {
        // Update loan's liquidity debt and GammaPool's state variables
        loanLiquidity = updateLoan(_loan);

        // Check if loan can be liquidated
        tokensHeld = _loan.tokensHeld; // Saves gas
        collateral = calcInvariant(cfmm, tokensHeld);
        checkMargin(collateral, loanLiquidity);

        // Write down any bad debt
        (writeDownAmt, loanLiquidity) = writeDown(adjustCollateralByLiqFee(collateral), loanLiquidity);
    }

    function adjustCollateralByLiqFee(uint256 collateral) internal virtual returns(uint256) {
        return collateral * liquidationFeeThreshold() / 10000;
    }

    /// @dev Account for liquidity payments in the loan and pool
    /// @param tokenId - id of loan to liquidate
    /// @param tokensHeld - loan collateral
    /// @param loanLiquidity - most updated total loan liquidity debt
    /// @param lpTokenPrincipalPaid - loan's CFMM LP token principal
    /// @param isFullPayment - true if liquidating in full
    /// @return tokensHeld - remaining collateral
    /// @return refund - refunded amounts
    /// @return loanLiquidity - remaining liquidity debt
    function payLoanAndRefundLiquidator(uint256 tokenId, uint128[] memory tokensHeld, uint256 loanLiquidity, uint256 lpTokenPrincipalPaid, bool isFullPayment)
        internal virtual returns(uint128[] memory, uint256[] memory, uint256) {

        uint256 payLiquidity;
        uint256 currLpBalance = s.LP_TOKEN_BALANCE;
        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;

        {
            // Check deposited CFMM LP tokens
            uint256 lpDeposit = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this)) - currLpBalance;

            // Revert if no CFMM LP tokens deposited to pay this loan
            if(lpDeposit == 0) {
                revert NoLiquidityProvided();
            }

            // Get liquidity being paid from deposited CFMM LP tokens and refund excess CFMM LP tokens
            (payLiquidity, lpDeposit) = refundOverPayment(loanLiquidity, lpDeposit, lastCFMMTotalSupply, lastCFMMInvariant);

            // Track locally GammaPool's current CFMM LP balance
            currLpBalance = currLpBalance + lpDeposit;
        }

        // Check if must be full liquidation
        if(isFullPayment && payLiquidity < loanLiquidity) {
            revert NotFullLiquidation();
        }

        // Refund collateral to liquidator and get remaining collateral and refunded amounts
        uint256[] memory refund;
        (tokensHeld, refund) = refundLiquidator(payLiquidity, loanLiquidity, tokensHeld);

        {
            if(tokenId > 0) { // if liquidating a specific loan
                LibStorage.Loan storage _loan = s.loans[tokenId];

                // Account for loan's liquidity paid and get CFMM LP token principal paid and remaining loan liquidity
                (lpTokenPrincipalPaid, loanLiquidity) = payLoanLiquidity(payLiquidity, loanLiquidity, _loan);

                // Account for pool's liquidity debt paid.
                // If isFullPayment is true then loan was paid with its collateral tokens (`_liquidate` function was called)
                // Therefore CFMM LP tokens were minted during liquidation, thus lastCFMMInvariant & lastCFMMTotalSupply increased => send lpDeposit to payPoolDebt
                // If isFullPayment is false then loan was paid with CFMM LP tokens (`_liquidateWithLP` function was called)
                // Therefore no CFMM LP tokens were minted during liquidation, thus lastCFMMTotalSupply & lastCFMMInvariant did not change => don't send lpDeposit
                // payPoolDebt(payLiquidity, lpTokenPrincipalPaid, lastCFMMInvariant, lastCFMMTotalSupply, currLpBalance, isFullPayment ? currLpBalance - s.LP_TOKEN_BALANCE : 0);
            } else {
                // Liquidation was a batch liquidation
                // Account for pool's liquidity debt paid.
                // Batch liquidations are paid with CFMM LP tokens, therefore no need to pass lpDeposit (i.e. pass 0)
                // payPoolDebt(payLiquidity, lpTokenPrincipalPaid, lastCFMMInvariant, lastCFMMTotalSupply, currLpBalance, 0);
            }
            payPoolDebt(payLiquidity, lpTokenPrincipalPaid, lastCFMMInvariant, lastCFMMTotalSupply, currLpBalance);
        }

        return(tokensHeld, refund, loanLiquidity);
    }

    /// @dev Refund liquidator with collateral from liquidated loan and return remaining loan collateral
    /// @param payLiquidity - liquidity debt paid by liquidator
    /// @param loanLiquidity - most updated loan liquidity debt before payment
    /// @param tokensHeld - loan collateral amounts
    /// @return tokensHeld - remaining loan collateral amounts
    /// @return refund - loan collateral amounts refunded to liquidator
    function refundLiquidator(uint256 payLiquidity, uint256 loanLiquidity, uint128[] memory tokensHeld) internal virtual returns(uint128[] memory, uint256[] memory) {
        address[] memory tokens = s.tokens; // Saves gas
        uint256[] memory refund = new uint256[](tokens.length);
        uint128 payAmt = 0;
        for (uint256 i; i < tokens.length;) {
            payAmt = uint128(payLiquidity * tokensHeld[i] / loanLiquidity); // Collateral share of liquidated debt
            s.TOKEN_BALANCE[i] = s.TOKEN_BALANCE[i] - payAmt;
            refund[i] = payAmt;
            tokensHeld[i] = tokensHeld[i] - payAmt;

            // Refund collateral share of liquidated debt to liquidator
            GammaSwapLibrary.safeTransfer(IERC20(tokens[i]), msg.sender, refund[i]);
            unchecked {
                ++i;
            }
        }
        return(tokensHeld, refund);
    }

    /// @dev See {BaseLongStrategy-checkMargin}.
    function checkMargin(uint256 collateral, uint256 liquidity) internal virtual override view {
        if(hasMargin(collateral, liquidity, ltvThreshold())) { // Revert if loan has enough collateral
            revert HasMargin();
        }
    }

    /// @dev Refund liquidator with collateral from liquidated loan and return remaining loan collateral
    /// @param loanLiquidity - most updated loan liquidity debt before payment
    /// @param lpDeposit - CFMM LP token deposit to pay liquidity debt of loan being liquidated
    /// @param lastCFMMTotalSupply - total supply of LP tokens issued by CFMM
    /// @param lastCFMMInvariant - liquidity invariant in CFMM
    /// @return payLiquidity - loan liquidity that will be repaid after refunding excess CFMM LP tokens
    /// @return payLPDeposit - CFMM LP tokens that will be used to repay liquidity after refunding excess CFMM LP tokens
    function refundOverPayment(uint256 loanLiquidity, uint256 lpDeposit, uint256 lastCFMMTotalSupply, uint256 lastCFMMInvariant) internal virtual returns(uint256, uint256) {
        // convert CFMM LP deposit to liquidity invariant
        uint256 payLiquidity = convertLPToInvariant(lpDeposit, lastCFMMInvariant, lastCFMMTotalSupply);
        if(payLiquidity <= loanLiquidity) { // Paying partially or full
            return(payLiquidity, lpDeposit);
        }

        // Overpayment
        uint256 excessInvariant;
        unchecked {
            excessInvariant = payLiquidity - loanLiquidity; // Excess liquidity deposited
        }

        // Convert excess liquidity deposited back to CFMM LP tokens
        uint256 lpRefund = convertInvariantToLP(excessInvariant, lastCFMMTotalSupply, lastCFMMInvariant);
        GammaSwapLibrary.safeTransfer(IERC20(s.cfmm), msg.sender, lpRefund); // Refund excess LP tokens

        return(loanLiquidity, lpDeposit - lpRefund);
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

        // Not enough collateral to cover liquidity loan
        uint256 writeDownAmt;
        unchecked{
            writeDownAmt = loanLiquidity - collateralAsLiquidity; // Liquidity shortfall
        }

        // Write down pool liquidity debt
        uint256 borrowedInvariant = s.BORROWED_INVARIANT; // Save gas

        // Shouldn't overflow because borrowedInvariant = sum(loanLiquidity of all loans)
        assert(borrowedInvariant >= writeDownAmt);
        borrowedInvariant = borrowedInvariant - writeDownAmt;
        s.LP_TOKEN_BORROWED_PLUS_INTEREST = convertInvariantToLP(borrowedInvariant, s.lastCFMMTotalSupply, s.lastCFMMInvariant);
        s.BORROWED_INVARIANT = uint128(borrowedInvariant);

        // Loan's liquidity debt is written down to its available collateral liquidity debt
        return(writeDownAmt,collateralAsLiquidity);
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
            if(hasMargin(collateral, liquidity, ltvThreshold())) { // Skip loans with enough collateral
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

    /// @dev Increase loan collateral amounts then repay liquidity debt
    /// @param _loan - loan whose collateral will be rebalanced
    /// @param loanLiquidity - liquidity of loan to liquidate (avoids reading from _loan again to save gas)
    /// @param fees - fee on transfer for tokens[i]. Send empty array if no token in pool has fee on transfer or array of zeroes
    /// @return tokensHeld - remaining loan collateral amounts
    function depositCollateralIntoCFMM(LibStorage.Loan storage _loan, uint256 loanLiquidity, uint256[] calldata fees) internal virtual returns(uint128[] memory tokensHeld) {
        updateCollateral(_loan); // Update collateral from token deposits or rebalancing

        // Repay liquidity debt, increase lastCFMMTotalSupply and lastCFMMTotalInvariant
        repayTokens(_loan, addFees(calcTokensToRepay(loanLiquidity), fees));
        (tokensHeld,) = updateCollateral(_loan); // Update remaining collateral
    }

    /// @notice Not used during liquidations
    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        return 0;
    }
}
