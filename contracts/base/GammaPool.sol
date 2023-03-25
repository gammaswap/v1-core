// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../libraries/GammaSwapLibrary.sol";
import "../interfaces/IGammaPool.sol";
import "../interfaces/IGammaPoolFactory.sol";
import "../interfaces/strategies/base/ILongStrategy.sol";
import "../interfaces/strategies/base/ILiquidationStrategy.sol";
import "./GammaPoolERC4626.sol";
import "./Refunds.sol";

/// @title Basic GammaPool smart contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used as template for building other GammaPool contract implementations for other CFMMs
abstract contract GammaPool is IGammaPool, GammaPoolERC4626, Refunds {

    using LibStorage for LibStorage.Storage;

    error Forbidden();

    /// @dev See {IGammaPool-protocolId}
    uint16 immutable public override protocolId;

    /// @dev See {IGammaPool-factory}
    address immutable public override factory;

    /// @dev See {IGammaPool-longStrategy}
    address immutable public override longStrategy;

    /// @dev See {IGammaPool-shortStrategy}
    address immutable public override shortStrategy;

    /// @dev See {IGammaPool-liquidationStrategy}
    address immutable public override liquidationStrategy;

    /// @dev Initializes the contract by setting `protocolId`, `factory`, `longStrategy`, `shortStrategy`, and `liquidationStrategy`.
    constructor(uint16 _protocolId, address _factory,  address _longStrategy, address _shortStrategy, address _liquidationStrategy) {
        protocolId = _protocolId;
        factory = _factory;
        longStrategy = _longStrategy;
        shortStrategy = _shortStrategy;
        liquidationStrategy = _liquidationStrategy;
    }

    /// @dev See {IGammaPool-initialize}
    function initialize(address _cfmm, address[] calldata _tokens, uint8[] calldata _decimals, bytes calldata) external virtual override {
        if(msg.sender != factory) // only factory is allowed to initialize
            revert Forbidden();

        s.initialize(factory, _cfmm, _tokens, _decimals);
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
        return GammaSwapLibrary.totalSupply(IERC20(s.cfmm));
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

    /// @dev See {IGammaPool-getLatestRates}
    function getLatestRates() external virtual override view returns(uint256 accFeeIndex, uint256 lastCFMMFeeIndex, uint256 lastFeeIndex, uint256 borrowRate, uint256 lastBlockNumber, uint256 currBlockNumber) {
        uint256 borrowedInvariant = s.BORROWED_INVARIANT;
        uint256 lastCFMMInvariant = _getLatestCFMMInvariant();
        uint256 lastCFMMTotalSupply = _getLatestCFMMTotalSupply();
        uint256 lpTokenBalance = s.LP_TOKEN_BALANCE;
        lastBlockNumber = s.LAST_BLOCK_NUMBER;
        currBlockNumber = block.number;
        (lastCFMMFeeIndex, lastFeeIndex, borrowRate) = IShortStrategy(shortStrategy)
        .getLastFees(borrowedInvariant, lpTokenBalance, lastCFMMInvariant, lastCFMMTotalSupply,
            s.lastCFMMInvariant, s.lastCFMMTotalSupply, lastBlockNumber);
        accFeeIndex = s.accFeeIndex * lastFeeIndex / 1e18;
    }

    /// @dev See {IGammaPool-getConstantPoolData}
    function getConstantPoolData() public virtual override view returns(PoolData memory data) {
        data.poolId = address(this);
        data.protocolId = protocolId;
        data.longStrategy = longStrategy;
        data.shortStrategy = shortStrategy;
        data.liquidationStrategy = liquidationStrategy;
        data.cfmm = s.cfmm;
        data.currBlockNumber = uint48(block.number);
        data.LAST_BLOCK_NUMBER = s.LAST_BLOCK_NUMBER;
        data.factory = s.factory;
        data.LP_TOKEN_BALANCE = s.LP_TOKEN_BALANCE;
        data.LP_TOKEN_BORROWED = s.LP_TOKEN_BORROWED;
        data.totalSupply = s.totalSupply;
        data.TOKEN_BALANCE = s.TOKEN_BALANCE;
        (data.tokens, data.symbols, data.names, data.decimals) = getTokensMetaData();
    }

    /// @dev See {IGammaPool-getTokensMetaData}
    function getTokensMetaData() public virtual override view returns(address[] memory _tokens, string[] memory _symbols, string[] memory _names, uint8[] memory _decimals) {
        _tokens = s.tokens;
        _decimals = s.decimals;
        _symbols = new string[](_tokens.length);
        _names = new string[](_tokens.length);
        for(uint256 i = 0; i < _tokens.length;) {
            _symbols[i] = GammaSwapLibrary.symbol(_tokens[i]);
            _names[i] = GammaSwapLibrary.name(_tokens[i]);
            unchecked {
                i++;
            }
        }
    }

    /// @dev See {IGammaPool-getPoolData}
    function getPoolData() external virtual override view returns(PoolData memory data) {
        data = getConstantPoolData();
        data.LP_TOKEN_BORROWED_PLUS_INTEREST = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        data.BORROWED_INVARIANT = s.BORROWED_INVARIANT;
        data.LP_INVARIANT = s.LP_INVARIANT;
        data.accFeeIndex = s.accFeeIndex;
        data.lastCFMMFeeIndex = s.lastCFMMFeeIndex;
        data.lastCFMMInvariant = s.lastCFMMInvariant;
        data.lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        data.CFMM_RESERVES = s.CFMM_RESERVES;
    }

    /// @dev See {IGammaPool-getLatestPoolData}
    function getLatestPoolData() external virtual override view returns(PoolData memory data) {
        data = getConstantPoolData();
        uint256 borrowedInvariant = s.BORROWED_INVARIANT;
        data.lastCFMMInvariant = uint128(_getLatestCFMMInvariant());
        data.lastCFMMTotalSupply = _getLatestCFMMTotalSupply();

        uint256 lastCFMMFeeIndex;
        (lastCFMMFeeIndex, data.lastFeeIndex, data.borrowRate) = IShortStrategy(shortStrategy)
        .getLastFees(borrowedInvariant, data.LP_TOKEN_BALANCE, data.lastCFMMInvariant, data.lastCFMMTotalSupply,
            s.lastCFMMInvariant, s.lastCFMMTotalSupply, data.LAST_BLOCK_NUMBER);

        data.lastCFMMFeeIndex = uint80(lastCFMMFeeIndex);
        (,data.LP_TOKEN_BORROWED_PLUS_INTEREST, borrowedInvariant) = IShortStrategy(shortStrategy)
        .getLatestBalances(data.lastFeeIndex, borrowedInvariant, data.LP_TOKEN_BALANCE,
            data.lastCFMMInvariant, data.lastCFMMTotalSupply);

        data.BORROWED_INVARIANT = uint128(borrowedInvariant);
        data.LP_INVARIANT = uint128(data.LP_TOKEN_BALANCE * data.lastCFMMInvariant / data.lastCFMMTotalSupply);
        data.accFeeIndex = uint96(s.accFeeIndex * data.lastFeeIndex / 1e18);

        data.CFMM_RESERVES = _getLatestCFMMReserves();
        data.lastPrice = _getLastCFMMPrice();
    }

    /***** SHORT *****/

    /// @dev See {IGammaPool-depositNoPull}
    function depositNoPull(address to) external virtual override returns(uint256 shares) {
        return abi.decode(callStrategy(shortStrategy, abi.encodeWithSelector(IShortStrategy._depositNoPull.selector, to)), (uint256));
    }

    /// @dev See {IGammaPool-withdrawNoPull}
    function withdrawNoPull(address to) external virtual override returns(uint256 assets) {
        return abi.decode(callStrategy(shortStrategy, abi.encodeWithSelector(IShortStrategy._withdrawNoPull.selector, to)), (uint256));
    }

    /// @dev See {IGammaPool-depositReserves}
    function depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external virtual override returns(uint256[] memory reserves, uint256 shares){
        return abi.decode(callStrategy(shortStrategy, abi.encodeWithSelector(IShortStrategy._depositReserves.selector, to, amountsDesired, amountsMin, data)), (uint256[],uint256));
    }

    /// @dev See {IGammaPool-withdrawReserves}
    function withdrawReserves(address to) external virtual override returns (uint256[] memory reserves, uint256 assets) {
        return abi.decode(callStrategy(shortStrategy, abi.encodeWithSelector(IShortStrategy._withdrawReserves.selector, to)), (uint256[],uint256));
    }

    /***** LONG *****/

    /// @dev See {IGammaPool-createLoan}
    function createLoan() external lock virtual override returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length);
        emit LoanCreated(msg.sender, tokenId);
    }

    /// @dev See {IGammaPool-loan}
    function loan(uint256 tokenId) external virtual override view returns(LoanData memory _loanData) {
        _loanData = getLoanData(tokenId);
    }

    /// @dev Get loan and convert to LoanData struct
    /// @param _tokenId - tokenId of loan to convert
    /// @return _loanData - loan data struct (same as Loan + tokenId)
    function getLoanData(uint256 _tokenId) internal virtual view returns(LoanData memory _loanData) {
        LibStorage.Loan memory _loan = s.loans[_tokenId];
        _loanData.tokenId = _tokenId;
        _loanData.id = _loan.id;
        _loanData.poolId = _loan.poolId;
        _loanData.tokensHeld = _loan.tokensHeld;
        _loanData.initLiquidity = _loan.initLiquidity;
        _loanData.liquidity = _loan.liquidity;
        _loanData.lpTokens = _loan.lpTokens;
        _loanData.rateIndex = _loan.rateIndex;
        _loanData.px = _loan.px;
        (_loanData.tokens, _loanData.symbols, _loanData.names, _loanData.decimals) = getTokensMetaData();
    }

    /// @dev See {IGammaPool-getLoans}
    function getLoans(uint256 start, uint256 end) external virtual override view returns(LoanData[] memory _loans) {
        uint256[] storage _tokenIds = s.tokenIds;
        if(start > end || _tokenIds.length == 0) {
            return new LoanData[](0);
        }
        uint256 lastIdx = _tokenIds.length - 1;
        if(start <= lastIdx) {
            uint256 _start = start;
            uint256 _end = lastIdx < end ? lastIdx : end;
            uint256 _size = _end - _start + 1;
            _loans = new LoanData[](_size);
            uint256 k = 0;
            for(uint256 i = _start; i <= _end;) {
                _loans[k] = getLoanData(_tokenIds[i]);
                unchecked {
                    k++;
                    i++;
                }
            }
        }
    }

    /// @dev See {IGammaPool-getLoanCount}
    function getLoanCount() external virtual override view returns(uint256) {
        return s.tokenIds.length;
    }

    /// @dev See {IGammaPool-increaseCollateral}
    function increaseCollateral(uint256 tokenId) external virtual override returns(uint128[] memory tokensHeld) {
        return abi.decode(callStrategy(longStrategy, abi.encodeWithSelector(ILongStrategy._increaseCollateral.selector, tokenId)), (uint128[]));
    }

    /// @dev See {IGammaPool-decreaseCollateral}
    function decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external virtual override returns(uint128[] memory tokensHeld) {
        return abi.decode(callStrategy(longStrategy, abi.encodeWithSelector(ILongStrategy._decreaseCollateral.selector, tokenId, amounts, to)), (uint128[]));
    }

    /// @dev See {IGammaPool-borrowLiquidity}
    function borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual override returns(uint256 liquidityBorrowed, uint256[] memory amounts) {
        return abi.decode(callStrategy(longStrategy, abi.encodeWithSelector(ILongStrategy._borrowLiquidity.selector, tokenId, lpTokens)), (uint256, uint256[]));
    }

    /// @dev See {IGammaPool-repayLiquidity}
    function repayLiquidity(uint256 tokenId, uint256 liquidity, uint256[] calldata fees) external virtual override returns(uint256 liquidityPaid, uint256[] memory amounts) {
        return abi.decode(callStrategy(longStrategy, abi.encodeWithSelector(ILongStrategy._repayLiquidity.selector, tokenId, liquidity, fees)), (uint256, uint256[]));
    }

    /// @dev See {IGammaPool-rebalanceCollateral}
    function rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external virtual override returns(uint128[] memory tokensHeld) {
        return abi.decode(callStrategy(longStrategy, abi.encodeWithSelector(ILongStrategy._rebalanceCollateral.selector, tokenId, deltas)), (uint128[]));
    }

    /// @dev See {IGammaPool-updatePool}
    function updatePool(uint256 tokenId) external virtual override returns(uint256 loanLiquidityDebt, uint256 poolLiquidityDebt) {
        return abi.decode(callStrategy(longStrategy, abi.encodeWithSelector(ILongStrategy._updatePool.selector, tokenId)), (uint256, uint256));
    }

    /// @dev See {IGammaPool-liquidate}
    function liquidate(uint256 tokenId, int256[] calldata deltas, uint256[] calldata fees) external virtual override returns(uint256 loanLiquidity, uint256[] memory refund) {
        return abi.decode(callStrategy(liquidationStrategy, abi.encodeWithSelector(ILiquidationStrategy._liquidate.selector, tokenId, deltas, fees)), (uint256, uint256[]));
    }

    /// @dev See {IGammaPool-liquidateWithLP}
    function liquidateWithLP(uint256 tokenId) external virtual override returns(uint256 loanLiquidity, uint256[] memory refund) {
        return abi.decode(callStrategy(liquidationStrategy, abi.encodeWithSelector(ILiquidationStrategy._liquidateWithLP.selector, tokenId)), (uint256, uint256[]));
    }

    /// @dev See {IGammaPool-batchLiquidations}
    function batchLiquidations(uint256[] calldata tokenIds) external virtual override returns(uint256 totalLoanLiquidity, uint256 totalCollateral, uint256[] memory refund) {
        return abi.decode(callStrategy(liquidationStrategy, abi.encodeWithSelector(ILiquidationStrategy._batchLiquidations.selector, tokenIds)), (uint256, uint256, uint256[]));
    }

    /***** SYNC POOL *****/

    /// @dev See {IGammaPool-sync}
    function sync() external virtual override {
        callStrategy(shortStrategy, abi.encodeWithSelector(IShortStrategy._sync.selector));
    }

    /// @dev See {IGammaPool-skim}
    function skim(address to) external virtual override lock {
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
