// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/strategies/base/ILongStrategy.sol";

contract TestLongStrategy is ILongStrategy {

    function _increaseCollateral(uint256 tokenId) external override returns(uint256[] memory tokensHeld) {
        tokensHeld = new uint256[](2);
        tokensHeld[0] = 1;
        tokensHeld[1] = tokenId;
        emit LoanUpdated(tokenId, tokensHeld, 10, 11, 12, 13);
    }

    function _decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external override returns(uint256[] memory tokensHeld) {
        tokensHeld = new uint256[](2);
        tokensHeld[0] = amounts[0];
        tokensHeld[1] = amounts[1];
        emit LoanUpdated(tokenId, tokensHeld, 20, 21, 22, 23);
    }

    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external override returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = tokenId;
        amounts[1] = lpTokens;
        emit LoanUpdated(tokenId, amounts, 30, 31, 32, 33);
    }

    function _repayLiquidity(uint256 tokenId, uint256 liquidity) external override returns(uint256 liquidityPaid, uint256[] memory amounts){
        liquidityPaid = tokenId;
        amounts = new uint256[](2);
        amounts[0] = 9;
        amounts[1] = 10;
        emit LoanUpdated(tokenId, amounts, liquidityPaid, liquidity, 42, 43);
    }

    function _rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external override returns(uint256[] memory tokensHeld){
        tokensHeld = new uint256[](2);
        tokensHeld[0] = uint256(deltas[0]);
        tokensHeld[1] = uint256(deltas[1]);
        emit LoanUpdated(tokenId, tokensHeld, tokenId, 51, 52, 53);
    }
}
