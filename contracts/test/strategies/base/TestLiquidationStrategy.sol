// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../TestCFMM2.sol";
import "../../../strategies/liquidation/SingleLiquidationStrategy.sol";
import "../../../strategies/liquidation/BatchLiquidationStrategy.sol";
import "../../../strategies/base/BaseBorrowStrategy.sol";

contract TestLiquidationStrategy is SingleLiquidationStrategy, BatchLiquidationStrategy, BaseBorrowStrategy {
    using LibStorage for LibStorage.Storage;
    event LoanCreated(address indexed caller, uint256 tokenId);
    event Refund(uint128[] tokensHeld, uint256[] tokenIds);
    event WriteDown2(uint256 writeDownAmt, uint256 loanLiquidity);
    event RefundOverPayment(uint256 loanLiquidity, uint256 lpDeposit);
    event RefundLiquidator(uint128[] tokensHeld, uint128[] refund);
    event BatchLiquidations(uint256 liquidityTotal, uint256 collateralTotal, uint256 lpTokensPrincipalTotal, uint128[] tokensHeldTotal, uint256[] tokenIds);

    struct PoolBalances {
        // LP Tokens
        uint256 LP_TOKEN_BALANCE;//LP Tokens in GS, LP_TOKEN_TOTAL = LP_TOKEN_BALANCE + LP_TOKEN_BORROWED_PLUS_INTEREST
        uint256 LP_TOKEN_BORROWED;//LP Tokens that have been borrowed (Principal)
        uint256 LP_TOKEN_BORROWED_PLUS_INTEREST;//(LP Tokens that have been borrowed (principal) plus interest in LP Tokens)

        // 1x256 bits, Invariants
        uint128 BORROWED_INVARIANT;
        uint128 LP_INVARIANT;//Invariant from LP Tokens, TOTAL_INVARIANT = BORROWED_INVARIANT + LP_INVARIANT

        uint128 lastCFMMInvariant;//uint128
        uint256 lastCFMMTotalSupply;
    }

    function initialize(address _factory, address cfmm, address[] calldata tokens, uint8[] calldata decimals) external virtual {
        s.initialize(_factory, cfmm, 1, tokens, decimals, 1e3);
    }

    function minPay() internal virtual override view returns(uint256) {
        return 1e3;
    }

    function _ltvThreshold() internal virtual override pure returns(uint16) {
        return 9500;
    }

    function _liquidationFee() internal virtual override pure returns(uint16) {
        return 250;
    }

    function maxTotalApy() internal virtual override view returns(uint256) {
        return 1e19;
    }

    function blocksPerYear() internal virtual override pure returns(uint256) {
        return 2252571;
    }

    function _beforeLiquidation() internal override virtual {
    }

    function syncCFMM(address cfmm) internal override virtual {
    }

    function getStaticParams() external virtual view returns(address factory, address cfmm, address[] memory tokens, uint128[] memory tokenBalances) {
        factory = s.factory;
        cfmm = s.cfmm;
        tokens = s.tokens;
        tokenBalances = s.TOKEN_BALANCE;
    }

    function updatePoolBalances() external virtual {
        address cfmm = s.cfmm;
        s.lastCFMMInvariant = uint128(TestCFMM2(cfmm).invariant());
        s.lastCFMMTotalSupply = TestCFMM2(cfmm).totalSupply();
        s.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(cfmm, address(this));
        s.LP_INVARIANT = uint128(convertLPToInvariant(s.LP_TOKEN_BALANCE, s.lastCFMMInvariant, s.lastCFMMTotalSupply));
    }

    function getPoolBalances() external virtual view returns(PoolBalances memory bal, uint128[] memory tokenBalances, uint256 accFeeIndex) {
        bal.LP_TOKEN_BALANCE = s.LP_TOKEN_BALANCE;
        bal.LP_TOKEN_BORROWED = s.LP_TOKEN_BORROWED;
        bal.LP_TOKEN_BORROWED_PLUS_INTEREST = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        bal.BORROWED_INVARIANT = s.BORROWED_INVARIANT;
        bal.LP_INVARIANT = s.LP_INVARIANT;
        bal.lastCFMMInvariant = s.lastCFMMInvariant;
        bal.lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        tokenBalances = s.TOKEN_BALANCE;
        accFeeIndex = s.accFeeIndex;
        return(bal, tokenBalances, accFeeIndex);
    }

    function checkMargin2(uint256 collateral, uint256 liquidity, uint256 limit) internal virtual pure {
        if(!hasMargin(collateral, liquidity, limit)) revert Margin();
    }

    // **** LONG GAMMA **** //
    function createLoan(uint256 lpTokens) external virtual returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length, 0);

        LibStorage.Loan storage _loan = _getLoan(tokenId);

        TestCFMM2(s.cfmm).withdrawReserves(lpTokens);

        (uint128[] memory tokensHeld,) = updateCollateral(_loan);

        (,uint256 liquidity) = openLoan(_loan, lpTokens);
        _loan.rateIndex = s.accFeeIndex;
        uint256 collateral = calcInvariant(s.cfmm, tokensHeld);
        checkMargin2(collateral, liquidity, 8000);

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

    function testPayBatchLoans(uint256 liquidity, uint256 lpTokenPrincipal) external virtual {
        uint256 currBalance = GammaSwapLibrary.balanceOf(s.cfmm, address(this));
        // uint256 lpDeposit = currBalance - s.LP_TOKEN_BALANCE;
        // payPoolDebt(liquidity, lpTokenPrincipal, s.lastCFMMInvariant, s.lastCFMMTotalSupply, currBalance, lpDeposit);
        payPoolDebt(liquidity, lpTokenPrincipal, s.lastCFMMInvariant, s.lastCFMMTotalSupply, currBalance);
    }

    function testPayBatchLoanAndRefundLiquidator(uint256[] calldata tokenIds) external virtual {
        (SummedLoans memory summedLoans, uint128[] memory refund) = sumLiquidity(tokenIds);
        (refund, ) = refundLiquidator(summedLoans.liquidityTotal, summedLoans.liquidityTotal, refund);
        emit Refund(refund, tokenIds);
    }

    function testRefundLiquidator(uint256 tokenId, uint256 payLiquidity, uint256 loanLiquidity) external virtual {
        (uint128[] memory refund, uint128[] memory tokensHeld) = refundLiquidator(payLiquidity, loanLiquidity, _getLoan(tokenId).tokensHeld);
        emit RefundLiquidator(tokensHeld, refund);
    }

    function testSumLiquidity(uint256[] calldata tokenIds) external virtual {
        (SummedLoans memory summedLoans, uint128[] memory refund) = sumLiquidity(tokenIds);
        emit BatchLiquidations(summedLoans.liquidityTotal, summedLoans.collateralTotal, summedLoans.lpTokensTotal, refund, summedLoans.tokenIds);
    }

    function testCanLiquidate(uint256 collateral, uint256 liquidity) external virtual {
        if(!canLiquidate(liquidity, collateral)) revert HasMargin();
    }

    function testUpdateLoan(uint256 tokenId) external virtual {
        updateLoan(_getLoan(tokenId));
    }

    function updateLoan(LibStorage.Loan storage _loan) internal override virtual returns(uint256) {
        return updateLoanLiquidity(_loan, s.accFeeIndex);
    }

    function updateIndex() internal override virtual returns(uint256 accFeeIndex, uint256 lastFeeIndex, uint256 lastCFMMIndex) {
        accFeeIndex = s.accFeeIndex;
        s.CFMM_RESERVES = getReserves(s.cfmm);
        lastFeeIndex = 1e18;
        lastCFMMIndex = 1e18;
    }

    function incBorrowedInvariant(uint256 invariant) external virtual {
        uint256 borrowedInvariant = s.BORROWED_INVARIANT + invariant;
        uint256 feeGrowth = borrowedInvariant * 1e18 / s.BORROWED_INVARIANT;
        s.accFeeIndex = uint80(s.accFeeIndex * feeGrowth / 1e18);
        s.BORROWED_INVARIANT = uint128(borrowedInvariant);
        s.LP_TOKEN_BORROWED_PLUS_INTEREST = convertInvariantToLP(s.BORROWED_INVARIANT, s.lastCFMMTotalSupply, s.lastCFMMInvariant);
    }

    function testRefundOverPayment(uint256 loanLiquidity, uint256 lpDeposit, bool fullPayment) external virtual {
        (loanLiquidity, lpDeposit) = calcDeposit(loanLiquidity, s.lastCFMMInvariant, s.lastCFMMTotalSupply, s.LP_TOKEN_BALANCE, fullPayment);
        emit RefundOverPayment(loanLiquidity, lpDeposit);
    }

    function testWriteDown(uint256 payableLiquidity, uint256 loanLiquidity) external virtual {
        (uint256 _writeDownAmt, uint256 _loanLiquidity) = writeDown(payableLiquidity, loanLiquidity);
        emit WriteDown2(_writeDownAmt, _loanLiquidity);
    }

    function payLoan(LibStorage.Loan storage, uint256, uint256) internal override virtual returns(uint256, uint256) {
        return (0,0);
    }

    //AbstractRateModel abstract functions
    function calcBorrowRate(uint256, uint256, address, address) public virtual override view returns(uint256, uint256, uint256, uint256) {
        return (0,0,5000,1e18);
    }

    //BaseStrategy functions
    function calcCFMMFeeIndex(uint256, uint256, uint256, uint256, uint256, uint256) internal override virtual view returns(uint256) {
        return 0;
    }

    function calcFeeIndex(uint256, uint256, uint256, uint256) internal override virtual view returns(uint256) {
        return 0;
    }

    function updateCFMMIndex(uint256, uint256) internal override virtual returns(uint256, uint256, uint256){
        return (0,0,0);
    }

    //BaseStrategy abstract functions
    function updateReserves(address) internal virtual override {
    }

    function calcInvariant(address, uint128[] memory amounts) internal virtual override view returns(uint256) {
        return GSMath.sqrt(uint256(amounts[0]) * amounts[1]);
    }

    function depositToCFMM(address, address, uint256[] memory) internal virtual override returns(uint256) {
        return 0;
    }

    function withdrawFromCFMM(address, address, uint256) internal virtual override returns(uint256[] memory) {
        return new uint256[](2);
    }

    //BaseLongStrategy abstract functions

    function beforeRepay(LibStorage.Loan storage, uint256[] memory) internal virtual override {
    }

    function calcTokensToRepay(uint128[] memory,uint256, uint128[] memory, bool) internal virtual override view returns(uint256[] memory) {
        return new uint256[](2);
    }

    function beforeSwapTokens(LibStorage.Loan storage, int256[] memory, uint128[] memory) internal virtual override returns(uint256[] memory, uint256[] memory) {
        return (new uint256[](2), new uint256[](2));
    }

    function swapTokens(LibStorage.Loan storage, uint256[] memory, uint256[] memory) internal virtual override {
    }

    function originationFee() internal virtual override view returns(uint16) {
        return 0;
    }

    function getReserves(address cfmm) internal virtual override view returns(uint128[] memory reserves) {
        reserves = new uint128[](2);
        (reserves[0], reserves[1],) = TestCFMM(cfmm).getReserves();
    }

    function getLPReserves(address cfmm,bool) internal virtual override view returns(uint128[] memory) {
        return s.CFMM_RESERVES;
    }

    function validateParameters(bytes calldata _data) external override view returns(bool) {
        return false;
    }

    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        return 0;
    }

    function _calcCollateralPostTrade(int256[] memory deltas, uint128[] memory tokensHeld, uint128[] memory reserves) internal virtual override view returns(uint256 collateral) {
        return GSMath.sqrt(uint256(tokensHeld[0]) * tokensHeld[1]);
    }

    function _calcDeltasForMaxLP(uint128[] memory tokensHeld, uint128[] memory reserves) internal virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](2);
        deltas[0] = 0;
        deltas[1] = 100;
    }

    function _calcDeltasToCloseSetRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity, uint256[] memory ratio) internal virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](2);
        deltas[0] = 0;
        deltas[1] = 100;
    }
    function _calcDeltasForWithdrawal(uint128[] memory amounts, uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) internal virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](2);
        deltas[0] = 0;
        deltas[1] = 100;
    }

    function _calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) internal virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](2);
        deltas[0] = 0;
        deltas[1] = 100;
    }

    function _calcDeltasToClose(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity, uint256 collateralId) internal virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](2);
        deltas[0] = 0;
        deltas[1] = 0;
    }

    function _calcMaxCollateralNotMktImpact(uint128[] memory tokensHeld, uint128[] memory reserves) internal virtual override returns(uint256) {
        uint256 price = uint256(reserves[1]) * (10**18) / uint256(reserves[0]);
        uint256 num = uint256(tokensHeld[0]) * price / (10 ** 18) + uint256(tokensHeld[1]);
        uint256 denom = 2 * GSMath.sqrt(price*(10**18));
        return num * (10**18)/ denom;
    }

    function _calcOriginationFee(uint256 liquidityBorrowed, uint256 borrowedInvariant, uint256 lpInvariant, uint256 lowUtilRate, uint256 discount) internal virtual override view returns(uint256 _origFee) {
        _origFee = originationFee(); // base fee
        return discount > _origFee ? 0 : (_origFee - discount);
    }
}