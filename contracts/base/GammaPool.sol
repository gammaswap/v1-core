// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import "../libraries/GammaSwapLibrary.sol";
import "../interfaces/IGammaPool.sol";
import "../interfaces/IGammaPoolFactory.sol";
import "../interfaces/strategies/lending/IBorrowStrategy.sol";
import "../interfaces/strategies/lending/IRepayStrategy.sol";
import "../interfaces/strategies/rebalance/IRebalanceStrategy.sol";
import "../interfaces/strategies/base/ILongStrategy.sol";
import "../interfaces/strategies/base/ILiquidationStrategy.sol";
import "../interfaces/strategies/liquidation/ISingleLiquidationStrategy.sol";
import "../interfaces/strategies/liquidation/IBatchLiquidationStrategy.sol";
import "../interfaces/IPoolViewer.sol";
import "./GammaPoolERC4626.sol";

/// @title Basic GammaPool smart contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used as template for building other GammaPool contract implementations for other CFMMs
abstract contract GammaPool is IGammaPool, GammaPoolERC4626 {

    using LibStorage for LibStorage.Storage;

    error Forbidden();
    error ZeroFeeDivisor();
    error LiquidationFeeGtLTVThreshold();
    error InvalidMinBorrow();

    /// @dev See {IGammaPool-protocolId}
    uint16 immutable public override protocolId;

    /// @dev See {IGammaPool-factory}
    address immutable public override factory;

    /// @dev See {IGammaPool-borrowStrategy}
    address immutable public override borrowStrategy;

    /// @dev See {IGammaPool-repayStrategy}
    address immutable public override repayStrategy;

    /// @dev See {IGammaPool-rebalanceStrategy}
    address immutable public override rebalanceStrategy;

    /// @dev See {IGammaPool-shortStrategy}
    address immutable public override shortStrategy;

    /// @dev See {IGammaPool-singleLiquidationStrategy}
    address immutable public override singleLiquidationStrategy;

    /// @dev See {IGammaPool-batchLiquidationStrategy}
    address immutable public override batchLiquidationStrategy;

    /// @dev See {IGammaPool-viewer}
    address immutable public override viewer;

    /// @dev Initializes the contract by setting `protocolId`, `factory`, `borrowStrategy`, `repayStrategy`, `rebalanceStrategy`,
    /// @dev shortStrategy`, `singleLiquidationStrategy`, `batchLiquidationStrategy`, and `viewer`.
    constructor(uint16 protocolId_, address factory_,  address borrowStrategy_, address repayStrategy_, address rebalanceStrategy_,
        address shortStrategy_, address singleLiquidationStrategy_, address batchLiquidationStrategy_, address viewer_) {
        protocolId = protocolId_;
        factory = factory_;
        borrowStrategy = borrowStrategy_;
        repayStrategy = repayStrategy_;
        rebalanceStrategy = rebalanceStrategy_;
        shortStrategy = shortStrategy_;
        singleLiquidationStrategy = singleLiquidationStrategy_;
        batchLiquidationStrategy = batchLiquidationStrategy_;
        viewer = viewer_;
    }

    /// @dev See {IGammaPool-initialize}
    function initialize(address _cfmm, address[] calldata _tokens, uint8[] calldata _decimals, uint72 _minBorrow, bytes calldata) external virtual override {
        if(msg.sender != factory) revert Forbidden(); // only factory is allowed to initialize
        s.initialize(factory, _cfmm, protocolId, _tokens, _decimals, _minBorrow);
    }

    /// @dev See {IGammaPool-setPoolParams}
    function setPoolParams(uint16 origFee, uint8 extSwapFee, uint8 emaMultiplier, uint8 minUtilRate1, uint8 minUtilRate2, uint16 feeDivisor, uint8 liquidationFee, uint8 ltvThreshold, uint72 minBorrow) external virtual override {
        if(msg.sender != factory) revert Forbidden(); // only factory is allowed to update dynamic fee parameters

        if(feeDivisor == 0) revert ZeroFeeDivisor();
        if(liquidationFee > uint256(ltvThreshold) * 10) revert LiquidationFeeGtLTVThreshold();
        if(minBorrow < 1e3) revert InvalidMinBorrow();

        s.ltvThreshold = ltvThreshold;
        s.liquidationFee = liquidationFee;
        s.origFee = origFee;
        s.extSwapFee = extSwapFee;
        s.emaMultiplier = emaMultiplier;
        s.minUtilRate1 = minUtilRate1;
        s.minUtilRate2 = minUtilRate2;
        s.feeDivisor = feeDivisor;
        s.minBorrow = minBorrow;
    }

    /// @dev See {IGammaPool-cfmm}
    function cfmm() external virtual override view returns(address) {
        return s.cfmm;
    }

    /// @dev See {IGammaPool-tokens}
    function tokens() external virtual override view returns(address[] memory) {
        return s.tokens;
    }

    /// @dev See {IGammaPool-vaultImplementation}
    function vaultImplementation() internal virtual override view returns(address) {
        return shortStrategy;
    }

    /// @dev See {IRateModel-validateParameters}
    function validateParameters(bytes calldata _data) external view returns(bool) {
        return IRateModel(borrowStrategy).validateParameters(_data);
    }

    /// @dev See {IRateModel-rateParamsStore}
    function rateParamsStore() external view returns(address) {
        return s.factory;
    }

    /***** CFMM Data *****/

    /// @dev See {GammaPoolERC4626-_getLatestCFMMReserves}
    function _getLatestCFMMReserves() internal virtual override view returns(uint128[] memory cfmmReserves) {
        return IShortStrategy(shortStrategy)._getLatestCFMMReserves(abi.encode(s.cfmm));
    }

    /// @dev See {GammaPoolERC4626-_getLatestCFMMInvariant}
    function _getLatestCFMMInvariant() internal virtual override view returns(uint256 lastCFMMInvariant) {
        return IShortStrategy(shortStrategy)._getLatestCFMMInvariant(abi.encode(s.cfmm));
    }

    /// @dev See {GammaPoolERC4626-_getLatestCFMMTotalSupply}
    function _getLatestCFMMTotalSupply() internal virtual override view returns(uint256 lastCFMMTotalSupply) {
        return GammaSwapLibrary.totalSupply(s.cfmm);
    }

    /// @dev See {IGammaPool-getLatestCFMMReserves}
    function getLatestCFMMReserves() external virtual override view returns(uint128[] memory cfmmReserves) {
        return _getLatestCFMMReserves();
    }

    /// @dev See {IGammaPool-getCFMMBalances}
    function getLatestCFMMBalances() external virtual override view returns(uint128[] memory cfmmReserves, uint256 cfmmInvariant, uint256 cfmmTotalSupply) {
        return(_getLatestCFMMReserves(), _getLatestCFMMInvariant(), _getLatestCFMMTotalSupply());
    }

    /// @dev See {IGammaPool.getLastCFMMPrice}.
    function getLastCFMMPrice() external virtual override view returns(uint256) {
        return _getLastCFMMPrice();
    }

    /***** GammaPool Data *****/

    /// @dev See {IGammaPool-getPoolBalances}
    function getPoolBalances() external virtual override view returns(uint128[] memory tokenBalances, uint256 lpTokenBalance, uint256 lpTokenBorrowed,
        uint256 lpTokenBorrowedPlusInterest, uint256 borrowedInvariant, uint256 lpInvariant) {
        return(s.TOKEN_BALANCE, s.LP_TOKEN_BALANCE, s.LP_TOKEN_BORROWED, s.LP_TOKEN_BORROWED_PLUS_INTEREST, s.BORROWED_INVARIANT, s.LP_INVARIANT);
    }

    /// @dev See {IGammaPool-getCFMMBalances}
    function getCFMMBalances() external virtual override view returns(uint128[] memory cfmmReserves, uint256 cfmmInvariant, uint256 cfmmTotalSupply) {
        return(s.CFMM_RESERVES, s.lastCFMMInvariant, s.lastCFMMTotalSupply);
    }

    /// @dev See {IGammaPool-getRates}
    function getRates() external virtual override view returns(uint256 accFeeIndex, uint256 lastCFMMFeeIndex, uint256 lastBlockNumber) {
        return(s.accFeeIndex, s.lastCFMMFeeIndex, s.LAST_BLOCK_NUMBER);
    }

    /// @dev See {IGammaPool-getPoolData}
    function getPoolData() external virtual override view returns(PoolData memory data) {
        data.poolId = address(this);
        data.protocolId = protocolId;
        data.borrowStrategy = borrowStrategy;
        data.repayStrategy = repayStrategy;
        data.rebalanceStrategy = rebalanceStrategy;
        data.shortStrategy = shortStrategy;
        data.singleLiquidationStrategy = singleLiquidationStrategy;
        data.batchLiquidationStrategy = batchLiquidationStrategy;
        data.cfmm = s.cfmm;
        data.currBlockNumber = uint40(block.number);
        data.LAST_BLOCK_NUMBER = s.LAST_BLOCK_NUMBER;
        data.factory = s.factory;
        data.paramsStore = s.factory;
        data.LP_TOKEN_BALANCE = s.LP_TOKEN_BALANCE;
        data.LP_TOKEN_BORROWED = s.LP_TOKEN_BORROWED;
        data.totalSupply = s.totalSupply;
        data.TOKEN_BALANCE = s.TOKEN_BALANCE;
        data.tokens = s.tokens;
        data.decimals = s.decimals;
        data.LP_TOKEN_BORROWED_PLUS_INTEREST = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        data.BORROWED_INVARIANT = s.BORROWED_INVARIANT;
        data.LP_INVARIANT = s.LP_INVARIANT;
        data.accFeeIndex = s.accFeeIndex;
        data.ltvThreshold = s.ltvThreshold;
        data.liquidationFee = s.liquidationFee;
        data.origFee = s.origFee;
        data.extSwapFee = s.extSwapFee;
        data.lastCFMMFeeIndex = s.lastCFMMFeeIndex;
        data.lastCFMMInvariant = s.lastCFMMInvariant;
        data.lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        data.CFMM_RESERVES = s.CFMM_RESERVES;
        data.emaUtilRate = s.emaUtilRate;
        data.emaMultiplier = s.emaMultiplier;
        data.minUtilRate1 = s.minUtilRate1;
        data.minUtilRate2 = s.minUtilRate2;
        data.feeDivisor = s.feeDivisor;
        data.minBorrow = s.minBorrow;
    }

    /***** SHORT *****/

    /// @dev See {IGammaPool-depositNoPull}
    function depositNoPull(address to) external virtual override whenNotPaused(5) returns(uint256 shares) {
        return abi.decode(callStrategy(shortStrategy, abi.encodeCall(IShortStrategy._depositNoPull, to)), (uint256));
    }

    /// @dev See {IGammaPool-withdrawNoPull}
    function withdrawNoPull(address to) external virtual override whenNotPaused(6) returns(uint256 assets) {
        return abi.decode(callStrategy(shortStrategy, abi.encodeCall(IShortStrategy._withdrawNoPull, to)), (uint256));
    }

    /// @dev See {IGammaPool-depositReserves}
    function depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external virtual override whenNotPaused(7) returns(uint256[] memory reserves, uint256 shares){
        return abi.decode(callStrategy(shortStrategy, abi.encodeCall(IShortStrategy._depositReserves, (to, amountsDesired, amountsMin, data))), (uint256[],uint256));
    }

    /// @dev See {IGammaPool-withdrawReserves}
    function withdrawReserves(address to) external virtual override whenNotPaused(8) returns (uint256[] memory reserves, uint256 assets) {
        return abi.decode(callStrategy(shortStrategy, abi.encodeCall(IShortStrategy._withdrawReserves, to)), (uint256[],uint256));
    }

    /***** LONG *****/

    /// @dev See {IGammaPool-createLoan}
    function createLoan(uint16 refId) external lock virtual override whenNotPaused(9) returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length, refId);
        emit LoanCreated(msg.sender, tokenId, refId);
    }

    /// @dev See {IGammaPool-loan}
    function loan(uint256 tokenId) external virtual override view returns(LoanData memory _loanData) {
        _loanData = _getLoanData(tokenId);
    }

    /// @dev Get loan and convert to LoanData struct
    /// @param _tokenId - tokenId of loan to convert
    /// @return _loanData - loan data struct (same as Loan + tokenId)
    function _getLoanData(uint256 _tokenId) internal virtual view returns(LoanData memory _loanData) {
        LibStorage.Loan memory _loan = s.loans[_tokenId];
        _loanData.tokenId = _tokenId;
        _loanData.id = _loan.id;
        _loanData.poolId = _loan.poolId;
        _loanData.tokensHeld = _loan.tokensHeld;
        _loanData.initLiquidity = _loan.initLiquidity;
        _loanData.lastLiquidity = _loan.liquidity;
        _loanData.liquidity = _loan.liquidity;
        _loanData.lpTokens = _loan.lpTokens;
        _loanData.rateIndex = _loan.rateIndex;
        _loanData.px = _loan.px;
        _loanData.refAddr = _loan.refAddr;
        _loanData.refFee = _loan.refFee;
        _loanData.refType = _loan.refType;
    }

    /// @dev Get loan and convert to LoanData struct
    /// @param _tokenId - tokenId of loan to convert
    /// @return _loanData - loan data struct (same as Loan + tokenId)
    function getLoanData(uint256 _tokenId) public virtual override view returns(LoanData memory _loanData) {
        _loanData = _getLoanData(_tokenId);
        _loanData.tokens = s.tokens;
        _loanData.decimals = s.decimals;
        _loanData.paramsStore = s.factory;
        _loanData.shortStrategy = shortStrategy;
        _loanData.accFeeIndex = s.accFeeIndex;
        _loanData.LAST_BLOCK_NUMBER = s.LAST_BLOCK_NUMBER;
        _loanData.BORROWED_INVARIANT = s.BORROWED_INVARIANT;
        _loanData.LP_INVARIANT = s.LP_INVARIANT;
        _loanData.LP_TOKEN_BALANCE = s.LP_TOKEN_BALANCE;
        _loanData.lastCFMMInvariant = s.lastCFMMInvariant;
        _loanData.lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        _loanData.ltvThreshold = s.ltvThreshold;
        _loanData.liquidationFee = s.liquidationFee;
        _loanData.lastCFMMFeeIndex = s.lastCFMMFeeIndex;
    }

    /// @dev See {IGammaPool-getLoans}
    function getLoans(uint256 start, uint256 end, bool active) external virtual override view returns(LoanData[] memory _loans) {
        uint256[] storage _tokenIds = s.tokenIds;
        if(start > end || _tokenIds.length == 0) {
            return _loans;
        }
        uint256 lastIdx;
        unchecked {
            lastIdx = _tokenIds.length - 1;
        }
        end = lastIdx < end ? lastIdx : end; // end = min(lastIdx,end) <= min(type(uint256).max-1,end)
        if(start <= end) {
            unchecked {
                _loans = new LoanData[](1 + end - start);
            }
            LoanData memory _loan;
            uint256 k = 0;
            for(uint256 i = start; i <= end;) {
                _loan = _getLoanData(_tokenIds[i]);
                if(!active || _loan.initLiquidity > 0) {
                    _loans[k] = _loan;
                    unchecked {
                        ++k;
                    }
                }
                unchecked {
                    ++i;
                }
            }
        }
        return _loans;
    }

    /// @dev See {IGammaPool-getLoansById}
    function getLoansById(uint256[] calldata tokenIds, bool active) external virtual override view returns(LoanData[] memory _loans) {
        uint256 _size = tokenIds.length;
        _loans = new LoanData[](_size);
        LoanData memory _loan;
        uint256 k = 0;
        for(uint256 i = 0; i < _size;) {
            _loan = _getLoanData(tokenIds[i]);
            if(_loan.id > 0 && (!active || _loan.initLiquidity > 0)) {
                _loans[k] = _loan;
                unchecked {
                    ++k;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @dev calculate liquidity invariant from collateral tokens
    /// @param tokensHeld - loan's collateral tokens
    /// @return collateralInvariant - invariant calculated from loan's collateral tokens
    function _calcInvariant(uint128[] memory tokensHeld) internal virtual view returns(uint256);

    /// @dev See {IGammaPool-calcInvariant}
    function calcInvariant(uint128[] memory tokensHeld) external virtual override view returns(uint256) {
        return _calcInvariant(tokensHeld);
    }

    /// @dev See {IGammaPool-getLoanCount}
    function getLoanCount() external virtual override view returns(uint256) {
        return s.tokenIds.length;
    }

    /// @dev See {IGammaPool-increaseCollateral}
    function increaseCollateral(uint256 tokenId, uint256[] calldata ratio) external virtual override whenNotPaused(10) returns(uint128[] memory tokensHeld) {
        return abi.decode(callStrategy(borrowStrategy, abi.encodeCall(IBorrowStrategy._increaseCollateral, (tokenId, ratio))), (uint128[]));
    }

    /// @dev See {IGammaPool-decreaseCollateral}
    function decreaseCollateral(uint256 tokenId, uint128[] memory amounts, address to, uint256[] calldata ratio) external virtual override whenNotPaused(11) returns(uint128[] memory tokensHeld) {
        return abi.decode(callStrategy(borrowStrategy, abi.encodeCall(IBorrowStrategy._decreaseCollateral, (tokenId, amounts, to, ratio))), (uint128[]));
    }

    /// @dev See {IGammaPool-borrowLiquidity}
    function borrowLiquidity(uint256 tokenId, uint256 lpTokens, uint256[] calldata ratio) external virtual override whenNotPaused(12) returns(uint256 liquidityBorrowed, uint256[] memory amounts, uint128[] memory tokensHeld) {
        return abi.decode(callStrategy(borrowStrategy, abi.encodeCall(IBorrowStrategy._borrowLiquidity, (tokenId, lpTokens, ratio))), (uint256, uint256[], uint128[]));
    }

    /// @dev See {IGammaPool-repayLiquidity}
    function repayLiquidity(uint256 tokenId, uint256 liquidity, uint256 collateralId, address to) external virtual override whenNotPaused(13) returns(uint256 liquidityPaid, uint256[] memory amounts) {
        return abi.decode(callStrategy(repayStrategy, abi.encodeCall(IRepayStrategy._repayLiquidity, (tokenId, liquidity, collateralId, to))), (uint256, uint256[]));
    }

    /// @dev See {IGammaPool-repayLiquiditySetRatio}
    function repayLiquiditySetRatio(uint256 tokenId, uint256 liquidity, uint256[] calldata ratio) external virtual override whenNotPaused(14) returns(uint256 liquidityPaid, uint256[] memory amounts) {
        return abi.decode(callStrategy(repayStrategy, abi.encodeCall(IRepayStrategy._repayLiquiditySetRatio, (tokenId, liquidity, ratio))), (uint256, uint256[]));
    }

    /// @dev See {IGammaPool-repayLiquidityWithLP}
    function repayLiquidityWithLP(uint256 tokenId, uint256 collateralId, address to) external virtual override whenNotPaused(15) returns(uint256 liquidityPaid, uint128[] memory tokensHeld) {
        return abi.decode(callStrategy(repayStrategy, abi.encodeCall(IRepayStrategy._repayLiquidityWithLP, (tokenId, collateralId, to))), (uint256, uint128[]));
    }

    /// @dev See {IGammaPool-rebalanceCollateral}
    function rebalanceCollateral(uint256 tokenId, int256[] memory deltas, uint256[] calldata ratio) external virtual override whenNotPaused(16) returns(uint128[] memory tokensHeld) {
        return abi.decode(callStrategy(rebalanceStrategy, abi.encodeCall(IRebalanceStrategy._rebalanceCollateral, (tokenId, deltas, ratio))), (uint128[]));
    }

    /// @dev See {IGammaPool-updatePool}
    function updatePool(uint256 tokenId) external virtual override whenNotPaused(17) returns(uint256 loanLiquidityDebt, uint256 poolLiquidityDebt) {
        return abi.decode(callStrategy(rebalanceStrategy, abi.encodeCall(IRebalanceStrategy._updatePool, tokenId)), (uint256, uint256));
    }

    /// @dev See {IGammaPool-liquidate}
    function liquidate(uint256 tokenId) external virtual override whenNotPaused(18) returns(uint256 loanLiquidity, uint256 refund) {
        return abi.decode(callStrategy(singleLiquidationStrategy, abi.encodeCall(ISingleLiquidationStrategy._liquidate, tokenId)), (uint256, uint256));
    }

    /// @dev See {IGammaPool-liquidateWithLP}
    function liquidateWithLP(uint256 tokenId) external virtual override whenNotPaused(19) returns(uint256 loanLiquidity, uint256[] memory refund) {
        return abi.decode(callStrategy(singleLiquidationStrategy, abi.encodeCall(ISingleLiquidationStrategy._liquidateWithLP, tokenId)), (uint256, uint256[]));
    }

    /// @dev See {IGammaPool-batchLiquidations}
    function batchLiquidations(uint256[] calldata tokenIds) external virtual override whenNotPaused(20) returns(uint256 totalLoanLiquidity, uint256[] memory refund) {
        return abi.decode(callStrategy(batchLiquidationStrategy, abi.encodeCall(IBatchLiquidationStrategy._batchLiquidations, tokenIds)), (uint256, uint256[]));
    }

    /***** SYNC POOL *****/

    /// @dev See {IGammaPool-sync}
    function sync() external virtual override whenNotPaused(21) {
        callStrategy(shortStrategy, abi.encodeCall(IShortStrategy._sync, ()));
    }

    /// @dev See {IGammaPool-skim}
    function skim(address to) external virtual override lock whenNotPaused(22) {
        address[] memory _tokens = s.tokens; // gas savings
        uint128[] memory _tokenBalances = s.TOKEN_BALANCE;
        for(uint256 i; i < _tokens.length;) {
            skim(_tokens[i], _tokenBalances[i], to); // skim collateral tokens
            unchecked {
                ++i;
            }
        }
        skim(s.cfmm, s.LP_TOKEN_BALANCE, to); // skim cfmm LP tokens
    }

    /// @dev See {ITransfers-clearToken}
    function clearToken(address token, address to, uint256 minAmt) external override virtual lock whenNotPaused(23) {
        // Can't clear CFMM LP tokens or collateral tokens
        if(isCFMMToken(token) || isCollateralToken(token)) revert RestrictedToken();

        uint256 tokenBal = IERC20(token).balanceOf(address(this));
        if(tokenBal < minAmt) revert NotEnoughTokens(); // Only clear if past threshold

        // If not CFMM LP token or collateral token send entire amount
        if (tokenBal > 0) GammaSwapLibrary.safeTransfer(token, to, tokenBal);
    }

    /// @dev See {Transfers-isCFMMToken}
    function isCFMMToken(address token) internal virtual override view returns(bool) {
        return token == s.cfmm;
    }

    /// @dev See {Transfers-isCollateralToken}
    function isCollateralToken(address token) internal virtual override view returns(bool) {
        address[] memory _tokens = s.tokens; // gas savings
        for(uint256 i; i < _tokens.length;) {
            if(token == _tokens[i]) {
                return true;
            }
            unchecked {
                ++i;
            }
        }
        return false;
    }
}
