// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

interface ILiquidationStrategy {

    event LoanUpdated(uint256 indexed tokenId, uint128[] tokensHeld, uint256 liquidity, uint256 lpTokens, uint256 rateIndex);
    event Liquidation(uint256 indexed tokenId, uint256 collateral, uint256 liquidity, uint8 typ);
    event BatchLiquidations(uint256 liquidityTotal, uint256 collateralTotal, uint256 lpTokensPrincipalTotal, uint128[] tokensHeldTotal, uint256[] tokenIds);
    event WriteDown(uint256 indexed tokenId, uint256 writeDownAmt);

    function _liquidate(uint256 tokenId, int256[] calldata deltas) external virtual returns(uint256[] memory refund);
    function _liquidateWithLP(uint256 tokenId) external virtual returns(uint256[] memory refund);
    function _batchLiquidations(uint256[] calldata tokenIds) external virtual returns(uint256[] memory refund);
}
