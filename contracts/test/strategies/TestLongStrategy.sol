// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../interfaces/strategies/base/ILongStrategy.sol";

contract TestLongStrategy is ILongStrategy {

    function _getLatestCFMMReserves() external override view returns(uint256[] memory cfmmReserves) {
        cfmmReserves = new uint256[](2);
        cfmmReserves[0] = 3;
        cfmmReserves[1] = 4;
    }

    function _increaseCollateral(uint256 tokenId) external override returns(uint128[] memory tokensHeld) {
        tokensHeld = new uint128[](2);
        tokensHeld[0] = 1;
        tokensHeld[1] = 2;
        emit LoanUpdated(tokenId, tokensHeld, 11, 12, 13);
    }

    function _decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external override returns(uint128[] memory tokensHeld) {
        tokensHeld = new uint128[](2);
        tokensHeld[0] = uint128(amounts[0]);
        tokensHeld[1] = uint128(amounts[1]);
        emit LoanUpdated(tokenId, tokensHeld, 21, 22, 23);
    }

    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external override returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = lpTokens * 2;
        amounts[1] = lpTokens;
        uint128[] memory heldTokens = new uint128[](2);
        heldTokens[0] = uint128(lpTokens * 2);
        heldTokens[1] = uint128(lpTokens);
        emit LoanUpdated(tokenId, heldTokens, 31, 32, 33);
    }

    function _repayLiquidity(uint256 tokenId, uint256 liquidity) external override returns(uint256 liquidityPaid, uint256[] memory amounts){
        liquidityPaid = tokenId;
        amounts = new uint256[](2);
        amounts[0] = 9;
        amounts[1] = 10;
        uint128[] memory heldTokens = new uint128[](2);
        heldTokens[0] = 9;
        heldTokens[1] = 10;
        emit LoanUpdated(tokenId, heldTokens, uint128(liquidity), 42, 43);
    }

    function _rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external override returns(uint128[] memory tokensHeld){
        tokensHeld = new uint128[](2);
        tokensHeld[0] = uint128(uint256(deltas[0]));
        tokensHeld[1] = uint128(uint256(deltas[1]));
        emit LoanUpdated(tokenId, tokensHeld, 51, 52, 53);
    }
}
