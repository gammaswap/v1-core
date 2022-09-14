// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./interfaces/IGammaPoolFactory.sol";
import "./interfaces/IGammaPool.sol";
import "./interfaces/strategies/base/IShortStrategy.sol";
import "./interfaces/strategies/base/ILongStrategy.sol";
import "./base/GammaPoolERC4626.sol";

contract GammaPool is IGammaPool, GammaPoolERC4626 {

    modifier lock() {
        GammaPoolStorage.lockit();
        _;
        GammaPoolStorage.unlockit();
    }

    constructor() {
        GammaPoolStorage.init();
        (bytes memory stratParams, bytes memory rateParams) = IProtocol(GammaPoolStorage.store().protocol).parameters();
        (bool success,bytes memory data) = GammaPoolStorage.store().protocol.delegatecall(abi.encodeWithSelector(IProtocol(GammaPoolStorage.store().protocol).initialize.selector, stratParams, rateParams));
        require(success && (data.length == 0 || abi.decode(data, (bool))),"INIT");
    }

    function cfmm() external virtual override view returns(address) {
        return GammaPoolStorage.store().cfmm;
    }

    function protocolId() external virtual override view returns(uint24) {
        return GammaPoolStorage.store().protocolId;
    }

    function protocol() external virtual override view returns(address) {
        return GammaPoolStorage.store().protocol;
    }

    function tokens() external virtual override view returns(address[] memory) {
        return GammaPoolStorage.store().tokens;
    }

    function factory() external virtual override view returns(address) {
        return GammaPoolStorage.store().factory;
    }

    function longStrategy() external virtual override view returns(address) {
        return GammaPoolStorage.store().longStrategy;
    }

    function shortStrategy() external virtual override view returns(address) {
        return GammaPoolStorage.store().shortStrategy;
    }

    //GamamPool Data
    function tokenBalances() external virtual override view returns(uint256[] memory) {
        return GammaPoolStorage.store().TOKEN_BALANCE;
    }

    function lpTokenBalance() external virtual override view returns(uint256) {
        return GammaPoolStorage.store().LP_TOKEN_BALANCE;
    }

    function lpTokenBorrowed() external virtual override view returns(uint256) {
        return GammaPoolStorage.store().LP_TOKEN_BORROWED;
    }

    function lpTokenBorrowedPlusInterest() external virtual override view returns(uint256) {
        return GammaPoolStorage.store().LP_TOKEN_BORROWED_PLUS_INTEREST;//(BORROWED_INVARIANT as LP Tokens)
    }

    function lpTokenTotal() external virtual override view returns(uint256) {
        return GammaPoolStorage.store().LP_TOKEN_TOTAL;//LP_TOKEN_BALANCE + LP_TOKEN_BORROWED_PLUS_INTEREST
    }

    function borrowedInvariant() external virtual override view returns(uint256) {
        return GammaPoolStorage.store().BORROWED_INVARIANT;
    }

    function lpInvariant() external virtual override view returns(uint256) {
        return GammaPoolStorage.store().LP_INVARIANT;//Invariant from LP Tokens
    }

    function totalInvariant() external virtual override view returns(uint256) {
        return GammaPoolStorage.store().TOTAL_INVARIANT;//BORROWED_INVARIANT + LP_INVARIANT
    }

    function cfmmReserves() external virtual override view returns(uint256[] memory) {
        return GammaPoolStorage.store().CFMM_RESERVES;
    }

    function borrowRate() external virtual override view returns(uint256) {
        return GammaPoolStorage.store().borrowRate;
    }

    function accFeeIndex() external virtual override view returns(uint256) {
        return GammaPoolStorage.store().accFeeIndex;
    }

    function lastFeeIndex() external virtual override view returns(uint256) {
        return GammaPoolStorage.store().lastFeeIndex;
    }

    function lastCFMMFeeIndex() external virtual override view returns(uint256) {
        return GammaPoolStorage.store().lastCFMMFeeIndex;
    }

    function lastCFMMInvariant() external virtual override view returns(uint256) {
        return GammaPoolStorage.store().lastCFMMInvariant;
    }

    function lastCFMMTotalSupply() external virtual override view returns(uint256) {
        return GammaPoolStorage.store().lastCFMMTotalSupply;
    }

    function lastBlockNumber() external virtual override view returns(uint256) {
        return GammaPoolStorage.store().LAST_BLOCK_NUMBER;
    }

    /*****SHORT*****/

    /*********ERC4626 Functions Start********/
    function totalAssets() public view virtual override returns(uint256) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        return IShortStrategy(store.shortStrategy).totalAssets(store.cfmm, store.BORROWED_INVARIANT, store.LP_TOKEN_BALANCE,
            store.LP_TOKEN_BORROWED, store.lastCFMMInvariant, store.lastCFMMTotalSupply, store.LAST_BLOCK_NUMBER);
    }

    function deposit(uint256 assets, address receiver) external virtual override returns (uint256 shares) {
        (bool success, bytes memory result) = GammaPoolStorage.store().shortStrategy.delegatecall(abi.encodeWithSelector(
                IShortStrategy(GammaPoolStorage.store().shortStrategy)._deposit.selector, assets, receiver));
        require(success);
        return abi.decode(result, (uint256));
    }

    function mint(uint256 shares, address receiver) external virtual override returns (uint256 assets) {
        (bool success, bytes memory result) = GammaPoolStorage.store().shortStrategy.delegatecall(abi.encodeWithSelector(
                IShortStrategy(GammaPoolStorage.store().shortStrategy)._mint.selector, shares, receiver));
        require(success);
        return abi.decode(result, (uint256));
    }

    function withdraw(uint256 assets, address receiver, address owner) external virtual override returns (uint256 shares){
        (bool success, bytes memory result) = GammaPoolStorage.store().shortStrategy.delegatecall(abi.encodeWithSelector(
                IShortStrategy(GammaPoolStorage.store().shortStrategy)._withdraw.selector, assets, receiver, owner));
        require(success);
        return abi.decode(result, (uint256));
    }

    function redeem(uint256 shares, address receiver, address owner) external virtual override returns (uint256 assets){
        (bool success, bytes memory result) = GammaPoolStorage.store().shortStrategy.delegatecall(abi.encodeWithSelector(
                IShortStrategy(GammaPoolStorage.store().shortStrategy)._redeem.selector, shares, receiver, owner));
        require(success);
        return abi.decode(result, (uint256));
    }

    /*********ERC4626 Functions End********/

    function depositNoPull(address to) external virtual override returns(uint256 shares) {
        (bool success, bytes memory result) = GammaPoolStorage.store().shortStrategy.delegatecall(abi.encodeWithSelector(
                IShortStrategy(GammaPoolStorage.store().shortStrategy)._depositNoPull.selector, to));
        require(success);
        return abi.decode(result, (uint256));
    }

    function withdrawNoPull(address to) external virtual override returns(uint256 assets) {
        (bool success, bytes memory result) = GammaPoolStorage.store().shortStrategy.delegatecall(abi.encodeWithSelector(
                IShortStrategy(GammaPoolStorage.store().shortStrategy)._withdrawNoPull.selector, to));
        require(success);
        return abi.decode(result, (uint256));
    }

    function depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external virtual override returns(uint256[] memory reserves, uint256 shares){
        (bool success, bytes memory result) = GammaPoolStorage.store().shortStrategy.delegatecall(abi.encodeWithSelector(
                IShortStrategy(GammaPoolStorage.store().shortStrategy)._depositReserves.selector, to, amountsDesired, amountsMin, data));
        require(success);
        return abi.decode(result, (uint256[],uint256));
    }

    function withdrawReserves(address to) external virtual override returns (uint256[] memory reserves, uint256 assets) {
        (bool success, bytes memory result) = GammaPoolStorage.store().shortStrategy.delegatecall(abi.encodeWithSelector(
                IShortStrategy(GammaPoolStorage.store().shortStrategy)._withdrawReserves.selector, to));
        require(success);
        return abi.decode(result, (uint256[],uint256));
    }


    /*****LONG*****/
    function createLoan() external virtual override lock returns(uint256 tokenId) {
        tokenId = GammaPoolStorage.createLoan();
        emit LoanCreated(msg.sender, tokenId);
    }

    function loan(uint256 tokenId) external virtual override view returns (uint256 id, address poolId,
        uint256[] memory tokensHeld, uint256 liquidity, uint256 rateIndex, uint256 blockNum) {
        GammaPoolStorage.Loan storage _loan = GammaPoolStorage.store().loans[tokenId];
        return (_loan.id, _loan.poolId, _loan.tokensHeld, _loan.liquidity, _loan.rateIndex, _loan.blockNum);
    }

    function increaseCollateral(uint256 tokenId) external virtual override returns(uint256[] memory tokensHeld) {
        (bool success, bytes memory result) = GammaPoolStorage.store().longStrategy.delegatecall(abi.encodeWithSelector(
                ILongStrategy(GammaPoolStorage.store().longStrategy)._increaseCollateral.selector, tokenId));
        require(success);
        return abi.decode(result, (uint256[]));
    }

    function decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external virtual override returns(uint256[] memory tokensHeld) {
        (bool success, bytes memory result) = GammaPoolStorage.store().longStrategy.delegatecall(abi.encodeWithSelector(
                ILongStrategy(GammaPoolStorage.store().longStrategy)._decreaseCollateral.selector, tokenId, amounts, to));
        require(success);
        return abi.decode(result, (uint256[]));
    }

    function borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual override returns(uint256[] memory amounts) {
        (bool success, bytes memory result) = GammaPoolStorage.store().longStrategy.delegatecall(abi.encodeWithSelector(
                ILongStrategy(GammaPoolStorage.store().longStrategy)._borrowLiquidity.selector, tokenId, lpTokens));
        require(success);
        return abi.decode(result, (uint256[]));
    }

    function repayLiquidity(uint256 tokenId, uint256 liquidity) external virtual override returns(uint256 liquidityPaid, uint256 lpTokensPaid, uint256[] memory amounts) {
        (bool success, bytes memory result) = GammaPoolStorage.store().longStrategy.delegatecall(abi.encodeWithSelector(
                ILongStrategy(GammaPoolStorage.store().longStrategy)._repayLiquidity.selector, tokenId, liquidity));
        require(success);
        return abi.decode(result, (uint256,uint256,uint256[]));
    }

    function rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external virtual override returns(uint256[] memory tokensHeld) {
        (bool success, bytes memory result) = GammaPoolStorage.store().longStrategy.delegatecall(abi.encodeWithSelector(
                ILongStrategy(GammaPoolStorage.store().longStrategy)._rebalanceCollateral.selector, tokenId, deltas));
        require(success);
        return abi.decode(result, (uint256[]));
    }

    function rebalanceCollateralWithLiquidity(uint256 tokenId, uint256 liquidity) external virtual override returns(uint256[] memory tokensHeld) {
        (bool success, bytes memory result) = GammaPoolStorage.store().longStrategy.delegatecall(abi.encodeWithSelector(
                ILongStrategy(GammaPoolStorage.store().longStrategy)._rebalanceCollateralWithLiquidity.selector, tokenId, liquidity));
        require(success);
        return abi.decode(result, (uint256[]));
    }
}
