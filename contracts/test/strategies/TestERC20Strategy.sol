// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../storage/AppStorage.sol";
import "../../interfaces/strategies/base/IShortStrategy.sol";

contract TestERC20Strategy is AppStorage, IShortStrategy {

    event Transfer(address indexed from, address indexed to, uint256 value);

    bytes4 private constant BALANCE_OF = bytes4(keccak256(bytes('balanceOf(address)')));

    address public _cfmm;

    constructor(address cfmm_) {
        _cfmm = cfmm_;
    }

    function _depositNoPull(address) external override returns(uint256) {
        (bool success, bytes memory data) = s.cfmm.staticcall(abi.encodeWithSelector(BALANCE_OF, msg.sender));
        require(success && data.length >= 32);
        s.LP_TOKEN_BALANCE = abi.decode(data, (uint256));
        return 0;
    }

    function _withdrawNoPull(address) external override pure returns(uint256) {
        return 0;
    }

    function _withdrawReserves(address) external override pure returns(uint256[] memory, uint256) {
        return (new uint256[](0), 0);
    }

    function _depositReserves(address, uint256[] calldata, uint256[] calldata, bytes calldata) external override pure returns(uint256[] memory, uint256) {
        return (new uint256[](0), 0);
    }

    function _getLatestCFMMReserves(bytes memory) external override pure returns(uint128[] memory cfmmReserves) {
        cfmmReserves = new uint128[](2);
    }

    function _getLatestCFMMInvariant(bytes memory) external override pure virtual returns(uint256 cfmmInvariant) {
        cfmmInvariant = 100;
    }

    function totalAssets(uint256, uint256, uint256, uint256, uint256) public override view returns(uint256) {
        (bool success, bytes memory data) = address(_cfmm).staticcall(abi.encodeWithSelector(BALANCE_OF, msg.sender));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    function totalSupply(address, address, uint256, uint256, uint256, uint256) public override view returns(uint256) {
        return s.totalSupply;
    }

    function totalAssetsAndSupply(VaultBalancesParams memory vaultBalanceParams) external override view returns(uint256 assets, uint256 supply) {
        return (totalAssets(0,0,0,0,0),totalSupply(address(0),address(0),0,0,0,0));
    }

    function getLastFees(uint256 borrowRate, uint256 borrowedInvariant, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply,
        uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlockNum, uint256 lastCFMMFeeIndex,
        uint256 maxCFMMFeeLeverage, uint256 spread) external override view returns(uint256 lastFeeIndex, uint256 updLastCFMMFeeIndex) {
        return (2,3);
    }

    function getLatestBalances(uint256 lastFeeIndex, uint256 borrowedInvariant, uint256 lpBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply)
        external override view returns(uint256 lastLPBalance, uint256 lastBorrowedLPBalance, uint256 lastBorrowedInvariant) {
        return (4,5,6);
    }

    /***** ERC4626 Functions *****/

    function _deposit(uint256 assets, address to) external override returns (uint256 shares) {
        shares = 3*10**18;
        emit Deposit(msg.sender, to, assets, shares);
        _mint(to, assets);
        return 0;
    }

    function _mint(uint256 shares, address to) external override returns (uint256 assets) {
        assets = 4*10**18;
        emit Deposit(msg.sender, to, assets, shares);
        _mint(to, shares);
        return 0;
    }

    function _withdraw(uint256 assets, address to, address from) external override returns (uint256 shares) {
        shares = 5*10**18;
        emit Withdraw(msg.sender, to, from, assets, shares);
        _mint(to, assets);
        return 0;
    }

    function _redeem(uint256 shares, address to, address from) external override returns (uint256 assets) {
        assets = 6*10**18;
        emit Withdraw(msg.sender, to, from, assets, shares);
        _mint(to, shares);
        return 0;
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(amount > 0, '0 amt');
        s.totalSupply += amount;
        s.balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "0 address");
        s.balanceOf[account] -= amount;
        s.totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _sync() external override {
    }

    function calcUtilRateEma(uint256 utilizationRate, uint256 emaUtilRateLast, uint256 emaMultiplier) external virtual override view returns(uint256 emaUtilRate) {
        return 0;
    }

    function calcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant, address paramsStore, address pool) public virtual view returns(uint256 borrowRate, uint256 utilizationRate, uint256 maxCFMMFeeLeverage, uint256 spread) {
        borrowRate = 4*1e16;
        utilizationRate = 3*1e17;
        maxCFMMFeeLeverage = 5000;
        spread = 1e18;
    }
}
