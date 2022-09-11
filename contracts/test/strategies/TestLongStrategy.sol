// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/strategies/base/ILongStrategy.sol";

contract TestLongStrategy is ILongStrategy {
    function _increaseCollateral(uint256 tokenId) external override returns(uint256[] memory tokensHeld) {
        tokensHeld = new uint256[](2);
        tokensHeld[0] = 1;
        tokensHeld[1] = tokenId;
    }

    function _decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external override returns(uint256[] memory tokensHeld) {
        tokensHeld = new uint256[](2);
        tokensHeld[0] = tokenId;
        tokensHeld[1] = amounts[0];
    }

    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external override returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = tokenId;
        amounts[1] = lpTokens;
    }

    function _repayLiquidity(uint256 tokenId, uint256 liquidity) external override returns(uint256 liquidityPaid, uint256 lpTokensPaid, uint256[] memory amounts){
        liquidityPaid = tokenId;
        lpTokensPaid = liquidity;
        amounts = new uint256[](2);
        amounts[0] = 9;
        amounts[1] = 10;
    }

    function _rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external override returns(uint256[] memory tokensHeld){
        tokensHeld = new uint256[](2);
        tokensHeld[0] = tokenId;
        tokensHeld[1] = uint256(deltas[0]);
    }

    function _rebalanceCollateralWithLiquidity(uint256 tokenId, uint256 liquidity) external override returns(uint256[] memory tokensHeld){
        tokensHeld = new uint256[](2);
        tokensHeld[0] = tokenId;
        tokensHeld[1] = liquidity;
    }
}
