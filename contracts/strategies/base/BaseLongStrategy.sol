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
    function minBorrow() internal view virtual returns(uint256) {
        return s.minBorrow;
    }

    /// @dev Minimum amount of liquidity to pay to avoid rounding issues. Assumes invariant >= CFMM LP Token. Default should be 1e3
    function minPay() internal view virtual returns(uint256);

    /// @dev Perform necessary transaction before repaying liquidity debt
    /// @param _loan - liquidity loan that will be repaid
    /// @param amounts - collateral amounts that will be used to repay liquidity loan
    function beforeRepay(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual;

    /// @dev Calculate token amounts the liquidity invariant amount converts to in the CFMM
    /// @param reserves - token quantites in CFMM used to calculate tokens to repay
    /// @param liquidity - liquidity invariant units from CFMM
    /// @param maxAmounts - max token amounts to repay
    /// @param maxAmounts - max token amounts to repay
    /// @param isLiquidation - calculating to liquidate loan
    /// @return amounts - reserve token amounts in CFMM that liquidity invariant converted to
    function calcTokensToRepay(uint128[] memory reserves, uint256 liquidity, uint128[] memory maxAmounts, bool isLiquidation) internal virtual view returns(uint256[] memory amounts);

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

    /// @return ltvThreshold - max ltv ratio acceptable before a loan is eligible for liquidation
    function _ltvThreshold() internal virtual view returns(uint16) {
        unchecked {
            return 10000 - uint16(s.ltvThreshold) * 10;
        }
    }

    /// @dev See {ILongStrategy-ltvThreshold}.
    function ltvThreshold() external virtual override view returns(uint256) {
        return _ltvThreshold();
    }

    /// @dev Update loan observer or collateral manager with updated loan information, return externally held collateral for loan if using collateral manager
    /// @param _loan - loan being observed by loan observer or collateral manager
    /// @param tokenId - identifier of liquidity loan that will be observed
    /// @return externalCollateral - collateral held in the collateral manager for liquidity loan `_loan`
    function onLoanUpdate(LibStorage.Loan storage _loan, uint256 tokenId) internal virtual returns(uint256 externalCollateral) {
        uint256 refType = _loan.refType;
        address refAddr = _loan.refAddr;
        uint256 collateral = 0;
        if(refAddr != address(0) && refType > 1) {
            collateral = ILoanObserver(refAddr).onLoanUpdate(s.cfmm, s.protocolId, tokenId,
                abi.encode(ILoanObserver.LoanObserved({ id: _loan.id, rateIndex: _loan.rateIndex, initLiquidity: _loan.initLiquidity,
                liquidity: _loan.liquidity, lpTokens: _loan.lpTokens, tokensHeld: _loan.tokensHeld, px: _loan.px})));
        }
        externalCollateral = refType == 3 ? collateral : 0;
    }

    /// @dev Get `loan` from `tokenId` if it exists
    /// @param tokenId - identifier of liquidity loan whose collateral will be traded
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
        _loan.rateIndex = uint80(accFeeIndex);
    }

    /// @dev Send collateral amount from loan out of GammaPool
    /// @param token - address of ERC20 token being transferred
    /// @param to - receiver of `token` amount
    /// @param amount - amount of `token` being transferred
    /// @param balance - amount of `token` in GammaPool
    /// @param collateral - amount of `token` collateral in loan
    function sendToken(address token, address to, uint256 amount, uint256 balance, uint256 collateral) internal {
        if(amount > collateral) revert NotEnoughCollateral(); // Check enough collateral in loan
        if(amount > balance) revert NotEnoughBalance(); // Check enough in pool's accounted balance
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
                unchecked {
                    balanceChange = newTokenBalance - oldTokenBalance;
                }
                tokensHeld[i] += balanceChange;
                tokenChange[i] = int256(uint256(balanceChange));
            } else if(newTokenBalance < oldTokenBalance) { // If balance decreased
                unchecked {
                    balanceChange = oldTokenBalance - newTokenBalance;
                }
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
