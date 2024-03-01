// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../interfaces/strategies/base/IShortStrategy.sol";

contract TestShortStrategy2 is IShortStrategy{

    function _getLatestCFMMReserves(bytes memory) external override pure returns(uint128[] memory cfmmReserves) {
        cfmmReserves = new uint128[](2);
        cfmmReserves[0] = 1;
        cfmmReserves[1] = 2;
    }

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

    function _getLatestCFMMInvariant(bytes memory) external override pure virtual returns(uint256 cfmmInvariant) {
        cfmmInvariant = 100;
    }

    function totalAssets(uint256, uint256, uint256, uint256, uint256) external override pure returns(uint256) {
        return 1000*(10**18);
    }

    function totalSupply(address, address, uint256, uint256, uint256, uint256) external override pure returns(uint256) {
        return 1000*(10**18);
    }

    function totalAssetsAndSupply(VaultBalancesParams memory vaultBalanceParams) external override view returns(uint256 assets, uint256 supply) {
        return (1000*(10**18),1000*(10**18));
    }

    function getLastFees(uint256 borrowRate, uint256 borrowedInvariant, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply,
        uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlockNum, uint256 lastCFMMFeeIndex,
        uint256 maxCFMMFeeLeverage, uint256 spread) external override view returns(uint256 lastFeeIndex, uint256 updLastCFMMFeeIndex) {
        return (2,1e18);
    }

    function getLatestBalances(uint256 lastFeeIndex, uint256 borrowedInvariant, uint256 lpBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply)
        external override view returns(uint256 lastLPBalance, uint256 lastBorrowedLPBalance, uint256 lastBorrowedInvariant) {
        return (4,5,6);
    }

    function calcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant, address paramsStore, address pool) public virtual view returns(uint256 borrowRate, uint256 utilizationRate, uint256 maxCFMMFeeLeverage, uint256 spread) {
        borrowRate = 4*1e16;
        utilizationRate = 3*1e17;
        maxCFMMFeeLeverage = 5000;
        spread = 1e18;
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
        uint128[] memory cfmmReserves = new uint128[](2);
        cfmmReserves[0] = 8;
        cfmmReserves[1] = 9;
        emit PoolUpdated(1, 2, 3, 4, 5, 6, 7, cfmmReserves, TX_TYPE.SYNC);
    }

    function calcUtilRateEma(uint256 utilizationRate, uint256 emaUtilRateLast, uint256 emaMultiplier) external virtual override view returns(uint256 emaUtilRate) {
        return 0;
    }
}
