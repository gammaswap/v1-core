// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

library GammaPoolStorage {
    error Locked();
    error StoreInitialized();

    bytes32 constant STRUCT_POSITION = keccak256("com.gammaswap.gammapool");
    bytes32 constant STRUCT_POSITION_ERC20 = keccak256("com.gammaswap.gammapool.erc20");

    struct Loan {
        address poolId;//160
        uint256 heldLiquidity;//uint128
        uint256 initLiquidity;//uint128
        uint256 liquidity;//uint128
        uint256 rateIndex;//this can be uint96 (7.9 trillion return with 18 decimals)
        uint256 lpTokens;//uint256
        uint256 id;
        uint256[] tokensHeld;//array of uint128
    }

    struct ERC20 {
        //ERC20 fields
        uint256 totalSupply;
        mapping(address => uint256) balanceOf;
        mapping(address => mapping(address => uint256)) allowance;
    }/**/

    struct Store {
        address[] tokens;
        address cfmm;

        uint256[] TOKEN_BALANCE;
        uint256 LP_TOKEN_BALANCE;//LP Tokens in GS, LP_TOKEN_TOTAL = LP_TOKEN_BALANCE + LP_TOKEN_BORROWED_PLUS_INTEREST (will remove this)
        uint256 LP_TOKEN_BORROWED;//LP Tokens that have been borrowed (Principal)
        uint256 LP_TOKEN_BORROWED_PLUS_INTEREST;//(LP Tokens that have been borrowed (principal) plus interest in LP Tokens)
        uint256 BORROWED_INVARIANT;
        uint256 LP_INVARIANT;//Invariant from LP Tokens, TOTAL_INVARIANT = BORROWED_INVARIANT + LP_INVARIANT
        uint256[] CFMM_RESERVES;
        uint256 borrowRate;//uint96, can probably be less
        uint256 accFeeIndex;//uint96
        uint256 lastFeeIndex;//uint96, can probably be less
        uint256 lastCFMMFeeIndex;//uint96, can probably be less
        uint256 lastCFMMInvariant;//uint128
        uint256 lastCFMMTotalSupply;
        uint256 LAST_BLOCK_NUMBER;//uint48

        uint32 cumulativeTime;
        uint256 cumulativeYield;
        uint32 lastBlockTimestamp;
        uint256 yieldTWAP;

        uint256 ONE;

        /// @dev The token ID position data
        mapping(uint256 => Loan) loans;

        //address owner;

        /// @dev The ID of the next loan that will be minted. Skips 0
        uint256 nextId;//should be 1

        uint256 unlocked;//should be 1
    }

    function store() internal pure returns (Store storage _store) {
        bytes32 position = STRUCT_POSITION;
        assembly {
            _store.slot := position
        }
    }

    function erc20() internal pure returns (ERC20 storage _store) {
        bytes32 position = STRUCT_POSITION_ERC20;
        assembly {
            _store.slot := position
        }
    }

    function init(address cfmm, address[] calldata tokens) internal {
        Store storage _store = store();
        if(_store.cfmm != address(0)) {
            revert StoreInitialized();
        }
        _store.cfmm = cfmm;
        _store.tokens = tokens;
        _store.TOKEN_BALANCE = new uint256[](tokens.length);
        _store.CFMM_RESERVES = new uint256[](tokens.length);

        _store.accFeeIndex = 10**18;
        _store.lastFeeIndex = 10**18;
        _store.lastCFMMFeeIndex = 10**18;
        _store.LAST_BLOCK_NUMBER = block.number;
        _store.nextId = 1;
        _store.unlocked = 1;
        _store.ONE = 10**18;
    }

    function lockit() internal {
        Store storage _store = store();
        if(_store.unlocked != 1) {
            revert Locked();
        }
        _store.unlocked = 0;
    }

    function unlockit() internal {
        store().unlocked = 1;
    }

    function createLoan() internal returns(uint256 tokenId) {
        Store storage _store = store();
        uint256 id = _store.nextId++;
        tokenId = uint256(keccak256(abi.encode(msg.sender, address(this), id)));

        _store.loans[tokenId] = Loan({
            id: id,
            poolId: address(this),
            tokensHeld: new uint[](_store.tokens.length),
            heldLiquidity: 0,
            initLiquidity: 0,
            liquidity: 0,
            lpTokens: 0,
            rateIndex: _store.accFeeIndex
        });
    }
}
