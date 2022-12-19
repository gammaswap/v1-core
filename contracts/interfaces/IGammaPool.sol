// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

interface IGammaPool {

    event PoolUpdated(uint256 lpTokenBalance, uint256 lpTokenBorrowed, uint256 lastBlockNumber, uint256 accFeeIndex,
        uint256 lastFeeIndex, uint256 lpTokenBorrowedPlusInterest, uint256 lpInvariant, uint256 lpBorrowedInvariant);
    event LoanCreated(address indexed caller, uint256 tokenId);
    event LoanUpdated(uint256 indexed tokenId, uint128[] tokensHeld, uint256 liquidity, uint256 lpTokens, uint256 rateIndex);

    struct PoolData {
        uint16 protocolId;
        address longStrategy;
        address shortStrategy;
        address liquidationStrategy;

        address cfmm;
        uint96 LAST_BLOCK_NUMBER;//uint96
        address factory;

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

        // ERC20 fields
        uint256 totalSupply;

        // tokens and balances
        address[] tokens;
        uint128[] TOKEN_BALANCE;
        uint128[] CFMM_RESERVES; //keeps track of price of CFMM at time of update
    }

    function initialize(address cfmm, address[] calldata tokens) external;

    function cfmm() external view returns(address);
    function protocolId() external view returns(uint16);
    function tokens() external view returns(address[] memory);
    function factory() external view returns(address);
    function longStrategy() external view returns(address);
    function shortStrategy() external view returns(address);
    function liquidationStrategy() external view returns(address);

    function getPoolBalances() external virtual view returns(uint128[] memory tokenBalances, uint256 lpTokenBalance, uint256 lpTokenBorrowed,
        uint256 lpTokenBorrowedPlusInterest, uint256 borrowedInvariant, uint256 lpInvariant);
    function getCFMMBalances() external virtual view returns(uint128[] memory cfmmReserves, uint256 cfmmInvariant, uint256 cfmmTotalSupply);
    function getRates() external virtual view returns(uint256 accFeeIndex, uint256 lastBlockNumber);
    function getPoolData() external virtual view returns(PoolData memory data);

    function validateCFMM(address[] calldata _tokens, address _cfmm) external view returns(address[] memory tokens);

    //Short Gamma
    function depositNoPull(address to) external returns(uint256 shares);
    function withdrawNoPull(address to) external returns(uint256 assets);
    function withdrawReserves(address to) external returns (uint256[] memory reserves, uint256 assets);
    function depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external returns(uint256[] memory reserves, uint256 shares);

    //Long Gamma
    function getCFMMPrice() external view returns(uint256 price);
    function createLoan() external returns(uint tokenId);
    function loan(uint256 tokenId) external view returns (uint256 id, address poolId, uint128[] memory tokensHeld, uint256 initLiquidity, uint256 liquidity, uint256 lpTokens, uint256 rateIndex);
    function increaseCollateral(uint256 tokenId) external returns(uint128[] memory tokensHeld);
    function decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external returns(uint128[] memory tokensHeld);
    function borrowLiquidity(uint256 tokenId, uint256 lpTokens) external returns(uint256[] memory amounts);
    function repayLiquidity(uint256 tokenId, uint256 liquidity) external returns(uint256 liquidityPaid, uint256[] memory amounts);
    function rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external returns(uint128[] memory tokensHeld);
    function liquidate(uint256 tokenId, bool isRebalance, int256[] calldata deltas) external virtual returns(uint256[] memory refund);
    function liquidateWithLP(uint256 tokenId) external virtual returns(uint256[] memory refund);
    function batchLiquidations(uint256[] calldata tokenIds) external virtual returns(uint256[] memory refund);
}
