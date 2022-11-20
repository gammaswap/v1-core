// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

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

struct Storage {
    address[] tokens;
    address cfmm;
    address factory;

    //ERC20 fields
    uint256 totalSupply;
    mapping(address => uint256) balanceOf;
    mapping(address => mapping(address => uint256)) allowance;

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

contract AppStorage {
    Storage internal s;

    error Locked();

    modifier lock() {
        if(s.unlocked != 1)
            revert Locked();
        s.unlocked = 0;
        _;
        s.unlocked = 1;
    }
}