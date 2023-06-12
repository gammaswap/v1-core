// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../../interfaces/strategies/lending/IRepayStrategy.sol";

contract TestRepayStrategy2 is IRepayStrategy {

    function ltvThreshold() external virtual override view returns(uint256) {
        return 8000;
    }

    function _repayLiquidity(uint256 tokenId, uint256 liquidity, uint256[] calldata fees, uint256 collateralId, address to) external override returns(uint256 liquidityPaid, uint256[] memory amounts){
        liquidityPaid = tokenId;
        amounts = new uint256[](2);
        amounts[0] = 9;
        amounts[1] = 10;
        uint128[] memory heldTokens = new uint128[](2);
        heldTokens[0] = 9;
        heldTokens[1] = 10;
        emit LoanUpdated(tokenId, heldTokens, uint128(liquidity), uint128(40 + fees.length), fees[0], uint96(fees[1]), TX_TYPE.REPAY_LIQUIDITY);
    }

    function _repayLiquidityWithLP(uint256 tokenId, uint256 liquidity, uint256 collateralId, address to) external override returns(uint256 liquidityPaid){
        liquidityPaid = tokenId;
        uint128[] memory heldTokens = new uint128[](2);
        heldTokens[0] = 11;
        heldTokens[1] = 12;
        emit LoanUpdated(tokenId, heldTokens, uint128(liquidity), uint128(40), uint8(collateralId), uint96(20), TX_TYPE.REPAY_LIQUIDITY_WITH_LP);
    }
}
