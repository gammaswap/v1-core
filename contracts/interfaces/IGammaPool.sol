// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

/// @title Interface for GammaPool
/// @author Daniel D. Alcarraz
/// @dev Interface used to clear tokens from the GammaPool
interface IGammaPool {
    /// @dev See {IBaseStrategy-PoolUpdated}
    event PoolUpdated(uint256 lpTokenBalance, uint256 lpTokenBorrowed, uint256 lastBlockNumber, uint256 accFeeIndex,
        uint256 lpTokenBorrowedPlusInterest, uint256 lpInvariant, uint256 borrowedInvariant);

    /// @dev Event emitted when a Loan is created
    /// @param caller - address that created the loan
    /// @param tokenId - unique id that identifies the loan in question
    event LoanCreated(address indexed caller, uint256 tokenId);

    /// @dev See {IBaseLongStrategy-LoanUpdated}
    event LoanUpdated(uint256 indexed tokenId, uint128[] tokensHeld, uint256 liquidity, uint256 lpTokens, uint256 rateIndex);

    /// @dev See {ILiquidationStrategy-Liquidation}
    event Liquidation(uint256 indexed tokenId, uint256 collateral, uint256 liquidity, uint8 typ);

    /// @dev See {ILiquidationStrategy-BatchLiquidations}
    event BatchLiquidations(uint256 liquidityTotal, uint256 collateralTotal, uint256 lpTokensPrincipalTotal, uint128[] tokensHeldTotal, uint256[] tokenIds);

    /// @dev Event emitted when a write down due to bad debt happens in the GammaPool
    /// @param tokenId - unique id that identifies the loan causing the write down
    /// @param writeDownAmt - amount written down
    event WriteDown(uint256 indexed tokenId, uint256 writeDownAmt);

    /// @dev Event emitted when synchronizing cfmm LP token amounts (cfmm LP tokens deposited do not match LP_TOKEN_BALANCE)
    /// @param oldLpTokenBalance - previous LP_TOKEN_BALANCE
    /// @param newLpTokenBalance - updated LP_TOKEN_BALANCE
    event Sync(uint256 oldLpTokenBalance, uint256 newLpTokenBalance);

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

        /// @dev cfmm - address of cfmm this GammaPool is for
        address cfmm;
        /// @dev LAST_BLOCK_NUMBER - last block an update to the GammaPool's global storage variables happened
        uint96 LAST_BLOCK_NUMBER;
        /// @dev factory - address of factory contract that instantiated this GammaPool
        address factory;

        // LP Tokens
        /// @dev Quantity of cfmm's LP tokens deposited in GammaPool by liquidity providers
        uint256 LP_TOKEN_BALANCE;//LP Tokens in GS, LP_TOKEN_TOTAL = LP_TOKEN_BALANCE + LP_TOKEN_BORROWED_PLUS_INTEREST
        /// @dev Quantity of cfmm's LP tokens that have been borrowed by liquidity borrowers excluding accrued interest (principal)
        uint256 LP_TOKEN_BORROWED;//LP Tokens that have been borrowed (Principal)
        /// @dev Quantity of cfmm's LP tokens that have been borrowed by liquidity borrowers including accrued interest
        uint256 LP_TOKEN_BORROWED_PLUS_INTEREST;//LP Tokens that have been borrowed (principal) plus interest in LP Tokens

        // Invariants
        /// @dev Quantity of cfmm's liquidity invariant that has been borrowed including accrued interest, maps to LP_TOKEN_BORROWED_PLUS_INTEREST
        uint128 BORROWED_INVARIANT;
        /// @dev Quantity of cfmm's liquidity invariant held in GammaPool as LP tokens, maps to LP_TOKEN_BALANCE
        uint128 LP_INVARIANT;//Invariant from LP Tokens, TOTAL_INVARIANT = BORROWED_INVARIANT + LP_INVARIANT

        // Rates
        /// @dev GammaPool's ever increasing interest rate index, tracks interest accrued through cfmm and liquidity loans, max 7.9% trillion
        uint96 accFeeIndex;
        /// @dev Total liquidity invariant amount in cfmm (from GammaPool and others), read in last update to GammaPool's storage variables
        uint128 lastCFMMInvariant;
        /// @dev Total LP token supply from cfmm (belonging to GammaPool and others), read in last update to GammaPool's storage variables
        uint256 lastCFMMTotalSupply;

