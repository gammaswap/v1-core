// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "./GammaPoolERC20.sol";
import "../interfaces/strategies/base/IShortStrategy.sol";

/// @title ERC4626 (GS LP) implementation of GammaPool
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Vault implementation of GammaPool, assets are CFMM LP tokens, shares are GS LP tokens
abstract contract GammaPoolERC4626 is GammaPoolERC20 {

    error MinShares();

    /// @dev Minimum number of shares issued on first deposit to avoid rounding issues
    uint256 public constant MIN_SHARES = 1e3;

    /// @return address - implementation contract that implements vault logic (e.g. ShortStrategy)
    function vaultImplementation() internal virtual view returns(address);

    /// @return address - CFMM LP token address used for the Vault for accounting, depositing, and withdrawing.
    function asset() external virtual view returns(address) {
        return s.cfmm;
    }

    /// @dev Deposit CFMM LP token and get GS LP token, does a transferFrom according to ERC4626 implementation
    /// @param assets - CFMM LP tokens deposited in exchange for GS LP tokens
    /// @param to - address receiving GS LP tokens
    /// @return shares - quantity of GS LP tokens sent to receiver address (`to`) for CFMM LP tokens
    function deposit(uint256 assets, address to) external virtual returns (uint256 shares) {
        return abi.decode(callStrategy(vaultImplementation(), abi.encodeWithSelector(IShortStrategy._deposit.selector, assets, to)), (uint256));
    }

    /// @dev Mint GS LP token in exchange for CFMM LP token deposits, does a transferFrom according to ERC4626 implementation
    /// @param shares - GS LP tokens minted from CFMM LP token deposits
    /// @param to - address receiving GS LP tokens
    /// @return assets - quantity of CFMM LP tokens sent to receiver address (`to`)
    function mint(uint256 shares, address to) external virtual returns (uint256 assets) {
        return abi.decode(callStrategy(vaultImplementation(), abi.encodeWithSelector(IShortStrategy._mint.selector, shares, to)), (uint256));
    }

    /// @dev Withdraw CFMM LP token by burning GS LP tokens
    /// @param assets - amount of CFMM LP tokens requested to withdraw in exchange for GS LP tokens
    /// @param to - address receiving CFMM LP tokens
    /// @param from - address burning its GS LP tokens
    /// @return shares - quantity of GS LP tokens burned
    function withdraw(uint256 assets, address to, address from) external virtual returns (uint256 shares) {
        return abi.decode(callStrategy(vaultImplementation(), abi.encodeWithSelector(IShortStrategy._withdraw.selector, assets, to, from)), (uint256));
    }

    /// @dev Redeem GS LP tokens and get CFMM LP token
    /// @param shares - GS LP tokens requested to redeem in exchange for GS LP tokens
    /// @param to - address receiving CFMM LP tokens
    /// @param from - address redeeming GS LP tokens
    /// @return assets - quantity of CFMM LP tokens sent to receiver address (`to`) for GS LP tokens redeemed
    function redeem(uint256 shares, address to, address from) external virtual returns (uint256 assets) {
        return abi.decode(callStrategy(vaultImplementation(), abi.encodeWithSelector(IShortStrategy._redeem.selector, shares, to, from)), (uint256));
    }

    /// @dev Calculates and returns total CFMM LP tokens belonging to liquidity providers using state global variables. It does not update the GammaPool
    /// @return totalAssets - current total CFMM LP tokens (real and virtual) in existence in the GammaPool, including accrued interest
    function totalAssets() public view virtual returns(uint256) {
        return IShortStrategy(vaultImplementation()).totalAssets(s.cfmm, s.BORROWED_INVARIANT, s.LP_TOKEN_BALANCE,
            s.lastCFMMInvariant, s.lastCFMMTotalSupply, s.LAST_BLOCK_NUMBER);
    }

    /// @dev Convert CFMM LP tokens to GS LP tokens
    /// @param assets - CFMM LP tokens
    /// @return shares - GS LP tokens quantity that corresponds to assets quantity provided as a parameter (CFMM LP tokens)
    function convertToShares(uint256 assets) public view virtual returns (uint256) {
        if(assets == 0) {
            return 0;
        }
        uint256 supply = totalSupply(); // Total amount of GS LP tokens issued
        uint256 _totalAssets = totalAssets(); // Calculates total CFMM LP tokens, including accrued interest, using state variables

        if(supply == 0 || _totalAssets == 0) {
            if(assets <= MIN_SHARES) {
                revert MinShares();
            }
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
        uint256 supply = totalSupply(); // Total amount of GS LP tokens issued
        if(supply == 0) {
            if(shares <= MIN_SHARES) {
                revert MinShares();
            }
            unchecked {
                return shares - MIN_SHARES;
            }
        }
        // totalAssets is total CFMM LP tokens, including accrued interest, calculated using state variables
        return (shares * totalAssets()) / supply;
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
        return totalAssets() > 0 || totalSupply() == 0 ? type(uint256).max : 0; // no limits on deposits unless pool is a bad state
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