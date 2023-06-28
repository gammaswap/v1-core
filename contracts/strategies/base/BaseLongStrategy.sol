// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../../interfaces/strategies/base/ILongStrategy.sol";
import "../../interfaces/observer/ILoanObserver.sol";
import "./BaseStrategy.sol";

/// @title Base Long Strategy abstract contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Common functions used by all strategy implementations that need access to loans
/// @dev This contract inherits from BaseStrategy and should normally be inherited by Borrow, Repay, Rebalance, and Liquidation strategies
abstract contract BaseLongStrategy is ILongStrategy, BaseStrategy {

    error Forbidden();
    error Margin();
    error MinBorrow();
    error LoanDoesNotExist();
    error InvalidAmountsLength();

    /// @dev Minimum number of liquidity borrowed to avoid rounding issues. Assumes invariant >= CFMM LP Token. Default should be 1e3
    function minBorrow() internal view virtual returns(uint256);

    /// @dev Perform necessary transaction before repaying liquidity debt
    /// @param _loan - liquidity loan that will be repaid
    /// @param amounts - collateral amounts that will be used to repay liquidity loan
    function beforeRepay(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual;

    /// @dev Calculate token amounts the liquidity invariant amount converts to in the CFMM
    /// @param liquidity - liquidity invariant units from CFMM
    /// @return amounts - reserve token amounts in CFMM that liquidity invariant converted to
    function calcTokensToRepay(uint128[] memory reserves, uint256 liquidity) internal virtual view returns(uint256[] memory amounts);

    /// @dev Perform necessary transaction before repaying swapping tokens
    /// @param _loan - liquidity loan whose collateral will be swapped
    /// @param deltas - collateral amounts that will be swapped (> 0 buy, < 0 sell, 0 ignore)
    /// @param reserves - most up to date CFMM reserves
    /// @return outAmts - collateral amounts that will be sent out of GammaPool (sold)
    /// @return inAmts - collateral amounts that will be received in GammaPool (bought)
    function beforeSwapTokens(LibStorage.Loan storage _loan, int256[] memory deltas, uint128[] memory reserves) internal virtual returns(uint256[] memory outAmts, uint256[] memory inAmts);

    /// @dev Calculate tokens liquidity invariant amount converts to in CFMM
    /// @param _loan - liquidity loan whose collateral will be traded
    /// @param outAmts - expected amounts to send to CFMM (sold),
    /// @param inAmts - expected amounts to receive from CFMM (bought)
    function swapTokens(LibStorage.Loan storage _loan, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual;

    /// @return origFee - origination fee charged to every new loan that is issued
    function originationFee() internal virtual view returns(uint24);

    /// @return ltvThreshold - max ltv ratio acceptable before a loan is eligible for liquidation
    function _ltvThreshold() internal virtual view returns(uint16);

    /// @dev See {ILongStrategy-ltvThreshold}.
    function ltvThreshold() external virtual override view returns(uint256) {
        return _ltvThreshold();
    }

    function calcOriginationFee(uint256 discount) internal virtual view returns(uint256) {
        uint256 origFee = originationFee();
        return discount > origFee ? 0 : (origFee - discount);
    }

    function getExternalCollateral(LibStorage.Loan storage _loan, uint256 tokenId) internal virtual view returns(uint256 externalCollateral) {
        if(_loan.refAddr != address(0) && _loan.refTyp == 3) {
            externalCollateral = ILoanObserver(_loan.refAddr).getCollateral(address(this), tokenId);
        }
    }

    function getMaxExternalCollateral(LibStorage.Loan storage _loan, uint256 tokenId) internal virtual view returns(uint256 externalCollateral) {
        if(_loan.refAddr != address(0) && _loan.refTyp == 3) {
            externalCollateral = ILoanObserver(_loan.refAddr).getMaxCollateral(address(this), tokenId);
        }
    }

    function repayWithExternalCollateral(LibStorage.Loan storage _loan, uint256 tokenId, uint256 liquidity) internal virtual returns(uint256 externalLiquidity) {
        if(_loan.refAddr != address(0) && _loan.refTyp == 3) {
            externalLiquidity = ILoanObserver(_loan.refAddr).payLiquidity(address(this), tokenId, liquidity, address(this));
        }
    }

    /// @dev Get `loan` from `tokenId` if it exists
    /// @param tokenId - liquidity loan whose collateral will be traded
    /// @return _loan - existing loan (id > 0)
    function _getExistingLoan(uint256 tokenId) internal virtual view returns(LibStorage.Loan storage _loan) {
        _loan = s.loans[tokenId]; // Get loan
        if(_loan.id == 0) revert LoanDoesNotExist();
    }

    /// @dev Get `loan` from `tokenId` and authenticate
    /// @param tokenId - liquidity loan whose collateral will be traded
    /// @return _loan - existing loan created by caller
    function _getLoan(uint256 tokenId) internal virtual view returns(LibStorage.Loan storage _loan) {
        _loan = _getExistingLoan(tokenId);

        // Revert if msg.sender is not the creator of this loan
        if(tokenId != uint256(keccak256(abi.encode(msg.sender, address(this), _loan.id)))) revert Forbidden();
    }

    /// @dev Check if loan is undercollateralized
    /// @param collateral - liquidity invariant collateral
    /// @param liquidity - liquidity invariant debt
    function checkMargin(uint256 collateral, uint256 liquidity) internal virtual view;

    /// @dev Check if loan is over collateralized
    /// @param collateral - liquidity invariant collateral
    /// @param liquidity - liquidity invariant debt
    /// @param limit - loan to value ratio limit in hundredths of a percent (e.g. 8000 => 80%)
    /// @return bool - true if loan is over collateralized, false otherwise
    function hasMargin(uint256 collateral, uint256 liquidity, uint256 limit) internal virtual pure returns(bool) {
        return collateral * limit / 1e4 >= liquidity;
    }

    /// @dev Send tokens `amounts` from `loan` collateral to receiver (`to`)
    /// @param _loan - loan whose collateral we are sending to recipient
    /// @param to - recipient of token `amounts`
    /// @param amounts - quantities of loan's collateral tokens being sent to recipient
    function sendTokens(LibStorage.Loan storage _loan, address to, uint128[] memory amounts) internal virtual {
        address[] memory tokens = s.tokens;
        uint128[] memory balance = s.TOKEN_BALANCE;
        uint128[] memory tokensHeld = _loan.tokensHeld;
        for (uint256 i; i < tokens.length;) {
            if(amounts[i] > 0) {
                sendToken(tokens[i], to, amounts[i], balance[i], tokensHeld[i]);
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

    /// @dev Add transfer fees to amounts if any
    /// @param amounts - amount of `token` being transferred
    /// @param fees - transfer fees charged to amount of `token` being transferred in basis points
    /// @return amountsWithFees - amount of `token` being transferred including fees
    function addFees(uint256[] memory amounts, uint256[] memory fees) internal virtual pure returns(uint256[] memory) {
        if(fees.length != amounts.length) {
            return amounts;
        }
        for(uint256 i; i < amounts.length;) {
            amounts[i] += amounts[i] * fees[i] / 10000;
            unchecked {
                ++i;
            }
        }
        return amounts;
    }

    /// @dev Send collateral amount from loan out of GammaPool
    /// @param token - address of ERC20 token being transferred
    /// @param to - receiver of `token` amount
    /// @param amount - amount of `token` being transferred
    /// @param balance - amount of `token` in GammaPool
    /// @param collateral - amount of `token` collateral in loan
    function sendToken(address token, address to, uint256 amount, uint256 balance, uint256 collateral) internal {
        if(amount > balance) revert NotEnoughBalance(); // Check enough in pool's accounted balance
        if(amount > collateral) revert NotEnoughCollateral(); // Check enough collateral in loan
        GammaSwapLibrary.safeTransfer(token, to, amount); // Send token amount
    }

    /// @dev Update collateral amounts in loan (increased/decreased)
    /// @param _loan - address of ERC20 token being transferred
    /// @return tokensHeld - current CFMM LP token balance in GammaPool
    /// @return tokenChange - change in token amounts
    function updateCollateral(LibStorage.Loan storage _loan) internal returns(uint128[] memory tokensHeld, int256[] memory tokenChange) {
        address[] memory tokens = s.tokens; // GammaPool collateral tokens (saves gas)
        uint128[] memory tokenBalance = s.TOKEN_BALANCE; // Tracked collateral token balances in GammaPool (saves gas)
        tokenChange = new int256[](tokens.length);
        tokensHeld = _loan.tokensHeld; // Loan's collateral token amounts (saves gas)
        for (uint256 i; i < tokens.length;) {
            // Get i token's balance
            uint128 balanceChange;
            uint128 oldTokenBalance = tokenBalance[i];
            uint128 newTokenBalance = uint128(GammaSwapLibrary.balanceOf(tokens[i], address(this)));
            tokenBalance[i] = newTokenBalance;
            if(newTokenBalance > oldTokenBalance) { // If balance increased
                balanceChange = newTokenBalance - oldTokenBalance;
                tokensHeld[i] += balanceChange;
                tokenChange[i] = int256(uint256(balanceChange));
            } else if(newTokenBalance < oldTokenBalance) { // If balance decreased
                balanceChange = oldTokenBalance - newTokenBalance;
                if(balanceChange > oldTokenBalance) revert NotEnoughBalance(); // Withdrew more than expected tracked balance, must synchronize
                if(balanceChange > tokensHeld[i]) revert NotEnoughCollateral(); // Withdrew more than available collateral
                unchecked {
                    tokensHeld[i] -= balanceChange; // Update loan collateral
                }
                tokenChange[i] = -int256(uint256(balanceChange));
            }
            unchecked {
                ++i;
            }
        }
        _loan.tokensHeld = tokensHeld; // Update storage
        s.TOKEN_BALANCE = tokenBalance; // Update storage
    }
}
