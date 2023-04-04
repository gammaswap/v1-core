// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "./TestLongStrategy.sol";
import "../../../strategies/LiquidationStrategy.sol";
import "../../TestCFMM2.sol";

contract TestLiquidationStrategy is LiquidationStrategy {
    using LibStorage for LibStorage.Storage;
    event LoanCreated(address indexed caller, uint256 tokenId);
    event Refund(uint128[] tokensHeld, uint256[] tokenIds);
    event WriteDown2(uint256 writeDownAmt, uint256 loanLiquidity);
    event RefundOverPayment(uint256 loanLiquidity, uint256 lpDeposit);
    event RefundLiquidator(uint128[] tokensHeld, uint256[] refund);
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

    function initialize(address cfmm, address[] calldata tokens, uint8[] calldata decimals) external virtual {
        s.initialize(msg.sender, cfmm, tokens, decimals);
    }

    function minBorrow() internal virtual override view returns(uint256) {
        return 1e3;
    }

    function ltvThreshold() internal virtual override pure returns(uint16) {
        return 9500;
    }

    function liquidationFeeThreshold() internal virtual override pure returns(uint16) {
        return 9750;
    }

    function maxTotalApy() internal virtual override view returns(uint256) {
        return 1e19;
    }

    function blocksPerYear() internal virtual override pure returns(uint256) {
        return 2252571;
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
        s.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(IERC20(cfmm), address(this));
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
        if(!hasMargin(collateral, liquidity, limit)) {
            revert Margin();
        }
    }

    // **** LONG GAMMA **** //
    function createLoan(uint256 lpTokens) external virtual returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length);

        LibStorage.Loan storage _loan = _getLoan(tokenId);

        TestCFMM2(s.cfmm).withdrawReserves(lpTokens);

        uint128[] memory tokensHeld = updateCollateral(_loan);

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
        uint256 currBalance = GammaSwapLibrary.balanceOf(IERC20(s.cfmm), address(this));
        // uint256 lpDeposit = currBalance - s.LP_TOKEN_BALANCE;
        // payPoolDebt(liquidity, lpTokenPrincipal, s.lastCFMMInvariant, s.lastCFMMTotalSupply, currBalance, lpDeposit);
        payPoolDebt(liquidity, lpTokenPrincipal, s.lastCFMMInvariant, s.lastCFMMTotalSupply, currBalance);
    }

    function testPayBatchLoanAndRefundLiquidator(uint256[] calldata tokenIds) external virtual {
        (uint256 liquidityTotal, uint256 payLiquidityTotal,, uint128[] memory tokensHeldTotal, uint256[] memory _tokenIds) = sumLiquidity(tokenIds);
        (tokensHeldTotal, ) = refundLiquidator(payLiquidityTotal, liquidityTotal, tokensHeldTotal);
        emit Refund(tokensHeldTotal, _tokenIds);
    }

    function testRefundLiquidator(uint256 tokenId, uint256 payLiquidity, uint256 loanLiquidity) external virtual {
        (uint128[] memory tokensHeld, uint256[] memory refund) = refundLiquidator(payLiquidity, loanLiquidity, _getLoan(tokenId).tokensHeld);
        emit RefundLiquidator(tokensHeld, refund);
    }

    function testSumLiquidity(uint256[] calldata tokenIds) external virtual {
        (uint256 liquidityTotal, uint256 collateralTotal, uint256 lpTokensPrincipalTotal, uint128[] memory tokensHeldTotal, uint256[] memory _tokenIds) = sumLiquidity(tokenIds);
        emit BatchLiquidations(liquidityTotal, collateralTotal, lpTokensPrincipalTotal, tokensHeldTotal, _tokenIds);
    }

    function testCanLiquidate(uint256 collateral, uint256 liquidity) external virtual {
        checkMargin(collateral, liquidity);
    }

    function testUpdateLoan(uint256 tokenId) external virtual {
        updateLoan(_getLoan(tokenId));
    }

    function updateLoan(LibStorage.Loan storage _loan) internal override virtual returns(uint256) {
        return updateLoanLiquidity(_loan, s.accFeeIndex);
    }

    function updateIndex() internal override virtual returns(uint256 accFeeIndex, uint256 lastFeeIndex, uint256 lastCFMMIndex) {
        accFeeIndex = s.accFeeIndex;
        lastFeeIndex = 1e18;
        lastCFMMIndex = 1e18;
    }

    function incBorrowedInvariant(uint256 invariant) external virtual {
        uint256 borrowedInvariant = s.BORROWED_INVARIANT + invariant;
        uint256 feeGrowth = borrowedInvariant * 1e18 / s.BORROWED_INVARIANT;
        s.accFeeIndex = uint96(s.accFeeIndex * feeGrowth / 1e18);
        s.BORROWED_INVARIANT = uint128(borrowedInvariant);
        s.LP_TOKEN_BORROWED_PLUS_INTEREST = convertInvariantToLP(s.BORROWED_INVARIANT, s.lastCFMMTotalSupply, s.lastCFMMInvariant);
    }

    function testRefundOverPayment(uint256 loanLiquidity, uint256 lpDeposit) external virtual {
        (loanLiquidity, lpDeposit) = refundOverPayment(loanLiquidity, lpDeposit, s.lastCFMMTotalSupply, s.lastCFMMInvariant);
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
    function calcBorrowRate(uint256, uint256) internal virtual override view returns(uint256, uint256) {
        return (0,0);
    }

    //BaseStrategy functions
    function calcCFMMFeeIndex(uint256, uint256, uint256, uint256, uint256) internal override virtual view returns(uint256) {
        return 0;
    }

    function calcFeeIndex(uint256, uint256, uint256) internal override virtual view returns(uint256) {
        return 0;
    }

    function updateCFMMIndex(uint256) internal override virtual returns(uint256, uint256, uint256){
        return (0,0,0);
    }

    //BaseStrategy abstract functions
    function updateReserves(address) internal virtual override {
    }

    function calcInvariant(address, uint128[] memory amounts) internal virtual override view returns(uint256) {
        return Math.sqrt(uint256(amounts[0]) * amounts[1]);
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

    function calcTokensToRepay(uint256) internal virtual override view returns(uint256[] memory) {
        return new uint256[](2);
    }

    function beforeSwapTokens(LibStorage.Loan storage, int256[] calldata) internal virtual override returns(uint256[] memory, uint256[] memory) {
        return (new uint256[](2), new uint256[](2));
    }

    function swapTokens(LibStorage.Loan storage, uint256[] memory, uint256[] memory) internal virtual override {
    }

    function originationFee() internal virtual override view returns(uint24) {
        return 0;
    }

}