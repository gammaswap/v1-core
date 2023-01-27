// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../interfaces/IGammaPool.sol";
import "../interfaces/strategies/base/ILongStrategy.sol";
import "../interfaces/strategies/base/ILiquidationStrategy.sol";
import "./GammaPoolERC4626.sol";
import "./Refunds.sol";

/// @title Basic GammaPool smart contract
/// @author Daniel D. Alcarraz
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
    function initialize(address _cfmm, address[] calldata _tokens, uint8[] calldata _decimals) external virtual override {
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

    //GamamPool Data

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
    function getRates() external virtual override view returns(uint256 accFeeIndex, uint256 lastBlockNumber) {
        return(s.accFeeIndex, s.LAST_BLOCK_NUMBER);
    }

    /// @dev See {IGammaPool-getPoolData}
    function getPoolData() external virtual override view returns(PoolData memory data) {
        data.protocolId = protocolId;
        data.longStrategy = longStrategy;
        data.shortStrategy = shortStrategy;
        data.liquidationStrategy = liquidationStrategy;
        data.cfmm = s.cfmm;
        data.LAST_BLOCK_NUMBER = s.LAST_BLOCK_NUMBER;
        data.factory = s.factory;
        data.LP_TOKEN_BALANCE = s.LP_TOKEN_BALANCE;
        data.LP_TOKEN_BORROWED = s.LP_TOKEN_BORROWED;
        data.LP_TOKEN_BORROWED_PLUS_INTEREST = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        data.BORROWED_INVARIANT = s.BORROWED_INVARIANT;
        data.LP_INVARIANT = s.LP_INVARIANT;
        data.accFeeIndex = s.accFeeIndex;
        data.lastCFMMInvariant = s.lastCFMMInvariant;
        data.lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        data.totalSupply = s.totalSupply;
        data.decimals = s.decimals;
        data.tokens = s.tokens;
        data.TOKEN_BALANCE = s.TOKEN_BALANCE;
        data.CFMM_RESERVES = s.CFMM_RESERVES;
    }

    /*****SHORT*****/

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

    /*****LONG*****/

    /// @dev See {IGammaPool-getLatestCFMMReserves}
    function getLatestCFMMReserves() external virtual override view returns(uint256[] memory cfmmReserves) {
        return ILongStrategy(longStrategy)._getLatestCFMMReserves(s.cfmm);
    }

    /// @dev See {IGammaPool-createLoan}
    function createLoan() external lock virtual override returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length);
        emit LoanCreated(msg.sender, tokenId);
    }

    /// @dev See {IGammaPool-loan}
    function loan(uint256 tokenId) external virtual override view returns (uint256 id, address poolId,
        uint128[] memory tokensHeld, uint256 initLiquidity, uint256 liquidity, uint256 lpTokens, uint256 rateIndex) {
        LibStorage.Loan storage _loan = s.loans[tokenId];
        return (_loan.id, _loan.poolId, _loan.tokensHeld, _loan.initLiquidity, _loan.liquidity, _loan.lpTokens, _loan.rateIndex);
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
    function borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual override returns(uint256[] memory amounts) {
        return abi.decode(callStrategy(longStrategy, abi.encodeWithSelector(ILongStrategy._borrowLiquidity.selector, tokenId, lpTokens)), (uint256[]));
    }

    /// @dev See {IGammaPool-repayLiquidity}
    function repayLiquidity(uint256 tokenId, uint256 liquidity) external virtual override returns(uint256 liquidityPaid, uint256[] memory amounts) {
        return abi.decode(callStrategy(longStrategy, abi.encodeWithSelector(ILongStrategy._repayLiquidity.selector, tokenId, liquidity)), (uint256,uint256[]));
    }

    /// @dev See {IGammaPool-rebalanceCollateral}
    function rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external virtual override returns(uint128[] memory tokensHeld) {
        return abi.decode(callStrategy(longStrategy, abi.encodeWithSelector(ILongStrategy._rebalanceCollateral.selector, tokenId, deltas)), (uint128[]));
    }

    /// @dev See {IGammaPool-liquidate}
    function liquidate(uint256 tokenId, int256[] calldata deltas) external override virtual returns(uint256[] memory refund) {
        return abi.decode(callStrategy(liquidationStrategy, abi.encodeWithSelector(ILiquidationStrategy._liquidate.selector, tokenId, deltas)), (uint256[]));
    }

    /// @dev See {IGammaPool-liquidateWithLP}
    function liquidateWithLP(uint256 tokenId) external override virtual returns(uint256[] memory refund) {
        return abi.decode(callStrategy(liquidationStrategy, abi.encodeWithSelector(ILiquidationStrategy._liquidateWithLP.selector, tokenId)), (uint256[]));
    }

    /// @dev See {IGammaPool-batchLiquidations}
    function batchLiquidations(uint256[] calldata tokenIds) external override virtual returns(uint256[] memory refund) {
        return abi.decode(callStrategy(liquidationStrategy, abi.encodeWithSelector(ILiquidationStrategy._batchLiquidations.selector, tokenIds)), (uint256[]));
    }

    /// @dev See {IGammaPool-skim}
    function skim(address to) external override lock {
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

    /// @dev See {IGammaPool-sync}
    function sync() external override lock {
        uint256 oldLpTokenBalance = s.LP_TOKEN_BALANCE;
        uint256 newLpTokenBalance = IERC20(s.cfmm).balanceOf(address(this));
        s.LP_TOKEN_BALANCE = newLpTokenBalance;
        emit Sync(oldLpTokenBalance, newLpTokenBalance);
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
