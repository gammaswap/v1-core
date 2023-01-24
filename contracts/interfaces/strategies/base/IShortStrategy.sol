// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./IBaseStrategy.sol";

/// @title Interface for Short Strategy
/// @author Daniel D. Alcarraz
/// @dev Used in strategies that deposit and withdraw liquidity from cfmm for LPs
interface IShortStrategy is IBaseStrategy {
    /// @dev Deposit cfmm LP token and get GS LP token, without doing a transferFrom transaction. Must have sent cfmm LP token first
    /// @param to - address of receiver of GS LP token
    /// @return shares - quantity of GS LP tokens received for cfmm LP tokens
    function _depositNoPull(address to) external returns(uint256 shares);

    /// @dev Withdraw cfmm LP token, by burning GS LP token, without doing a transferFrom transaction. Must have sent GS LP token first
    /// @param to - address of receiver of cfmm LP tokens
    /// @return assets - quantity of cfmm LP tokens received for GS LP tokens
    function _withdrawNoPull(address to) external returns(uint256 assets);

    /// @dev Withdraw reserve token quantities of cfmm (instead of cfmm LP tokens), by burning GS LP token
    /// @param to - address of receiver of reserve token quantities
    /// @return reserves - quantity of reserve tokens withdrawn from cfmm and sent to receiver
    /// @return assets - quantity of cfmm LP tokens representing reserve tokens withdrawn
    function _withdrawReserves(address to) external returns(uint256[] memory reserves, uint256 assets);

    /// @dev Deposit reserve token quantities to cfmm (instead of cfmm LP tokens) to get cfmm LP tokens, store them in GammaPool and receive GS LP tokens
    /// @param to - address of receiver of GS LP tokens
    /// @param amountsDesired - desired amounts of reserve tokens to deposit
    /// @param amountsMin - minimum amounts of reserve tokens to deposit
    /// @param data - information identifying request to deposit
    /// @return reserves - quantity of actual reserve tokens deposited in cfmm
    /// @return shares - quantity of GS LP tokens received for reserve tokens deposited
    function _depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external returns(uint256[] memory reserves, uint256 shares);

    /// @dev Calculate current total cfmm LP tokens (real and virtual) in existence in the GammaPool, including accrued interest
    /// @param cfmm - address of cfmm
    /// @param borrowedInvariant - invariant amount borrowed in GammaPool including accrued interest calculated in last update to GammaPool
    /// @param lpBalance - amount of LP tokens deposited in GammaPool
    /// @param prevCFMMInvariant - invariant amount in cfmm in last update to GammaPool
    /// @param prevCFMMTotalSupply - total supply in cfmm in last update to GammaPool
    /// @param lastBlockNum - last block GammaPool was updated
    /// @return totalAssets - total cfmm LP tokens in existence in the pool (real and virtual) including accrued interest
    function totalAssets(address cfmm, uint256 borrowedInvariant, uint256 lpBalance, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlockNum) external view returns(uint256);

    /***** ERC4626 Functions *****/

    /// @dev Deposit cfmm LP token and get GS LP token, does a transferFrom according to ERC4626 implementation
    /// @param assets - cfmm LP tokens deposited in exchange for GS LP tokens
    /// @param to - address receiving GS LP tokens
    /// @return shares - quantity of GS LP tokens sent to receiver address (`to`) for cfmm LP tokens
    function _deposit(uint256 assets, address to) external returns (uint256 shares);

    /// @dev Mint GS LP token in exchange for cfmm LP token deposits, does a transferFrom according to ERC4626 implementation
    /// @param shares - GS LP tokens minted from cfmm LP token deposits
    /// @param to - address receiving GS LP tokens
    /// @return assets - quantity of cfmm LP tokens sent to receiver address (`to`)
    function _mint(uint256 shares, address to) external returns (uint256 assets);

    /// @dev Withdraw cfmm LP token by burning GS LP tokens
    /// @param assets - amount of cfmm LP tokens requested to withdraw in exchange for GS LP tokens
    /// @param to - address receiving cfmm LP tokens
    /// @param from - address burning its GS LP tokens
    /// @return shares - quantity of GS LP tokens burned
    function _withdraw(uint256 assets, address to, address from) external returns (uint256 shares);

    /// @dev Redeem GS LP tokens and get cfmm LP token
    /// @param shares - GS LP tokens requested to redeem in exchange for GS LP tokens
    /// @param to - address receiving cfmm LP tokens
    /// @param from - address redeeming GS LP tokens
    /// @return assets - quantity of cfmm LP tokens sent to receiver address (`to`) for GS LP tokens redeemed
    function _redeem(uint256 shares, address to, address from) external returns (uint256 assets);

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
}