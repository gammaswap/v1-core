// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../../../strategies/external/BaseExternalStrategy.sol";
import "../../../strategies/LongStrategy.sol";
import "../../TestCFMM.sol";

contract TestBaseExternalStrategy is BaseExternalStrategy {

    using LibStorage for LibStorage.Storage;

    event LoanCreated(address indexed caller, uint256 tokenId);
    event AmountsWithFees(uint256[] amounts);

    event SwapCollateral(uint256 collateral);
    event ExternalSwap(uint256 liquiditySwapped, uint128[] tokensHeld);
    event SendLPTokens(uint256 lpTokens);

    uint80 public _borrowRate = 1;
    uint16 public _origFee = 0;
    uint16 public protocolId;
    uint256 public swapFee = 0;

    constructor() {
    }

    function initialize(address _cfmm, uint16 _protocolId, address[] calldata _tokens, uint8[] calldata _decimals) external virtual {
        protocolId = _protocolId;
        s.initialize(msg.sender, _cfmm, _tokens, _decimals);
    }

    function maxTotalApy() internal virtual override view returns(uint256) {
        return 1e19;
    }

    function blocksPerYear() internal virtual override pure returns(uint256) {
        return 2252571;
    }

    function ltvThreshold() internal virtual override view returns(uint16) {
        return 800;
    }

    function minBorrow() internal view virtual override returns(uint256) {
        return 1e3;
    }

    function originationFee() internal virtual view override returns(uint16) {
        return 10;
    }

    function externalSwapFee() internal view override virtual returns(uint256) {
        return swapFee;
    }

    function setExternalSwapFee(uint256 _swapFee) public virtual {
        swapFee = _swapFee;
    }

    function getParameters() public virtual view returns(uint16 _protocolId, address cfmm, address factory, address[] memory tokens, uint8[] memory decimals) {
        _protocolId = protocolId;
        cfmm = s.cfmm;
        factory = s.factory;
        tokens = s.tokens;
        decimals = s.decimals;
    }

    // Test functions
    function testCalcExternalSwapFee(uint256 liquiditySwapped, uint256 loanLiquidity) public view virtual returns(uint256 fee) {
        fee = calcExternalSwapFee(liquiditySwapped, loanLiquidity);
    }

    function testSendAndCalcCollateralLPTokens(address to, uint128[] calldata amounts, uint256 lastCFMMTotalSupply) public virtual returns(uint256 swappedCollateralAsLPTokens) {
        swappedCollateralAsLPTokens = sendAndCalcCollateralLPTokens(to, amounts, lastCFMMTotalSupply);
        emit SwapCollateral(swappedCollateralAsLPTokens);
    }

    function testSendCFMMLPTokens(address _cfmm, address to, uint256 lpTokens) public virtual returns(uint256 sentLPTokens) {
        sentLPTokens = sendCFMMLPTokens(_cfmm, to, lpTokens);
        emit SendLPTokens(sentLPTokens);
    }

    function testExternalSwap(uint256 tokenId, address _cfmm, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) public virtual returns(uint256 liquiditySwapped, uint128[] memory tokensHeld) {
        LibStorage.Loan storage _loan = s.loans[tokenId];
        (liquiditySwapped, tokensHeld) = externalSwap(_loan, _cfmm, amounts, lpTokens, to, data);
        emit ExternalSwap(liquiditySwapped, tokensHeld);
    }

    // deposit liquidity
    function updatePoolBalances() external virtual {
        (s.CFMM_RESERVES[0], s.CFMM_RESERVES[1],) = TestCFMM(s.cfmm).getReserves();
        s.lastCFMMTotalSupply = TestCFMM(s.cfmm).totalSupply();
        s.lastCFMMInvariant = uint128(calcInvariant(s.cfmm, s.CFMM_RESERVES));
        s.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this));
        s.LP_INVARIANT = uint128(convertLPToInvariant(s.LP_TOKEN_BALANCE, s.lastCFMMInvariant, s.lastCFMMTotalSupply));
    }

    function getPoolBalances() external virtual view returns(uint128[] memory tokenBalances, uint128[] memory cfmmReserves, uint256 lastCFMMTotalSupply, uint128 lastCFMMInvariant, uint256 lpTokenBalance, uint128 lpInvariant) {
        tokenBalances = s.TOKEN_BALANCE;
        cfmmReserves = s.CFMM_RESERVES;
        lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        lastCFMMInvariant = s.lastCFMMInvariant;
        lpTokenBalance = s.LP_TOKEN_BALANCE;
        lpInvariant = s.LP_INVARIANT;
    }

    // create loan
    function createLoan(uint128 liquidity) external virtual returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length);
        LibStorage.Loan storage _loan = s.loans[tokenId];
        _loan.liquidity = liquidity;
        _loan.initLiquidity = liquidity;

        uint128[] memory tokensHeld = updateCollateral(_loan);
        uint256 heldLiquidity = calcInvariant(s.cfmm, tokensHeld);

        checkMargin(heldLiquidity, liquidity);

        _loan.tokensHeld = tokensHeld;
        _loan.lpTokens = convertInvariantToLP(liquidity, s.lastCFMMTotalSupply, s.lastCFMMInvariant);

        emit LoanCreated(msg.sender, tokenId);
    }

    function getLoan(uint256 tokenId) public virtual view returns(uint256 id, address poolId, uint128[] memory tokensHeld,
        uint256 heldLiquidity, uint256 initLiquidity, uint256 liquidity, uint256 lpTokens, uint256 rateIndex) {
        LibStorage.Loan storage _loan = _getLoan(tokenId);
        id = _loan.id;
        poolId = _loan.poolId;
        tokensHeld = _loan.tokensHeld;
        heldLiquidity = calcInvariant(s.cfmm, _loan.tokensHeld);
        initLiquidity = _loan.initLiquidity;
        liquidity = _loan.liquidity;
        lpTokens = _loan.lpTokens;
        rateIndex = _loan.rateIndex;
    }

    // **** Not used **** //
    function beforeRepay(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual override {
    }

    function beforeSwapTokens(LibStorage.Loan storage _loan, int256[] calldata deltas) internal virtual override returns(uint256[] memory outAmts, uint256[] memory inAmts) {

    }

    function calcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant) internal virtual override view returns(uint256) {

    }

    function calcInvariant(address, uint128[] memory amounts) internal virtual override view returns(uint256) {
        return Math.sqrt(uint256(amounts[0]) * amounts[1]);
    }

    function calcTokensToRepay(uint256 liquidity) internal virtual override view returns(uint256[] memory amounts) {

    }

    function checkMargin(uint256 collateral, uint256 liquidity) internal virtual override view {
        if(!hasMargin(collateral, liquidity, ltvThreshold())) { // if collateral is below ltvThreshold revert transaction
            revert Margin();
        }
    }

    function depositToCFMM(address cfmm, address to, uint256[] memory amounts) internal virtual override returns(uint256 lpTokens) {

    }

    function swapTokens(LibStorage.Loan storage _loan, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual override {

    }

    function updateReserves(address cfmm) internal virtual override {

    }

    function withdrawFromCFMM(address cfmm, address to, uint256 lpTokens) internal virtual override returns(uint256[] memory amounts) {

    }/**/
}
