// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../../interfaces/strategies/base/ILongStrategy.sol";

contract TestLongStrategy2 is ILongStrategy {

    function ltvThreshold() external virtual override view returns(uint256) {
        return 8000;
    }

    function calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) public virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](3);
        deltas[0] = int128(tokensHeld[0] * tokensHeld[1]);
        deltas[1] = -int128(reserves[0] * reserves[1]);
        deltas[2] = int256(ratio[0] * ratio[1]);
    }

    function calcDeltasToClose(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity, uint256 collateralId) public virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](4);
        deltas[0] = int128(tokensHeld[0] * tokensHeld[1]);
        deltas[1] = -int128(reserves[0] * reserves[1]);
        deltas[2] = int256(liquidity * 100);
        deltas[3] = int256(collateralId * 200);
    }

    function _increaseCollateral(uint256 tokenId) external override returns(uint128[] memory tokensHeld) {
        tokensHeld = new uint128[](2);
        tokensHeld[0] = 1;
        tokensHeld[1] = 2;
        emit LoanUpdated(tokenId, tokensHeld, 11, 12, 13, 14, TX_TYPE.INCREASE_COLLATERAL);
    }

    function _decreaseCollateral(uint256 tokenId, uint128[] calldata amounts, address) external override returns(uint128[] memory tokensHeld) {
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

    function _rebalanceCollateral(uint256 tokenId, int256[] memory deltas, uint256[] calldata ratio) external override returns(uint128[] memory tokensHeld){
        tokensHeld = new uint128[](2);
        tokensHeld[0] = uint128(uint256(deltas[0]));
        tokensHeld[1] = uint128(uint256(deltas[1]));
        emit LoanUpdated(tokenId, tokensHeld, 51, 52, 53, 54, TX_TYPE.REBALANCE_COLLATERAL);
    }

    function _updatePool(uint256 tokenId) external override returns(uint256,uint256){
        return(tokenId,tokenId + 1);
    }
}
