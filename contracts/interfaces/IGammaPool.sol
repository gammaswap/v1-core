// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IGammaPool {

    event PoolUpdated(uint256 lpTokenBalance, uint256 lpTokenBorrowed, uint256 lastBlockNumber, uint256 accFeeIndex,
        uint256 lastFeeIndex, uint256 lpTokenBorrowedPlusInterest, uint256 lpInvariant, uint256 lpBorrowedInvariant);
    event LoanCreated(address indexed caller, uint256 tokenId);
    event LoanUpdated(uint256 indexed tokenId, uint256[] tokensHeld, uint256 heldLiquidity, uint256 liquidity, uint256 lpTokens, uint256 rateIndex);

    function cfmm() external view returns(address);
    function protocolId() external view returns(uint24);
    function protocol() external view returns(address);
    function tokens() external view returns(address[] memory);

    function factory() external view returns(address);
    function longStrategy() external view returns(address);
    function shortStrategy() external view returns(address);
    function tokenBalances() external view returns(uint256[] memory);
    function lpTokenBalance() external view returns(uint256);
    function lpTokenBorrowed() external view returns(uint256);
    function lpTokenBorrowedPlusInterest() external view returns(uint256);
    function lpTokenTotal() external view returns(uint256);
    function borrowedInvariant() external view returns(uint256);
    function lpInvariant() external view returns(uint256);
    function totalInvariant() external view returns(uint256);
    function cfmmReserves() external view returns(uint256[] memory);
    function borrowRate() external view returns(uint256);
    function accFeeIndex() external view returns(uint256);
    function lastFeeIndex() external view returns(uint256);
    function lastCFMMFeeIndex() external view returns(uint256);
    function lastCFMMInvariant() external view returns(uint256);
    function lastCFMMTotalSupply() external view returns(uint256);
    function lastBlockNumber() external view returns(uint256);

    //Short Gamma
    function depositNoPull(address to) external returns(uint256 shares);
    function withdrawNoPull(address to) external returns(uint256 assets);
    function withdrawReserves(address to) external returns (uint256[] memory reserves, uint256 assets);
    function depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external returns(uint256[] memory reserves, uint256 shares);

    //Long Gamma
    function getCFMMPrice() external view returns(uint256 price);
    function createLoan() external returns(uint tokenId);
    function loan(uint256 tokenId) external view returns (uint256 id, address poolId, uint256[] memory tokensHeld, uint256 initLiquidity, uint256 liquidity, uint256 lpTokens, uint256 rateIndex);
    function increaseCollateral(uint256 tokenId) external returns(uint256[] memory tokensHeld);
    function decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external returns(uint256[] memory tokensHeld);
    function borrowLiquidity(uint256 tokenId, uint256 lpTokens) external returns(uint256[] memory amounts);
    function repayLiquidity(uint256 tokenId, uint256 liquidity) external returns(uint256 liquidityPaid, uint256[] memory amounts);
    function rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external returns(uint256[] memory tokensHeld);
}
