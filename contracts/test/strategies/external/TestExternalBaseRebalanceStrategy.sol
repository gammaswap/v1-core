// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../../../strategies/base/BaseExternalStrategy.sol";
import "../../TestCFMM.sol";
import "../../../strategies/base/BaseBorrowStrategy.sol";

abstract contract TestExternalBaseRebalanceStrategy is BaseExternalStrategy {

    using LibStorage for LibStorage.Storage;

    event LoanCreated(address indexed caller, uint256 tokenId);

    uint80 public _borrowRate = 1;
    uint16 public _origFee = 0;
    uint16 public protocolId;
    uint256 public swapFee = 0;

    constructor() {
    }

    function initialize(address factory, address _cfmm, uint16 _protocolId, address[] calldata _tokens, uint8[] calldata _decimals) external virtual {
        protocolId = _protocolId;
        s.initialize(factory, _cfmm, _protocolId, _tokens, _decimals, 1e3);
    }

    function maxTotalApy() internal virtual override view returns(uint256) {
        return 1e19;
    }

    function blocksPerYear() internal virtual override pure returns(uint256) {
        return 2252571;
    }

    function _ltvThreshold() internal virtual override view returns(uint16) {
        return 8000;
    }

    function minPay() internal view virtual override returns(uint256) {
        return 1e3;
    }

    function validateParameters(bytes calldata _data) external override view returns(bool) {
        return false;
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

    // deposit liquidity
    function updatePoolBalances() external virtual {
        s.CFMM_RESERVES = getReserves(s.cfmm);
        s.lastCFMMTotalSupply = TestCFMM(s.cfmm).totalSupply();
        s.lastCFMMInvariant = uint128(calcInvariant(s.cfmm, s.CFMM_RESERVES));
        s.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(s.cfmm, address(this));
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

    function getBorrowedBalances() external virtual view returns(uint256 borrowedInvariant,
        uint256 lpTokensBorrowedPlusInterest, uint256 lpTokensBorrowed) {
        borrowedInvariant = s.BORROWED_INVARIANT;
        lpTokensBorrowedPlusInterest = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        lpTokensBorrowed = s.LP_TOKEN_BORROWED;
    }

    // create loan
    function createLoan(uint128 liquidity) external virtual returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length, 0);
        LibStorage.Loan storage _loan = s.loans[tokenId];
        _loan.liquidity = liquidity;
        _loan.initLiquidity = liquidity;

        (uint128[] memory tokensHeld,) = updateCollateral(_loan);
        uint256 heldLiquidity = calcInvariant(s.cfmm, tokensHeld);

        checkMargin(heldLiquidity, liquidity);

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

    function calcBorrowRate(uint256,uint256,address, address) public virtual override view returns(uint256,uint256,uint256,uint256) {
        return(0,0,5000,1e18);
    }

    function calcInvariant(address, uint128[] memory amounts) internal virtual override view returns(uint256) {
        return GSMath.sqrt(uint256(amounts[0]) * amounts[1]);
    }

    function getReserves(address cfmm) internal virtual override view returns(uint128[] memory reserves) {
        reserves = new uint128[](2);
        (reserves[0], reserves[1],) = TestCFMM(cfmm).getReserves();
    }

    function getLPReserves(address cfmm,bool) internal virtual override view returns(uint128[] memory) {
        return s.CFMM_RESERVES;
    }
}
