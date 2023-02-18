// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../../interfaces/strategies/base/IShortStrategy.sol";

contract TestShortStrategy2 is IShortStrategy{

    function _depositNoPull(address to) external override returns(uint256 shares) {
        shares = 2;
        uint256 assets = 3;
        emit Deposit(msg.sender, to, assets, shares);
    }

    function _withdrawNoPull(address to) external override returns(uint256 assets) {
        assets = 7;
        uint256 shares = 14;
        emit Withdraw(msg.sender, to, msg.sender, assets, shares);
    }

    function _withdrawReserves(address to) external override returns(uint256[] memory reserves, uint256 assets) {
        reserves = new uint256[](2);
        reserves[0] = 3;
        reserves[1] = 4;
        assets = 5;
        uint256 shares = reserves[0] + reserves[1] + 2;
        emit Withdraw(msg.sender, to, msg.sender, assets, shares);
    }

    function _depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external override returns(uint256[] memory reserves, uint256 shares) {
        reserves = new uint256[](2);
        reserves[0] = amountsDesired[0];
        reserves[1] = amountsMin[0];
        shares = amountsDesired[0] + amountsDesired[1];
        uint256 assets = amountsMin[0] + amountsMin[1];
        address from = abi.decode(data, (address));
        emit Deposit(from, to, assets, shares);
    }

    function totalAssets(address, uint256, uint256, uint256, uint256, uint256) external override pure returns(uint256) {
        return 1000*(10**18);
    }

    /***** ERC4626 Functions *****/

    function _deposit(uint256 assets, address to) external override returns (uint256 shares) {
        shares = 3*10**18;
        emit Deposit(msg.sender, to, assets, shares);
    }

    function _mint(uint256 shares, address to) external override returns (uint256 assets) {
        assets = 4*10**18;
        emit Deposit(msg.sender, to, assets, shares);
    }

    function _withdraw(uint256 assets, address to, address from) external override returns (uint256 shares) {
        shares = 5*10**18;
        emit Withdraw(msg.sender, to, from, assets, shares);
    }

    function _redeem(uint256 shares, address to, address from) external override returns (uint256 assets) {
        assets = 6*10**18;
        emit Withdraw(msg.sender, to, from, assets, shares);
    }

    /***** Sync Function *****/

    function _sync() external override {
        emit PoolUpdated(1, 2, 3, 4, 5, 6, 7, TX_TYPE.SYNC);
    }
}