// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../interfaces/strategies/lending/IRepayStrategy.sol";

contract TestRepayStrategy2 is IRepayStrategy {

    function ltvThreshold() external virtual override view returns(uint256) {
        return 8000;
    }

    function _repayLiquidityWithLP(uint256 tokenId, uint256 collateralId, address to) external override returns(uint256 liquidityPaid, uint128[] memory tokensHeld){
        liquidityPaid = tokenId;
        tokensHeld = new uint128[](2);
        tokensHeld[0] = 11;
        tokensHeld[1] = 12;
        emit LoanUpdated(tokenId, tokensHeld, uint128(400), uint128(40), uint8(collateralId), uint96(20), TX_TYPE.REPAY_LIQUIDITY_WITH_LP);
    }

    function _repayLiquidity(uint256 tokenId, uint256 liquidity, uint256 collateralId, address to) external override returns(uint256 liquidityPaid, uint256[] memory amounts){
        liquidityPaid = tokenId;
        amounts = new uint256[](2);
        amounts[0] = 9;
        amounts[1] = 10;
        uint128[] memory heldTokens = new uint128[](2);
        heldTokens[0] = 9;
        heldTokens[1] = 10;
        emit LoanUpdated(tokenId, heldTokens, uint128(liquidity), uint128(40 + 2), 43, 44, TX_TYPE.REPAY_LIQUIDITY);
    }

    function _repayLiquiditySetRatio(uint256 tokenId, uint256 liquidity, uint256[] calldata ratio) external override returns(uint256 liquidityPaid, uint256[] memory amounts){
        liquidityPaid = tokenId;
        amounts = new uint256[](2);
        amounts[0] = 9;
        amounts[1] = 10;
        uint128[] memory heldTokens = new uint128[](2);
        heldTokens[0] = 13;
        heldTokens[1] = 11;
        emit LoanUpdated(tokenId, heldTokens, uint128(liquidity), uint128(40 + 2), 43, 44, TX_TYPE.REPAY_LIQUIDITY_SET_RATIO);
    }
}
