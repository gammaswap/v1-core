// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../events/IShortStrategyEvents.sol";

/// @title Interface for Short Strategy
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used in strategies that deposit and withdraw liquidity from CFMM for liquidity providers
interface IShortStrategy is IShortStrategyEvents {
    /// @dev Deposit CFMM LP tokens and get GS LP tokens, without doing a transferFrom transaction. Must have sent CFMM LP tokens first
    /// @param to - address of receiver of GS LP token
    /// @return shares - quantity of GS LP tokens received for CFMM LP tokens
    function _depositNoPull(address to) external returns(uint256 shares);

    /// @dev Withdraw CFMM LP tokens, by burning GS LP tokens, without doing a transferFrom transaction. Must have sent GS LP tokens first
    /// @param to - address of receiver of CFMM LP tokens
    /// @return assets - quantity of CFMM LP tokens received for GS LP tokens
    function _withdrawNoPull(address to) external returns(uint256 assets);

    /// @dev Withdraw reserve token quantities of CFMM (instead of CFMM LP tokens), by burning GS LP tokens
    /// @param to - address of receiver of reserve token quantities
    /// @return reserves - quantity of reserve tokens withdrawn from CFMM and sent to receiver
    /// @return assets - quantity of CFMM LP tokens representing reserve tokens withdrawn
    function _withdrawReserves(address to) external returns(uint256[] memory reserves, uint256 assets);

    /// @dev Deposit reserve token quantities to CFMM (instead of CFMM LP tokens) to get CFMM LP tokens, store them in GammaPool and receive GS LP tokens
    /// @param to - address of receiver of GS LP tokens
    /// @param amountsDesired - desired amounts of reserve tokens to deposit
    /// @param amountsMin - minimum amounts of reserve tokens to deposit
    /// @param data - information identifying request to deposit
    /// @return reserves - quantity of actual reserve tokens deposited in CFMM
    /// @return shares - quantity of GS LP tokens received for reserve tokens deposited
    function _depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external returns(uint256[] memory reserves, uint256 shares);

    /// @dev Get latest reserves in the CFMM, which can be used for pricing
    /// @param cfmmData - bytes data for calculating CFMM reserves
    /// @return cfmmReserves - reserves in the CFMM
    function _getLatestCFMMReserves(bytes memory cfmmData) external view returns(uint128[] memory cfmmReserves);

    /// @dev Get latest invariant from CFMM
    /// @param cfmmData - bytes data for calculating CFMM invariant
    /// @return cfmmInvariant - reserves in the CFMM
    function _getLatestCFMMInvariant(bytes memory cfmmData) external view returns(uint256 cfmmInvariant);

    /// @dev Calculate current total CFMM LP tokens (real and virtual) in existence in the GammaPool, including accrued interest
    /// @param borrowedInvariant - invariant amount borrowed in GammaPool including accrued interest calculated in last update to GammaPool
    /// @param lpBalance - amount of LP tokens deposited in GammaPool
    /// @param lastCFMMInvariant - invariant amount in CFMM
    /// @param lastCFMMTotalSupply - total supply in CFMM
    /// @param lastFeeIndex - last fees charged by GammaPool since last update
    /// @return totalAssets - total CFMM LP tokens in existence in the pool (real and virtual) including accrued interest
    function totalAssets(uint256 borrowedInvariant, uint256 lpBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 lastFeeIndex) external view returns(uint256);

    /// @dev Calculate current total CFMM LP tokens (real and virtual) in existence in the GammaPool, including accrued interest
    /// @param paramsStore - address containing rate model parameters
    /// @param pool - address of pool to get interest rate calculations for
    /// @param lastCFMMFeeIndex - accrued CFMM Fees in storage
    /// @param lastFeeIndex - last fees charged by GammaPool since last update
    /// @param utilizationRate - current utilization rate of GammaPool
    /// @param supply - actual GS LP total supply available in the pool
    /// @return totalSupply - total GS LP tokens in the pool including accrued interest
    function totalSupply(address paramsStore, address pool, uint256 lastCFMMFeeIndex, uint256 lastFeeIndex, uint256 utilizationRate, uint256 supply) external view returns (uint256);

