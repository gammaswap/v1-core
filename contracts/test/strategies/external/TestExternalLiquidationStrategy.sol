// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../../strategies/external/ExternalLiquidationStrategy.sol";
import "./TestExternalBaseStrategy.sol";

contract TestExternalLiquidationStrategy is TestExternalBaseLongStrategy, ExternalLiquidationStrategy {

    using LibStorage for LibStorage.Storage;

    uint16 public liqFeeThreshold = 975;

    constructor(){
    }

    function mintToDevs(uint256 lastFeeIndex, uint256 lastCFMMIndex) internal virtual override {
    }

    // create loan
    function createLoan(uint128 liquidity) external virtual override returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length);
        LibStorage.Loan storage _loan = s.loans[tokenId];
        //_loan.liquidity = liquidity;
        //_loan.initLiquidity = liquidity;
        updateCollateral(_loan);
        //uint128[] memory tokensHeld = updateCollateral(_loan);
        //uint256 heldLiquidity = calcInvariant(s.cfmm, tokensHeld);

        // checkMargin2(heldLiquidity, liquidity);
        uint256 lpTokens = convertInvariantToLP(liquidity, s.lastCFMMTotalSupply, s.lastCFMMInvariant);
        openLoan(_loan, lpTokens);
        //(liquidityBorrowed, loanLiquidity) = openLoan(_loan, lpTokens);
        //_loan.lpTokens = convertInvariantToLP(liquidity, s.lastCFMMTotalSupply, s.lastCFMMInvariant);

        emit LoanCreated(msg.sender, tokenId);
    }

    function checkMargin2(uint256 collateral, uint256 liquidity) internal virtual view {
        if(!hasMargin(collateral, liquidity, ltvThreshold())) { // Revert if loan has enough collateral
            revert Margin();
        }
    }

    function liquidationFeeThreshold() internal virtual override view returns(uint16) {
        return liqFeeThreshold;
    }

    function beforeRepay(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual override {
    }

    function beforeSwapTokens(LibStorage.Loan storage _loan, int256[] calldata deltas) internal virtual override returns(uint256[] memory outAmts, uint256[] memory inAmts) {
    }

    function calcTokensToRepay(uint256 liquidity) internal virtual override view returns(uint256[] memory amounts) {
    }

    function depositToCFMM(address cfmm, address to, uint256[] memory amounts) internal virtual override returns(uint256 lpTokens) {
    }

    function swapTokens(LibStorage.Loan storage _loan, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual override {
    }

    function updateReserves(address cfmm) internal virtual override {
    }

    function withdrawFromCFMM(address cfmm, address to, uint256 lpTokens) internal virtual override returns(uint256[] memory amounts) {
    }
}