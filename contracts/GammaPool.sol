// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./interfaces/IGammaPool.sol";
import "./interfaces/IProtocol.sol";
import "./interfaces/strategies/base/ILongStrategy.sol";
import "./base/GammaPoolERC4626.sol";

contract GammaPool is IGammaPool, GammaPoolERC4626 {

    modifier lock() {
        GammaPoolStorage.lockit();
        _;
        GammaPoolStorage.unlockit();
    }

    constructor() {
    }

    function initialize(InitializeParameters calldata params) external virtual override {
        GammaPoolStorage.init(params.cfmm, params.protocolId, params.protocol, params.tokens, params.longStrategy, params.shortStrategy);
        (bool success,bytes memory data) = params.protocol.delegatecall(abi.encodeWithSelector(IProtocol(params.protocol).initialize.selector, params.stratParams, params.rateParams));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
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
    function getPoolBalances() external virtual override view returns(uint256[] memory tokenBalances, uint256 lpTokenBalance, uint256 lpTokenBorrowed,
        uint256 lpTokenBorrowedPlusInterest, uint256 lpTokenTotal, uint256 borrowedInvariant, uint256 lpInvariant, uint256 totalInvariant){
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        return(store.TOKEN_BALANCE, store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.LP_TOKEN_TOTAL, store.BORROWED_INVARIANT, store.LP_INVARIANT, store.TOTAL_INVARIANT);
    }

    function getCFMMBalances() external virtual override view returns(uint256[] memory cfmmReserves, uint256 cfmmInvariant, uint256 cfmmTotalSupply) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        return(store.CFMM_RESERVES, store.lastCFMMInvariant, store.lastCFMMTotalSupply);
    }

    function getRates() external virtual override view returns(uint256 borrowRate, uint256 accFeeIndex, uint256 lastFeeIndex, uint256 lastCFMMFeeIndex, uint256 lastBlockNumber) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        return(store.borrowRate, store.accFeeIndex, store.lastFeeIndex, store.lastCFMMFeeIndex, store.LAST_BLOCK_NUMBER);
    }

    /*****SHORT*****/
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

    function liquidate(uint256 tokenId, bool isRebalance, int256[] calldata deltas) external override virtual returns(uint256[] memory refund) {
        (bool success, bytes memory result) = GammaPoolStorage.store().longStrategy.delegatecall(abi.encodeWithSelector(
                ILongStrategy(GammaPoolStorage.store().longStrategy)._liquidate.selector, tokenId, isRebalance, deltas));
        require(success);
        return abi.decode(result, (uint256[]));
    }

    function liquidateWithLP(uint256 tokenId) external override virtual returns(uint256[] memory refund) {
        (bool success, bytes memory result) = GammaPoolStorage.store().longStrategy.delegatecall(abi.encodeWithSelector(
                ILongStrategy(GammaPoolStorage.store().longStrategy)._liquidateWithLP.selector, tokenId));
        require(success);
        return abi.decode(result, (uint256[]));
    }

    function getCFMMPrice() external virtual override view returns(uint256 price) {
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        return ILongStrategy(store.longStrategy)._getCFMMPrice(store.cfmm, store.ONE);
    }

    function createLoan() external virtual override lock returns(uint256 tokenId) {
        tokenId = GammaPoolStorage.createLoan();
        emit LoanCreated(msg.sender, tokenId);
    }

    function loan(uint256 tokenId) external virtual override view returns (uint256 id, address poolId,
        uint256[] memory tokensHeld, uint256 initLiquidity, uint256 liquidity, uint256 lpTokens, uint256 rateIndex) {
        GammaPoolStorage.Loan storage _loan = GammaPoolStorage.store().loans[tokenId];
        return (_loan.id, _loan.poolId, _loan.tokensHeld, _loan.initLiquidity, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);
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

    function repayLiquidity(uint256 tokenId, uint256 liquidity) external virtual override returns(uint256 liquidityPaid, uint256[] memory amounts) {
        (bool success, bytes memory result) = GammaPoolStorage.store().longStrategy.delegatecall(abi.encodeWithSelector(
                ILongStrategy(GammaPoolStorage.store().longStrategy)._repayLiquidity.selector, tokenId, liquidity));
        require(success);
        return abi.decode(result, (uint256,uint256[]));
    }

    function rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external virtual override returns(uint256[] memory tokensHeld) {
        (bool success, bytes memory result) = GammaPoolStorage.store().longStrategy.delegatecall(abi.encodeWithSelector(
                ILongStrategy(GammaPoolStorage.store().longStrategy)._rebalanceCollateral.selector, tokenId, deltas));
        require(success);
        return abi.decode(result, (uint256[]));
    }
}
