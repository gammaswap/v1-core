// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

interface IShortStrategy {
    function _depositNoPull(address to) external returns(uint256 shares);
    function _withdrawNoPull(address to) external returns(uint256 assets);
    function _withdrawReserves(address to) external returns(uint256[] memory reserves, uint256 assets);
    function _depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external returns(uint256[] memory reserves, uint256 shares);

    function totalAssets(address cfmm, uint256 borrowedInvariant, uint256 lpBalance, uint256 lpBorrowed, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlockNum) external view returns(uint256);

    /***** ERC4626 Functions *****/

    function _deposit(uint256 assets, address to) external returns (uint256 shares);
    function _mint(uint256 shares, address to) external returns (uint256 assets);
    function _withdraw(uint256 assets, address to, address from) external returns (uint256 shares);
    function _redeem(uint256 shares, address to, address from) external returns (uint256 assets);

    event Deposit(address indexed caller, address indexed to, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed to, address indexed from, uint256 assets, uint256 shares);
}