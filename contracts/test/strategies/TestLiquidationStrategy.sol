pragma solidity ^0.8.0;

import "../../interfaces/strategies/base/ILiquidationStrategy.sol";

contract TestLiquidationStrategy is ILiquidationStrategy  {

    function _liquidate(uint256 tokenId, bool isRebalance, int256[] calldata deltas) external override virtual returns(uint256[] memory refund) {
        uint128[] memory tokensHeld = new uint128[](2);
        tokensHeld[0] = 1;
        tokensHeld[1] = isRebalance ? 2 : 3;
        refund = new uint256[](2);
        refund[0] = uint128(uint256(deltas[0]));
        refund[1] = uint128(uint256(deltas[1]));
        emit LoanUpdated(tokenId, tokensHeld, refund[0], refund[1], 5);
    }

    function _liquidateWithLP(uint256 tokenId) external override virtual returns(uint256[] memory refund) {
        uint128[] memory tokensHeld = new uint128[](2);
        tokensHeld[0] = 6;
        tokensHeld[1] = 7;
        refund = new uint256[](2);
        refund[0] = 8;
        refund[1] = 9;
        emit LoanUpdated(tokenId, tokensHeld, refund[0], refund[1], 10);
    }

    function _batchLiquidations(uint256[] calldata tokenIds) external override virtual returns(uint256[] memory refund) {
        uint128[] memory tokensHeld = new uint128[](2);
        tokensHeld[0] = 11;
        tokensHeld[1] = 12;
        refund = new uint256[](2);
        refund[0] = 13;
        refund[1] = 14;
        emit LoanUpdated(tokenIds[0], tokensHeld, refund[0], refund[1], 15);
        emit LoanUpdated(tokenIds[1], tokensHeld, refund[0], refund[1], 15);
    }
}
