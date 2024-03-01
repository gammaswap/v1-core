// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import "../interfaces/strategies/base/IShortStrategy.sol";
import "../rates/AbstractRateModel.sol";
import "../utils/DelegateCaller.sol";
import "../utils/Pausable.sol";
import "./Refunds.sol";
import "./GammaPoolERC20.sol";

/// @title ERC4626 (GS LP) implementation of GammaPool
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Vault implementation of GammaPool, assets are CFMM LP tokens, shares are GS LP tokens
abstract contract GammaPoolERC4626 is GammaPoolERC20, DelegateCaller, Refunds, Pausable {

    error MinShares();

    /// @dev Minimum number of shares issued on first deposit to avoid rounding issues
    uint256 public constant MIN_SHARES = 1e3;

    /// @return address - implementation contract that implements vault logic (e.g. ShortStrategy)
    function vaultImplementation() internal virtual view returns(address);

    /// @return cfmmTotalSupply - latest total supply of LP tokens from CFMM
    function _getLatestCFMMTotalSupply() internal virtual view returns(uint256 cfmmTotalSupply);

    /// @return cfmmInvariant - latest invariant in CFMM
    function _getLatestCFMMInvariant() internal virtual view returns(uint256 cfmmInvariant);

    /// @return cfmmReserves - latest token reserves in the CFMM
    function _getLatestCFMMReserves() internal virtual view returns(uint128[] memory cfmmReserves);

    /// @return lastPrice - latest token reserves in the CFMM
    function _getLastCFMMPrice() internal virtual view returns(uint256 lastPrice);

    // @dev See {Pausable-_pauser}
    function _pauser() internal override virtual view returns(address) {
        return s.factory;
    }

    /// @dev See {Pausable-_functionIds}
    function _functionIds() internal override virtual view returns(uint256) {
        return s.funcIds;
    }

    /// @dev See {Pausable-_setFunctionIds}
    function _setFunctionIds(uint256 _funcIds) internal override virtual {
        s.funcIds = _funcIds;
    }

    /// @return address - CFMM LP token address used for the Vault for accounting, depositing, and withdrawing.
    function asset() external virtual view returns(address) {
        return s.cfmm;
    }

    /// @dev Deposit CFMM LP token and get GS LP token, does a transferFrom according to ERC4626 implementation
    /// @param assets - CFMM LP tokens deposited in exchange for GS LP tokens
    /// @param to - address receiving GS LP tokens
    /// @return shares - quantity of GS LP tokens sent to receiver address (`to`) for CFMM LP tokens
    function deposit(uint256 assets, address to) external virtual whenNotPaused(1) returns (uint256 shares) {
        return abi.decode(callStrategy(vaultImplementation(), abi.encodeCall(IShortStrategy._deposit, (assets, to))), (uint256));
    }

    /// @dev Mint GS LP token in exchange for CFMM LP token deposits, does a transferFrom according to ERC4626 implementation
    /// @param shares - GS LP tokens minted from CFMM LP token deposits
    /// @param to - address receiving GS LP tokens
    /// @return assets - quantity of CFMM LP tokens sent to receiver address (`to`)
    function mint(uint256 shares, address to) external virtual whenNotPaused(2) returns (uint256 assets) {
        return abi.decode(callStrategy(vaultImplementation(), abi.encodeCall(IShortStrategy._mint, (shares, to))), (uint256));
    }

    /// @dev Withdraw CFMM LP token by burning GS LP tokens
    /// @param assets - amount of CFMM LP tokens requested to withdraw in exchange for GS LP tokens
    /// @param to - address receiving CFMM LP tokens
    /// @param from - address burning its GS LP tokens
    /// @return shares - quantity of GS LP tokens burned
    function withdraw(uint256 assets, address to, address from) external virtual whenNotPaused(3) returns (uint256 shares) {
        return abi.decode(callStrategy(vaultImplementation(), abi.encodeCall(IShortStrategy._withdraw, (assets, to, from))), (uint256));
    }

    /// @dev Redeem GS LP tokens and get CFMM LP token
    /// @param shares - GS LP tokens requested to redeem in exchange for GS LP tokens
    /// @param to - address receiving CFMM LP tokens
    /// @param from - address redeeming GS LP tokens
    /// @return assets - quantity of CFMM LP tokens sent to receiver address (`to`) for GS LP tokens redeemed
    function redeem(uint256 shares, address to, address from) external virtual whenNotPaused(4) returns (uint256 assets) {
        return abi.decode(callStrategy(vaultImplementation(), abi.encodeCall(IShortStrategy._redeem, (shares, to, from))), (uint256));
    }

    /// @dev Calculates and returns total CFMM LP tokens belonging to liquidity providers using state global variables. It does not update the GammaPool
    /// @return assets - current total CFMM LP tokens (real and virtual) in existence in the GammaPool, including accrued interest
    function totalAssets() public view virtual returns(uint256 assets) {
        (assets,) = _totalAssetsAndSupply();
    }

    /// @dev Get total supply of GS LP tokens, takes into account dilution through protocol revenue
    /// @return supply - total supply of GS LP tokens after taking protocol revenue dilution into account
    function totalSupply() public virtual override view returns(uint256 supply){
        (, supply) = _totalAssetsAndSupply();
    }

    /// @dev Convert CFMM LP tokens to GS LP tokens
    /// @param assets - CFMM LP tokens
    /// @return shares - GS LP tokens quantity that corresponds to assets quantity provided as a parameter (CFMM LP tokens)
    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        if(assets == 0) {
            return 0;
        }
        (uint256 _totalAssets, uint256 supply) = _totalAssetsAndSupply();

        if(supply == 0 || _totalAssets == 0) {
            if(assets <= MIN_SHARES) revert MinShares();

            unchecked {
                return assets - MIN_SHARES;
            }
        }
        return (assets * supply) / _totalAssets;
    }

    /// @dev Convert GS LP tokens to GS LP tokens
    /// @param shares - GS LP tokens
    /// @return assets - CFMM LP tokens quantity that corresponds to shares quantity provided as a parameter (GS LP tokens)
    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        if(shares == 0) {
            return 0;
        }
        (uint256 assets, uint256 supply) = _totalAssetsAndSupply();
        if(supply == 0) {
            if(shares <= MIN_SHARES) revert MinShares();

            unchecked {
                return shares - MIN_SHARES;
            }
        }
        // totalAssets is total CFMM LP tokens, including accrued interest, calculated using state variables
        return (shares * assets) / supply;
    }

    /// @dev Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given current on-chain conditions.
    /// @param assets - CFMM LP tokens
    /// @return shares - expected GS LP tokens to get from assets (CFMM LP tokens) deposited
    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    /// @dev Allows an on-chain or off-chain user to simulate the effects of their mint at the current block, given current on-chain conditions.
    /// @param shares - GS LP tokens
    /// @return assets - CFMM LP tokens needed to deposit to get the desired shares (GS LP tokens)
    function previewMint(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    /// @dev Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block, given current on-chain conditions.
    /// @param assets - CFMM LP tokens
    /// @return shares - expected GS LP tokens needed to burn to withdraw desired assets (CFMM LP tokens)
    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    /// @dev Allows an on-chain or off-chain user to simulate the effects of their redemption at the current block, given current on-chain conditions.
    /// @param shares - GS LP tokens
    /// @return assets - expected CFMM LP tokens withdrawn if shares (GS LP tokens) burned
    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    /// @dev Returns the maximum amount of CFMM LP tokens that can be deposited into the Vault for the receiver, through a deposit call. Ignores address parameter
    /// @return maxAssets - maximum amount of CFMM LP tokens that can be deposited
    function maxDeposit(address) public view virtual returns (uint256) {
        (uint256 assets, uint256 supply) = _totalAssetsAndSupply();
        return assets > 0 || supply == 0 ? type(uint256).max : 0; // no limits on deposits unless pool is a bad state
    }

    /// @dev Returns the maximum amount of the GS LP tokens that can be minted for the receiver, through a mint call. Ignores address parameter
    /// @return maxShares - maximum amount of GS LP tokens that can be minted
    function maxMint(address) public view virtual returns (uint256) {
        return type(uint256).max;
    }

    /// @dev Calculate max CFMM LP tokens available for withdrawal by checking against CFMM LP tokens not borrowed
    /// @param assets - CFMM LP tokens to withdraw
    /// @return maxAssets - maximum CFMM LP tokens available for withdrawal
    function maxAssets(uint256 assets) internal view virtual returns(uint256) {
        uint256 lpTokenBalance = s.LP_TOKEN_BALANCE; // CFMM LP tokens in GammaPool that have not been borrowed
        if(assets < lpTokenBalance){ // limit assets available to withdraw to what has not been borrowed
            return assets;
        }
        return lpTokenBalance;
    }

    /// @dev Returns the maximum amount of CFMM LP tokens that can be withdrawn from the owner balance in the Vault, through a withdraw call.
    /// @param owner - address that owns GS LP tokens
    /// @return maxAssets - maximum amount of CFMM LP tokens that can be withdrawn by owner address
    function maxWithdraw(address owner) public view virtual returns (uint256) {
        return maxAssets(convertToAssets(s.balanceOf[owner])); // convert owner GS LP tokens to equivalent CFMM LP tokens and check if available to withdraw
    }

    /// @dev Returns the maximum amount of GS LP tokens that can be redeemed from the owner balance in the Vault, through a redeem call.
    /// @param owner - address that owns GS LP tokens
    /// @return maxShares - maximum amount of GS LP tokens that can be redeemed by owner address
    function maxRedeem(address owner) public view virtual returns (uint256) {
        return convertToShares(maxWithdraw(owner)); // get maximum amount of CFMM LP tokens that can be withdrawn and convert to equivalent GS LP token amount
    }

    /// @dev Calculate and return total CFMM LP tokens belonging to GammaPool liquidity providers using state global variables.
    /// @dev And calculate and return total supply of GS LP tokens taking into account dilution through protocol revenue.
    /// @dev This function does not update the GammaPool
    /// @return assets - current total CFMM LP tokens (real and virtual) in existence in the GammaPool, including accrued interest
    /// @return supply - total supply of GS LP tokens after taking protocol revenue dilution into account
    function _totalAssetsAndSupply() internal view virtual returns (uint256 assets, uint256 supply) {
        IShortStrategy.VaultBalancesParams memory _params;
        _params.factory = s.factory;
        _params.pool = address(this);
        _params.paramsStore = _params.factory;
        _params.BORROWED_INVARIANT = s.BORROWED_INVARIANT;
        _params.latestCfmmInvariant = _getLatestCFMMInvariant();
        _params.latestCfmmTotalSupply = _getLatestCFMMTotalSupply();
        _params.LAST_BLOCK_NUMBER = s.LAST_BLOCK_NUMBER;
        _params.lastCFMMInvariant = s.lastCFMMInvariant;
        _params.lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        _params.lastCFMMFeeIndex = s.lastCFMMFeeIndex;
        _params.totalSupply = s.totalSupply;
        _params.LP_TOKEN_BALANCE = s.LP_TOKEN_BALANCE;
        _params.LP_INVARIANT = s.LP_INVARIANT;

        (assets, supply) = IShortStrategy(vaultImplementation()).totalAssetsAndSupply(_params);
    }
}