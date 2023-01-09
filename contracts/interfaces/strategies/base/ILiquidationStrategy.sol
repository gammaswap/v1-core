// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./IBaseLongStrategy.sol";

interface ILiquidationStrategy is IBaseLongStrategy {

    event Liquidation(uint256 indexed tokenId, uint256 collateral, uint256 liquidity, uint8 typ);
    event BatchLiquidations(uint256 liquidityTotal, uint256 collateralTotal, uint256 lpTokensPrincipalTotal, uint128[] tokensHeldTotal, uint256[] tokenIds);
    event WriteDown(uint256 indexed tokenId, uint256 writeDownAmt);

    function _liquidate(uint256 tokenId, int256[] calldata deltas) external returns(uint256[] memory refund);
    function _liquidateWithLP(uint256 tokenId) external returns(uint256[] memory refund);
    function _batchLiquidations(uint256[] calldata tokenIds) external returns(uint256[] memory refund);
}
