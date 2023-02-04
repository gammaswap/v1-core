// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./IGammaPoolEvents.sol";

/// @title Interface for GammaPool
/// @author Daniel D. Alcarraz
/// @dev Interface used to clear tokens from the GammaPool
interface IGammaPool is IGammaPoolEvents {
    /// @dev Struct returned in getPoolData function. Contains all relevant global state variables
    struct PoolData {
        /// @dev Protocol id of the implementation contract for this GammaPool
        uint16 protocolId;
        /// @dev Long Strategy implementation contract for this GammaPool
        address longStrategy;
        /// @dev Short Strategy implementation contract for this GammaPool
        address shortStrategy;
        /// @dev Liquidation Strategy implementation contract for this GammaPool
        address liquidationStrategy;

        /// @dev factory - address of factory contract that instantiated this GammaPool
        address factory;

        // LP Tokens
        /// @dev Quantity of CFMM's LP tokens deposited in GammaPool by liquidity providers
        uint256 LP_TOKEN_BALANCE;//LP Tokens in GS, LP_TOKEN_TOTAL = LP_TOKEN_BALANCE + LP_TOKEN_BORROWED_PLUS_INTEREST
        /// @dev Quantity of CFMM's LP tokens that have been borrowed by liquidity borrowers excluding accrued interest (principal)
        uint256 LP_TOKEN_BORROWED;//LP Tokens that have been borrowed (Principal)
        /// @dev Quantity of CFMM's LP tokens that have been borrowed by liquidity borrowers including accrued interest
        uint256 LP_TOKEN_BORROWED_PLUS_INTEREST;//LP Tokens that have been borrowed (principal) plus interest in LP Tokens

        // Invariants
        /// @dev Quantity of CFMM's liquidity invariant that has been borrowed including accrued interest, maps to LP_TOKEN_BORROWED_PLUS_INTEREST
        uint128 BORROWED_INVARIANT;
        /// @dev Quantity of CFMM's liquidity invariant held in GammaPool as LP tokens, maps to LP_TOKEN_BALANCE
        uint128 LP_INVARIANT;//Invariant from LP Tokens, TOTAL_INVARIANT = BORROWED_INVARIANT + LP_INVARIANT

        // Rates
        /// @dev cfmm - address of CFMM this GammaPool is for
        address cfmm;
        /// @dev GammaPool's ever increasing interest rate index, tracks interest accrued through CFMM and liquidity loans, max 7.9% trillion
        uint96 accFeeIndex;
        /// @dev LAST_BLOCK_NUMBER - last block an update to the GammaPool's global storage variables happened
        uint48 LAST_BLOCK_NUMBER;
        /// @dev percent accrual in CFMM invariant since last update
        uint80 lastCFMMFeeIndex; // 80 bits
        /// @dev Total liquidity invariant amount in CFMM (from GammaPool and others), read in last update to GammaPool's storage variables
        uint128 lastCFMMInvariant;
        /// @dev Total LP token supply from CFMM (belonging to GammaPool and others), read in last update to GammaPool's storage variables
        uint256 lastCFMMTotalSupply;

        // ERC20 fields
        /// @dev Total supply of GammaPool's own ERC20 token representing the liquidity of depositors to the CFMM through the GammaPool
        uint256 totalSupply;

        // tokens and balances
        /// @dev ERC20 tokens of CFMM
        address[] tokens;
        /// @dev Decimals of CFMM tokens, indices match tokens[] array
        uint8[] decimals;
        /// @dev Amounts of ERC20 tokens from the CFMM held as collateral in the GammaPool. Equals to the sum of all tokensHeld[] quantities in all loans
        uint128[] TOKEN_BALANCE;
        /// @dev Amounts of ERC20 tokens from the CFMM held in the CFMM as reserve quantities. Used to log prices in the CFMM during updates to the GammaPool
        uint128[] CFMM_RESERVES; //keeps track of price of CFMM at time of update
    }

    /// @dev Function to initialize state variables GammaPool, called usually from GammaPoolFactory contract right after GammaPool instantiation
    /// @param _cfmm - address of CFMM GammaPool is for
    /// @param _tokens - ERC20 tokens of CFMM
    /// @param _decimals - decimals of CFMM tokens, indices must match _tokens[] array
    function initialize(address _cfmm, address[] calldata _tokens, uint8[] calldata _decimals) external;

    /// @dev cfmm - address of CFMM this GammaPool is for
    function cfmm() external view returns(address);

    /// @dev Protocol id of the implementation contract for this GammaPool
    function protocolId() external view returns(uint16);

    /// @dev ERC20 tokens of CFMM
    function tokens() external view returns(address[] memory);

    /// @dev factory - address of factory contract that instantiated this GammaPool
    function factory() external view returns(address);

    /// @dev Long Strategy implementation contract for this GammaPool
    function longStrategy() external view returns(address);

