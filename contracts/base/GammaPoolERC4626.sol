// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./GammaPoolERC20.sol";
import "../interfaces/strategies/base/IShortStrategy.sol";

/// @title ERC4626 (GS LP) implementation of GammaPool
/// @author Daniel D. Alcarraz
/// @dev Vault implementation of GammaPool, assets are cfmm LP tokens, shares are GS LP tokens
abstract contract GammaPoolERC4626 is GammaPoolERC20 {
    /// @dev Event emitted when a deposit of cfmm LP tokens in exchange of GS LP tokens happens (e.g. _deposit, _mint, _depositReserves, _depositNoPull)
    /// @param caller - address calling the function to deposit cfmm LP tokens
    /// @param to - address receiving GS LP tokens
    /// @param assets - cfmm LP tokens deposited
    /// @param shares - GS LP tokens minted
    event Deposit(address indexed caller, address indexed to, uint256 assets, uint256 shares);

    /// @dev Event emitted when a withdrawal of cfmm LP tokens happens (e.g. _withdraw, _redeem, _withdrawReserves, _withdrawNoPull)
    /// @param caller - address calling the function to withdraw cfmm LP tokens
    /// @param to - address receiving cfmm LP tokens
    /// @param from - address redeeming/burning GS LP tokens
    /// @param assets - cfmm LP tokens withdrawn
    /// @param shares - GS LP tokens redeemed
    event Withdraw(address indexed caller, address indexed to, address indexed from, uint256 assets, uint256 shares);

    /// @return address - implementation contract that implements vault logic (e.g. ShortStrategy)
    function vaultImplementation() internal virtual view returns(address);

    /// @return address - cfmm LP token address used for the Vault for accounting, depositing, and withdrawing.
    function asset() external virtual view returns(address) {
        return s.cfmm;
    }

    /// @dev Deposit cfmm LP token and get GS LP token, does a transferFrom according to ERC4626 implementation
    /// @param assets - cfmm LP tokens deposited in exchange for GS LP tokens
    /// @param to - address receiving GS LP tokens
    /// @return shares - quantity of GS LP tokens sent to receiver address (`to`) for cfmm LP tokens
    function deposit(uint256 assets, address to) external virtual returns (uint256 shares) {
        return abi.decode(callStrategy(vaultImplementation(), abi.encodeWithSelector(IShortStrategy._deposit.selector, assets, to)), (uint256));
    }

    /// @dev Mint GS LP token in exchange for cfmm LP token deposits, does a transferFrom according to ERC4626 implementation
    /// @param shares - GS LP tokens minted from cfmm LP token deposits
    /// @param to - address receiving GS LP tokens
    /// @return assets - quantity of cfmm LP tokens sent to receiver address (`to`)
    function mint(uint256 shares, address to) external virtual returns (uint256 assets) {
        return abi.decode(callStrategy(vaultImplementation(), abi.encodeWithSelector(IShortStrategy._mint.selector, shares, to)), (uint256));
    }

    /// @dev Withdraw cfmm LP token by burning GS LP tokens
    /// @param assets - amount of cfmm LP tokens requested to withdraw in exchange for GS LP tokens
    /// @param to - address receiving cfmm LP tokens
    /// @param from - address burning its GS LP tokens
    /// @return shares - quantity of GS LP tokens burned
    function withdraw(uint256 assets, address to, address from) external virtual returns (uint256 shares) {
        return abi.decode(callStrategy(vaultImplementation(), abi.encodeWithSelector(IShortStrategy._withdraw.selector, assets, to, from)), (uint256));
    }

    /// @dev Redeem GS LP tokens and get cfmm LP token
    /// @param shares - GS LP tokens requested to redeem in exchange for GS LP tokens
    /// @param to - address receiving cfmm LP tokens
    /// @param from - address redeeming GS LP tokens
    /// @return assets - quantity of cfmm LP tokens sent to receiver address (`to`) for GS LP tokens redeemed
    function redeem(uint256 shares, address to, address from) external virtual returns (uint256 assets) {
        return abi.decode(callStrategy(vaultImplementation(), abi.encodeWithSelector(IShortStrategy._redeem.selector, shares, to, from)), (uint256));
    }

    /// @dev Calculates and returns total cfmm LP tokens belonging to liquidity providers using state global variables. It does not update the GammaPool
    /// @return totalAssets - current total cfmm LP tokens (real and virtual) in existence in the GammaPool, including accrued interest
    function totalAssets() public view virtual returns(uint256) {
        return IShortStrategy(vaultImplementation()).totalAssets(s.cfmm, s.BORROWED_INVARIANT, s.LP_TOKEN_BALANCE,
            s.lastCFMMInvariant, s.lastCFMMTotalSupply, s.LAST_BLOCK_NUMBER);
    }

    /// @dev Convert cfmm LP tokens to GS LP tokens
    /// @param assets - cfmm LP tokens
    /// @return shares - GS LP tokens quantity that corresponds to assets quantity provided as a parameter (cfmm LP tokens)
    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply(); // total amount of GS LP tokens issued
        uint256 _totalAssets = totalAssets(); // calculates total cfmm LP tokens, including accrued interest, using state variables

        return supply == 0 || _totalAssets == 0 ? assets : (assets * supply) / _totalAssets;
    }

    /// @dev Convert GS LP tokens to GS LP tokens
    /// @param shares - GS LP tokens
    /// @return assets - cfmm LP tokens quantity that corresponds to shares quantity provided as a parameter (GS LP tokens)
    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply(); // total amount of GS LP tokens issued

        // totalAssets is total cfmm LP tokens, including accrued interest, calculated using state variables
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    /// @dev Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given current on-chain conditions.
    /// @param assets - cfmm LP tokens
    /// @return shares - expected GS LP tokens to get from assets (cfmm LP tokens) deposited
    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    /// @dev Allows an on-chain or off-chain user to simulate the effects of their mint at the current block, given current on-chain conditions.
    /// @param shares - GS LP tokens
    /// @return assets - cfmm LP tokens needed to deposit to get the desired shares (GS LP tokens)
    function previewMint(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    /// @dev Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block, given current on-chain conditions.
    /// @param assets - cfmm LP tokens
    /// @return shares - expected GS LP tokens needed to burn to withdraw desired assets (cfmm LP tokens)
    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    /// @dev Allows an on-chain or off-chain user to simulate the effects of their redemption at the current block, given current on-chain conditions.
    /// @param shares - GS LP tokens
    /// @return assets - expected cfmm LP tokens withdrawn if shares (GS LP tokens) burned
    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    /// @dev Returns the maximum amount of cfmm LP tokens that can be deposited into the Vault for the receiver, through a deposit call. Ignores address parameter
    /// @return maxAssets - maximum amount of cfmm LP tokens that can be deposited
    function maxDeposit(address) public view virtual returns (uint256) {
        return totalAssets() > 0 || totalSupply() == 0 ? type(uint256).max : 0; // no limits on deposits unless pool is a bad state
    }

    /// @dev Returns the maximum amount of the GS LP tokens that can be minted for the receiver, through a mint call. Ignores address parameter
    /// @return maxShares - maximum amount of GS LP tokens that can be minted
    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /// @dev Calculate max cfmm LP tokens available for withdrawal by checking against cfmm LP tokens not borrowed
    /// @param assets - cfmm LP tokens to withdraw
    /// @return maxAssets - maximum cfmm LP tokens available for withdrawal
    function maxAssets(uint256 assets) internal view virtual returns(uint256) {
        uint256 lpTokenBalance = s.LP_TOKEN_BALANCE; // cfmm LP tokens in GammaPool that have not been borrowed
        if(assets < lpTokenBalance){ // limit assets available to withdraw to what has not been borrowed
            return assets;
        }
        return lpTokenBalance;
    }

    /// @dev Returns the maximum amount of cfmm LP tokens that can be withdrawn from the owner balance in the Vault, through a withdraw call.
    /// @param owner - address that owns GS LP tokens
    /// @return maxAssets - maximum amount of cfmm LP tokens that can be withdrawn by owner address
    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return maxAssets(convertToAssets(s.balanceOf[owner])); // convert owner GS LP tokens to equivalent cfmm LP tokens and check if available to withdraw
    }

    /// @dev Returns the maximum amount of GS LP tokens that can be redeemed from the owner balance in the Vault, through a redeem call.
    /// @param owner - address that owns GS LP tokens
    /// @return maxShares - maximum amount of GS LP tokens that can be redeemed by owner address
    function maxRedeem(address owner) public view virtual returns (uint256) {
        return convertToShares(maxWithdraw(owner)); // get maximum amount of cfmm LP tokens that can be withdrawn and convert to equivalent GS LP token amount
    }

    /// @dev Implement contract logic via delegate calls of implementation contracts
    /// @param strategy - address of implementation contract
    /// @param data - bytes containing function call and parameters at implementation (`strategy`) contract
    /// @return result - returned data from delegate function call
    function callStrategy(address strategy, bytes memory data) internal virtual returns(bytes memory result) {
        bool success;
        (success, result) = strategy.delegatecall(data);
        require(success);
        return result;
    }
}