// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./GammaPoolERC20.sol";

abstract contract GammaPoolERC4626 is GammaPoolERC20 {

    event Deposit(address indexed caller, address indexed to, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed to, address indexed from, uint256 assets, uint256 shares);

    function asset() public virtual view returns(address) {
        return GammaPoolStorage.store().cfmm;
    }

    function deposit(uint256 assets, address receiver) external virtual returns (uint256 shares);

    function mint(uint256 shares, address receiver) external virtual returns (uint256 assets);

    function withdraw(uint256 assets, address receiver, address owner) external virtual returns (uint256 shares);

    function redeem(uint256 shares, address receiver, address owner) external virtual returns (uint256 assets);

    function totalAssets() public view virtual returns (uint256);

    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply();

        return supply == 0 || assets == 0 ? assets : (assets * supply) / totalAssets();
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply();

        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    function maxDeposit(address) public view virtual returns (uint256) {
        return totalAssets() > 0 || totalSupply() == 0 ? type(uint256).max : 0;
    }

    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return convertToAssets(GammaPoolStorage.store().balanceOf[owner]);
    }

    function maxRedeem(address owner) public view virtual returns (uint256) {
        return GammaPoolStorage.store().balanceOf[owner];
    }

}