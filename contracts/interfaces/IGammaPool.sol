// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

interface IGammaPool {

    event PoolUpdated(uint256 lpTokenBalance, uint256 lpTokenBorrowed, uint256 lastBlockNumber, uint256 accFeeIndex,
        uint256 lastFeeIndex, uint256 lpTokenBorrowedPlusInterest, uint256 lpInvariant, uint256 lpBorrowedInvariant);
    event LoanCreated(address indexed caller, uint256 tokenId);
    event LoanUpdated(uint256 indexed tokenId, uint128[] tokensHeld, uint256 liquidity, uint256 lpTokens, uint256 rateIndex);

    function initialize(address cfmm, address[] calldata tokens) external;

    function cfmm() external view returns(address);
    function protocolId() external view returns(uint16);
    function tokens() external view returns(address[] memory);
    function factory() external view returns(address);
    function longStrategy() external view returns(address);
    function shortStrategy() external view returns(address);

    function getPoolBalances() external virtual view returns(uint128[] memory tokenBalances, uint256 lpTokenBalance, uint256 lpTokenBorrowed,
        uint256 lpTokenBorrowedPlusInterest, uint256 borrowedInvariant, uint256 lpInvariant);
    function getCFMMBalances() external virtual view returns(uint128[] memory cfmmReserves, uint256 cfmmInvariant, uint256 cfmmTotalSupply);
    function getRates() external virtual view returns(uint256 borrowRate, uint256 accFeeIndex, uint256 lastFeeIndex, uint256 lastCFMMFeeIndex, uint256 lastBlockNumber);

    function validateCFMM(address[] calldata _tokens, address _cfmm) external view returns(address[] memory tokens);

    //Short Gamma
    function depositNoPull(address to) external returns(uint256 shares);
    function withdrawNoPull(address to) external returns(uint256 assets);
    function withdrawReserves(address to) external returns (uint128[] memory reserves, uint256 assets);
    function depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external returns(uint128[] memory reserves, uint256 shares);

    //Long Gamma
    function liquidate(uint256 tokenId, bool isRebalance, int256[] calldata deltas) external virtual returns(uint128[] memory refund);
    function liquidateWithLP(uint256 tokenId) external virtual returns(uint128[] memory refund);
    function getCFMMPrice() external view returns(uint256 price);
    function createLoan() external returns(uint tokenId);
    function loan(uint256 tokenId) external view returns (uint256 id, address poolId, uint128[] memory tokensHeld, uint256 initLiquidity, uint256 liquidity, uint256 lpTokens, uint256 rateIndex);
    function increaseCollateral(uint256 tokenId) external returns(uint128[] memory tokensHeld);
    function decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external returns(uint128[] memory tokensHeld);
    function borrowLiquidity(uint256 tokenId, uint256 lpTokens) external returns(uint128[] memory amounts);
    function repayLiquidity(uint256 tokenId, uint256 liquidity) external returns(uint256 liquidityPaid, uint128[] memory amounts);
    function rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external returns(uint128[] memory tokensHeld);
}