    /// @dev Short Strategy implementation contract for this GammaPool
    function shortStrategy() external view returns(address);

    /// @dev Liquidation Strategy implementation contract for this GammaPool
    function liquidationStrategy() external view returns(address);

    /// @dev Balances in the GammaPool of collateral tokens, CFMM LP tokens, and invariant amounts at last update
    /// @return tokenBalances - balances of collateral tokens in GammaPool
    /// @return lpTokenBalance - CFMM LP token balance of GammaPool
    /// @return lpTokenBorrowed - CFMM LP token principal amounts borrowed from GammaPool
    /// @return lpTokenBorrowedPlusInterest - CFMM LP token amounts borrowed from GammaPool including accrued interest
    /// @return borrowedInvariant - invariant amount borrowed from GammaPool including accrued interest, maps to lpTokenBorrowedPlusInterest
    /// @return lpInvariant - invariant of CFMM LP tokens in GammaPool not borrowed, maps to lpTokenBalance
    function getPoolBalances() external view returns(uint128[] memory tokenBalances, uint256 lpTokenBalance, uint256 lpTokenBorrowed,
        uint256 lpTokenBorrowedPlusInterest, uint256 borrowedInvariant, uint256 lpInvariant);

    /// @dev Balances in CFMM at last update of GammaPool
    /// @return cfmmReserves - total reserve tokens in CFMM last time GammaPool was updated
    /// @return cfmmInvariant - total liquidity invariant of CFMM last time GammaPool was updated
    /// @return cfmmTotalSupply - total CFMM LP tokens in existence last time GammaPool was updated
    function getCFMMBalances() external view returns(uint128[] memory cfmmReserves, uint256 cfmmInvariant, uint256 cfmmTotalSupply);

    /// @dev Interest rate information in GammaPool at last update
    /// @return accFeeIndex - total accrued interest in GammaPool at last update
    /// @return lastCFMMFeeIndex - total accrued CFMM fee since last update
    /// @return lastBlockNumber - last block GammaPool was updated
    function getRates() external view returns(uint256 accFeeIndex, uint256 lastCFMMFeeIndex, uint256 lastBlockNumber);

    /// @return data - struct containing all relevant global state variables and descriptive information of GammaPool. Used to avoid making multiple calls
    function getPoolData() external view returns(PoolData memory data);

    /// @dev Check GammaPool for CFMM and tokens can be created with this implementation
    /// @param _tokens - assumed tokens of CFMM, validate function should check CFMM is indeed for these tokens
    /// @param _cfmm - address of CFMM GammaPool will be for
    /// @return _tokensOrdered - tokens ordered to match the same order as in CFMM
    /// @return _decimals - decimal places of tokens in CFMM. Their index matches _tokensOrdered.
    function validateCFMM(address[] calldata _tokens, address _cfmm) external view returns(address[] memory _tokensOrdered, uint8[] memory _decimals);

    // Short Gamma

    /// @dev Deposit CFMM LP token and get GS LP token, without doing a transferFrom transaction. Must have sent CFMM LP token first
    /// @param to - address of receiver of GS LP token
    /// @return shares - quantity of GS LP tokens received for CFMM LP tokens
    function depositNoPull(address to) external returns(uint256 shares);

    /// @dev Withdraw CFMM LP token, by burning GS LP token, without doing a transferFrom transaction. Must have sent GS LP token first
    /// @param to - address of receiver of CFMM LP tokens
    /// @return assets - quantity of CFMM LP tokens received for GS LP tokens
    function withdrawNoPull(address to) external returns(uint256 assets);

    /// @dev Withdraw reserve token quantities of CFMM (instead of CFMM LP tokens), by burning GS LP token
    /// @param to - address of receiver of reserve token quantities
    /// @return reserves - quantity of reserve tokens withdrawn from CFMM and sent to receiver
    /// @return assets - quantity of CFMM LP tokens representing reserve tokens withdrawn
    function withdrawReserves(address to) external returns (uint256[] memory reserves, uint256 assets);

    /// @dev Deposit reserve token quantities to CFMM (instead of CFMM LP tokens) to get CFMM LP tokens, store them in GammaPool and receive GS LP tokens
    /// @param to - address of receiver of GS LP tokens
    /// @param amountsDesired - desired amounts of reserve tokens to deposit
    /// @param amountsMin - minimum amounts of reserve tokens to deposit
    /// @param data - information identifying request to deposit
    /// @return reserves - quantity of actual reserve tokens deposited in CFMM
    /// @return shares - quantity of GS LP tokens received for reserve tokens deposited
    function depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external returns(uint256[] memory reserves, uint256 shares);

    // Long Gamma

    /// @return cfmmReserves - latest token reserves in the CFMM
    function getLatestCFMMReserves() external view returns(uint256[] memory cfmmReserves);

    /// @dev Create a new Loan struct
    /// @return tokenId - unique id of loan struct created
    function createLoan() external returns(uint256 tokenId);

