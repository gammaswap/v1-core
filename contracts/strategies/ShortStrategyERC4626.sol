// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "./ShortStrategy.sol";

/// @title Short Strategy ERC4626 abstract contract implementation of IShortStrategy's ERC4626 functions
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice All external functions that modify the state are locked to avoid reentrancy
/// @dev Only defines ERC4626 functions of ShortStrategy
abstract contract ShortStrategyERC4626 is ShortStrategy {

    /// @dev See {IShortStrategy-_deposit}.
    function _deposit(uint256 assets, address to) external virtual override lock returns(uint256 shares) {
        // Update interest rate and state variables before conversion
        updateIndex();

        // Convert CFMM LP tokens to GS LP tokens
        shares = convertToShares(assets);

        // Revert if redeeming 0 GS LP tokens
        if(shares == 0) revert ZeroShares();

        // Transfer CFMM LP tokens (`assets`) from msg.sender to GammaPool and mint GS LP tokens (`shares`) to receiver (`to`)
        depositAssetsFrom(msg.sender, to, assets, shares);
    }

    /// @dev See {IShortStrategy-_mint}.
    function _mint(uint256 shares, address to) external virtual override lock returns(uint256 assets) {
        // Update interest rate and state variables before conversion
        updateIndex();

        // Convert GS LP tokens to CFMM LP tokens
        assets = convertToAssets(shares);

        // Revert if withdrawing 0 CFMM LP tokens
        if(assets == 0) revert ZeroAssets();

        // Transfer CFMM LP tokens (`assets`) from msg.sender to GammaPool and mint GS LP tokens (`shares`) to receiver (`to`)
        depositAssetsFrom(msg.sender, to, assets, shares);
    }

    /// @dev See {IShortStrategy-_withdraw}.
    function _withdraw(uint256 assets, address to, address from) external virtual override lock returns(uint256 shares) {
        // Update interest rate and state variables before conversion
        updateIndex();

        // Revert if not enough CFMM LP tokens to withdraw
        if(assets > s.LP_TOKEN_BALANCE) revert ExcessiveWithdrawal();

        // Convert CFMM LP tokens to GS LP tokens
        shares = convertToShares(assets);

        // Revert if redeeming 0 GS LP tokens
        if(shares == 0) revert ZeroShares();

        // Send CFMM LP tokens to receiver (`to`) and burn corresponding GS LP tokens from msg.sender
        withdrawAssets(msg.sender, to, from, assets, shares, false);
    }

    /// @dev See {IShortStrategy-_redeem}.
    function _redeem(uint256 shares, address to, address from) external virtual override lock returns(uint256 assets) {
        // Update interest rate and state variables before conversion
        updateIndex();

        // Convert GS LP tokens to CFMM LP tokens
        assets = convertToAssets(shares);
        if(assets == 0) revert ZeroAssets(); // revert if withdrawing 0 CFMM LP tokens

        // Revert if not enough CFMM LP tokens to withdraw
        if(assets > s.LP_TOKEN_BALANCE) revert ExcessiveWithdrawal();

        // Send CFMM LP tokens to receiver (`to`) and burn corresponding GS LP tokens from msg.sender
        withdrawAssets(msg.sender, to, from, assets, shares, false);
    }

    /// @dev Deposit CFMM LP tokens (`assets`) via transferFrom and mint corresponding GS LP tokens (`shares`) to receiver (`to`)
    /// @param caller - user address that requested to deposit CFMM LP tokens
    /// @param to - address receiving GS LP tokens (`shares`)
    /// @param assets - amount of CFMM LP tokens deposited
    /// @param shares - amount of GS LP tokens minted to receiver (`to`)
    function depositAssetsFrom(address caller, address to, uint256 assets, uint256 shares) internal virtual {
        // Transfer `assets` (CFMM LP tokens) from `caller` to GammaPool
        GammaSwapLibrary.safeTransferFrom(s.cfmm, caller, address(this), assets);

        // To prevent rounding errors, lock min shares in first deposit
        if(s.totalSupply == 0) {
            shares = shares - MIN_SHARES;
            assets = assets - MIN_SHARES;
            depositAssets(caller, address(0), MIN_SHARES, MIN_SHARES, false);
        }
        // Track CFMM LP tokens (`assets`) in GammaPool and mint GS LP tokens (`shares`) to receiver (`to`)
        depositAssets(caller, to, assets, shares, false);
    }
}