// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "./TestExternalBaseRebalanceStrategy.sol";
import "../../../strategies/rebalance/ExternalRebalanceStrategy.sol";

contract TestExternalRebalanceStrategy is TestExternalBaseRebalanceStrategy, ExternalRebalanceStrategy {
    constructor(){
    }

    function externalSwapFee() internal view override(TestExternalBaseRebalanceStrategy,BaseExternalStrategy) virtual returns(uint256) {
        return swapFee;
    }

    function _ltvThreshold() internal virtual override(BaseLongStrategy, TestExternalBaseRebalanceStrategy) view returns(uint16) {
        return 8000;
    }

    // **** Not used **** //
    function beforeRepay(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual override {
    }

    function syncCFMM(address cfmm) internal override virtual {
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
}