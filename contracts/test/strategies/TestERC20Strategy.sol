pragma solidity ^0.8.0;
import "../../interfaces/strategies/base/IShortStrategy.sol";
import "../../libraries/storage/GammaPoolStorage.sol";

contract TestERC20Strategy is IShortStrategy{

    event Transfer(address indexed from, address indexed to, uint256 value);

    bytes4 private constant BALANCE_OF = bytes4(keccak256(bytes('balanceOf(address)')));

    function _depositNoPull(address to) external override returns(uint256) {
        return 0;
    }

    function _withdrawNoPull(address to) external override returns(uint256) {
        return 0;
    }

    function _withdrawReserves(address to) external override returns(uint256[] memory, uint256) {
        return (new uint256[](0), 0);
    }

    function _depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external override returns(uint256[] memory, uint256) {
        return (new uint256[](0), 0);
    }

    function getBorrowRate(uint256 lpBalance, uint256 lpBorrowed) external override pure returns(uint256) {
        return 0;
    }

    function calcFeeIndex(address cfmm, uint256 borrowRate, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlackNum)
        external override pure returns(uint256, uint256, uint256, uint256) {
        return (0, 0, 0, 0);
    }

    function calcBorrowedLPTokensPlusInterest(uint256 borrowedInvariant, uint256 lastFeeIndex, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) external override pure returns(uint256) {
        return 0;
    }

    function totalAssets(address cfmm, uint256 borrowedInvariant, uint256 lpBalance, uint256 lpBorrowed, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlackNum) external override view returns(uint256) {
        (bool success, bytes memory data) = address(cfmm).staticcall(abi.encodeWithSelector(BALANCE_OF, msg.sender));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /***** ERC4626 Functions *****/

    function _deposit(uint256 assets, address to) external override returns (uint256 shares) {
        shares = 3*10**18;
        emit Deposit(msg.sender, to, assets, shares);
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        _mint(store, to, assets);
        return 0;
    }

    function _mint(uint256 shares, address to) external override returns (uint256 assets) {
        assets = 4*10**18;
        emit Deposit(msg.sender, to, assets, shares);
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        _mint(store, to, shares);
        return 0;
    }

    function _withdraw(uint256 assets, address to, address from) external override returns (uint256 shares) {
        shares = 5*10**18;
        emit Withdraw(msg.sender, to, from, assets, shares);
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        _mint(store, to, assets);
        return 0;
    }

    function _redeem(uint256 shares, address to, address from) external override returns (uint256 assets) {
        assets = 6*10**18;
        emit Withdraw(msg.sender, to, from, assets, shares);
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        _mint(store, to, shares);
        return 0;
    }

    function _mint(GammaPoolStorage.Store storage store, address account, uint256 amount) internal virtual {
        require(amount > 0, '0 amt');
        store.totalSupply += amount;
        store.balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(GammaPoolStorage.Store storage store, address account, uint256 amount) internal virtual {
        require(account != address(0), "0 address");
        store.balanceOf[account] -= amount;
        store.totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

}
