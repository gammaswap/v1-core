// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../../strategies/external/ExternalLongStrategy.sol";
import "./TestExternalBaseLongStrategy.sol";

contract TestExternalLongStrategy is TestExternalBaseLongStrategy, ExternalLongStrategy {
    constructor(){
    }

    function checkMargin(uint256 collateral, uint256 liquidity) internal virtual override view {
        if(!hasMargin(collateral, liquidity, ltvThreshold())) { // if collateral is below ltvThreshold revert transaction
            revert Margin();
        }
    }

    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual override returns(uint256 liquidityBorrowed, uint256[] memory amounts) {
    }

    function _decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external virtual override returns(uint128[] memory tokensHeld) {
    }

    function _increaseCollateral(uint256 tokenId) external virtual override returns(uint128[] memory tokensHeld) {
    }

    function _rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external virtual override returns(uint128[] memory tokensHeld) {
    }

    function _repayLiquidity(uint256 tokenId, uint256 payLiquidity, uint256[] calldata fees) external virtual override returns(uint256 liquidityPaid, uint256[] memory amounts) {
    }

    // **** Not used **** //
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