    /// @dev Calculate fees charged by GammaPool since last update to liquidity loans and current borrow rate
    /// @param borrowRate - current borrow rate of GammaPool
    /// @param borrowedInvariant - invariant amount borrowed in GammaPool including accrued interest calculated in last update to GammaPool
    /// @param lastCFMMInvariant - current invariant amount of CFMM in GammaPool
    /// @param lastCFMMTotalSupply - current total supply of CFMM LP shares in GammaPool
    /// @param prevCFMMInvariant - invariant amount in CFMM in last update to GammaPool
    /// @param prevCFMMTotalSupply - total supply in CFMM in last update to GammaPool
    /// @param lastBlockNum - last block GammaPool was updated
    /// @param lastCFMMFeeIndex - last fees accrued by CFMM since last update
    /// @return lastFeeIndex - last fees charged by GammaPool since last update
    /// @return updLastCFMMFeeIndex - updated fees accrued by CFMM till current block
    function getLastFees(uint256 borrowRate, uint256 borrowedInvariant, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply,
        uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 lastBlockNum, uint256 lastCFMMFeeIndex)
        external view returns(uint256 lastFeeIndex, uint256 updLastCFMMFeeIndex);

    /// @dev Calculate balances updated by fees charged since last update
    /// @param lastFeeIndex - last fees charged by GammaPool since last update
    /// @param borrowedInvariant - invariant amount borrowed in GammaPool including accrued interest calculated in last update to GammaPool
    /// @param lpBalance - amount of LP tokens deposited in GammaPool
    /// @param lastCFMMInvariant - invariant amount in CFMM
    /// @param lastCFMMTotalSupply - total supply in CFMM
    /// @return lastLPBalance - last fees accrued by CFMM since last update
    /// @return lastBorrowedLPBalance - last fees charged by GammaPool since last update
    /// @return lastBorrowedInvariant - current borrow rate of GammaPool
    function getLatestBalances(uint256 lastFeeIndex, uint256 borrowedInvariant, uint256 lpBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) external view returns(uint256 lastLPBalance, uint256 lastBorrowedLPBalance, uint256 lastBorrowedInvariant);

    /// @dev Update pool invariant, LP tokens borrowed plus interest, interest rate index, and last block update
    /// @param utilizationRate - interest accrued to loans in GammaPool
    /// @param emaUtilRateLast - interest accrued to loans in GammaPool
    /// @param emaMultiplier - interest accrued to loans in GammaPool
    /// @return emaUtilRate - interest accrued to loans in GammaPool
    function calcUtilRateEma(uint256 utilizationRate, uint256 emaUtilRateLast, uint256 emaMultiplier) external view returns(uint256 emaUtilRate);

    /// @dev Synchronize LP_TOKEN_BALANCE with actual CFMM LP tokens deposited in GammaPool
    function _sync() external;

    /***** ERC4626 Functions *****/

    /// @dev Deposit CFMM LP tokens and get GS LP tokens, does a transferFrom according to ERC4626 implementation
    /// @param assets - CFMM LP tokens deposited in exchange for GS LP tokens
    /// @param to - address receiving GS LP tokens
    /// @return shares - quantity of GS LP tokens sent to receiver address (`to`) for CFMM LP tokens
    function _deposit(uint256 assets, address to) external returns (uint256 shares);

    /// @dev Mint GS LP token in exchange for CFMM LP token deposits, does a transferFrom according to ERC4626 implementation
    /// @param shares - GS LP tokens minted from CFMM LP token deposits
    /// @param to - address receiving GS LP tokens
    /// @return assets - quantity of CFMM LP tokens sent to receiver address (`to`)
    function _mint(uint256 shares, address to) external returns (uint256 assets);

    /// @dev Withdraw CFMM LP token by burning GS LP tokens
    /// @param assets - amount of CFMM LP tokens requested to withdraw in exchange for GS LP tokens
    /// @param to - address receiving CFMM LP tokens
    /// @param from - address burning its GS LP tokens
    /// @return shares - quantity of GS LP tokens burned
    function _withdraw(uint256 assets, address to, address from) external returns (uint256 shares);

    /// @dev Redeem GS LP tokens and get CFMM LP token
    /// @param shares - GS LP tokens requested to redeem in exchange for GS LP tokens
    /// @param to - address receiving CFMM LP tokens
    /// @param from - address redeeming GS LP tokens
    /// @return assets - quantity of CFMM LP tokens sent to receiver address (`to`) for GS LP tokens redeemed
    function _redeem(uint256 shares, address to, address from) external returns (uint256 assets);
}