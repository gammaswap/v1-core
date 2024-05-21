// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../interfaces/observer/ILoanObserverStore.sol";
import "../interfaces/IGammaPoolFactory.sol";

/// @title Library containing global storage variables for GammaPools according to App Storage pattern
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
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

        /// @dev price at which loan was opened
        uint256 px;

        /// @dev reference address holding additional collateral information for the loan
        address refAddr;
        /// @dev reference fee, typically used for loans using a collateral reference addresses
        uint16 refFee;
        /// @dev reference type, typically used for loans using a collateral reference addresses
        uint8 refType;
    }

    /// @dev Storage struct used to track GammaPool's state variables
    /// @notice `LP_TOKEN_TOTAL = LP_TOKEN_BALANCE + LP_TOKEN_BORROWED_PLUS_INTEREST` and `TOTAL_INVARIANT = BORROWED_INVARIANT + LP_INVARIANT`
    struct Storage {
        // 1x256 bits
        /// @dev factory - address of factory contract that instantiated this GammaPool
        address factory; // 160 bits
        /// @dev Protocol id of the implementation contract for this GammaPool
        uint16 protocolId; // 16 bits
        /// @dev unlocked - flag used in mutex implementation (1 = unlocked, 0 = locked). Initialized at 1
        uint8 unlocked; // 8 bits
        /// @dev EMA of utilization rate
        uint32 emaUtilRate; // 32 bits, 6 decimal number
        /// @dev Multiplier of EMA used to calculate emaUtilRate
        uint8 emaMultiplier; // 8 bits, 1 decimals (0 = 0%, 1 = 0.1%, max 255 = 25.5%)
        /// @dev Minimum utilization rate at which point we start using the dynamic fee
        uint8 minUtilRate1; // 8 bits, 0 decimals (0 = 0%, 100 = 100%), default is 85. If set to 100, dynamic orig fee is disabled
        /// @dev Minimum utilization rate at which point we start using the dynamic fee
        uint8 minUtilRate2; // 8 bits, 0 decimals (0 = 0%, 100 = 100%), default is 65. If set to 100, dynamic orig fee is disabled
        /// @dev Dynamic origination fee divisor, to cap at 99% use 16384 = 2^(99-85)
        uint16 feeDivisor; // 16 bits, 0 decimals, max is 5 digit integer 65535, formula is 2^(maxUtilRate - minUtilRate1)

        // 3x256 bits, LP Tokens
        /// @dev Quantity of CFMM's LP tokens deposited in GammaPool by liquidity providers
        uint256 LP_TOKEN_BALANCE;
        /// @dev Quantity of CFMM's LP tokens that have been borrowed by liquidity borrowers excluding accrued interest (principal)
        uint256 LP_TOKEN_BORROWED;
        /// @dev Quantity of CFMM's LP tokens that have been borrowed by liquidity borrowers including accrued interest
        uint256 LP_TOKEN_BORROWED_PLUS_INTEREST;

        // 1x256 bits, Invariants
        /// @dev Quantity of CFMM's liquidity invariant that has been borrowed including accrued interest, maps to LP_TOKEN_BORROWED_PLUS_INTEREST
        uint128 BORROWED_INVARIANT; // 128 bits
        /// @dev Quantity of CFMM's liquidity invariant held in GammaPool as LP tokens, maps to LP_TOKEN_BALANCE
        uint128 LP_INVARIANT; // 128 bits

        // 3x256 bits, Rates & CFMM
        /// @dev cfmm - address of CFMM this GammaPool is for
        address cfmm; // 160 bits
        /// @dev GammaPool's ever increasing interest rate index, tracks interest accrued through CFMM and liquidity loans, max 120.8% million
        uint80 accFeeIndex; // 80 bits
        /// @dev GammaPool's Margin threshold (1 - 255 => 0.1% to 25.5%) LTV = 1 - ltvThreshold
        uint8 ltvThreshold; // 8 bits
        /// @dev GammaPool's liquidation fee in basis points (1 - 255 => 0.01% to 2.55%)
        uint8 liquidationFee; // 8 bits
        /// @dev External swap fee in basis points, max 255 basis points = 2.55%
        uint8 extSwapFee; // 8 bits
        /// @dev Loan opening origination fee in basis points
        uint16 origFee; // 16 bits
        /// @dev LAST_BLOCK_NUMBER - last block an update to the GammaPool's global storage variables happened
        uint40 LAST_BLOCK_NUMBER; // 40 bits
        /// @dev Percent accrual in CFMM invariant since last update in a different block, max 1,844.67%
        uint64 lastCFMMFeeIndex; // 64 bits
        /// @dev Total liquidity invariant amount in CFMM (from GammaPool and others), read in last update to GammaPool's storage variables
        uint128 lastCFMMInvariant; // 128 bits
        /// @dev Total LP token supply from CFMM (belonging to GammaPool and others), read in last update to GammaPool's storage variables
        uint256 lastCFMMTotalSupply;

        /// @dev The ID of the next loan that will be minted. Initialized at 1
        uint256 nextId;

        /// @dev Function IDs so that we can pause individual functions
        uint256 funcIds;

        // ERC20 fields
        /// @dev Total supply of GammaPool's own ERC20 token representing the liquidity of depositors to the CFMM through the GammaPool
        uint256 totalSupply;
        /// @dev Balance of GammaPool's ERC20 token, this is used to keep track of the balances of different addresses as defined in the ERC20 standard
        mapping(address => uint256) balanceOf;
        /// @dev Spending allowance of GammaPool's ERC20 token, this is used to keep track of the spending allowance of different addresses as defined in the ERC20 standard
        mapping(address => mapping(address => uint256)) allowance;

        /// @dev Mapping of all loans issued by the GammaPool, the key is the tokenId (unique identifier) of the loan
        mapping(uint256 => Loan) loans;

        /// @dev Minimum liquidity that can be borrowed or remain for a loan
        uint72 minBorrow;

        // tokens and balances
        /// @dev ERC20 tokens of CFMM
        address[] tokens;
        /// @dev Decimals of tokens in CFMM, indices match tokens[] array
        uint8[] decimals;
        /// @dev Amounts of ERC20 tokens from the CFMM held as collateral in the GammaPool. Equals to the sum of all tokensHeld[] quantities in all loans
        uint128[] TOKEN_BALANCE;
        /// @dev Amounts of ERC20 tokens from the CFMM held in the CFMM as reserve quantities. Used to log prices quoted by the CFMM during updates to the GammaPool
        uint128[] CFMM_RESERVES;
        /// @dev List of all tokenIds created in GammaPool
        uint256[] tokenIds;

        // Custom parameters
        /// @dev Custom fields
        mapping(uint256 => bytes32) fields;
        /// @dev Custom object (e.g. struct)
        bytes obj;
    }

    error Initialized();

    /// @dev Initializes global storage variables of GammaPool, must be called right after instantiating GammaPool
    /// @param self - pointer to storage variables (doesn't need to be passed)
    /// @param _factory - address of factory that created this GammaPool
    /// @param _cfmm - address of CFMM this GammaPool is for
    /// @param _protocolId - protocol id of the implementation contract for this GammaPool
    /// @param _tokens - tokens of CFMM this GammaPool is for
    /// @param _decimals -decimals of the tokens of the CFMM the GammaPool is for, indices must match tokens array
    /// @param _minBorrow - minimum amount of liquidity that can be borrowed or left unpaid in a loan
    function initialize(Storage storage self, address _factory, address _cfmm, uint16 _protocolId, address[] calldata _tokens, uint8[] calldata _decimals, uint72 _minBorrow) internal {
        if(self.factory != address(0)) revert Initialized();// cannot initialize twice

        self.factory = _factory;
        self.protocolId = _protocolId;
        self.cfmm = _cfmm;
        self.tokens = _tokens;
        self.decimals = _decimals;
        self.minBorrow =_minBorrow;

        self.lastCFMMFeeIndex = 1e18;
        self.accFeeIndex = 1e18; // initialized as 1 with 18 decimal places
        self.LAST_BLOCK_NUMBER = uint40(block.number); // first block update number is block at initialization

        self.nextId = 1; // loan counter starts at 1
        self.unlocked = 1; // mutex initialized as unlocked

        self.ltvThreshold = 5; // 50 basis points
        self.liquidationFee = 25; // 25 basis points
        self.origFee = 2;
        self.extSwapFee = 10;

        self.emaMultiplier = 10; // ema smoothing factor is 10/1000 = 1%
        self.minUtilRate1 = 92; // min util rate 1 is 92%
        self.minUtilRate2 = 80; // min util rate 2 is 80%
        self.feeDivisor = 2048; // 25% orig fee at 99% util rate

        self.TOKEN_BALANCE = new uint128[](_tokens.length);
        self.CFMM_RESERVES = new uint128[](_tokens.length);
    }

    /// @dev Creates an empty loan struct in the GammaPool and initializes it to start tracking borrowed liquidity
    /// @param self - pointer to storage variables (doesn't need to be passed)
    /// @param _tokenCount - number of tokens in the CFMM the loan is for
    /// @param refId - reference id of CollateralManager set up in CollateralReferenceStore (e.g. GammaPoolFactory)
    /// @return _tokenId - unique tokenId used to get and update loan
    function createLoan(Storage storage self, uint256 _tokenCount, uint16 refId) internal returns(uint256 _tokenId) {
        // get loan counter for GammaPool and increase it by 1 for the next loan
        uint256 id = self.nextId++;

        // create unique tokenId to identify loan across all GammaPools. _tokenId is hash of GammaPool address, sender address, and loan counter
        _tokenId = uint256(keccak256(abi.encode(msg.sender, address(this), id)));

        address refAddr;
        uint16 refFee;
        uint8 refType;
        if(refId > 0 ) {
            (refAddr, refFee, refType) = ILoanObserverStore(self.factory).getPoolObserverByUser(refId, address(this), msg.sender);
        }

        // instantiate Loan struct and store it mapped to _tokenId
        self.loans[_tokenId] = Loan({
            id: id, // loan counter
            poolId: address(this), // GammaPool address loan belongs to
            rateIndex: self.accFeeIndex, // initialized as current interest rate index
            initLiquidity: 0,
            liquidity: 0,
            lpTokens: 0,
            tokensHeld: new uint128[](_tokenCount),
            px: 0,
            refAddr: refAddr,
            refFee: refFee,
            refType: refType
        });

        self.tokenIds.push(_tokenId);
    }

    /// @dev Get custom field as uint256
    /// @param self - pointer to storage variables (doesn't need to be passed)
    /// @param idx - index of mapping of uint256 field
    /// @return field - value of custom field from storage as uint256
    function getUint256(Storage storage self, uint256 idx) internal view returns(uint256) {
        return uint256(self.fields[idx]);
    }

    /// @dev Set custom field as uint256
    /// @param self - pointer to storage variables (doesn't need to be passed)
    /// @param idx - index of mapping of uint256 field
    /// @param val - value of custom field to store in storage as uint256
    function setUint256(Storage storage self, uint256 idx, uint256 val) internal {
        self.fields[idx] = bytes32(val);
    }

    /// @dev Get custom field as int256
    /// @param self - pointer to storage variables (doesn't need to be passed)
    /// @param idx - index of mapping of int256 field
    /// @return field - value of custom field from storage as int256
    function getInt256(Storage storage self, uint256 idx) internal view returns(int256) {
        return int256(uint256(self.fields[idx]));
    }

    /// @dev Set custom field as int256
    /// @param self - pointer to storage variables (doesn't need to be passed)
    /// @param idx - index of mapping of int256 field
    /// @param val - value of custom field to store in storage as int256
    function setInt256(Storage storage self, uint256 idx, int256 val) internal {
        self.fields[idx] = bytes32(uint256(val));
    }

    /// @dev Get custom field as bytes32
    /// @param self - pointer to storage variables (doesn't need to be passed)
    /// @param idx - index of mapping of bytes32 field
    /// @return field - value of custom field from storage as bytes32
    function getBytes32(Storage storage self, uint256 idx) internal view returns(bytes32) {
        return self.fields[idx];
    }

    /// @dev Set custom field as bytes32
    /// @param self - pointer to storage variables (doesn't need to be passed)
    /// @param idx - index of mapping of bytes32 field
    /// @param val - value of custom field to store in storage as bytes32
    function setBytes32(Storage storage self, uint256 idx, bytes32 val) internal {
        self.fields[idx] = val;
    }

    /// @dev Get custom field as address
    /// @param self - pointer to storage variables (doesn't need to be passed)
    /// @param idx - index of mapping of address field
    /// @return field - value of custom field from storage as address
    function getAddress(Storage storage self, uint256 idx) internal view returns(address) {
        return address(uint160(uint256(self.fields[idx])));
    }

    /// @dev Set custom field as address
    /// @param self - pointer to storage variables (doesn't need to be passed)
    /// @param idx - index of mapping of address field
    /// @param val - value of custom field to store in storage as address
    function setAddress(Storage storage self, uint256 idx, address val) internal {
        self.fields[idx] = bytes32(uint256(uint160(val)));
    }
}