    /// @dev Get loan information for loan identified by tokenId
    /// @param tokenId - unique id of loan, used to look up loan in GammaPool
    /// @return id - loan counter of the GammaPool at the time the loan was created
    /// @return poolId - address of the GammaPool
    /// @return tokensHeld - collateral tokens held to collateralize liquidity debt
    /// @return initLiquidity - initial liquidity invariant debt
    /// @return liquidity - liquidity debt at last update
    /// @return lpTokens - quantity of CFMM LP tokens borrowed to create liquidity debt
    /// @return rateIndex - total accrued interest rate index of GammaPool at time of last loan update
    function loan(uint256 tokenId) external view returns (uint256 id, address poolId, uint128[] memory tokensHeld, uint256 initLiquidity, uint256 liquidity, uint256 lpTokens, uint256 rateIndex);

    /// @dev Deposit more collateral in loan identified by tokenId
    /// @param tokenId - unique id identifying loan
    /// @return tokensHeld - updated collateral token amounts backing loan
    function increaseCollateral(uint256 tokenId) external returns(uint128[] memory tokensHeld);

    /// @dev Withdraw collateral from loan identified by tokenId
    /// @param tokenId - unique id identifying loan
    /// @param amounts - amounts of collateral tokens requested to withdraw
    /// @param to - destination address of receiver of collateral withdrawn
    /// @return tokensHeld - updated collateral token amounts backing loan
    function decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external returns(uint128[] memory tokensHeld);

    /// @dev Borrow liquidity from the CFMM and add it to the debt and collateral of loan identified by tokenId
    /// @param tokenId - unique id identifying loan
    /// @param lpTokens - quantity of CFMM LP tokens requested to short
    /// @return liquidityBorrowed - liquidity amount that has been borrowed
    /// @return amounts - reserves quantities withdrawn from CFMM that correspond to the LP tokens shorted, now used as collateral
    function borrowLiquidity(uint256 tokenId, uint256 lpTokens) external returns(uint256 liquidityBorrowed, uint256[] memory amounts);

    /// @dev Repay liquidity debt of loan identified by tokenId, debt is repaid using available collateral in loan
    /// @param tokenId - unique id identifying loan
    /// @param liquidity - liquidity debt being repaid, capped at actual liquidity owed. Can't repay more than you owe
    /// @return liquidityPaid - liquidity amount that has been repaid
    /// @return amounts - collateral amounts consumed in repaying liquidity debt
    function repayLiquidity(uint256 tokenId, uint256 liquidity) external returns(uint256 liquidityPaid, uint256[] memory amounts);

    /// @dev Rebalance collateral amounts of loan identified by tokenId by purchasing or selling some of the collateral
    /// @param tokenId - unique id identifying loan
    /// @param deltas - collateral amounts being bought or sold (>0 buy, <0 sell), index matches tokensHeld[] index. Only n-1 tokens can be traded
    /// @return tokensHeld - updated collateral token amounts backing loan
    function rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external returns(uint128[] memory tokensHeld);

    /// @notice When calling this function and adding additional collateral it is assumed that you have sent the collateral first
    /// @dev Function to liquidate a loan using its own collateral or depositing additional tokens. Seeks full liquidation
    /// @param tokenId - tokenId of loan being liquidated
    /// @param deltas - amount tokens to trade to re-balance the collateral
    /// @return loanLiquidity - loan liquidity liquidated (after write down)
    /// @return refund - amounts from collateral tokens being refunded to liquidator
    function liquidate(uint256 tokenId, int256[] calldata deltas) external returns(uint256 loanLiquidity, uint256[] memory refund);

    /// @dev Function to liquidate a loan using external LP tokens. Allows partial liquidation
    /// @param tokenId - tokenId of loan being liquidated
    /// @return loanLiquidity - loan liquidity liquidated (after write down)
    /// @return refund - amounts from collateral tokens being refunded to liquidator
    function liquidateWithLP(uint256 tokenId) external returns(uint256 loanLiquidity, uint256[] memory refund);

    /// @dev Function to liquidate multiple loans in batch.
    /// @param tokenIds - list of tokenIds of loans to liquidate
    /// @return totalLoanLiquidity - total loan liquidity liquidated (after write down)
    /// @return totalCollateral - total collateral available for liquidation
    /// @return refund - amounts from collateral tokens being refunded to liquidator
    function batchLiquidations(uint256[] calldata tokenIds) external returns(uint256 totalLoanLiquidity, uint256 totalCollateral, uint256[] memory refund);

    // Sync functions

    /// @dev Skim excess collateral tokens or CFMM LP tokens from GammaPool and send them to receiver (`to`) address
    /// @param to - address receiving excess tokens
    function skim(address to) external;

    /// @dev Synchronize LP_TOKEN_BALANCE with actual CFMM LP tokens deposited in GammaPool
    function sync() external;
}
