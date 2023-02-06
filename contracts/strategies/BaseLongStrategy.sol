// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./BaseStrategy.sol";

/// @title Base Long Strategy abstract contract
/// @author Daniel D. Alcarraz
/// @notice Common functions used by all strategy implementations that need access to loans
/// @dev This contract inherits from BaseStrategy and should normally be inherited by LongStrategy and LiquidationStrategy
abstract contract BaseLongStrategy is BaseStrategy {

    error Forbidden();
    error Margin();
    error MinBorrow();

    /// @dev Minimum number of CFMM LP tokens borrowed to avoid rounding issues. Assumes invariant >= CFMM LP Token
    uint256 public constant MIN_BORROW = 1e3;

    /// @dev Perform necessary transaction before repaying liquidity debt
    /// @param _loan - liquidity loan that will be repaid
    /// @param amounts - collateral amounts that will be used to repay liquidity loan
    function beforeRepay(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual;

    /// @dev Calculate token amounts the liquidity invariant amount converts to in the CFMM
    /// @param liquidity - liquidity invariant units from CFMM
    /// @return amounts - reserve token amounts in CFMM that liquidity invariant converted to
    function calcTokensToRepay(uint256 liquidity) internal virtual view returns(uint256[] memory amounts);

    /// @dev Perform necessary transaction before repaying swapping tokens
    /// @param _loan - liquidity loan whose collateral will be swapped
    /// @param deltas - collateral amounts that will be swapped (> 0 buy, < 0 sell, 0 ignore)
    /// @return outAmts - collateral amounts that will be sent out of GammaPool (sold)
    /// @return inAmts - collateral amounts that will be received in GammaPool (bought)
    function beforeSwapTokens(LibStorage.Loan storage _loan, int256[] calldata deltas) internal virtual returns(uint256[] memory outAmts, uint256[] memory inAmts);

    /// @dev Calculate tokens liquidity invariant amount converts to in CFMM
    /// @param _loan - liquidity loan whose collateral will be traded
    /// @param outAmts - expected amounts to send to CFMM (sold),
    /// @param inAmts - expected amounts to receive from CFMM (bought)
    function swapTokens(LibStorage.Loan storage _loan, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual;

    /// @return origFee - origination fee charged to every new loan that is issued
    function originationFee() internal virtual view returns(uint16);

    /// @return ltvThreshold - max ltv ratio acceptable before a loan is eligible for liquidation
    function ltvThreshold() internal virtual view returns(uint16);

    /// @dev Get `loan` from `tokenId` and authenticate requester has permission to get loan
    /// @param tokenId - liquidity loan whose collateral will be traded
    /// @return _loan - origination fee charged to every new loan that is issued
    function _getLoan(uint256 tokenId) internal virtual view returns(LibStorage.Loan storage _loan) {
        _loan = s.loans[tokenId]; // Get loan
        // Revert if msg.sender is not the creator of this loan
        if(tokenId != uint256(keccak256(abi.encode(msg.sender, address(this), _loan.id)))) {
            revert Forbidden();
        }
    }

    /// @dev Check if loan is undercollateralized
    /// @param collateral - liquidity invariant collateral
    /// @param liquidity - liquidity invariant debt
    function checkMargin(uint256 collateral, uint256 liquidity) internal virtual view;

    /// @dev Check if loan is over collateralized
    /// @param collateral - liquidity invariant collateral
    /// @param liquidity - liquidity invariant debt
    /// @param limit - loan to value ratio limit in tenths of a percent (e.g. 800 => 80%)
    /// @return bool - true if loan is over collateralized, false otherwise
    function hasMargin(uint256 collateral, uint256 liquidity, uint256 limit) internal virtual pure returns(bool) {
        return collateral * limit / 1000 >= liquidity;
    }

    /// @dev Send tokens `amounts` from `loan` collateral to receiver (`to`)
    /// @param _loan - loan whose collateral we are sending to recipient
    /// @param to - recipient of token `amounts`
    /// @param amounts - quantities of loan's collateral tokens being sent to recipient
    function sendTokens(LibStorage.Loan storage _loan, address to, uint256[] memory amounts) internal virtual {
        address[] memory tokens = s.tokens;
        for (uint256 i; i < tokens.length;) {
            if(amounts[i] > 0) {
                sendToken(IERC20(tokens[i]), to, amounts[i], s.TOKEN_BALANCE[i], _loan.tokensHeld[i]);
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Repay loan's liquidity debt
    /// @param _loan - loan whose debt we're repaying
    /// @param amounts - reserve token amounts used to repay liquidity debt
    /// @return lpTokens - CFMM LP tokens received for liquidity repayment
    function repayTokens(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual returns(uint256) {
        beforeRepay(_loan, amounts); // Perform necessary transactions before depositing to CFMM
        return depositToCFMM(s.cfmm, address(this), amounts); // Reserve token amounts sent to CFMM
    }

    /// @dev Update GammaPool's state variables (interest rate index) and loan's liquidity debt
    /// @param _loan - loan whose debt is being updated
    /// @return liquidity - new liquidity debt of loan including interest
    function updateLoan(LibStorage.Loan storage _loan) internal virtual returns(uint256) {
        (uint256 accFeeIndex,,) = updateIndex();
        return updateLoanLiquidity(_loan, accFeeIndex);
    }

    /// @dev Update loan's liquidity debt
    /// @param _loan - loan whose debt is being updated
    /// @param accFeeIndex - GammaPool's interest rate index
    /// @return liquidity - new liquidity debt of loan including interest
    function updateLoanLiquidity(LibStorage.Loan storage _loan, uint256 accFeeIndex) internal virtual returns(uint256 liquidity) {
        uint256 rateIndex = _loan.rateIndex;
        liquidity = rateIndex == 0 ? 0 : (_loan.liquidity * accFeeIndex) / rateIndex;
        _loan.liquidity = uint128(liquidity);
        _loan.rateIndex = uint96(accFeeIndex);
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
        if (liquidityBorrowedExFee < MIN_BORROW) {
            revert MinBorrow();
        }

        // Calculate add loan origination fee to LP token debt
        uint256 lpTokensPlusOrigFee = lpTokens + lpTokens * originationFee() / 10000;

        // Calculate borrowed liquidity invariant including origination fee
        liquidityBorrowed = convertLPToInvariant(lpTokensPlusOrigFee, lastCFMMInvariant, lastCFMMTotalSupply);

        // Add liquidity invariant borrowed including origination fee to total pool liquidity invariant borrowed
        uint256 borrowedInvariant = s.BORROWED_INVARIANT + liquidityBorrowed;

        s.BORROWED_INVARIANT = uint128(borrowedInvariant);
        s.LP_TOKEN_BORROWED = s.LP_TOKEN_BORROWED + lpTokens; // Track total CFMM LP tokens borrowed from pool (principal)

        // Update CFMM LP tokens deposited in GammaPool, this could be higher than expected. Excess CFMM LP tokens accrue to GS LPs
        uint256 lpTokenBalance = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this));
        s.LP_TOKEN_BALANCE = lpTokenBalance;

        // Update lastCFMMInvariant and lastCFMMTotalSupply to account for borrowed amounts
        lastCFMMInvariant = lastCFMMInvariant - liquidityBorrowedExFee;
        lastCFMMTotalSupply = lastCFMMTotalSupply - lpTokens;

        // Update liquidity invariant from CFMM LP tokens deposited in GammaPool
        uint256 lpInvariant = convertLPToInvariant(lpTokenBalance, lastCFMMInvariant, lastCFMMTotalSupply);
        s.LP_INVARIANT = uint128(lpInvariant);

        s.lastCFMMInvariant = uint128(lastCFMMInvariant);
        s.lastCFMMTotalSupply = lastCFMMTotalSupply;

        // Add CFMM LP tokens borrowed (principal) plus origination fee to pool's total CFMM LP tokens borrowed including accrued interest
        s.LP_TOKEN_BORROWED_PLUS_INTEREST = s.LP_TOKEN_BORROWED_PLUS_INTEREST + lpTokensPlusOrigFee;

        // Update loan's total liquidity debt and principal amounts
        liquidity = _loan.liquidity + liquidityBorrowed;
        _loan.initLiquidity = _loan.initLiquidity + uint128(liquidityBorrowed);
        _loan.lpTokens = _loan.lpTokens + lpTokens;
        _loan.liquidity = uint128(liquidity);
    }

    /// @dev Account for paid liquidity debt
    /// @param _loan - loan whose debt was paid
    /// @param liquidity - liquidity invariant paid
    /// @param loanLiquidity - loan liquidity debt
    /// @return liquidityPaid - decrease in liquidity debt
    /// @return remainingLiquidity - outstanding loan liquidity debt after payment
    function payLoan(LibStorage.Loan storage _loan, uint256 liquidity, uint256 loanLiquidity) internal virtual returns(uint256 liquidityPaid, uint256 remainingLiquidity) {
        (uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 paidLiquidity, uint256 newLPBalance, uint256 lpTokenChange) = getLpTokenBalance();
        // Take the lowest, if actually paid less liquidity than expected. Only way is there was a transfer fee.
        liquidityPaid = paidLiquidity < liquidity ? paidLiquidity : liquidity;
        // If more liquidity than stated was actually paid, that goes to liquidity providers
        uint256 lpTokenPrincipal;
        (lpTokenPrincipal, remainingLiquidity) = payLoanLiquidity(liquidityPaid, loanLiquidity, _loan);

        payPoolDebt(liquidityPaid, lpTokenPrincipal, lastCFMMInvariant, lastCFMMTotalSupply, newLPBalance, lpTokenChange);
    }

    /// @dev Get CFMM LP token balance changes in GammaPool
    /// @return lastCFMMInvariant - liquidity invariant in CFMM during last GammaPool state update
    /// @return lastCFMMTotalSupply - total LP tokens outstanding from CFMM during last GammaPool state update
    /// @return paidLiquidity - amount of liquidity invariant paid calculated from `lpTokenChange`
    /// @return newLPBalance - current CFMM LP token balance in GammaPool
    /// @return lpTokenChange - CFMM LP tokens deposited in GammaPool since last update, presumably to pay for this liquidity debt
    function getLpTokenBalance() internal view virtual returns(uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 paidLiquidity, uint256 newLPBalance, uint256 lpTokenChange) {
        // So lp balance is supposed to be greater than before, no matter what since tokens were deposited into the CFMM
        newLPBalance = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this));
        uint256 lpTokenBalance = s.LP_TOKEN_BALANCE;
        // The change will always be positive, might be greater than expected, which means you paid more. If it's less it will be a small difference because of a fee
        if(newLPBalance <= lpTokenBalance) {
            revert NotEnoughLPDeposit();
        }
        lpTokenChange = newLPBalance - lpTokenBalance;

        // Liquidity invariant in CFMM, updated at start of transaction that opens loan. Understated after loan repayment
        lastCFMMInvariant = s.lastCFMMInvariant;

        // Total CFMM LP tokens in existence, updated at start of transaction that opens loan. Understated after loan repayment
        lastCFMMTotalSupply = s.lastCFMMTotalSupply;

        // Irrelevant that lastCFMMInvariant and lastCFMMTotalSupply are outdated because their conversion rate did not change
        paidLiquidity = convertLPToInvariant(lpTokenChange, lastCFMMInvariant, lastCFMMTotalSupply);
    }

    /// @dev Account for paid liquidity debt in pool
    /// @param liquidity - amount of liquidity invariant paid calculated from `lpTokenChange`
    /// @param lpTokenPrincipal - current CFMM LP token balance in GammaPool
    /// @param lastCFMMInvariant - liquidity invariant in CFMM during last GammaPool state update
    /// @param lastCFMMTotalSupply - total LP tokens outstanding from CFMM during last GammaPool state update
    /// @param newLPBalance - current CFMM LP token balance in GammaPool
    /// @param lpTokenPaid - CFMM LP tokens deposited in GammaPool since last update, presumably to pay for this liquidity debt
    function payPoolDebt(uint256 liquidity, uint256 lpTokenPrincipal, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 newLPBalance, uint256 lpTokenPaid) internal virtual {
        uint256 borrowedInvariant = s.BORROWED_INVARIANT; // saves gas
        uint256 lpTokenBorrowedPlusInterest = s.LP_TOKEN_BORROWED_PLUS_INTEREST; // saves gas

        // Calculate CFMM LP tokens that were intended to be repaid
        uint256 _lpTokenPaid = convertInvariantToLP(liquidity, lastCFMMTotalSupply, lastCFMMInvariant);

        // Update lastCFMMInvariant and lastCFMMTotalSupply to account for actual repaid amounts (can be greater than what was intended to be repaid)
        lastCFMMInvariant = lastCFMMInvariant + convertLPToInvariant(lpTokenPaid, lastCFMMInvariant, lastCFMMTotalSupply);
        lastCFMMTotalSupply = lastCFMMTotalSupply + lpTokenPaid; // Total supply went up by actual repaid amounts in CFMM LP tokens

        // Won't overflow because liquidity paid <= loan's liquidity debt and borrowedInvariant = sum(liquidity debt of all loans)
        borrowedInvariant = borrowedInvariant - liquidity;
        s.BORROWED_INVARIANT = uint128(borrowedInvariant);

        // Update CFMM LP tokens deposited in GammaPool, this could be higher than expected. Excess CFMM LP tokens accrue to GS LPs
        s.LP_TOKEN_BALANCE = newLPBalance;

        // Update liquidity invariant from CFMM LP tokens deposited in GammaPool
        uint256 lpInvariant = convertLPToInvariant(newLPBalance, lastCFMMInvariant, lastCFMMTotalSupply);
        s.LP_INVARIANT = uint128(lpInvariant);
        s.lastCFMMInvariant = uint128(lastCFMMInvariant);
        s.lastCFMMTotalSupply = lastCFMMTotalSupply;

        // Won't overflow because _lpTokenPaid is derived from lpTokenBorrowedPlusInterest
        s.LP_TOKEN_BORROWED_PLUS_INTEREST = lpTokenBorrowedPlusInterest - _lpTokenPaid;

        // Won't overflow because LP_TOKEN_BORROWED = sum(lpTokenPrincipal of all loans)
        s.LP_TOKEN_BORROWED = s.LP_TOKEN_BORROWED - lpTokenPrincipal;
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
        lpTokenPrincipal = convertInvariantToLP(liquidity, loanLpTokens, loanLiquidity);

        // Calculate loan's outstanding liquidity invariant principal after liquidity payment
        _loan.initLiquidity = uint128(loanInitLiquidity - (liquidity * loanInitLiquidity / loanLiquidity));

        // Update loan's outstanding CFMM LP token principal
        _loan.lpTokens = loanLpTokens - lpTokenPrincipal;

        // Calculate loan's outstanding liquidity invariant after liquidity payment
        remainingLiquidity = loanLiquidity - liquidity;

        // Can't be less than min liquidity to avoid rounding issues
        if (remainingLiquidity > 0 && remainingLiquidity < MIN_BORROW) {
            revert MinBorrow();
        }

        _loan.liquidity = uint128(remainingLiquidity);

        // If fully paid, free memory to save gas
        if(remainingLiquidity == 0) {
            _loan.rateIndex = 0;
        }
    }

    /// @dev Send collateral amount from loan out of GammaPool
    /// @param token - address of ERC20 token being transferred
    /// @param to - receiver of `token` amount
    /// @param amount - amount of `token` being transferred
    /// @param balance - amount of `token` in GammaPool
    /// @param collateral - amount of `token` collateral in loan
    function sendToken(IERC20 token, address to, uint256 amount, uint256 balance, uint256 collateral) internal {
        if(amount > balance) { // Check enough in pool's accounted balance
            revert NotEnoughBalance();
        }
        if(amount > collateral) { // Check enough collateral in loan
            revert NotEnoughCollateral();
        }
        GammaSwapLibrary.safeTransfer(token, to, amount); // Send token amount
    }

    /// @dev Update collateral amounts in loan (increased/decreased)
    /// @param _loan - address of ERC20 token being transferred
    /// @return tokensHeld - current CFMM LP token balance in GammaPool
    function updateCollateral(LibStorage.Loan storage _loan) internal returns(uint128[] memory tokensHeld) {
        address[] memory tokens = s.tokens; // GammaPool collateral tokens (saves gas)
        uint128[] memory tokenBalance = s.TOKEN_BALANCE; // Tracked collateral token balances in GammaPool (saves gas)
        tokensHeld = _loan.tokensHeld; // Loan's collateral token amounts (saves gas)
        for (uint256 i; i < tokens.length;) {
            // Get i token's balance
            uint256 currentBalance = GammaSwapLibrary.balanceOf(IERC20(tokens[i]), address(this));
            if(currentBalance > tokenBalance[i]) { // If balance increased
                uint128 balanceChange = uint128(currentBalance - tokenBalance[i]);
                tokensHeld[i] = tokensHeld[i] + balanceChange;
                tokenBalance[i] = tokenBalance[i] + balanceChange;
            } else if(currentBalance < tokenBalance[i]) { // If balance decreased
                uint128 balanceChange = uint128(tokenBalance[i] - currentBalance);
                if(balanceChange > tokenBalance[i]) { // Withdrew more than expected tracked balance, must synchronize
                    revert NotEnoughBalance();
                }
                if(balanceChange > tokensHeld[i]) { // Withdrew more than available collateral
                    revert NotEnoughCollateral();
                }
                unchecked {
                    tokensHeld[i] = tokensHeld[i] - balanceChange; // Update loan collateral
                    tokenBalance[i] = tokenBalance[i] - balanceChange; // Update GammaPool collateral balance
                }
            }
            unchecked {
                ++i;
            }
        }
        _loan.tokensHeld = tokensHeld; // Update storage
        s.TOKEN_BALANCE = tokenBalance; // Update storage
    }
}
