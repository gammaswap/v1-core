// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../libraries/GammaSwapLibrary.sol";
import "../interfaces/IPoolViewer.sol";
import "../interfaces/IGammaPool.sol";
import "../interfaces/ITokenMetaData.sol";
import "../interfaces/observer/ICollateralManager.sol";
import "../interfaces/strategies/base/ILongStrategy.sol";
import "../interfaces/strategies/base/IShortStrategy.sol";
import "../interfaces/strategies/lending/IBorrowStrategy.sol";
import "../rates/AbstractRateModel.sol";
import "../libraries/GSMath.sol";

/// @title Implementation of Viewer Contract for GammaPool
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used make complex view function calls from GammaPool's storage data (e.g. updated loan and pool debt)
contract PoolViewer is IPoolViewer, ITokenMetaData {

    /// @inheritdoc IPoolViewer
    function getLoans(address pool, uint256 start, uint256 end, bool active) external virtual override view returns(IGammaPool.LoanData[] memory _loans) {
        _loans = IGammaPool(pool).getLoans(start, end, active);
        return _getUpdatedLoans(pool, _loans);
    }

    /// @inheritdoc IPoolViewer
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
            _loan.shortStrategy = data.shortStrategy;
            _loan.paramsStore = data.paramsStore;
            _loan.ltvThreshold = data.ltvThreshold;
            _loan.liquidationFee = data.liquidationFee;
            _loan.canLiquidate = _canLiquidate(_loan.liquidity, _loan.collateral, _loan.ltvThreshold);
            unchecked {
                ++i;
            }
        }
        return _loans;
    }

    /// @dev check if collateral is below loan-to-value threshold
    function _canLiquidate(uint256 liquidity, uint256 collateral, uint256 ltvThreshold) internal virtual view returns(bool) {
        return collateral * (10000 - ltvThreshold * 10) / 1e4 < liquidity;
    }

    /// @inheritdoc IPoolViewer
    function loan(address pool, uint256 tokenId) external virtual override view returns(IGammaPool.LoanData memory _loanData) {
        _loanData = IGammaPool(pool).getLoanData(tokenId);
        if(_loanData.id == 0) {
            return _loanData;
        }
        _loanData.accFeeIndex = _getLoanLastFeeIndex(_loanData);
        _loanData.liquidity = _updateLiquidity(_loanData.liquidity, _loanData.rateIndex, _loanData.accFeeIndex);
        address refAddr = _loanData.refType == 3 ? _loanData.refAddr : address(0);
        _loanData.collateral = _collateral(pool, tokenId, _loanData.tokensHeld, refAddr);
        _loanData.canLiquidate = _canLiquidate(_loanData.liquidity, _loanData.collateral, _loanData.ltvThreshold);
        (_loanData.symbols, _loanData.names, _loanData.decimals) = getTokensMetaData(_loanData.tokens);
        return _loanData;
    }

    /// @inheritdoc IPoolViewer
    function canLiquidate(address pool, uint256 tokenId) external virtual override view returns(bool) {
        IGammaPool.LoanData memory _loanData = IGammaPool(pool).getLoanData(tokenId);
        if(_loanData.liquidity == 0) {
            return false;
        }
        uint256 liquidity = _updateLiquidity(_loanData.liquidity, _loanData.rateIndex, _getLoanLastFeeIndex(_loanData));
        address refAddr = _loanData.refType == 3 ? _loanData.refAddr : address(0);
        uint256 collateral = _collateral(pool, tokenId, _loanData.tokensHeld, refAddr);
        return _canLiquidate(liquidity, collateral, _loanData.ltvThreshold);
    }

    /// @dev Get interest rate changes per source, utilization rate, and borrowing and supply APR charged to users
    /// @param _loanData - struct containing necessary loan information to calculate accFeeIndex
    /// @return accFeeIndex - updated accFeeIndex of pool loan belongs to
    function _getLoanLastFeeIndex(IGammaPool.LoanData memory _loanData) internal virtual view returns(uint256 accFeeIndex) {
        uint256 lastCFMMInvariant;
        uint256 lastCFMMTotalSupply;
        if(_loanData.poolId == address(0)) {
            return 1e18;
        }
        (, lastCFMMInvariant, lastCFMMTotalSupply) = IGammaPool(_loanData.poolId).getLatestCFMMBalances();
        if(lastCFMMTotalSupply == 0) {
            return 1e18;
        }

        // using lastFeeIndex to hold spread
        (uint256 borrowRate,,uint256 maxCFMMFeeLeverage,uint256 lastFeeIndex) = AbstractRateModel(_loanData.shortStrategy).calcBorrowRate(_loanData.LP_INVARIANT,
            _loanData.BORROWED_INVARIANT, _loanData.paramsStore, _loanData.poolId);

        (lastFeeIndex,) = IShortStrategy(_loanData.shortStrategy).getLastFees(borrowRate, _loanData.BORROWED_INVARIANT,
            lastCFMMInvariant, lastCFMMTotalSupply, _loanData.lastCFMMInvariant, _loanData.lastCFMMTotalSupply,
            _loanData.LAST_BLOCK_NUMBER, _loanData.lastCFMMFeeIndex, maxCFMMFeeLeverage, lastFeeIndex);

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

    /// @inheritdoc IPoolViewer
    function calcDynamicOriginationFee(address pool, uint256 liquidity) external virtual override view returns(uint256 origFee) {
        IGammaPool.RateData memory data = _getLastFeeIndex(pool);

        if(liquidity >= data.LP_INVARIANT) {
            return 10000;
        }

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
        IGammaPool.PoolData memory params = IGammaPool(pool).getPoolData();

        uint256 lastCFMMInvariant;
        uint256 lastCFMMTotalSupply;
        (, lastCFMMInvariant, lastCFMMTotalSupply) = IGammaPool(pool).getLatestCFMMBalances();
        if(lastCFMMTotalSupply > 0) {
            uint256 maxCFMMFeeLeverage;
            uint256 spread;
            (data.borrowRate,data.utilizationRate,maxCFMMFeeLeverage,spread) = AbstractRateModel(params.shortStrategy).calcBorrowRate(params.LP_INVARIANT,
                params.BORROWED_INVARIANT, params.paramsStore, pool);

            (data.lastFeeIndex,data.lastCFMMFeeIndex) = IShortStrategy(params.shortStrategy)
                .getLastFees(data.borrowRate, params.BORROWED_INVARIANT, lastCFMMInvariant, lastCFMMTotalSupply,
                params.lastCFMMInvariant, params.lastCFMMTotalSupply, params.LAST_BLOCK_NUMBER, params.lastCFMMFeeIndex,
                maxCFMMFeeLeverage, spread);

            data.supplyRate = data.borrowRate * data.utilizationRate / 1e18;

            (,, data.BORROWED_INVARIANT) = IShortStrategy(params.shortStrategy).getLatestBalances(data.lastFeeIndex,
                params.BORROWED_INVARIANT, params.LP_TOKEN_BALANCE, lastCFMMInvariant, lastCFMMTotalSupply);

            data.LP_INVARIANT = uint128(params.LP_TOKEN_BALANCE * lastCFMMInvariant / lastCFMMTotalSupply);

            data.utilizationRate = _calcUtilizationRate(data.LP_INVARIANT, data.BORROWED_INVARIANT);
            data.emaUtilRate = uint40(IShortStrategy(params.shortStrategy).calcUtilRateEma(data.utilizationRate, params.emaUtilRate,
                GSMath.max(block.number - params.LAST_BLOCK_NUMBER, params.emaMultiplier)));
        } else {
            data.lastFeeIndex = 1e18;
        }

        data.origFee = params.origFee;
        data.feeDivisor = params.feeDivisor;
        data.minUtilRate1 = params.minUtilRate1;
        data.minUtilRate2 = params.minUtilRate2;
        data.ltvThreshold = params.ltvThreshold;
        data.liquidationFee = params.liquidationFee;
        data.shortStrategy = params.shortStrategy;
        data.paramsStore = params.paramsStore;

        data.accFeeIndex = params.accFeeIndex * data.lastFeeIndex / 1e18;
        data.lastBlockNumber = params.LAST_BLOCK_NUMBER;
        data.currBlockNumber = block.number;
    }

    /// @inheritdoc IPoolViewer
    function getLatestRates(address pool) external virtual override view returns(IGammaPool.RateData memory data) {
        data = _getLastFeeIndex(pool);
        data.lastPrice = IGammaPool(pool).getLastCFMMPrice();
    }

    /// @inheritdoc IPoolViewer
    function getLatestPoolData(address pool) public virtual override view returns(IGammaPool.PoolData memory data) {
        data = getPoolData(pool);
        uint256 lastCFMMInvariant;
        uint256 lastCFMMTotalSupply;
        (data.CFMM_RESERVES, lastCFMMInvariant, lastCFMMTotalSupply) = IGammaPool(pool).getLatestCFMMBalances();
        if(lastCFMMTotalSupply == 0) {
            return data;
        }

        uint256 lastCFMMFeeIndex; // holding maxCFMMFeeLeverage temporarily
        uint256 borrowedInvariant; // holding spread temporarily
        (data.borrowRate, data.utilizationRate, lastCFMMFeeIndex, borrowedInvariant) = AbstractRateModel(data.shortStrategy).calcBorrowRate(data.LP_INVARIANT,
            data.BORROWED_INVARIANT, data.paramsStore, pool);

        (data.lastFeeIndex,lastCFMMFeeIndex) = IShortStrategy(data.shortStrategy)
        .getLastFees(data.borrowRate, data.BORROWED_INVARIANT, lastCFMMInvariant, lastCFMMTotalSupply,
            data.lastCFMMInvariant, data.lastCFMMTotalSupply, data.LAST_BLOCK_NUMBER, data.lastCFMMFeeIndex,
            lastCFMMFeeIndex, borrowedInvariant);

        data.supplyRate = data.borrowRate * data.utilizationRate / 1e18;

        data.lastCFMMFeeIndex = uint64(lastCFMMFeeIndex);
        (,data.LP_TOKEN_BORROWED_PLUS_INTEREST, borrowedInvariant) = IShortStrategy(data.shortStrategy)
        .getLatestBalances(data.lastFeeIndex, data.BORROWED_INVARIANT, data.LP_TOKEN_BALANCE,
            lastCFMMInvariant, lastCFMMTotalSupply);

        data.BORROWED_INVARIANT = uint128(borrowedInvariant);
        data.LP_INVARIANT = uint128(data.LP_TOKEN_BALANCE * lastCFMMInvariant / lastCFMMTotalSupply);
        data.accFeeIndex = uint80(data.accFeeIndex * data.lastFeeIndex / 1e18);

        data.utilizationRate = _calcUtilizationRate(data.LP_INVARIANT, data.BORROWED_INVARIANT);
        data.emaUtilRate = uint40(IShortStrategy(data.shortStrategy).calcUtilRateEma(data.utilizationRate, data.emaUtilRate,
            GSMath.max(block.number - data.LAST_BLOCK_NUMBER, data.emaMultiplier)));

        data.lastPrice = IGammaPool(pool).getLastCFMMPrice();
        data.lastCFMMInvariant = uint128(lastCFMMInvariant);
        data.lastCFMMTotalSupply = lastCFMMTotalSupply;
    }

    /// @inheritdoc IPoolViewer
    function getLatestPoolDataWithMetaData(address pool) external virtual override view returns(IGammaPool.PoolData memory data) {
        data = getLatestPoolData(pool);
        (data.symbols, data.names,) = getTokensMetaData(data.tokens);
    }

    /// @inheritdoc IPoolViewer
    function getPoolData(address pool) public virtual override view returns(IGammaPool.PoolData memory data) {
        data = IGammaPool(pool).getPoolData();
    }

    /// @inheritdoc IPoolViewer
    function getTokensMetaData(address[] memory _tokens) public virtual override view returns(string[] memory _symbols,
        string[] memory _names, uint8[] memory _decimals) {
        _symbols = new string[](_tokens.length);
        _names = new string[](_tokens.length);
        _decimals = new uint8[](_tokens.length);
        for(uint256 i = 0; i < _tokens.length;) {
            _symbols[i] = getTokenSymbol(_tokens[i]);
            _names[i] = getTokenName(_tokens[i]);
            _decimals[i] = getTokenDecimals(_tokens[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc ITokenMetaData
    function getTokenSymbol(address _token) public virtual override view returns(string memory _symbol) {
        (bool success, bytes memory data) = _token.staticcall(abi.encodeWithSignature("symbol()")); // requesting via ERC20 name implementation

        require(success && data.length >= 1);

        // Try to decode as bytes32
        if (data.length == 32) {
            bytes32 bytes32Value;
            assembly {
                bytes32Value := mload(add(data, 32))
            }
            return bytes32ToString(bytes32Value);
        }

        return abi.decode(data, (string));
    }

    /// @inheritdoc ITokenMetaData
    function getTokenName(address _token) public virtual override view returns(string memory _name) {
        (bool success, bytes memory data) = _token.staticcall(abi.encodeWithSignature("name()")); // requesting via ERC20 name implementation

        require(success && data.length >= 1);

        // Try to decode as bytes32
        if (data.length == 32) {
            bytes32 bytes32Value;
            assembly {
                bytes32Value := mload(add(data, 32))
            }
            return bytes32ToString(bytes32Value);
        }

        return abi.decode(data, (string));
    }

    /// @inheritdoc ITokenMetaData
    function getTokenDecimals(address _token) public virtual override view returns(uint8 _decimals) {
        return GammaSwapLibrary.decimals(_token);
    }

    /// @dev Update liquidity to current debt level
    /// @param liquidity - loan's liquidity debt
    /// @param rateIndex - accFeeIndex in last update of loan's liquidity debt
    /// @param accFeeIndex - current accFeeIndex
    /// @return updatedLiquidity - liquidity debt updated to current time
    function _updateLiquidity(uint256 liquidity, uint256 rateIndex, uint256 accFeeIndex) internal virtual view returns(uint128) {
        return rateIndex == 0 ? 0 : uint128(liquidity * accFeeIndex / rateIndex);
    }

    /// @dev Convert bytes32 to string
    /// @param _bytes32 - bytes32 parameter to convert to string
    /// @return string - _bytes32 parameter converted to string
    function bytes32ToString(bytes32 _bytes32) internal pure returns (string memory) {
        uint8 i = 0;
        while(i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }
}
