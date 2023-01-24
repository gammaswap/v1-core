// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

/// @title Library containing global storage variables for GammaPools according to App Storage pattern
/// @author Daniel D. Alcarraz
/// @dev Structs are packed to minimize storage size
library LibStorage {

    /// @dev Loan struct used to track relevant liquidity loan information
    struct Loan {
        /// @dev Loan counter, used to generate unique tokenId which indentifies the loan in the GammaPool
        uint256 id;

        // 1x256 bits
        /// @dev GammaPool address loan belongs to
        address poolId; // 160 bits
        /// @dev Index of GammaPool interest rate at time loan is created/updated, max 7.9% trillion
        uint96 rateIndex; // 96 bits

        // 1x256 bits
        /// @dev Initial loan debt in liquidity invariant units. Only increase when more liquidity is borrowed, decreases when liquidity is paid
        uint128 initLiquidity; // 128 bits
        /// @dev Loan debt in liquidity invariant units, increases with every update according to how many blocks have passed
        uint128 liquidity; // 128 bits

        /// @dev Initial loan debt in terms of LP tokens at time liquidity was borrowed, updates along with initLiquidity
        uint256 lpTokens;
        /// @dev Reserve tokens held as collateral for the liquidity debt, indices match GammaPool's tokens[] array indices
        uint128[] tokensHeld; // array of 128 bit numbers
    }

    /// @dev Storage struct used to track GammaPool's state variables
    /// @notice `LP_TOKEN_TOTAL = LP_TOKEN_BALANCE + LP_TOKEN_BORROWED_PLUS_INTEREST` and `TOTAL_INVARIANT = BORROWED_INVARIANT + LP_INVARIANT`
    struct Storage {
        // 2x256 bits
        /// @dev cfmm - address of cfmm this GammaPool is for
        address cfmm; // 160 bits
        /// @dev LAST_BLOCK_NUMBER - last block an update to the GammaPool's global storage variables happened
        uint96 LAST_BLOCK_NUMBER; // 96 bits
        /// @dev factory - address of factory contract that instantiated this GammaPool
        address factory; // 160 bits
        /// @dev unlocked - flag used in mutex implementation (1 = unlocked, 0 = locked). Initialized at 1
        uint96 unlocked; // 96 bits

        //3x256 bits, LP Tokens
        /// @dev Quantity of cfmm's LP tokens deposited in GammaPool by liquidity providers
        uint256 LP_TOKEN_BALANCE;
        /// @dev Quantity of cfmm's LP tokens that have been borrowed by liquidity borrowers excluding accrued interest (principal)
        uint256 LP_TOKEN_BORROWED;
        /// @dev Quantity of cfmm's LP tokens that have been borrowed by liquidity borrowers including accrued interest
        uint256 LP_TOKEN_BORROWED_PLUS_INTEREST;

        // 1x256 bits, Invariants
        /// @dev Quantity of cfmm's liquidity invariant that has been borrowed including accrued interest, maps to LP_TOKEN_BORROWED_PLUS_INTEREST
        uint128 BORROWED_INVARIANT; // 128 bits
        /// @dev Quantity of cfmm's liquidity invariant held in GammaPool as LP tokens, maps to LP_TOKEN_BALANCE
        uint128 LP_INVARIANT; // 128 bits

        // 2x256 bits, Rates
        /// @dev GammaPool's ever increasing interest rate index, tracks interest accrued through cfmm and liquidity loans, max 7.9% trillion
        uint96 accFeeIndex; // 96 bits
        /// @dev Total liquidity invariant amount in cfmm (from GammaPool and others), read in last update to GammaPool's storage variables
        uint128 lastCFMMInvariant; // 128 bits
        /// @dev Total LP token supply from cfmm (belonging to GammaPool and others), read in last update to GammaPool's storage variables
        uint256 lastCFMMTotalSupply;

        /// @dev The ID of the next loan that will be minted. Initialized at 1
        uint256 nextId;

        // ERC20 fields
        /// @dev Total supply of GammaPool's own ERC20 token representing the liquidity of depositors to the cfmm through the GammaPool
        uint256 totalSupply;
        /// @dev Balance of GammaPool's ERC20 token, this is used to keep track of the balances of different addresses as defined in the ERC20 standard
        mapping(address => uint256) balanceOf;
        /// @dev Spending allowance of GammaPool's ERC20 token, this is used to keep track of the spending allowance of different addresses as defined in the ERC20 standard
        mapping(address => mapping(address => uint256)) allowance;

        /// @dev Mapping of all loans issued by the GammaPool, the key is the tokenId (unique identifier) of the loan
        mapping(uint256 => Loan) loans;

        // tokens and balances
        /// @dev ERC20 tokens of cfmm
        address[] tokens;
        /// @dev Decimals of cfmm tokens, indices match tokens[] array
        uint8[] decimals;
        /// @dev Amounts of ERC20 tokens from the cfmm held as collateral in the GammaPool. Equals to the sum of all tokensHeld[] quantities in all loans
        uint128[] TOKEN_BALANCE;
        /// @dev Amounts of ERC20 tokens from the cfmm held in the cfmm as reserve quantities. Used to log prices in the cfmm during updates to the GammaPool
        uint128[] CFMM_RESERVES;
    }

    error Initialized();

    /// @dev Initializes global storage variables of GammaPool, must be called right after instantiating GammaPool
    /// @param self - pointer to storage variables (doesn't need to be passed)
    /// @param _factory - address of factory that created this GammaPool
    /// @param _cfmm - address of cfmm this GammaPool is for
    /// @param _tokens - tokens of cfmm this GammaPool is for
    /// @param _decimals -decimals of the tokens of the cfmm the GammaPool is for, indices must match tokens array
    function initialize(Storage storage self, address _factory, address _cfmm, address[] calldata _tokens, uint8[] calldata _decimals) internal {
        if(self.factory != address(0)) // cannot initialize twice
            revert Initialized();

        self.factory = _factory;
        self.cfmm = _cfmm;
        self.tokens = _tokens;
        self.decimals = _decimals;

        self.accFeeIndex = 1e18; // initialized as 1 with 18 decimal places
        self.LAST_BLOCK_NUMBER = uint96(block.number); // first block update number is block at initialization

        self.nextId = 1; // loan counter starts at 1
        self.unlocked = 1; // mutex initialized as unlocked

        self.TOKEN_BALANCE = new uint128[](_tokens.length);
        self.CFMM_RESERVES = new uint128[](_tokens.length);
    }

    /// @dev Creates an empty loan struct in the GammaPool and initializes it to start tracking borrowed liquidity
    /// @param self - pointer to storage variables (doesn't need to be passed)
    /// @param _tokenCount - number of tokens in the cfmm the loan is for
    /// @return _tokenId - unique tokenId used to get and update loan
    function createLoan(Storage storage self, uint256 _tokenCount) internal returns(uint256 _tokenId) {
        // get loan counter for GammaPool and increase it by 1 for the next loan
        uint256 id = self.nextId++;

        // create unique tokenId to identify loan across all GammaPools. _tokenId is hash of GammaPool address, sender address, and loan counter
        _tokenId = uint256(keccak256(abi.encode(msg.sender, address(this), id)));

        // instantiate Loan struct and store it mapped to _tokenId
        self.loans[_tokenId] = Loan({
            id: id, // loan counter
            poolId: address(this), // GammaPool address loan belongs to
            rateIndex: self.accFeeIndex, // initialized as current interest rate index
            initLiquidity: 0,
            liquidity: 0,
            lpTokens: 0,
            tokensHeld: new uint128[](_tokenCount)
        });
    }
}
