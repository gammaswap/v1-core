// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;
import "../../storage/AppStorage.sol";
import "../../interfaces/strategies/base/IShortStrategy.sol";

contract TestERC20Strategy is AppStorage, IShortStrategy {

    event Transfer(address indexed from, address indexed to, uint256 value);

    bytes4 private constant BALANCE_OF = bytes4(keccak256(bytes('balanceOf(address)')));

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

    function totalAssets(address cfmm, uint256, uint256, uint256, uint256, uint256) external override view returns(uint256) {
        (bool success, bytes memory data) = address(cfmm).staticcall(abi.encodeWithSelector(BALANCE_OF, msg.sender));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
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
}
