// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "./IGammaPoolEvents.sol";
import "./IProtocol.sol";
import "./strategies/events/IGammaPoolERC20Events.sol";
import "./rates/IRateModel.sol";

/// @title Interface for GammaPool
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Interface used for GammaPool implementations
interface IGammaPool is IProtocol, IGammaPoolEvents, IGammaPoolERC20Events, IRateModel {
    /// @dev Struct containing Loan data plus tokenId
    struct LoanData {
        /// @dev Loan counter, used to generate unique tokenId which indentifies the loan in the GammaPool
        uint256 id;

        /// @dev Loan tokenId
        uint256 tokenId;

        // 1x256 bits
        /// @dev GammaPool address loan belongs to
        address poolId; // 160 bits
        /// @dev Index of GammaPool interest rate at time loan is created/updated, max 7.9% trillion
        uint96 rateIndex; // 96 bits

        // 1x256 bits
        /// @dev Initial loan debt in liquidity invariant units. Only increase when more liquidity is borrowed, decreases when liquidity is paid
        uint128 initLiquidity; // 128 bits
        /// @dev Loan debt in liquidity invariant units in last update
        uint128 lastLiquidity; // 128 bits
        /// @dev Loan debt in liquidity invariant units, increases with every update according to how many blocks have passed
        uint128 liquidity; // 128 bits
        /// @dev Collateral in terms of liquidity invariant units, increases with every update according to how many blocks have passed
        uint256 collateral;

        /// @dev Initial loan debt in terms of LP tokens at time liquidity was borrowed, updates along with initLiquidity
        uint256 lpTokens;
        /// @dev Reserve tokens held as collateral for the liquidity debt, indices match GammaPool's tokens[] array indices
        uint128[] tokensHeld; // array of 128 bit numbers

        /// @dev reference address of contract holding additional collateral for loan (e.g. CollateralManager)
        address refAddr;
        /// @dev reference fee of contract holding additional collateral for loan (e.g. CollateralManager)
        uint16 refFee;
        /// @dev reference type of contract holding additional collateral for loan (e.g. CollateralManager)
        uint8 refType;

        /// @dev price at which loan was opened
        uint256 px;
        /// @dev if true loan can be liquidated
        bool canLiquidate;

        /// @dev names of ERC20 tokens of CFMM
        uint256 accFeeIndex;
        /// @dev Percent accrual in CFMM invariant since last update
        uint256 lastCFMMFeeIndex;
        /// @dev names of ERC20 tokens of CFMM
        uint256 LAST_BLOCK_NUMBER;

        /// @dev ERC20 tokens of CFMM
        address[] tokens;
        /// @dev decimals of ERC20 tokens of CFMM
        uint8[] decimals;
        /// @dev symbols of ERC20 tokens of CFMM
        string[] symbols;
        /// @dev names of ERC20 tokens of CFMM
        string[] names;

        /// @dev interest rate model parameter store
        address paramsStore;
        /// @dev address of short strategy
        address shortStrategy;

        /// @dev borrowed liquidity invariant of the pool
        uint256 BORROWED_INVARIANT;
        /// @dev Quantity of CFMM's liquidity invariant held in GammaPool as LP tokens
        uint256 LP_INVARIANT;
        /// @dev balance of CFMM LP tokens in the pool
        uint256 LP_TOKEN_BALANCE;
        /// @dev last CFMM liquidity invariant
        uint256 lastCFMMInvariant;
        /// @dev last CFMM total supply of LP tokens
        uint256 lastCFMMTotalSupply;
        /// @dev LTV liquidation threshold
        uint256 ltvThreshold;
        /// @dev Liquidation fee
        uint256 liquidationFee;
    }

