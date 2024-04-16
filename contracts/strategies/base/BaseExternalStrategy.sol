// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../../interfaces/periphery/IExternalCallee.sol";
import "./BaseLongStrategy.sol";

/// @title BaseExternalStrategy, base contract for external swapping
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used to flash loan collateral and CFMM LP tokens to an external address
abstract contract BaseExternalStrategy is BaseLongStrategy {
    error WrongLPTokenBalance();
    error ExternalCollateralRef();

    /// @return feeRate - rate in basis points charged to liquidity flash loaned for external swaps
    function externalSwapFee() internal view virtual returns(uint256) {
        return s.extSwapFee;
    }

    /// @dev Calculate fee for liquidity swapped in excess of loan's liquidity debt
    /// @param liquiditySwapped - flash loaned collateral tokens and CFMM LP tokens in terms of liquidity invariant units
    /// @param loanLiquidity - loan's liquidity debt
    /// @return fee - quantities of pool's collateral tokens being sent to recipient in terms of CFMM LP tokens
    function calcExternalSwapFee(uint256 liquiditySwapped, uint256 loanLiquidity) internal view virtual returns(uint256 fee) {
        if(liquiditySwapped > loanLiquidity) {
            unchecked {
                // Only way it could overflow is if liquiditySwapped is near max(uint256) and loanLiquidity is near 0.
                // But liquiditySwapped will be at most max(uint128)
                fee = (liquiditySwapped - loanLiquidity) * externalSwapFee() / 10000;
            }
        }
    }

    /// @dev Send collateral tokens from `pool` to receiver (`to`)
    /// @param to - recipient of token `amounts`
    /// @param amounts - quantities of pool's collateral tokens being sent to recipient
    /// @param lastCFMMTotalSupply - total supply of CFMM LP tokens, used for conversion
    /// @return swappedCollateralAsLPTokens - quantities of pool's collateral tokens being sent to recipient in terms of CFMM LP tokens
    function sendAndCalcCollateralLPTokens(address to, uint128[] calldata amounts, uint256 lastCFMMTotalSupply) internal virtual returns(uint256 swappedCollateralAsLPTokens){
        address[] memory tokens = s.tokens;
        if(tokens.length != amounts.length) revert InvalidAmountsLength();

        uint128[] memory lpReserves = getLPReserves(s.cfmm,false);
        for(uint256 i; i < amounts.length;) {
            // Collateral sent is measured as max of LP token equivalent if requested proportionally at current CFMM pool price
            swappedCollateralAsLPTokens += amounts[i] * (lastCFMMTotalSupply / amounts.length) / lpReserves[i];
            sendToken(tokens[i], to, amounts[i], s.TOKEN_BALANCE[i], type(uint128).max);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Send CFMM LP tokens from GS pool to receiver (`to`)
    /// @param _cfmm - CFMM LP token address
    /// @param to - recipient of token `lpTokens`
    /// @param lpTokens - quantities of pool's collateral tokens being sent to recipient
    /// @return lpTokens - quantity of LP tokens sent
    function sendCFMMLPTokens(address _cfmm, address to, uint256 lpTokens) internal virtual returns(uint256){
        sendToken(_cfmm, to, lpTokens, s.LP_TOKEN_BALANCE, type(uint256).max);
        return lpTokens;
    }

    /// @dev Flash loan collateral token `amounts` and CFMM LP tokens from GS pool to receiver (`to`)
    /// @param _loan - loan whose collateral will be swapped
    /// @param _cfmm - address of GammaPool's CFMM
    /// @param amounts - quantities of pool's collateral being swapped
    /// @param lpTokens - quantity of CFMM LP tokens being flash loaned
    /// @param to - address that will receive amounts and LP tokens
    /// @param data - optional bytes param
    /// @return liquiditySwapped - total liquidity swapped (amounts + lpTokens)
    /// @return tokensHeld - updated loan  collateral amounts
    function externalSwap(LibStorage.Loan storage _loan, address _cfmm, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) internal virtual returns(uint256 liquiditySwapped, uint128[] memory tokensHeld) {
        // Track change in CFMM LP Tokens and get CFMM invariant and totalSupply for conversions
        uint256 prevLpTokenBalance = s.LP_TOKEN_BALANCE;
        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;

        // Send collateral tokens and CFMM LP tokens to external address and calculate their value as LP tokens
        if(amounts.length > 0) liquiditySwapped = sendAndCalcCollateralLPTokens(to, amounts, lastCFMMTotalSupply);
        if(lpTokens > 0) {
            checkExpectedUtilizationRate(lpTokens, true);
            liquiditySwapped += sendCFMMLPTokens(_cfmm, to, lpTokens);
        }

        // Calculate liquidity sent out
        liquiditySwapped = convertLPToInvariant(liquiditySwapped, s.lastCFMMInvariant, lastCFMMTotalSupply);

        // Perform swap externally
        IExternalCallee(to).externalCall(msg.sender, amounts, lpTokens, data);

        // Update loan collateral tokens after external call
        (tokensHeld,) = updateCollateral(_loan);

        updateIndex();

        // CFMM LP Tokens in pool must at least not decrease
        checkLPTokens(_cfmm, prevLpTokenBalance, s.lastCFMMInvariant, s.lastCFMMTotalSupply);
    }

    /// @dev Check if CFMM LP tokens are above prevLpTokenBalance
    /// @param _cfmm - recipient of token `amounts`
    /// @param prevLpTokenBalance - quantities of pool's collateral tokens being sent to recipient
    /// @param lastCFMMInvariant - total invariant in CFMM, used for conversion
    /// @param lastCFMMTotalSupply - total supply of CFMM LP tokens, used for conversion
    function checkLPTokens(address _cfmm, uint256 prevLpTokenBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) internal virtual;
}
