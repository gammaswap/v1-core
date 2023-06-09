// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./TestExternalBaseStrategy.sol";
import "../../../strategies/liquidation/ExternalLiquidationStrategy.sol";
import "../../../strategies/lending/BaseBorrowStrategy.sol";

contract TestExternalLiquidationStrategy is TestExternalBaseRebalanceStrategy, ExternalLiquidationStrategy, BaseBorrowStrategy {

    using LibStorage for LibStorage.Storage;

    uint16 public liqFee = 250;

    constructor(){
    }

    function mintToDevs(uint256 lastFeeIndex, uint256 lastCFMMIndex) internal virtual override {
    }

    // create loan
    function createLoan(uint128 liquidity) external virtual override returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length);
        LibStorage.Loan storage _loan = s.loans[tokenId];
        updateCollateral(_loan);

        uint256 lpTokens = convertInvariantToLP(liquidity, s.lastCFMMTotalSupply, s.lastCFMMInvariant);
        openLoan(_loan, lpTokens);

        emit LoanCreated(msg.sender, tokenId);
    }

    function checkMargin2(uint256 collateral, uint256 liquidity) internal virtual view {
        if(!hasMargin(collateral, liquidity, _ltvThreshold())) revert Margin(); // Revert if loan has enough collateral
    }

    function _liquidationFee() internal virtual override view returns(uint16) {
        return liqFee;
    }

    function liqFeeAdjustment() external view returns(uint16) {
        return liquidationFeeAdjustment();
    }

    function beforeRepay(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual override {
    }

    function beforeSwapTokens(LibStorage.Loan storage _loan, int256[] memory deltas, uint128[] memory reserves) internal virtual override returns(uint256[] memory outAmts, uint256[] memory inAmts) {
    }

    function calcTokensToRepay(uint128[] memory reserves, uint256 liquidity) internal virtual override view returns(uint256[] memory amounts) {
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
}