    /// @dev Struct returned in getLatestRates function. Contains all relevant global state variables
    struct RateData {
        /// @dev GammaPool's ever increasing interest rate index, tracks interest accrued through CFMM and liquidity loans, max 7.9% trillion
        uint256 accFeeIndex;
        /// @dev Percent accrual in CFMM invariant since last update
        uint256 lastCFMMFeeIndex;
        /// @dev Percent accrual in CFMM invariant and GammaPool interest since last update
        uint256 lastFeeIndex;
        /// @dev Borrow APR of LP tokens in GammaPool
        uint256 borrowRate;
        /// @dev Utilization rate of GammaPool
        uint256 utilizationRate;
        /// @dev last block an update to the GammaPool's global storage variables happened
        uint256 lastBlockNumber;
        /// @dev Current block number when requesting pool data
        uint256 currBlockNumber;
        /// @dev Last Price in CFMM
        uint256 lastPrice;
        /// @dev Supply APR of LP tokens in GammaPool
        uint256 supplyRate;
        /// @dev names of ERC20 tokens of CFMM
        uint256 BORROWED_INVARIANT;
        /// @dev Quantity of CFMM's liquidity invariant held in GammaPool as LP tokens
        uint256 LP_INVARIANT;
        /// @dev EMA of utilization Rate
        uint256 emaUtilRate;
        /// @dev Minimum Utilization Rate 1
        uint256 minUtilRate1;
        /// @dev Minimum Utilization Rate 2
        uint256 minUtilRate2;
        /// @dev Dynamic origination fee divisor
        uint256 feeDivisor;
        /// @dev Loan opening origination fee in basis points
        uint256 origFee; // 16 bits
        /// @dev LTV liquidation threshold
        uint256 ltvThreshold;
        /// @dev Liquidation fee
        uint256 liquidationFee;
        /// @dev Short Strategy implementation address
        address shortStrategy;
        /// @dev Interest Rate Parameters Store contract
        address paramsStore;
    }

    /// @dev Struct returned in getPoolData function. Contains all relevant global state variables
    struct PoolData {
        /// @dev GammaPool address
        address poolId;
        /// @dev Protocol id of the implementation contract for this GammaPool
        uint16 protocolId;
        /// @dev Borrow Strategy implementation contract for this GammaPool
        address borrowStrategy;
        /// @dev Repay Strategy implementation contract for this GammaPool
        address repayStrategy;
        /// @dev Rebalance Strategy implementation contract for this GammaPool
        address rebalanceStrategy;
        /// @dev Short Strategy implementation contract for this GammaPool
        address shortStrategy;
        /// @dev Single Liquidation Strategy implementation contract for this GammaPool
        address singleLiquidationStrategy;
        /// @dev Batch Liquidation Strategy implementation contract for this GammaPool
        address batchLiquidationStrategy;

        /// @dev factory - address of factory contract that instantiated this GammaPool
        address factory;
        /// @dev paramsStore - interest rate model parameters store contract
        address paramsStore;

        // LP Tokens
        /// @dev Quantity of CFMM's LP tokens deposited in GammaPool by liquidity providers
        uint256 LP_TOKEN_BALANCE;// LP Tokens in GS, LP_TOKEN_TOTAL = LP_TOKEN_BALANCE + LP_TOKEN_BORROWED_PLUS_INTEREST
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
        /// @dev GammaPool's ever increasing interest rate index, tracks interest accrued through CFMM and liquidity loans, max 30.9% billion
        uint80 accFeeIndex;
        /// @dev External swap fee in basis points, max 255 basis points = 2.55%
        uint8 extSwapFee; // 8 bits
        /// @dev Loan opening origination fee in basis points
        uint16 origFee; // 16 bits
        /// @dev LAST_BLOCK_NUMBER - last block an update to the GammaPool's global storage variables happened
        uint40 LAST_BLOCK_NUMBER;
        /// @dev Percent accrual in CFMM invariant since last update
        uint64 lastCFMMFeeIndex; // 64 bits
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
        /// @dev symbols of ERC20 tokens of CFMM
        string[] symbols;
        /// @dev names of ERC20 tokens of CFMM
        string[] names;
        /// @dev Decimals of CFMM tokens, indices match tokens[] array
        uint8[] decimals;
        /// @dev Amounts of ERC20 tokens from the CFMM held as collateral in the GammaPool. Equals to the sum of all tokensHeld[] quantities in all loans
        uint128[] TOKEN_BALANCE;
        /// @dev Amounts of ERC20 tokens from the CFMM held in the CFMM as reserve quantities. Used to log prices in the CFMM during updates to the GammaPool
        uint128[] CFMM_RESERVES; //keeps track of price of CFMM at time of update

