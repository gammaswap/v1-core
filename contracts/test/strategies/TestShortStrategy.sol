// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/strategies/base/IShortStrategy.sol";

contract TestShortStrategy is IShortStrategy{

    function _depositNoPull(address to) external override returns(uint256 shares) {
        shares = 1;
    }

    function _withdrawNoPull(address to) external override returns(uint256 assets) {
        assets = 2;
    }

    function _withdrawReserves(address to) external override returns(uint256[] memory reserves, uint256 assets) {
        reserves = new uint256[](2);
        reserves[0] = 3;
        reserves[1] = 4;
        assets = 5;
    }

    function _depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external override returns(uint256[] memory reserves, uint256 shares) {
        reserves = new uint256[](2);
        reserves[0] = amountsDesired[0];
        reserves[1] = amountsMin[0];
        shares = 8;
    }

    function getBorrowRate(uint256 lpBalance, uint256 lpBorrowed) external override pure returns(uint256) {
        return lpBalance + lpBorrowed;
    }

    function calcFeeIndex(address cfmm, uint256 borrowRate, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlackNum)
        external override pure returns(uint256 lastFeeIndex, uint256 lastCFMMFeeIndex, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) {
        lastFeeIndex = prevCFMMInvariant;
        lastCFMMFeeIndex = prevCFMMTotalSupply;
        lastCFMMInvariant = lastBlackNum;
        lastCFMMTotalSupply = borrowRate;
    }

    function calcBorrowedLPTokensPlusInterest(uint256 borrowedInvariant, uint256 lastFeeIndex, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) external override pure returns(uint256) {
        return 0;
    }

    function totalAssets(address cfmm, uint256 borrowedInvariant, uint256 lpBalance, uint256 lpBorrowed, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlackNum) external override pure returns(uint256) {
        return 1000*(10**16);
    }

    /***** ERC4626 Functions *****/

    function _deposit(uint256 assets, address to) external override returns (uint256 shares) {
        shares = assets;
    }

    function _mint(uint256 shares, address to) external override returns (uint256 assets) {
        assets = shares;
    }

    function _withdraw(uint256 assets, address to, address from) external override returns (uint256 shares) {
        shares = assets;
    }

    function _redeem(uint256 shares, address to, address from) external override returns (uint256 assets) {
        assets = shares;
    }
}
