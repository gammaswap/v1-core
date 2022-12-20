// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

library LibStorage {
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
        address cfmm;
        uint96 LAST_BLOCK_NUMBER;//uint96
        address factory;
        uint96 unlocked;//should be 1

        // LP Tokens
        uint256 LP_TOKEN_BALANCE;//LP Tokens in GS, LP_TOKEN_TOTAL = LP_TOKEN_BALANCE + LP_TOKEN_BORROWED_PLUS_INTEREST
        uint256 LP_TOKEN_BORROWED;//LP Tokens that have been borrowed (Principal)
        uint256 LP_TOKEN_BORROWED_PLUS_INTEREST;//LP Tokens that have been borrowed (principal) plus interest in LP Tokens

        // 1x256 bits, Invariants
        uint128 BORROWED_INVARIANT;
        uint128 LP_INVARIANT;//Invariant from LP Tokens, TOTAL_INVARIANT = BORROWED_INVARIANT + LP_INVARIANT

        // 2x256 bits, rates
        uint96 accFeeIndex;//uint96, max 7.9% trillion
        uint128 lastCFMMInvariant;//uint128
        uint256 lastCFMMTotalSupply;

        /// @dev The ID of the next loan that will be minted. Skips 0
        uint256 nextId;//should be 1

        // ERC20 fields
        uint256 totalSupply;
        uint8[] decimals;
        mapping(address => uint256) balanceOf;
        mapping(address => mapping(address => uint256)) allowance;

        /// @dev The token ID position data
        mapping(uint256 => Loan) loans;


        // tokens and balances
        address[] tokens;
        uint128[] TOKEN_BALANCE;
        uint128[] CFMM_RESERVES; //keeps track of price of CFMM at time of update
    }

    error Initialized();

    function initialize(Storage storage self, address factory, address cfmm, address[] calldata tokens, uint8[] calldata decimals) internal {
        if(self.factory != address(0))
            revert Initialized();

        self.factory = factory;
        self.cfmm = cfmm;
        self.tokens = tokens;
        self.decimals = decimals;

        self.accFeeIndex = 10**18;
        self.LAST_BLOCK_NUMBER = uint96(block.number);

        self.nextId = 1;
        self.unlocked = 1;

        self.TOKEN_BALANCE = new uint128[](tokens.length);
        self.CFMM_RESERVES = new uint128[](tokens.length);
    }

    function createLoan(Storage storage self, uint256 tokenCount) internal returns(uint256 tokenId) {
        uint256 id = self.nextId++;
        tokenId = uint256(keccak256(abi.encode(msg.sender, address(this), id)));

        self.loans[tokenId] = Loan({
            id: id,
            poolId: address(this),
            rateIndex: self.accFeeIndex,
            initLiquidity: 0,
            liquidity: 0,
            lpTokens: 0,
            tokensHeld: new uint128[](tokenCount)
        });
    }
}
