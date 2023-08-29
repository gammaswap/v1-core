// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../interfaces/strategies/lending/IBorrowStrategy.sol";

contract TestBorrowStrategy2 is IBorrowStrategy {

    function ltvThreshold() external virtual override view returns(uint256) {
        return 8000;
    }

    function calcDynamicOriginationFee(uint256 liquidityBorrowed, uint256 borrowedInvariant, uint256 lpInvariant, uint256 lowUtilRate, uint256 discount) external virtual override view returns(uint256) {
        return 0;
    }

    function _increaseCollateral(uint256 tokenId, uint256[] calldata ratio) external override returns(uint128[] memory tokensHeld) {
        tokensHeld = new uint128[](2);
        tokensHeld[0] = 1;
        tokensHeld[1] = 2;
        emit LoanUpdated(tokenId, tokensHeld, 11, 12, 13, 14, TX_TYPE.INCREASE_COLLATERAL);
    }

    function _decreaseCollateral(uint256 tokenId, uint128[] calldata amounts, address, uint256[] calldata ratio) external override returns(uint128[] memory tokensHeld) {
        tokensHeld = new uint128[](2);
        tokensHeld[0] = uint128(amounts[0]);
        tokensHeld[1] = uint128(amounts[1]);
        emit LoanUpdated(tokenId, tokensHeld, 21, 22, 23, 24, TX_TYPE.DECREASE_COLLATERAL);
    }

    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens, uint256[] calldata ratio) external override returns(uint256 liquidityBorrowed, uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = lpTokens * 2;
        amounts[1] = lpTokens;
        uint128[] memory heldTokens = new uint128[](2);
        heldTokens[0] = uint128(lpTokens * 2);
        heldTokens[1] = uint128(lpTokens);
        liquidityBorrowed = tokenId;
        emit LoanUpdated(tokenId, heldTokens, 31, 32, 33, 34, TX_TYPE.BORROW_LIQUIDITY);
    }
}
