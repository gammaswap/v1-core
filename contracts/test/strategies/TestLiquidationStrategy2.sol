// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../../interfaces/strategies/base/ILiquidationStrategy.sol";

contract TestLiquidationStrategy2 is ILiquidationStrategy  {

    function _liquidate(uint256 tokenId, int256[] calldata deltas, uint256[] calldata fees) external override virtual returns(uint256 loanLiquidity, uint256[] memory refund) {
        uint128[] memory tokensHeld = new uint128[](2);
        tokensHeld[0] = 1;
        tokensHeld[1] = deltas.length > 0 ? 2 : 3;
        refund = new uint256[](2);
        refund[0] = deltas.length > 0 ? uint128(uint256(deltas[0])) : 777;
        refund[1] = deltas.length > 1 ? uint128(uint256(deltas[1])) : 888;
        loanLiquidity = 4;
        uint128 fee0 = fees.length > 0 ? uint128(fees[0]) : 0;
        uint128 fee1 = fees.length > 1 ? uint128(fees[1]) : 0;
        emit LoanUpdated(tokenId, tokensHeld, uint128(refund[0]), uint128(refund[1]), loanLiquidity, 5, TX_TYPE.LIQUIDATE);
        emit Liquidation(tokenId, 100, 200 + fee0, 300 + fee1, TX_TYPE.LIQUIDATE, new uint256[](0));
    }

    function _liquidateWithLP(uint256 tokenId) external override virtual returns(uint256 loanLiquidity, uint256[] memory refund) {
        uint128[] memory tokensHeld = new uint128[](2);
        tokensHeld[0] = 6;
        tokensHeld[1] = 7;
        refund = new uint256[](2);
        refund[0] = 8;
        refund[1] = 9;
        loanLiquidity = 10;
        emit LoanUpdated(tokenId, tokensHeld, uint128(refund[0]), uint128(refund[1]), loanLiquidity, 11, TX_TYPE.LIQUIDATE_WITH_LP);
        emit Liquidation(tokenId, 400, 500, 600, TX_TYPE.LIQUIDATE_WITH_LP, new uint256[](0));
    }

    function _batchLiquidations(uint256[] calldata tokenIds) external override virtual returns(uint256 totalLoanLiquidity, uint256 totalCollateral, uint256[] memory refund) {
        uint128[] memory tokensHeld = new uint128[](2);
        tokensHeld[0] = 11;
        tokensHeld[1] = 12;
        totalLoanLiquidity = 15;
        totalCollateral = 16;
        refund = new uint256[](2);
        refund[0] = 13;
        refund[1] = 14;
        uint128[] memory cfmmReserves = new uint128[](2);
        cfmmReserves[0] = 15;
        cfmmReserves[1] = 16;
        emit Liquidation(0, tokensHeld[0], tokensHeld[1], uint128(totalLoanLiquidity), TX_TYPE.BATCH_LIQUIDATION, tokenIds);
        emit PoolUpdated(totalCollateral, refund[0], uint48(refund[1]), 700, 800, 900, 1000, cfmmReserves, TX_TYPE.BATCH_LIQUIDATION);
    }
}
