// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "../libraries/GammaSwapLibrary.sol";
import "../interfaces/IPoolViewer.sol";
import "../interfaces/IGammaPool.sol";
import "../interfaces/observer/ICollateralManager.sol";
import "../interfaces/strategies/base/ILiquidationStrategy.sol";
import "../interfaces/strategies/base/ILongStrategy.sol";
import "../interfaces/strategies/base/IShortStrategy.sol";
import "../interfaces/strategies/lending/IBorrowStrategy.sol";
import "../libraries/GSMath.sol";

/// @title Implementation of Viewer Contract for GammaPool
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used make complex view function calls from GammaPool's storage data (e.g. updated loan and pool debt)
contract PoolViewer is IPoolViewer {

    /// @dev See {IPoolViewer-getLoans}
    function getLoans(address pool, uint256 start, uint256 end, bool active) external virtual override view returns(IGammaPool.LoanData[] memory _loans) {
        _loans = IGammaPool(pool).getLoans(start, end, active);
        return _getUpdatedLoans(pool, _loans);
    }

    /// @dev See {IPoolViewer-getLoansById}
    function getLoansById(address pool, uint256[] calldata tokenIds, bool active) external virtual override view returns(IGammaPool.LoanData[] memory _loans) {
        _loans = IGammaPool(pool).getLoansById(tokenIds, active);
        return _getUpdatedLoans(pool, _loans);
    }

    /// @dev Get interest rate changes per source, utilization rate, and borrowing and supply APR charged to users
    /// @param pool - address of GammaPool loans in `_loans` array belongs to
    /// @param _loans - list of LoanData structs containing loan information to update
    /// @return updatedLoans - updated accFeeIndex of pool loan belongs to
    function _getUpdatedLoans(address pool, IGammaPool.LoanData[] memory _loans) internal virtual view returns(IGammaPool.LoanData[] memory) {
        address[] memory _tokens = IGammaPool(pool).tokens();
        (string[] memory _symbols, string[] memory _names, uint8[] memory _decimals) = getTokensMetaData(_tokens);
        IGammaPool.RateData memory data = _getLastFeeIndex(pool);
        address liquidationStrategy = IGammaPool(pool).singleLiquidationStrategy();
        uint256 _size = _loans.length;
        IGammaPool.LoanData memory _loan;
        for(uint256 i = 0; i < _size;) {
            _loan = _loans[i];
            if(_loan.id == 0) {
                break;
            }
            _loan.tokens = _tokens;
            _loan.symbols = _symbols;
            _loan.names = _names;
            _loan.decimals = _decimals;
            _loan.liquidity = _updateLiquidity(_loan.liquidity, _loan.rateIndex, data.accFeeIndex);
            address refAddr = _loan.refType == 3 ? _loan.refAddr : address(0);
            _loan.collateral = _collateral(pool, _loan.tokenId, _loan.tokensHeld, refAddr);
            _loan.canLiquidate = ILiquidationStrategy(liquidationStrategy).canLiquidate(_loan.liquidity, _loan.collateral);
            unchecked {
                ++i;
            }
        }
        return _loans;
    }

    /*function canLiquidate(uint256 liquidity, uint256 collateral, uint256 ltvThreshold) internal virtual override view returns(bool) {
        return !hasMargin(collateral, liquidity, ltvThreshold);
    }

    function hasMargin(uint256 collateral, uint256 liquidity, uint256 limit) internal virtual pure returns(bool) {
        return collateral * limit / 1e4 >= liquidity;
    }/**/

    /// @dev See {IPoolViewer-loan}
    function loan(address pool, uint256 tokenId) external virtual override view returns(IGammaPool.LoanData memory _loanData) {
        _loanData = IGammaPool(pool).getLoanData(tokenId);
        _loanData.accFeeIndex = _getLoanLastFeeIndex(_loanData);
        _loanData.liquidity = _updateLiquidity(_loanData.liquidity, _loanData.rateIndex, _loanData.accFeeIndex);
        address refAddr = _loanData.refType == 3 ? _loanData.refAddr : address(0);
        _loanData.collateral = _collateral(pool, tokenId, _loanData.tokensHeld, refAddr);
        _loanData.canLiquidate = ILiquidationStrategy(_loanData.liquidationStrategy).canLiquidate(_loanData.liquidity, _loanData.collateral);
        (_loanData.symbols, _loanData.names, _loanData.decimals) = getTokensMetaData(_loanData.tokens);
        return _loanData;
    }

    /// @dev See {IGammaPool-canLiquidate}
    function canLiquidate(address pool, uint256 tokenId) external virtual override view returns(bool) {
        IGammaPool.LoanData memory _loanData = IGammaPool(pool).getLoanData(tokenId);
        uint256 accFeeIndex = _getLoanLastFeeIndex(_loanData);
        uint256 liquidity = _updateLiquidity(_loanData.liquidity, _loanData.rateIndex, accFeeIndex);
        address refAddr = _loanData.refType == 3 ? _loanData.refAddr : address(0);
        uint256 collateral = _collateral(pool, tokenId, _loanData.tokensHeld, refAddr);
        return ILiquidationStrategy(_loanData.liquidationStrategy).canLiquidate(liquidity, collateral);
    }

    /// @dev Get interest rate changes per source, utilization rate, and borrowing and supply APR charged to users
    /// @param _loanData - struct containing necessary loan information to calculate accFeeIndex
    /// @return accFeeIndex - updated accFeeIndex of pool loan belongs to
    function _getLoanLastFeeIndex(IGammaPool.LoanData memory _loanData) internal virtual view returns(uint256 accFeeIndex) {
        uint256 lastCFMMInvariant;
        uint256 lastCFMMTotalSupply;
        (, lastCFMMInvariant, lastCFMMTotalSupply) = IGammaPool(_loanData.poolId).getLatestCFMMBalances();

        (,uint256 lastFeeIndex,,) = IShortStrategy(_loanData.shortStrategy).getLastFees(_loanData.factory,
            _loanData.BORROWED_INVARIANT, _loanData.LP_TOKEN_BALANCE, lastCFMMInvariant, lastCFMMTotalSupply,
            _loanData.lastCFMMInvariant, _loanData.lastCFMMTotalSupply, _loanData.LAST_BLOCK_NUMBER, _loanData.poolId);

        accFeeIndex = _loanData.accFeeIndex * lastFeeIndex / 1e18;
    }

    /// @dev Get collateral in terms of liquidity invariant units for loan identified by `tokenId`
    /// @param pool - address of GammaPool loan belongs to
    /// @param tokenId - unique id of loan, used to look up loan in GammaPool
    /// @param tokensHeld - tokens held in GammaPool as collateral for loan
    /// @param refAddr - address of contract holding additional collateral for loan
    /// @return collateral - collateral of loan in terms of liquidity invariant units;
    function _collateral(address pool, uint256 tokenId, uint128[] memory tokensHeld, address refAddr) internal virtual view returns(uint256 collateral) {
        collateral = IGammaPool(pool).calcInvariant(tokensHeld);
        if(refAddr != address(0)) {
            collateral += ICollateralManager(refAddr).getCollateral(pool, tokenId);
        }
    }

    /// @dev See {IPoolViewer-calcDynamicOriginationFee}
    function calcDynamicOriginationFee(address pool, uint256 liquidity) external virtual override view returns(uint256 origFee) {
        IGammaPool.RateData memory data = _getLastFeeIndex(pool);

        uint256 utilRate = _calcUtilizationRate(data.LP_INVARIANT - liquidity, data.BORROWED_INVARIANT + liquidity) / 1e16;// convert utilizationRate to integer
        uint256 emaUtilRate = data.emaUtilRate / 1e4; // convert ema to integer

        origFee = IBorrowStrategy(IGammaPool(pool).borrowStrategy()).calcDynamicOriginationFee(data.origFee, utilRate, emaUtilRate, data.minUtilRate1, data.minUtilRate2, data.feeDivisor);
    }

    /// @dev Calculate utilization rate from borrowed invariant and invariant from LP tokens in GammaPool
    /// @param lpInvariant - liquidity invariant from LP tokens deposited in GammaPool
    /// @param borrowedInvariant - liquidity invariant units borrowed from GammaPool
    /// @return utilizationRate - utilization rate based on `borrowedInvariant` and `lpInvariant`
    function _calcUtilizationRate(uint256 lpInvariant, uint256 borrowedInvariant) internal view returns(uint256) {
        uint256 totalInvariant = borrowedInvariant + lpInvariant;
        if(totalInvariant == 0) {
            return 0;
        }
        return borrowedInvariant * 1e18 / totalInvariant;
    }

    /// @dev Get interest rate changes per source, utilization rate, and borrowing and supply APR charged to users
    /// @param pool - struct containing necessary loan information to calculate accFeeIndex
    /// @param data - struct containing updated fee index information from pool
    function _getLastFeeIndex(address pool) internal virtual view returns(IGammaPool.RateData memory data) {
        IGammaPool.FeeIndexUpdateParams memory params = IGammaPool(pool).getFeeIndexUpdateParams();

        uint256 lastCFMMInvariant;
        uint256 lastCFMMTotalSupply;
        (, lastCFMMInvariant, lastCFMMTotalSupply) = IGammaPool(pool).getLatestCFMMBalances();

        (data.lastCFMMFeeIndex,data.lastFeeIndex,data.borrowRate,data.utilizationRate) = IShortStrategy(params.shortStrategy)
        .getLastFees(params.factory, params.BORROWED_INVARIANT, params.LP_TOKEN_BALANCE, lastCFMMInvariant, lastCFMMTotalSupply,
            params.lastCFMMInvariant, params.lastCFMMTotalSupply, params.LAST_BLOCK_NUMBER, params.pool);

        (,, data.BORROWED_INVARIANT) = IShortStrategy(params.shortStrategy)
        .getLatestBalances(data.lastFeeIndex, params.BORROWED_INVARIANT, params.LP_TOKEN_BALANCE,
            lastCFMMInvariant, lastCFMMTotalSupply);

        data.LP_INVARIANT = uint128(params.LP_TOKEN_BALANCE * lastCFMMInvariant / lastCFMMTotalSupply);

        data.utilizationRate = _calcUtilizationRate(data.LP_INVARIANT, data.BORROWED_INVARIANT);
        data.emaUtilRate = uint40(IShortStrategy(params.shortStrategy).calcUtilRateEma(data.utilizationRate, params.emaUtilRate, params.emaMultiplier));
        data.origFee = params.origFee;
        data.feeDivisor = params.feeDivisor;
        data.minUtilRate1 = params.minUtilRate1;
        data.minUtilRate2 = params.minUtilRate2;
        data.ltvThreshold = params.ltvThreshold;
        data.liquidationFee = params.liquidationFee;

        data.accFeeIndex = params.accFeeIndex * data.lastFeeIndex / 1e18;
        data.lastBlockNumber = params.LAST_BLOCK_NUMBER;
        data.currBlockNumber = block.number;
    }

    /// @dev See {IPoolViewer-getLatestRates}
    function getLatestRates(address pool) external virtual override view returns(IGammaPool.RateData memory data) {
        data = _getLastFeeIndex(pool);
        data.currBlockNumber = block.number;
        data.lastPrice = IGammaPool(pool).getLastCFMMPrice();
        data.supplyRate = data.borrowRate * data.utilizationRate / 1e18;
    }

    /// @dev See {IPoolViewer-getLatestPoolData}
    function getLatestPoolData(address pool) external virtual override view returns(IGammaPool.PoolData memory data) {
        data = getPoolData(pool);
        uint256 borrowedInvariant = data.BORROWED_INVARIANT;
        uint256 lastCFMMInvariant;
        uint256 lastCFMMTotalSupply;
        (data.CFMM_RESERVES, lastCFMMInvariant, lastCFMMTotalSupply) = IGammaPool(pool).getLatestCFMMBalances();

        uint256 lastCFMMFeeIndex;
        (lastCFMMFeeIndex, data.lastFeeIndex, data.borrowRate, data.utilizationRate) = IShortStrategy(data.shortStrategy)
        .getLastFees(data.factory, borrowedInvariant, data.LP_TOKEN_BALANCE, lastCFMMInvariant, lastCFMMTotalSupply,
            data.lastCFMMInvariant, data.lastCFMMTotalSupply, data.LAST_BLOCK_NUMBER, pool);

        data.supplyRate = data.borrowRate * data.utilizationRate / 1e18;

        data.lastCFMMFeeIndex = uint64(lastCFMMFeeIndex);
        (,data.LP_TOKEN_BORROWED_PLUS_INTEREST, borrowedInvariant) = IShortStrategy(data.shortStrategy)
        .getLatestBalances(data.lastFeeIndex, borrowedInvariant, data.LP_TOKEN_BALANCE,
            lastCFMMInvariant, lastCFMMTotalSupply);

        data.BORROWED_INVARIANT = uint128(borrowedInvariant);
        data.LP_INVARIANT = uint128(data.LP_TOKEN_BALANCE * lastCFMMInvariant / lastCFMMTotalSupply);
        data.accFeeIndex = uint80(data.accFeeIndex * data.lastFeeIndex / 1e18);

        data.utilizationRate = _calcUtilizationRate(data.LP_INVARIANT, data.BORROWED_INVARIANT);
        data.emaUtilRate = uint40(IShortStrategy(data.shortStrategy).calcUtilRateEma(data.utilizationRate, data.emaUtilRate, data.emaMultiplier));

        data.lastPrice = IGammaPool(pool).getLastCFMMPrice();
        data.lastCFMMInvariant = uint128(lastCFMMInvariant);
        data.lastCFMMTotalSupply = lastCFMMTotalSupply;
    }

    /// @dev See {IPoolViewer-getPoolData}
    function getPoolData(address pool) public virtual override view returns(IGammaPool.PoolData memory data) {
        data = IGammaPool(pool).getPoolData();
        (data.symbols, data.names,) = getTokensMetaData(data.tokens);
    }

    /// dev See {IPoolViewer-getTokensMetaData}
    function getTokensMetaData(address[] memory _tokens) public virtual override view returns(string[] memory _symbols,
        string[] memory _names, uint8[] memory _decimals) {
        _symbols = new string[](_tokens.length);
        _names = new string[](_tokens.length);
        _decimals = new uint8[](_tokens.length);
        for(uint256 i = 0; i < _tokens.length;) {
            _symbols[i] = GammaSwapLibrary.symbol(_tokens[i]);
            _names[i] = GammaSwapLibrary.name(_tokens[i]);
            _decimals[i] = GammaSwapLibrary.decimals(_tokens[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Update liquidity to current debt level
    /// @param liquidity - loan's liquidity debt
    /// @param rateIndex - accFeeIndex in last update of loan's liquidity debt
    /// @param accFeeIndex - current accFeeIndex
    /// @return updatedLiquidity - liquidity debt updated to current time
    function _updateLiquidity(uint256 liquidity, uint256 rateIndex, uint256 accFeeIndex) internal virtual view returns(uint128) {
        return rateIndex == 0 ? 0 : uint128(liquidity * accFeeIndex / rateIndex);
    }
}
