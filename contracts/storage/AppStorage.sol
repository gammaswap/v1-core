// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

struct Loan {
    uint256 id;

    // 1x256 bits
    address poolId;//160
    uint96 rateIndex;//uint96, max 7.9% trillion

    // 1x256 bits
    uint128 initLiquidity;//uint128
    uint128 liquidity;//uint128

    uint256 lpTokens;//uint256
    uint128[] tokensHeld;//array of uint128
}

struct Storage {
    // 2x256 bits
    uint96 yieldTWAP;
    address cfmm;
    uint96 cumulativeYield;
    address factory;

    // 1x64 bits
    uint32 cumulativeTime;
    uint32 lastBlockTimestamp;

    // LP Tokens
    uint256 LP_TOKEN_BALANCE;//LP Tokens in GS, LP_TOKEN_TOTAL = LP_TOKEN_BALANCE + LP_TOKEN_BORROWED_PLUS_INTEREST (will remove this)
    uint256 LP_TOKEN_BORROWED;//LP Tokens that have been borrowed (Principal)
    uint256 LP_TOKEN_BORROWED_PLUS_INTEREST;//(LP Tokens that have been borrowed (principal) plus interest in LP Tokens)

    // 1x256 bits, Invariants
    uint128 BORROWED_INVARIANT;
    uint128 LP_INVARIANT;//Invariant from LP Tokens, TOTAL_INVARIANT = BORROWED_INVARIANT + LP_INVARIANT

    // 1x256 bits, rates
    uint80 borrowRate;//uint72, max 120% million
    uint80 lastFeeIndex;//uint72, max 120% million
    uint96 accFeeIndex;//uint96, max 7.9% trillion

    // 2x256 bits, CFMM values
    uint48 LAST_BLOCK_NUMBER;//uint48
    uint80 lastCFMMFeeIndex;//uint72, max 120% million
    uint128 lastCFMMInvariant;//uint128
    uint256 lastCFMMTotalSupply;

    /// @dev The ID of the next loan that will be minted. Skips 0
    uint256 nextId;//should be 1

    uint256 unlocked;//should be 1

    // ERC20 fields
    uint256 totalSupply;
    mapping(address => uint256) balanceOf;
    mapping(address => mapping(address => uint256)) allowance;

    /// @dev The token ID position data
    mapping(uint256 => Loan) loans;

    // tokens and balances
    address[] tokens;
    uint128[] TOKEN_BALANCE;
    uint128[] CFMM_RESERVES;
}

contract AppStorage {
    Storage internal s;

    error Locked();
    error Initialized();

    modifier lock() {
        if(s.unlocked != 1)
            revert Locked();
        s.unlocked = 0;
        _;
        s.unlocked = 1;
    }

    function _initialize(address factory, address cfmm, address[] calldata tokens) internal virtual {
        if(s.factory != address(0))
            revert Initialized();

        s.factory = factory;
        s.cfmm = cfmm;
        s.tokens = tokens;

        s.lastFeeIndex = 10**18;
        s.accFeeIndex = 10**18;
        s.LAST_BLOCK_NUMBER = uint48(block.number);
        s.lastCFMMFeeIndex = 10**18;

        s.nextId = 1;
        s.unlocked = 1;

        s.TOKEN_BALANCE = new uint128[](tokens.length);
        s.CFMM_RESERVES = new uint128[](tokens.length);
    }

    function _createLoan(uint256 tokenCount) internal virtual returns(uint256 tokenId) {
        uint256 id = s.nextId++;
        tokenId = uint256(keccak256(abi.encode(msg.sender, address(this), id)));

        s.loans[tokenId] = Loan({
            id: id,
            poolId: address(this),
            rateIndex: s.accFeeIndex,
            initLiquidity: 0,
            liquidity: 0,
            lpTokens: 0,
            tokensHeld: new uint128[](tokenCount)
        });
    }
}
