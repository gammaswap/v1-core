// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../interfaces/IGammaPool.sol";
import "../interfaces/strategies/base/ILongStrategy.sol";
import "./GammaPoolERC4626.sol";

abstract contract GammaPool is IGammaPool, GammaPoolERC4626 {

    modifier lock() {
        GammaPoolStorage.lockit();
        _;
        GammaPoolStorage.unlockit();
    }

    uint16 immutable public override protocolId;
    address immutable public override longStrategy;
    address immutable public override shortStrategy;
    address immutable public override factory;

    constructor(address _factory, uint16 _protocolId, address _longStrategy, address _shortStrategy) {
        factory = _factory;
        protocolId = _protocolId;
        longStrategy = _longStrategy;
        shortStrategy = _shortStrategy;
    }

    function initialize(address cfmm, address[] calldata tokens) external virtual override {
        GammaPoolStorage.init(cfmm, tokens);
    }

    function cfmm() external virtual override view returns(address) {
        return GammaPoolStorage.store().cfmm;
    }

    function tokens() external virtual override view returns(address[] memory) {
        return GammaPoolStorage.store().tokens;
    }

    function vaultImplementation() internal virtual override view returns(address) {
        return shortStrategy;
    }

    //GamamPool Data
    function getPoolBalances() external virtual override view returns(uint256[] memory tokenBalances, uint256 lpTokenBalance, uint256 lpTokenBorrowed,
        uint256 lpTokenBorrowedPlusInterest, uint256 borrowedInvariant, uint256 lpInvariant){
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        return(store.TOKEN_BALANCE, store.LP_TOKEN_BALANCE, store.LP_TOKEN_BORROWED, store.LP_TOKEN_BORROWED_PLUS_INTEREST, store.BORROWED_INVARIANT, store.LP_INVARIANT);
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
        return abi.decode(callStrategy(shortStrategy, abi.encodeWithSelector(IShortStrategy._depositNoPull.selector, to)), (uint256));
    }

    function withdrawNoPull(address to) external virtual override returns(uint256 assets) {
        return abi.decode(callStrategy(shortStrategy, abi.encodeWithSelector(IShortStrategy._withdrawNoPull.selector, to)), (uint256));
    }

    function depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external virtual override returns(uint256[] memory reserves, uint256 shares){
        return abi.decode(callStrategy(shortStrategy, abi.encodeWithSelector(IShortStrategy._depositReserves.selector, to, amountsDesired, amountsMin, data)), (uint256[],uint256));
    }

    function withdrawReserves(address to) external virtual override returns (uint256[] memory reserves, uint256 assets) {
        return abi.decode(callStrategy(shortStrategy, abi.encodeWithSelector(IShortStrategy._withdrawReserves.selector, to)), (uint256[],uint256));
    }

    /*****LONG*****/

    function liquidate(uint256 tokenId, bool isRebalance, int256[] calldata deltas) external override virtual returns(uint256[] memory refund) {
        return abi.decode(callStrategy(longStrategy, abi.encodeWithSelector(ILongStrategy._liquidate.selector, tokenId, isRebalance, deltas)), (uint256[]));
    }

    function liquidateWithLP(uint256 tokenId) external override virtual returns(uint256[] memory refund) {
        return abi.decode(callStrategy(longStrategy, abi.encodeWithSelector(ILongStrategy._liquidateWithLP.selector, tokenId)), (uint256[]));
    }

    function getCFMMPrice() external virtual override view returns(uint256 price) {
        return ILongStrategy(longStrategy)._getCFMMPrice(GammaPoolStorage.store().cfmm, GammaPoolStorage.store().ONE);
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
        return abi.decode(callStrategy(longStrategy, abi.encodeWithSelector(ILongStrategy._increaseCollateral.selector, tokenId)), (uint256[]));
    }

    function decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external virtual override returns(uint256[] memory tokensHeld) {
        return abi.decode(callStrategy(longStrategy, abi.encodeWithSelector(ILongStrategy._decreaseCollateral.selector, tokenId, amounts, to)), (uint256[]));
    }

    function borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual override returns(uint256[] memory amounts) {
        return abi.decode(callStrategy(longStrategy, abi.encodeWithSelector(ILongStrategy._borrowLiquidity.selector, tokenId, lpTokens)), (uint256[]));
    }

    function repayLiquidity(uint256 tokenId, uint256 liquidity) external virtual override returns(uint256 liquidityPaid, uint256[] memory amounts) {
        return abi.decode(callStrategy(longStrategy, abi.encodeWithSelector(ILongStrategy._repayLiquidity.selector, tokenId, liquidity)), (uint256,uint256[]));
    }

    function rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external virtual override returns(uint256[] memory tokensHeld) {
        return abi.decode(callStrategy(longStrategy, abi.encodeWithSelector(ILongStrategy._rebalanceCollateral.selector, tokenId, deltas)), (uint256[]));
    }

}
