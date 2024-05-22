// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../../strategies/liquidation/ExternalLiquidationStrategy.sol";
import "../../../strategies/base/BaseBorrowStrategy.sol";
import "./TestExternalBaseStrategy.sol";

contract TestExternalLiquidationStrategy is TestExternalBaseRebalanceStrategy, ExternalLiquidationStrategy, BaseBorrowStrategy {

    using LibStorage for LibStorage.Storage;

    uint16 public liqFee = 250;

    constructor(){
    }

    function externalSwapFee() internal view override(TestExternalBaseRebalanceStrategy,BaseExternalStrategy) virtual returns(uint256) {
        return swapFee;
    }

    function mintToDevs(uint256 lastFeeIndex, uint256 lastCFMMIndex, uint256 utilizationRate) internal virtual override {
    }

    function _beforeLiquidation() internal override virtual {
    }

    // create loan
    function createLoan(uint128 liquidity) external virtual override returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length, 0);
        LibStorage.Loan storage _loan = s.loans[tokenId];
        updateCollateral(_loan);

        uint256 lpTokens = convertInvariantToLP(liquidity, s.lastCFMMTotalSupply, s.lastCFMMInvariant);
        openLoan(_loan, lpTokens);

        emit LoanCreated(msg.sender, tokenId);
    }

    function checkMargin2(uint256 collateral, uint256 liquidity) internal virtual view {
        if(!hasMargin(collateral, liquidity, _ltvThreshold())) revert Margin(); // Revert if loan has enough collateral
    }

    function _ltvThreshold() internal virtual override(BaseLongStrategy, TestExternalBaseRebalanceStrategy) view returns(uint16) {
        return 8000;
    }

    function _liquidationFee() internal virtual override view returns(uint16) {
        return liqFee;
    }

    function syncCFMM(address cfmm) internal override virtual {
    }

    function beforeRepay(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual override {
    }

    function beforeSwapTokens(LibStorage.Loan storage _loan, int256[] memory deltas, uint128[] memory reserves) internal virtual override returns(uint256[] memory outAmts, uint256[] memory inAmts) {
    }

    function calcTokensToRepay(uint128[] memory reserves, uint256 liquidity, uint128[] memory maxAmounts, bool isLiquidation) internal virtual override view returns(uint256[] memory amounts) {
    }

    function depositToCFMM(address cfmm, address to, uint256[] memory amounts) internal virtual override returns(uint256 lpTokens) {
    }

    function swapTokens(LibStorage.Loan storage _loan, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual override {
    }

    function updateReserves(address cfmm) internal virtual override {
    }

    function withdrawFromCFMM(address cfmm, address to, uint256 lpTokens) internal virtual override returns(uint256[] memory amounts) {
    }

    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        return 0;
    }

    function _calcCollateralPostTrade(int256[] memory deltas, uint128[] memory tokensHeld, uint128[] memory reserves) internal virtual override view returns(uint256 collateral) {
        return GSMath.sqrt(uint256(tokensHeld[0]) * tokensHeld[1]);
    }

    function _calcDeltasForMaxLP(uint128[] memory tokensHeld, uint128[] memory reserves) internal virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](2);
        deltas[0] = 0;
        deltas[1] = 100;
    }

    function _calcDeltasToCloseSetRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity, uint256[] memory ratio) internal virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](2);
        deltas[0] = 0;
        deltas[1] = 100;
    }
    function _calcDeltasForWithdrawal(uint128[] memory amounts, uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) internal virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](2);
        deltas[0] = 0;
        deltas[1] = 100;
    }

    function _calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) internal virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](2);
        deltas[0] = 0;
        deltas[1] = 100;
    }

    function _calcDeltasToClose(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity, uint256 collateralId) internal virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](2);
        deltas[0] = 0;
        deltas[1] = 0;
    }
}