        // ERC20 fields
        /// @dev Total supply of GammaPool's own ERC20 token representing the liquidity of depositors to the cfmm through the GammaPool
        uint256 totalSupply;

        // tokens and balances
        /// @dev ERC20 tokens of cfmm
        address[] tokens;
        /// @dev Decimals of cfmm tokens, indices match tokens[] array
        uint8[] decimals;
        /// @dev Amounts of ERC20 tokens from the cfmm held as collateral in the GammaPool. Equals to the sum of all tokensHeld[] quantities in all loans
        uint128[] TOKEN_BALANCE;
        /// @dev Amounts of ERC20 tokens from the cfmm held in the cfmm as reserve quantities. Used to log prices in the cfmm during updates to the GammaPool
        uint128[] CFMM_RESERVES; //keeps track of price of CFMM at time of update
    }

    /// @dev Function to initialize state variables GammaPool, called usually from GammaPoolFactory contract right after GammaPool instantiation
    /// @param _cfmm - address of cfmm GammaPool is for
    /// @param _tokens - ERC20 tokens of cfmm
    /// @param _decimals - decimals of cfmm tokens, indices must match _tokens[] array
    function initialize(address _cfmm, address[] calldata _tokens, uint8[] calldata _decimals) external;

    /// @dev cfmm - address of cfmm this GammaPool is for
    function cfmm() external view returns(address);

    /// @dev Protocol id of the implementation contract for this GammaPool
    function protocolId() external view returns(uint16);

    /// @dev ERC20 tokens of cfmm
    function tokens() external view returns(address[] memory);

    /// @dev factory - address of factory contract that instantiated this GammaPool
    function factory() external view returns(address);

    /// @dev Long Strategy implementation contract for this GammaPool
    function longStrategy() external view returns(address);

    /// @dev Short Strategy implementation contract for this GammaPool
    function shortStrategy() external view returns(address);

    /// @dev Liquidation Strategy implementation contract for this GammaPool
    function liquidationStrategy() external view returns(address);

    /// @dev Balances in the GammaPool of collateral tokens, cfmm LP tokens, and invariant amounts at last update
    /// @return tokenBalances - balances of collateral tokens in GammaPool
    /// @return lpTokenBalance - cfmm LP token balance of GammaPool
    /// @return lpTokenBorrowed - cfmm LP token principal amounts borrowed from GammaPool
    /// @return lpTokenBorrowedPlusInterest - cfmm LP token amounts borrowed from GammaPool including accrued interest
    /// @return borrowedInvariant - invariant amount borrowed from GammaPool including accrued interest, maps to lpTokenBorrowedPlusInterest
    /// @return lpInvariant - invariant of cfmm LP tokens in GammaPool not borrowed, maps to lpTokenBalance
    function getPoolBalances() external view returns(uint128[] memory tokenBalances, uint256 lpTokenBalance, uint256 lpTokenBorrowed,
        uint256 lpTokenBorrowedPlusInterest, uint256 borrowedInvariant, uint256 lpInvariant);

    /// @dev Balances in cfmm at last update of GammaPool
    /// @return cfmmReserves - total reserve tokens in cfmm last time GammaPool was updated
    /// @return cfmmInvariant - total liquidity invariant of cfmm last time GammaPool was updated
    /// @return cfmmTotalSupply - total cfmm LP tokens in existence last time GammaPool was updated
    function getCFMMBalances() external view returns(uint128[] memory cfmmReserves, uint256 cfmmInvariant, uint256 cfmmTotalSupply);

    /// @dev Interest rate information in GammaPool at last update
    /// @return accFeeIndex - total accrued interest in GammaPool at last update
    /// @return lastBlockNumber - last block GammaPool was updated
    function getRates() external view returns(uint256 accFeeIndex, uint256 lastBlockNumber);

    /// @return data - struct containing all relevant global state variables and descriptive information of GammaPool. Used to avoid making multiple calls
    function getPoolData() external view returns(PoolData memory data);

    /// @dev Check GammaPool for cfmm and tokens can be created with this implementation
    /// @param _tokens - assumed tokens of cfmm, validate function should check cfmm is indeed for these tokens
    /// @param _cfmm - cfmm GammaPool will be for
    /// @return _tokensOrdered - tokens ordered to match the same order as in cfmm
    /// @return _decimals - decimal places of tokens in cfmm. Their index matches _tokensOrdered.
    function validateCFMM(address[] calldata _tokens, address _cfmm) external view returns(address[] memory _tokensOrdered, uint8[] memory _decimals);

    //Short Gamma

    /// @dev Deposit cfmm LP token and get GS LP token, without doing a transferFrom transaction. Must have sent cfmm LP token first
    /// @param to - address of receiver of GS LP token
    /// @return shares - quantity of GS LP tokens received for cfmm LP tokens
    function depositNoPull(address to) external returns(uint256 shares);

    /// @dev Withdraw cfmm LP token, by burning GS LP token, without doing a transferFrom transaction. Must have sent GS LP token first
    /// @param to - address of receiver of cfmm LP tokens
    /// @return assets - quantity of cfmm LP tokens received for GS LP tokens
    function withdrawNoPull(address to) external returns(uint256 assets);

    /// @dev Withdraw reserve token quantities of cfmm (instead of cfmm LP tokens), by burning GS LP token
    /// @param to - address of receiver of reserve token quantities
    /// @return reserves - quantity of reserve tokens withdrawn from cfmm and sent to receiver
    /// @return assets - quantity of cfmm LP tokens representing reserve tokens withdrawn
    function withdrawReserves(address to) external returns (uint256[] memory reserves, uint256 assets);

    /// @dev Deposit reserve token quantities to cfmm (instead of cfmm LP tokens) to get cfmm LP tokens, store them in GammaPool and receive GS LP tokens
    /// @param to - address of receiver of GS LP tokens
    /// @param amountsDesired - desired amounts of reserve tokens to deposit
    /// @param amountsMin - minimum amounts of reserve tokens to deposit
    /// @param data - information identifying request to deposit
    /// @return reserves - quantity of actual reserve tokens deposited in cfmm
    /// @return shares - quantity of GS LP tokens received for reserve tokens deposited
    function depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external returns(uint256[] memory reserves, uint256 shares);

    //Long Gamma

    /// @return cfmmReserves - latest reserves in the cfmm
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
    /// @return lpTokens - cfmm LP tokens borrowed to create liquidity debt
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

    /// @dev Borrow liquidity from the cfmm and add it to the debt and collateral of loan identified by tokenId
    /// @param tokenId - unique id identifying loan
    /// @param lpTokens - cfmm LP token amount requested to short
    /// @return amounts - reserves quantities withdrawn from cfmm that correspond to the LP tokens shorted, now used as collateral
    function borrowLiquidity(uint256 tokenId, uint256 lpTokens) external returns(uint256[] memory amounts);

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
    /// @return refund - amounts from collateral tokens being refunded to liquidator
    function liquidate(uint256 tokenId, int256[] calldata deltas) external returns(uint256[] memory refund);

    /// @dev Function to liquidate a loan using external LP tokens. Allows partial liquidation
    /// @param tokenId - tokenId of loan being liquidated
    /// @return refund - amounts from collateral tokens being refunded to liquidator
    function liquidateWithLP(uint256 tokenId) external returns(uint256[] memory refund);

    /// @dev Function to liquidate multiple loans in batch.
    /// @param tokenIds - list of tokenIds of loans to liquidate
    /// @return refund - amounts from collateral tokens being refunded to liquidator
    function batchLiquidations(uint256[] calldata tokenIds) external returns(uint256[] memory refund);

    //sync functions

    /// @dev Skim excess collateral tokens or cfmm LP tokens from GammaPool and send them to receiver (`to`) address
    /// @param to - address receiving excess tokens
    function skim(address to) external;

    /// @dev Synchronize LP_TOKEN_BALANCE with actual cfmm LP tokens deposited in GammaPool
    function sync() external;
}
