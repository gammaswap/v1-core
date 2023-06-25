pragma solidity >=0.8.4;

import "../libraries/GammaSwapLibrary.sol";
import "../interfaces/IPoolViewer.sol";
import "../interfaces/IGammaPool.sol";
import "../interfaces/ICollateralManager.sol";
import "../interfaces/strategies/base/ILiquidationStrategy.sol";
import "../interfaces/strategies/base/ILongStrategy.sol";
import "../interfaces/strategies/base/IShortStrategy.sol";

contract GammaPoolViewer is IPoolViewer {

    /// @dev See {IGammaPool-canLiquidate}
    function canLiquidate(address pool, uint256 tokenId) external virtual override view returns(bool) {
        IGammaPool.LoanData memory _loan = IGammaPool(pool).getLoanData(tokenId);
        IGammaPool.RateData memory data = _getLastFeeIndex(pool);
        uint256 liquidity = _updateLiquidity(_loan.liquidity, _loan.rateIndex, data.accFeeIndex);
        uint256 collateral = collateral(pool, tokenId, _loan.tokensHeld, _loan.collateralRef);
        return ILiquidationStrategy(_loan.liquidationStrategy).canLiquidate(liquidity, collateral);
    }

    /// @dev See {IGammaPool-getLatestRates}
    function getLatestRates(address pool) external virtual override view returns(IGammaPool.RateData memory data) {
        data = _getLastFeeIndex(pool);
        data.currBlockNumber = block.number;
        data.lastPrice = IGammaPool(pool).getLastCFMMPrice();
        data.supplyRate = data.borrowRate * data.utilizationRate / 1e18;/**/
    }

    /// @dev See {IGammaPool-getLoans}
    function getLoans(address pool, uint256 start, uint256 end, bool active) external virtual override view returns(IGammaPool.LoanData[] memory _loans) {
        _loans = IGammaPool(pool).getLoans(start, end, active);
        return getUpdatedLoans(pool, _loans);
    }

    /// @dev See {IGammaPool-getLoansById}
    function getLoansById(address pool, uint256[] calldata tokenIds, bool active) external virtual override view returns(IGammaPool.LoanData[] memory _loans) {
        _loans = IGammaPool(pool).getLoansById(tokenIds, active);
        return getUpdatedLoans(pool, _loans);
    }

    function getUpdatedLoans(address pool, IGammaPool.LoanData[] memory _loans) internal virtual view returns(IGammaPool.LoanData[] memory) {
        address[] memory _tokens = IGammaPool(pool).tokens();
        (string[] memory _symbols, string[] memory _names, uint8[] memory _decimals) = getTokensMetaData(_tokens);
        IGammaPool.RateData memory data = _getLastFeeIndex(pool);
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
            _loan.collateral = collateral(pool, _loan.tokenId, _loan.tokensHeld, _loan.collateralRef);
            _loan.canLiquidate = ILiquidationStrategy(_loan.liquidationStrategy).canLiquidate(_loan.liquidity, _loan.collateral);
            unchecked {
                ++i;
            }
        }
        return _loans;
    }

    /// @dev See {IGammaPool-loan}
    function loan(address pool, uint256 tokenId) external virtual override view returns(IGammaPool.LoanData memory _loanData) {
        _loanData = IGammaPool(pool).getLoanData(tokenId);
        IGammaPool.RateData memory data = _getLastFeeIndex(pool);
        _loanData.liquidity = _updateLiquidity(_loanData.liquidity, _loanData.rateIndex, data.accFeeIndex);
        _loanData.collateral = collateral(pool, tokenId, _loanData.tokensHeld, _loanData.collateralRef);
        _loanData.canLiquidate = ILiquidationStrategy(_loanData.liquidationStrategy).canLiquidate(_loanData.liquidity, _loanData.collateral);
        (_loanData.symbols, _loanData.names, _loanData.decimals) = getTokensMetaData(_loanData.tokens);
        return _loanData;
    }

    /// @dev Get collateral in terms of liquidity invariant units for loan identified by `tokenId`
    /// @param pool - address of GammaPool loan belongs to
    /// @param tokenId - unique id of loan, used to look up loan in GammaPool
    /// @param tokensHeld - tokens held in GammaPool as collateral for loan
    /// @param collateralRef - address of contract holding additional collateral for loan
    /// @return collateral - collateral of loan in terms of liquidity invariant units;
    function collateral(address pool, uint256 tokenId, uint128[] memory tokensHeld, address collateralRef) internal virtual view returns(uint256 collateral) {
        collateral = IGammaPool(pool).calcInvariant(tokensHeld);
        if(collateralRef != address(0)) {
            collateral += ICollateralManager(collateralRef).getCollateral(pool, tokenId);
        }
    }

    /// @dev Get interest rate changes per source, utilization rate, and borrowing and supply APR charged to users
    /// @param pool - struct containing necessary loan information to calculate accFeeIndex
    function _getLastFeeIndex(address pool) internal virtual view returns(IGammaPool.RateData memory data) {

        IGammaPool.FeeIndexUpdateParams memory params = IGammaPool(pool).getFeeIndexUpdateParams();

        uint256 lastCFMMInvariant;
        uint256 lastCFMMTotalSupply;
        (, lastCFMMInvariant, lastCFMMTotalSupply) = IGammaPool(pool).getLatestCFMMBalances();

        (data.lastCFMMFeeIndex,data.lastFeeIndex,data.borrowRate,data.utilizationRate) = IShortStrategy(params.shortStrategy)
        .getLastFees(params.factory, params.BORROWED_INVARIANT, params.LP_TOKEN_BALANCE, lastCFMMInvariant, lastCFMMTotalSupply,
            params.lastCFMMInvariant, params.lastCFMMTotalSupply, params.LAST_BLOCK_NUMBER, params.pool);

        data.accFeeIndex = params.accFeeIndex * data.lastFeeIndex / 1e18;
        data.lastBlockNumber = params.LAST_BLOCK_NUMBER;
    }

    /// @dev See {IGammaPool-getLatestPoolData}
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

        data.lastCFMMFeeIndex = uint80(lastCFMMFeeIndex);
        (,data.LP_TOKEN_BORROWED_PLUS_INTEREST, borrowedInvariant) = IShortStrategy(data.shortStrategy)
        .getLatestBalances(data.lastFeeIndex, borrowedInvariant, data.LP_TOKEN_BALANCE,
            lastCFMMInvariant, lastCFMMTotalSupply);

        data.BORROWED_INVARIANT = uint128(borrowedInvariant);
        data.LP_INVARIANT = uint128(data.LP_TOKEN_BALANCE * lastCFMMInvariant / lastCFMMTotalSupply);
        data.accFeeIndex = uint96(data.accFeeIndex * data.lastFeeIndex / 1e18);

        data.lastPrice = IGammaPool(pool).getLastCFMMPrice();
        data.lastCFMMInvariant = uint128(lastCFMMInvariant);
        data.lastCFMMTotalSupply = lastCFMMTotalSupply;/**/
    }

    /// @dev See {IGammaPool-getPoolData}
    function getPoolData(address pool) public virtual override view returns(IGammaPool.PoolData memory data) {
        data = IGammaPool(pool).getPoolData();
        /*data.LP_TOKEN_BORROWED_PLUS_INTEREST = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        data.BORROWED_INVARIANT = s.BORROWED_INVARIANT;
        data.LP_INVARIANT = s.LP_INVARIANT;
        data.accFeeIndex = s.accFeeIndex;
        data.lastCFMMFeeIndex = s.lastCFMMFeeIndex;
        data.lastCFMMInvariant = s.lastCFMMInvariant;
        data.lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        data.CFMM_RESERVES = s.CFMM_RESERVES;/**/
        data.ltvThreshold = ILongStrategy(data.borrowStrategy).ltvThreshold();
        data.liquidationFee = ILiquidationStrategy(data.singleLiquidationStrategy).liquidationFee();
        (data.symbols, data.names,) = getTokensMetaData(data.tokens);
    }

    /// dev See {IGammaPool-getTokensMetaData}
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
                i++;
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
