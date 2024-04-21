// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../TestCFMM.sol";
import "../../TestERC20.sol";
import "../../../strategies/lending/BorrowStrategy.sol";
import "../../../strategies/rebalance/RebalanceStrategy.sol";

contract TestRebalanceStrategy is BorrowStrategy, RebalanceStrategy {

    using LibStorage for LibStorage.Storage;

    event LoanCreated(address indexed caller, uint256 tokenId);
    uint80 public borrowRate = 1e18;
    uint16 public origFee = 0;
    uint16 public protocolId;
    uint256 private _minPay = 1e3;
    uint256 private mCurrPrice = 1e18;

    constructor() {
    }

    function initialize(address _factory, address _cfmm, uint16 _protocolId, address[] calldata _tokens, uint8[] calldata _decimals) external virtual {
        protocolId = _protocolId;
        s.initialize(_factory, _cfmm, _protocolId, _tokens, _decimals, 1e3);
    }

    function setMinPay(uint256 _newMinPay) external virtual {
        _minPay = _newMinPay;
    }

    function minPay() internal virtual override view returns(uint256) {
        return _minPay;
    }

    function maxTotalApy() internal virtual override view returns(uint256) {
        return 1e19;
    }

    function blocksPerYear() internal virtual override pure returns(uint256) {
        return 2252571;
    }

    function syncCFMM(address cfmm) internal override virtual {
    }

    function tokens() public virtual view returns(address[] memory) {
        return s.tokens;
    }

    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        return mCurrPrice;
    }

    function setCurrentCFMMPrice(uint256 _currPrice) external virtual {
        mCurrPrice = _currPrice;
    }

    function testUpdateLoanPrice(uint256 newLiquidity, uint256 currPrice, uint256 liquidity, uint256 lastPx) external virtual view returns(uint256) {
        return updateLoanPrice(newLiquidity, currPrice, liquidity, lastPx);
    }

    function tokenBalances() public virtual view returns(uint128[] memory) {
        return s.TOKEN_BALANCE;
    }

    function testGetReserves(address to) external virtual view returns(uint128[] memory) {
        return _getReserves(to);
    }

    // **** LONG GAMMA **** //
    function createLoan() external virtual returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length, 0);
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

    function setLiquidity(uint256 tokenId, uint128 liquidity) public virtual {
        LibStorage.Loan storage _loan = _getLoan(tokenId);
        _loan.liquidity = liquidity;
    }

    function setHeldAmounts(uint256 tokenId, uint128[] calldata heldAmounts) public virtual {
        LibStorage.Loan storage _loan = _getLoan(tokenId);
        _loan.tokensHeld = heldAmounts;
    }

    function _ltvThreshold() internal virtual override view returns(uint16){
        return 8000;
    }

    function checkMargin2(uint256 tokenId) public virtual view returns(bool) {
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        uint256 collateral = calcInvariant(s.cfmm, _loan.tokensHeld);
        checkMargin(collateral, _loan.liquidity);

        return true;
    }

    function setBorrowRate(uint80 _borrowRate) public virtual {
        borrowRate = _borrowRate;
    }

    function calcBorrowRate(uint256, uint256, address, address) public virtual override view returns(uint256, uint256, uint256, uint256) {
        return (borrowRate,0,5000,1e18);
    }

    //LongGamma
    function beforeRepay(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual override {
        _loan.tokensHeld[0] -= uint128(amounts[0]);
        _loan.tokensHeld[1] -= uint128(amounts[1]);
    }

    function depositToCFMM(address cfmm, address, uint256[] memory amounts) internal virtual override returns(uint256 liquidity) {
        liquidity = uint128(amounts[0]);
        TestCFMM(cfmm).mint(liquidity / 2, address(this));
    }

    function calcTokensToRepay(uint128[] memory reserves, uint256 liquidity, uint128[] memory maxAmounts, bool isLiquidation) internal virtual override view returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = liquidity;
        amounts[1] = liquidity * 2;
    }

    function squareRoot(uint256 num) public virtual pure returns(uint256) {
        return GSMath.sqrt(num * 1e18);
    }

    function beforeSwapTokens(LibStorage.Loan storage, int256[] memory deltas, uint128[] memory) internal virtual override view returns(uint256[] memory outAmts, uint256[] memory inAmts){
        outAmts = new uint256[](2);
        inAmts = new uint256[](2);
        outAmts[0] =  deltas[0] > 0 ? 0 : uint256(-deltas[0]);
        outAmts[1] =  deltas[1] > 0 ? 0 : uint256(-deltas[1]);
        inAmts[0] = deltas[0] > 0 ? uint256(deltas[0]) : 0;
        inAmts[1] = deltas[1] > 0 ? uint256(deltas[1]) : 0;
    }

    function swapTokens(LibStorage.Loan storage, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual override {
        address cfmm = s.cfmm;

        if(outAmts[0] > 0) {
            GammaSwapLibrary.safeTransfer(s.tokens[0], cfmm, outAmts[0]);
        } else if(outAmts[1] > 0) {
            GammaSwapLibrary.safeTransfer(s.tokens[1], cfmm, outAmts[1]);
        }

        if(inAmts[0] > 0) {
            TestERC20(s.tokens[0]).mint(address(this), inAmts[0]);
        } else if(inAmts[1] > 0) {
            TestERC20(s.tokens[1]).mint(address(this), inAmts[1]);
        }
    }

    //BaseStrategy
    function updateReserves(address) internal override virtual {
    }

    function calcInvariant(address, uint128[] memory amounts) internal virtual override view returns(uint256) {
        return GSMath.sqrt(uint256(amounts[0]) * amounts[1]);
    }

    function withdrawFromCFMM(address, address, uint256 amount) internal virtual override returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = amount * 2;
        amounts[1] = amount * 4;
    }

    function testOpenLoan(uint256 tokenId, uint256 lpTokens) public virtual {
        openLoan(_getLoan(tokenId), lpTokens);
    }

    function updateLoan(LibStorage.Loan storage _loan) internal override returns(uint256){
        uint80 rateIndex = borrowRate;
        s.accFeeIndex = rateIndex;
        return updateLoanLiquidity(_loan, rateIndex);
    }

    function setLPTokenLoanBalance(uint256 tokenId, uint256 lpInvariant, uint256 lpTokenBalance, uint256 liquidity, uint256 lpTokens, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) public virtual {
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        s.LP_INVARIANT = uint128(lpInvariant);
        s.LP_TOKEN_BALANCE = lpTokenBalance;

        s.BORROWED_INVARIANT = uint128(liquidity);
        s.LP_TOKEN_BORROWED = lpTokens;
        s.LP_TOKEN_BORROWED_PLUS_INTEREST = lpTokens;

        s.lastCFMMInvariant = uint128(lastCFMMInvariant);
        s.lastCFMMTotalSupply = lastCFMMTotalSupply;

        _loan.liquidity = uint128(liquidity);
        _loan.lpTokens = lpTokens;
    }

    function setCfmmReserves(uint128[] calldata reserves) public {
        s.CFMM_RESERVES = reserves;
    }

    function setLPTokenBalance(uint256 lpInvariant, uint256 lpTokenBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) public virtual {
        s.LP_TOKEN_BALANCE = lpTokenBalance;
        s.LP_INVARIANT = uint128(lpInvariant);
        s.lastCFMMInvariant = uint128(lastCFMMInvariant);
        s.lastCFMMTotalSupply = lastCFMMTotalSupply;
    }

    function chargeLPTokenInterest(uint256 tokenId, uint256 lpTokenInterest) public virtual {
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        uint128 invariantInterest = uint128(lpTokenInterest * s.LP_INVARIANT / s.LP_TOKEN_BALANCE);
        _loan.liquidity = _loan.liquidity + invariantInterest;
        s.BORROWED_INVARIANT = s.BORROWED_INVARIANT + invariantInterest;

        s.LP_TOKEN_BORROWED_PLUS_INTEREST = s.LP_TOKEN_BORROWED_PLUS_INTEREST + lpTokenInterest;
    }

    function getLoanChangeData(uint256 tokenId) public virtual view returns(uint256 loanLiquidity, uint256 loanLpTokens,
        uint256 loanPx, uint256 borrowedInvariant, uint256 lpInvariant, uint256 totalInvariant,
        uint256 lpTokenBorrowed, uint256 lpTokenBalance, uint256 lpTokenBorrowedPlusInterest,
        uint256 lpTokenTotal, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) {
        LibStorage.Loan storage _loan = _getLoan(tokenId);

        return(_loan.liquidity, _loan.lpTokens, _loan.px,
        s.BORROWED_INVARIANT, s.LP_INVARIANT, (s.BORROWED_INVARIANT + s.LP_INVARIANT),
        s.LP_TOKEN_BORROWED, s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED_PLUS_INTEREST,
        (s.LP_TOKEN_BALANCE + s.LP_TOKEN_BORROWED_PLUS_INTEREST), s.lastCFMMInvariant, s.lastCFMMTotalSupply);
    }

    function getPoolData() external virtual view returns(uint256 LP_TOKEN_BALANCE, uint256 LP_TOKEN_BORROWED, uint40 LAST_BLOCK_NUMBER,
        uint80 accFeeIndex, uint256 LP_TOKEN_BORROWED_PLUS_INTEREST, uint128 LP_INVARIANT, uint128 BORROWED_INVARIANT, uint128[] memory CFMM_RESERVES) {
        LP_TOKEN_BALANCE = s.LP_TOKEN_BALANCE;
        LP_TOKEN_BORROWED = s.LP_TOKEN_BORROWED;
        LAST_BLOCK_NUMBER = s.LAST_BLOCK_NUMBER;
        accFeeIndex = s.accFeeIndex;
        LP_TOKEN_BORROWED_PLUS_INTEREST = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        LP_INVARIANT = s.LP_INVARIANT;
        BORROWED_INVARIANT = s.BORROWED_INVARIANT;
        CFMM_RESERVES = s.CFMM_RESERVES;
    }

    function setOriginationFee(uint16 _origFee) external virtual {
        origFee = _origFee;
    }

    function originationFee() internal override virtual view returns(uint16) {
        return origFee;
    }

    function mintToDevs(uint256 lastFeeIndex, uint256 lastCFMMIndex, uint256 utilizationRate) internal virtual override {
    }

    function testUpdateIndex() public virtual {
        updateIndex();
    }

    function setAccFeeIndex(uint80 accFeeIndex) public virtual {
        s.accFeeIndex = accFeeIndex;
    }

    function getAccFeeIndex() public virtual view returns(uint256 accFeeIndex){
        accFeeIndex = s.accFeeIndex;
    }

    function setLoanLiquidity(uint256 tokenId, uint128 liquidity) public virtual {
        LibStorage.Loan storage _loan = s.loans[tokenId];
        _loan.liquidity = liquidity;
    }

    function testUpdateLoanLiquidity(uint256 tokenId, uint80 accFeeIndex) public virtual {
        LibStorage.Loan storage _loan = s.loans[tokenId];
        updateLoanLiquidity(_loan, accFeeIndex);
    }

    function testUpdateLoan(uint256 tokenId) public virtual {
        LibStorage.Loan storage _loan = s.loans[tokenId];
        super.updateLoan(_loan);
    }

    function calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) public virtual override view returns(int256[] memory deltas) {
        return _calcDeltasForRatio(tokensHeld, reserves, ratio);
    }

    function _calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) internal virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](2);
        deltas[0] = 0;
        deltas[1] = 100;
    }

    function calcDeltasToClose(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity, uint256 collateralId) external virtual override view returns(int256[] memory deltas) {
        return _calcDeltasToClose(tokensHeld, reserves, liquidity, collateralId);
    }

    function _calcDeltasToClose(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity, uint256 collateralId) internal virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](2);
        deltas[0] = 0;
        deltas[1] = 0;
    }

    function calcDeltasForWithdrawal(uint128[] memory amounts, uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) public virtual override view returns(int256[] memory deltas) {
        return _calcDeltasForWithdrawal(amounts, tokensHeld, reserves, ratio);
    }

    function _calcDeltasForWithdrawal(uint128[] memory amounts, uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) internal virtual override view returns(int256[] memory deltas) {
        deltas = new int256[](2);
        deltas[0] = 0;
        deltas[1] = 100;
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

    function _calcCollateralPostTrade(int256[] memory deltas, uint128[] memory tokensHeld, uint128[] memory reserves) internal virtual override view returns(uint256 collateral) {
        return 0;
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
}
