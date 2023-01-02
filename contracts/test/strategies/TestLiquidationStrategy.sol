// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../../interfaces/strategies/base/ILiquidationStrategy.sol";

contract TestLiquidationStrategy is ILiquidationStrategy  {

    function _liquidate(uint256 tokenId, int256[] calldata deltas) external override virtual returns(uint256[] memory refund) {
        uint128[] memory tokensHeld = new uint128[](2);
        tokensHeld[0] = 1;
        tokensHeld[1] = deltas.length > 0 ? 2 : 3;
        refund = new uint256[](2);
        refund[0] = deltas.length > 0 ? uint128(uint256(deltas[0])) : 777;
        refund[1] = deltas.length > 1 ? uint128(uint256(deltas[1])) : 888;
        emit LoanUpdated(tokenId, tokensHeld, refund[0], refund[1], 5);
        emit WriteDown(tokenId, 123);
        emit Liquidation(tokenId, 200, 300, 0);
    }

    function _liquidateWithLP(uint256 tokenId) external override virtual returns(uint256[] memory refund) {
        uint128[] memory tokensHeld = new uint128[](2);
        tokensHeld[0] = 6;
        tokensHeld[1] = 7;
        refund = new uint256[](2);
        refund[0] = 8;
        refund[1] = 9;
        emit LoanUpdated(tokenId, tokensHeld, refund[0], refund[1], 10);
        emit Liquidation(tokenId, 200, 300, 1);
    }

    function _batchLiquidations(uint256[] calldata tokenIds) external override virtual returns(uint256[] memory refund) {
        uint128[] memory tokensHeld = new uint128[](2);
        tokensHeld[0] = 11;
        tokensHeld[1] = 12;
        refund = new uint256[](2);
        refund[0] = 13;
        refund[1] = 14;
        emit BatchLiquidations(100, refund[0], refund[1], tokensHeld, tokenIds);
        emit WriteDown(0, 123);
    }
}
