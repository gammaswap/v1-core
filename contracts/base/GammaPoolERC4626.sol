// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./GammaPoolERC20.sol";
import "../interfaces/strategies/base/IShortStrategy.sol";

abstract contract GammaPoolERC4626 is GammaPoolERC20 {

    event Deposit(address indexed caller, address indexed to, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed to, address indexed from, uint256 assets, uint256 shares);

    function vaultImplementation() internal virtual view returns(address);

    function asset() external virtual view returns(address) {
        return GammaPoolStorage.store().cfmm;
    }

    function deposit(uint256 assets, address receiver) external virtual returns (uint256 shares) {
        return abi.decode(callStrategy(vaultImplementation(), abi.encodeWithSelector(IShortStrategy._deposit.selector, assets, receiver)), (uint256));
    }

    function mint(uint256 shares, address receiver) external virtual returns (uint256 assets) {
        return abi.decode(callStrategy(vaultImplementation(), abi.encodeWithSelector(IShortStrategy._mint.selector, shares, receiver)), (uint256));
    }

    function withdraw(uint256 assets, address receiver, address owner) external virtual returns (uint256 shares){
        return abi.decode(callStrategy(vaultImplementation(), abi.encodeWithSelector(IShortStrategy._withdraw.selector, assets, receiver, owner)), (uint256));
    }

    function redeem(uint256 shares, address receiver, address owner) external virtual returns (uint256 assets){
        return abi.decode(callStrategy(vaultImplementation(), abi.encodeWithSelector(IShortStrategy._redeem.selector, shares, receiver, owner)), (uint256));
    }

    function totalAssets() public view virtual returns(uint256) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        return IShortStrategy(vaultImplementation()).totalAssets(store.cfmm, store.BORROWED_INVARIANT, store.LP_TOKEN_BALANCE,
            store.lastCFMMInvariant, store.lastCFMMTotalSupply, store.LAST_BLOCK_NUMBER);
    }

    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply();
        uint256 _totalAssets = totalAssets();

        return supply == 0 || _totalAssets == 0 ? assets : (assets * supply) / _totalAssets;
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

    function maxAssets(uint256 assets) internal view virtual returns(uint256) {
        uint256 lpTokenBalance = GammaPoolStorage.store().LP_TOKEN_BALANCE;
        if(assets < lpTokenBalance){
            return assets;
        }
        return lpTokenBalance;
    }

    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return maxAssets(convertToAssets(GammaPoolStorage.erc20().balanceOf[owner]));
    }

    function maxRedeem(address owner) public view virtual returns (uint256) {
        return convertToShares(maxWithdraw(owner));
    }

    function callStrategy(address strategy, bytes memory data) internal virtual returns(bytes memory result) {
        (bool success, bytes memory result) = strategy.delegatecall(data);
        require(success);
        return result;
    }
}