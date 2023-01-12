// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./IBaseLongStrategy.sol";

interface ILongStrategy is IBaseLongStrategy {

    function _getLatestCFMMReserves(address cfmm) external view returns(uint256[] memory cfmmReserves);
    function _increaseCollateral(uint256 tokenId) external returns(uint128[] memory tokensHeld);
    function _decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external returns(uint128[] memory tokensHeld);
    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external returns(uint256[] memory amounts);
    function _repayLiquidity(uint256 tokenId, uint256 liquidity) external returns(uint256 liquidityPaid, uint256[] memory amounts);
    function _rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external returns(uint128[] memory tokensHeld);
}