        /// @dev Last Price in CFMM
        uint256 lastPrice;
        /// @dev Percent accrual in CFMM invariant and GammaPool interest since last update
        uint256 lastFeeIndex;
        /// @dev Borrow rate of LP tokens in GammaPool
        uint256 borrowRate;
        /// @dev Utilization rate of GammaPool
        uint256 utilizationRate;
        /// @dev Current block number when requesting pool data
        uint40 currBlockNumber;
        /// @dev LTV liquidation threshold
        uint8 ltvThreshold;
        /// @dev Liquidation fee
        uint8 liquidationFee;
        /// @dev Supply APR of LP tokens in GammaPool
        uint256 supplyRate;
        /// @dev EMA of utilization Rate
        uint40 emaUtilRate;
        /// @dev Multiplier of EMA Utilization Rate
        uint8 emaMultiplier;
        /// @dev Minimum Utilization Rate 1
        uint8 minUtilRate1;
        /// @dev Minimum Utilization Rate 2
        uint8 minUtilRate2;
        /// @dev Dynamic origination fee divisor
        uint16 feeDivisor;
        /// @dev Minimum liquidity amount that can be borrowed
        uint72 minBorrow;
    }

    /// @dev cfmm - address of CFMM this GammaPool is for
    function cfmm() external view returns(address);

    /// @dev ERC20 tokens of CFMM
    function tokens() external view returns(address[] memory);

    /// @dev address of factory contract that instantiated this GammaPool
    function factory() external view returns(address);

    /// @dev viewer contract to implement complex view functions for data in this GammaPool
    function viewer() external view returns(address);

    /// @dev Borrow Strategy implementation contract for this GammaPool
    function borrowStrategy() external view returns(address);

    /// @dev Repay Strategy implementation contract for this GammaPool
    function repayStrategy() external view returns(address);

    /// @dev Rebalance Strategy implementation contract for this GammaPool
    function rebalanceStrategy() external view returns(address);

    /// @dev Short Strategy implementation contract for this GammaPool
    function shortStrategy() external view returns(address);

    /// @dev Single Loan Liquidation Strategy implementation contract for this GammaPool
    function singleLiquidationStrategy() external view returns(address);

    /// @dev Batch Liquidations Strategy implementation contract for this GammaPool
    function batchLiquidationStrategy() external view returns(address);

    /// @dev Set parameters to calculate origination fee, liquidation fee, and ltv threshold
    /// @param origFee - loan opening origination fee in basis points
    /// @param extSwapFee - external swap fee in basis points, max 255 basis points = 2.55%
    /// @param emaMultiplier - multiplier used in EMA calculation of utilization rate
    /// @param minUtilRate1 - minimum utilization rate to calculate dynamic origination fee in exponential model
    /// @param minUtilRate2 - minimum utilization rate to calculate dynamic origination fee in linear model
    /// @param feeDivisor - fee divisor for calculating origination fee, based on 2^(maxUtilRate - minUtilRate1)
    /// @param liquidationFee - liquidation fee to charge during liquidations in basis points (1 - 255 => 0.01% to 2.55%)
    /// @param ltvThreshold - ltv threshold (1 - 255 => 0.1% to 25.5%)
    /// @param minBorrow - minimum liquidity amount that can be borrowed or left unpaid in a loan
    function setPoolParams(uint16 origFee, uint8 extSwapFee, uint8 emaMultiplier, uint8 minUtilRate1, uint8 minUtilRate2, uint16 feeDivisor, uint8 liquidationFee, uint8 ltvThreshold, uint72 minBorrow) external;

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

    /// @return cfmmReserves - latest token reserves in the CFMM
    function getLatestCFMMReserves() external view returns(uint128[] memory cfmmReserves);

    /// @return cfmmReserves - latest token reserves in the CFMM
    /// @return cfmmInvariant - latest total invariant in the CFMM
    /// @return cfmmTotalSupply - latest total supply of LP tokens in CFMM
    function getLatestCFMMBalances() external view returns(uint128[] memory cfmmReserves, uint256 cfmmInvariant, uint256 cfmmTotalSupply);

    /// @return lastPrice - calculates and gets current price at CFMM
    function getLastCFMMPrice() external view returns(uint256);

