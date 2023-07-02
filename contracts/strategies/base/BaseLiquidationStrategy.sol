// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../../interfaces/strategies/base/ILiquidationStrategy.sol";
import "../../interfaces/observer/ICollateralManager.sol";
import "./BaseRepayStrategy.sol";

/// @title Base Liquidation Strategy abstract contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Only defines common functions that would be used by all concrete contracts that implement a liquidation strategy
abstract contract BaseLiquidationStrategy is ILiquidationStrategy, BaseRepayStrategy {

    error NoLiquidityDebt();
    error NoLiquidityProvided();
    error NotFullLiquidation();
    error InsufficientDeposit();
    error InvalidTokenIdsLength();
    error HasMargin();

    /// @dev loan data used to determine results of liquidation
    struct LiquidatableLoan {
        /// @dev identifier of loan in GammaPool
        uint256 tokenId;
        /// @dev most updated loan liquidity invariant debt
        uint256 loanLiquidity;
        /// @dev loan collateral in liquidity invariant units
        uint256 collateral;
        /// @dev loan collateral token amounts
        uint128[] tokensHeld;
        /// @dev liquidity invariant units written down from loan's debt
        uint256 writeDownAmt;
        /// @dev liquidation fee in liquidity invariant units paid from internal collateral
        uint256 internalFee;
        /// @dev liquidity debt measured in invariant units payable from internal collateral
        uint256 payableInternalLiquidity;
        /// @dev liquidity debt plus liquidator fee measured in invariant units payable from external collateral
        uint256 payableInternalLiquidityPlusFee;
        /// @dev internal collateral available to pay liquidity debt
        uint256 internalCollateral;
        /// @dev external (e.g. CollateralManager) collateral available to pay liquidity debt
        uint256 externalCollateral;
        /// @dev remainder liquidity debt after paying payableInternalLiquidity debt
        uint256 remainderLiquidity;
        /// @dev reference address that tracks collateral
        address refAddr;
        /// @dev type of observer
        uint256 refType;
        /// @dev if true, then collateral is tracked by a separate contract
        bool isObserved;
    }

    /// @return - liquidationFee - threshold used to measure the liquidation fee
    function _liquidationFee() internal virtual view returns(uint16);

    /// @dev See {LiquidationStrategy-liquidationFee}.
    function liquidationFee() external override virtual view returns(uint256) {
        return _liquidationFee();
    }

    /// @dev See {ILiquidationStrategy-canLiquidate}.
    function canLiquidate(uint256 liquidity, uint256 collateral) external virtual override view returns(bool) {
        return !hasMargin(collateral, liquidity, _ltvThreshold());
    }

    /// @dev Update loan liquidity and check if can liquidate
    /// @param _loan - loan to liquidate
    /// @return _liqLoan - loan with most updated data used for liquidation
    /// @return deltas - deltas to rebalance collateral to get max LP deposit
    function getLiquidatableLoan(LibStorage.Loan storage _loan, uint256 tokenId) internal virtual
        returns(LiquidatableLoan memory _liqLoan, int256[] memory deltas) {
        // Update loan's liquidity debt and GammaPool's state variables
        _liqLoan.loanLiquidity = updateLoan(_loan);
        _liqLoan.tokenId = tokenId;
        // Check if loan can be liquidated
        _liqLoan.tokensHeld = _loan.tokensHeld; // Saves gas
        _liqLoan.internalCollateral = calcInvariant(s.cfmm, _liqLoan.tokensHeld);
        _liqLoan.refAddr = _loan.refAddr;
        _liqLoan.refType = _loan.refType;
        _liqLoan.isObserved = _loan.refAddr != address(0) && _loan.refType == 3;
        _liqLoan.externalCollateral = getCollateralAtObserver(_loan, tokenId); // point of this is to determine if we're undercollateralized
        _liqLoan.collateral = _liqLoan.internalCollateral + _liqLoan.externalCollateral;
        checkMargin(_liqLoan.collateral, _liqLoan.loanLiquidity);

        // the loanLiquidity should match the number of tokens we expect to deposit including theliquidation fee
        deltas = _calcDeltasForMaxLP(_liqLoan.tokensHeld, s.CFMM_RESERVES);
        _liqLoan.internalCollateral = _calcMaxCollateral(deltas, _liqLoan.tokensHeld, s.CFMM_RESERVES); // if external collateral has to rebalance too, that will affect the variables

        _liqLoan.payableInternalLiquidity = Math.min(_liqLoan.loanLiquidity, _liqLoan.internalCollateral);
        _liqLoan.remainderLiquidity = _liqLoan.loanLiquidity > _liqLoan.payableInternalLiquidity ? _liqLoan.loanLiquidity - _liqLoan.payableInternalLiquidity : 0;// Pay remainder

        _liqLoan.internalFee = _liqLoan.payableInternalLiquidity * _liquidationFee() / 10000;
        _liqLoan.payableInternalLiquidityPlusFee = _liqLoan.payableInternalLiquidity + _liqLoan.internalFee;
        if(_liqLoan.payableInternalLiquidityPlusFee > _liqLoan.internalCollateral) {
            _liqLoan.internalFee = _liqLoan.internalCollateral * _liquidationFee() / 10000;
            _liqLoan.payableInternalLiquidityPlusFee = _liqLoan.internalCollateral;
            _liqLoan.payableInternalLiquidity = _liqLoan.internalCollateral - _liqLoan.internalFee;
        }
    }

    /// @dev Refund liquidator with collateral from liquidated loan and return remaining loan collateral
    /// @param loanLiquidity - most updated loan liquidity debt before payment
    /// @param collateral - liquidity unit value of collateral tokens at current prices
    /// @param tokensHeld - loan collateral amounts
    /// @return refund - loan collateral amounts refunded to liquidator
    /// @return tokensHeld - remaining loan collateral amounts
    function refundLiquidator(uint256 loanLiquidity, uint256 collateral, uint128[] memory tokensHeld)
        internal virtual returns(uint128[] memory, uint128[] memory) {
        address[] memory tokens = s.tokens;
        uint128[] memory refund = new uint128[](tokens.length);
        for(uint256 i = 0; i < tokens.length;) {
            refund[i] = uint128(loanLiquidity * tokensHeld[i] / collateral);
            s.TOKEN_BALANCE[i] = s.TOKEN_BALANCE[i] - refund[i];
            tokensHeld[i] = tokensHeld[i] - refund[i];
            GammaSwapLibrary.safeTransfer(tokens[i], msg.sender, refund[i]);
            unchecked{
                ++i;
            }
        }
        return(refund, tokensHeld);
    }

    /// @dev See {BaseLongStrategy-checkMargin}.
    function checkMargin(uint256 collateral, uint256 liquidity) internal virtual override view {
        if(hasMargin(collateral, liquidity, _ltvThreshold())) revert HasMargin(); // Revert if loan has enough collateral
    }

    /// @dev Calculate excess invariant liquidity units deposited in GammaPool to liquidate loan
    /// @param liquidityDeposit - liquidatable loan struct with most up to date liquidity debt and collateral values
    /// @param loanLiquidity - liquidity debt that will be liquidated. Any liquidity deposited in excess of loanLiquidity is excess liquidity
    /// @param fullDeposit - if true then liquidityDeposit must be greater or equal to loanLiquidity. A full deposit is required
    /// @return excessLiquidity - excess liquidity invariant untis deposited in GammaPool
    function calcExcessLiquidity(uint256 liquidityDeposit, uint256 loanLiquidity, bool fullDeposit) internal virtual returns(uint256 excessLiquidity){
        if(fullDeposit && liquidityDeposit < loanLiquidity) {
            revert InsufficientDeposit();
        } else if(liquidityDeposit > loanLiquidity) {
            unchecked {
                excessLiquidity = liquidityDeposit - loanLiquidity;
            }
        } else {
            excessLiquidity = 0;
        }
    }

    /// @dev Liquidate liquidity debt using collateral held in external observer contract
    /// @param _liqLoan - liquidatable loan struct with most up to date liquidity debt and collateral values
    /// @param liquidator - address liquidating loan through GammaPool
    /// @return externalLiquidity - liquidated liquidity invariant units in loan observer
    function liquidateWithObserver(LiquidatableLoan memory _liqLoan, address liquidator) internal virtual returns(uint256 externalLiquidity) {
        return ICollateralManager(_liqLoan.refAddr).liquidateCollateral(address(this), _liqLoan.tokenId, _liqLoan.remainderLiquidity, liquidator);
    }

    function getCollateralAtObserver(LibStorage.Loan storage _loan, uint256 tokenId) internal virtual view returns(uint256 externalCollateral) {
        if(_loan.refAddr != address(0) && _loan.refType == 3) {
            externalCollateral = ICollateralManager(_loan.refAddr).getCollateral(address(this), tokenId);
        }
    }

    /// @dev Pay liquidity debt, and refund excess payments to liquidator
    /// @param _liqLoan - liquidatable loan struct with most up to date liquidity debt and collateral values
    /// @param lpTokensPaid - loan's CFMM LP token principal
    /// @return writeDownAmt - liquidity invariant units written down from loan's debt
    function payLiquidatableLoan(LiquidatableLoan memory _liqLoan, uint256 lpTokensPaid) internal virtual returns(uint256){
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;
        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        uint256 currLpBalance = s.LP_TOKEN_BALANCE;

        (uint256 liquidityDeposit, uint256 lpDeposit) = calcDeposit(_liqLoan.payableInternalLiquidity, lastCFMMInvariant, lastCFMMTotalSupply, currLpBalance, true);

        if(_liqLoan.isObserved) {
            liquidateWithObserver(_liqLoan, msg.sender);
            (liquidityDeposit, lpDeposit) = calcDeposit(_liqLoan.payableInternalLiquidity, lastCFMMInvariant, lastCFMMTotalSupply, currLpBalance, false);
        }

        // Track locally GammaPool's current CFMM LP balance
        currLpBalance = currLpBalance + lpDeposit;

        if(_liqLoan.tokenId > 0) { // if liquidating a specific loan
            if(liquidityDeposit < _liqLoan.loanLiquidity) { // not fully paid so write down
                (_liqLoan.writeDownAmt,_liqLoan.loanLiquidity) = writeDown(liquidityDeposit, _liqLoan.loanLiquidity);
            }
            LibStorage.Loan storage _loan = s.loans[_liqLoan.tokenId];
            _loan.liquidity = uint128(_liqLoan.loanLiquidity);
            // Account for loan's liquidity paid and get CFMM LP token principal paid and remaining loan liquidity
            (lpTokensPaid, _liqLoan.loanLiquidity) = payLoanLiquidity(liquidityDeposit, _liqLoan.loanLiquidity, _loan);
        } else {
            // Check if must be full liquidation
            if(liquidityDeposit < _liqLoan.loanLiquidity) revert NotFullLiquidation();
        }
        payPoolDebt(liquidityDeposit, lpTokensPaid, lastCFMMInvariant, lastCFMMTotalSupply, currLpBalance);
        return _liqLoan.writeDownAmt;
    }

    /// @dev Refund liquidator with collateral from liquidated loan and return remaining loan collateral
    /// @param loanLiquidity - most updated loan liquidity debt before payment
    /// @param lastCFMMTotalSupply - total supply of LP tokens issued by CFMM
    /// @param lastCFMMInvariant - liquidity invariant in CFMM
    /// @param currLpBalance - current value of LP_TOKEN_BALANCE in the GammaPool. Current CFMM LP tokens tracked in the GammaPool
    /// @param fullPayment - if true, function will revert if liquidityDeposit received does not cover the full loanLiquidity debt
    /// @return liquidityDeposit - loan liquidity that will be repaid after refunding excess CFMM LP tokens
    /// @return lpDeposit - CFMM LP tokens that will be used to repay liquidity after refunding excess CFMM LP tokens
    function calcDeposit(uint256 loanLiquidity, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 currLpBalance, bool fullPayment) internal virtual returns(uint256 liquidityDeposit, uint256 lpDeposit){
        lpDeposit = GammaSwapLibrary.balanceOf(s.cfmm, address(this)) - currLpBalance;
        liquidityDeposit = convertLPToInvariant(lpDeposit, lastCFMMInvariant, lastCFMMTotalSupply);
        uint256 excessInvariant = calcExcessLiquidity(liquidityDeposit, loanLiquidity, fullPayment);
        if(excessInvariant > 0) {
            uint256 lpRefund = convertInvariantToLP(excessInvariant, lastCFMMTotalSupply, lastCFMMInvariant);
            GammaSwapLibrary.safeTransfer(s.cfmm, msg.sender, lpRefund);
            lpDeposit -= lpRefund;// refundInvariant(excessInvariant, lastCFMMTotalSupply, lastCFMMInvariant);
            liquidityDeposit = convertLPToInvariant(lpDeposit, lastCFMMInvariant, lastCFMMTotalSupply);
        }
    }
}
