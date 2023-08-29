// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../interfaces/strategies/rebalance/IRebalanceStrategy.sol";

contract TestRebalanceStrategy2 is IRebalanceStrategy {

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

    function calcDeltasForWithdrawal(uint128[] memory amounts, uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) public virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](4);
        deltas[0] = int128(amounts[0] * amounts[1]);
        deltas[1] = int128(tokensHeld[0] * tokensHeld[1]);
        deltas[2] = -int128(reserves[0] * reserves[1]);
        deltas[3] = int256(ratio[0] * ratio[1]);
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