    // Long Gamma

    /// @dev Create a new Loan struct
    /// @param refId - Reference id of post transaction activities attached to this loan
    /// @return tokenId - unique id of loan struct created
    function createLoan(uint16 refId) external returns(uint256 tokenId);

    /// @dev Get loan from storage and convert to LoanData struct
    /// @param _tokenId - tokenId of loan to convert
    /// @return _loanData - loan data struct (same as Loan + tokenId)
    function getLoanData(uint256 _tokenId) external view returns(LoanData memory _loanData);

    /// @dev Get loan with its most updated information
    /// @param _tokenId - unique id of loan, used to look up loan in GammaPool
    /// @return _loanData - loan data struct (same as Loan + tokenId)
    function loan(uint256 _tokenId) external view returns(LoanData memory _loanData);

    /// @dev Get list of loans and their corresponding tokenIds created in GammaPool. Capped at s.tokenIds.length.
    /// @param start - index from where to start getting tokenIds from array
    /// @param end - end index of array wishing to get tokenIds. If end > s.tokenIds.length, end is s.tokenIds.length
    /// @param active - if true, return loans that have an outstanding liquidity debt
    /// @return _loans - list of loans created in GammaPool
    function getLoans(uint256 start, uint256 end, bool active) external view returns(LoanData[] memory _loans);

    /// @dev calculate liquidity invariant from collateral tokens
    /// @param tokensHeld - loan's collateral tokens
    /// @return collateralInvariant - invariant calculated from loan's collateral tokens
    function calcInvariant(uint128[] memory tokensHeld) external view returns(uint256);

    /// @dev Get list of loans mapped to tokenIds in array `tokenIds`
    /// @param tokenIds - list of loan tokenIds
    /// @param active - if true, return loans that have an outstanding liquidity debt
    /// @return _loans - list of loans created in GammaPool
    function getLoansById(uint256[] calldata tokenIds, bool active) external view returns(LoanData[] memory _loans);

    /// @return loanCount - total number of loans opened
    function getLoanCount() external view returns(uint256);

    /// @dev Deposit more collateral in loan identified by tokenId
    /// @param tokenId - unique id identifying loan
    /// @param ratio - ratio to rebalance collateral after increasing collateral
    /// @return tokensHeld - updated collateral token amounts backing loan
    function increaseCollateral(uint256 tokenId, uint256[] calldata ratio) external returns(uint128[] memory tokensHeld);

    /// @dev Withdraw collateral from loan identified by tokenId
    /// @param tokenId - unique id identifying loan
    /// @param amounts - amounts of collateral tokens requested to withdraw
    /// @param to - destination address of receiver of collateral withdrawn
    /// @param ratio - ratio to rebalance collateral after withdrawing collateral
    /// @return tokensHeld - updated collateral token amounts backing loan
    function decreaseCollateral(uint256 tokenId, uint128[] memory amounts, address to, uint256[] calldata ratio) external returns(uint128[] memory tokensHeld);

    /// @dev Borrow liquidity from the CFMM and add it to the debt and collateral of loan identified by tokenId
    /// @param tokenId - unique id identifying loan
    /// @param lpTokens - quantity of CFMM LP tokens requested to short
    /// @param ratio - ratio to rebalance collateral after borrowing
    /// @return liquidityBorrowed - liquidity amount that has been borrowed
    /// @return amounts - reserves quantities withdrawn from CFMM that correspond to the LP tokens shorted, now used as collateral
    /// @return tokensHeld - updated collateral token amounts backing loan
    function borrowLiquidity(uint256 tokenId, uint256 lpTokens, uint256[] calldata ratio) external returns(uint256 liquidityBorrowed, uint256[] memory amounts, uint128[] memory tokensHeld);

    /// @dev Repay liquidity debt of loan identified by tokenId, debt is repaid using available collateral in loan
    /// @param tokenId - unique id identifying loan
    /// @param liquidity - liquidity debt being repaid, capped at actual liquidity owed. Can't repay more than you owe
    /// @param collateralId - index of collateral token + 1
    /// @param to - if repayment type requires withdrawal, the address that will receive the funds. Otherwise can be zero address
    /// @return liquidityPaid - liquidity amount that has been repaid
    /// @return amounts - collateral amounts consumed in repaying liquidity debt
    function repayLiquidity(uint256 tokenId, uint256 liquidity, uint256 collateralId, address to) external returns(uint256 liquidityPaid, uint256[] memory amounts);

    /// @dev Repay liquidity debt of loan identified by tokenId, debt is repaid using available collateral in loan
    /// @param tokenId - unique id identifying loan
    /// @param liquidity - liquidity debt being repaid, capped at actual liquidity owed. Can't repay more than you owe
    /// @param ratio - weights of collateral after repaying liquidity
    /// @return liquidityPaid - liquidity amount that has been repaid
    /// @return amounts - collateral amounts consumed in repaying liquidity debt
    function repayLiquiditySetRatio(uint256 tokenId, uint256 liquidity, uint256[] calldata ratio) external returns(uint256 liquidityPaid, uint256[] memory amounts);

    /// @dev Repay liquidity debt of loan identified by tokenId, using CFMM LP token
    /// @param tokenId - unique id identifying loan
    /// @param collateralId - index of collateral token to rebalance to + 1
    /// @param to - if repayment type requires withdrawal, the address that will receive the funds. Otherwise can be zero address
    /// @return liquidityPaid - liquidity amount that has been repaid
    /// @return tokensHeld - remaining token amounts collateralizing loan
    function repayLiquidityWithLP(uint256 tokenId, uint256 collateralId, address to) external returns(uint256 liquidityPaid, uint128[] memory tokensHeld);

    /// @dev Rebalance collateral amounts of loan identified by tokenId by purchasing or selling some of the collateral
    /// @param tokenId - unique id identifying loan
    /// @param deltas - collateral amounts being bought or sold (>0 buy, <0 sell), index matches tokensHeld[] index. Only n-1 tokens can be traded
    /// @param ratio - ratio to rebalance collateral
    /// @return tokensHeld - updated collateral token amounts backing loan
    function rebalanceCollateral(uint256 tokenId, int256[] memory deltas, uint256[] calldata ratio) external returns(uint128[] memory tokensHeld);

    /// @dev Update pool liquidity debt and optinally also loan liquidity debt
    /// @param tokenId - (optional) unique ids identifying loan, pass zero to ignore this parameter
    /// @return loanLiquidityDebt - updated liquidity debt amount of loan
    /// @return poolLiquidityDebt - updated liquidity debt amount of pool
    function updatePool(uint256 tokenId) external returns(uint256 loanLiquidityDebt, uint256 poolLiquidityDebt);

    /// @notice When calling this function and adding additional collateral it is assumed that you have sent the collateral first
    /// @dev Function to liquidate a loan using its own collateral or depositing additional tokens. Seeks full liquidation
    /// @param tokenId - tokenId of loan being liquidated
    /// @return loanLiquidity - loan liquidity liquidated (after write down)
    /// @return refund - amount of CFMM LP tokens being refunded to liquidator
    function liquidate(uint256 tokenId) external returns(uint256 loanLiquidity, uint256 refund);

    /// @dev Function to liquidate a loan using external LP tokens. Allows partial liquidation
    /// @param tokenId - tokenId of loan being liquidated
    /// @return loanLiquidity - loan liquidity liquidated (after write down)
    /// @return refund - amounts from collateral tokens being refunded to liquidator
    function liquidateWithLP(uint256 tokenId) external returns(uint256 loanLiquidity, uint256[] memory refund);

    /// @dev Function to liquidate multiple loans in batch.
    /// @param tokenIds - list of tokenIds of loans to liquidate
    /// @return totalLoanLiquidity - total loan liquidity liquidated (after write down)
    /// @return refund - amounts from collateral tokens being refunded to liquidator
    function batchLiquidations(uint256[] calldata tokenIds) external returns(uint256 totalLoanLiquidity, uint256[] memory refund);

    // Sync functions

    /// @dev Skim excess collateral tokens or CFMM LP tokens from GammaPool and send them to receiver (`to`) address
    /// @param to - address receiving excess tokens
    function skim(address to) external;

    /// @dev Synchronize LP_TOKEN_BALANCE with actual CFMM LP tokens deposited in GammaPool
    function sync() external;
}
