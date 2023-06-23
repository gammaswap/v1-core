// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../interfaces/IGammaPoolExternal.sol";
import "../interfaces/strategies/rebalance/IExternalRebalanceStrategy.sol";
import "../interfaces/strategies/liquidation/IExternalLiquidationStrategy.sol";
import "./GammaPool.sol";

/// @title Basic GammaPool smart contract with flash loan functionality
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used as template for building other GammaPool contract implementations with flash loan functionality for other CFMMs
abstract contract GammaPoolExternal is GammaPool, IGammaPoolExternal {

    /// @dev See {IGammaPool-externalRebalanceStrategy}
    address immutable public override externalRebalanceStrategy;

    /// @dev See {IGammaPool-externalLiquidationStrategy}
    address immutable public override externalLiquidationStrategy;

    /// @dev Initializes the contract by setting `protocolId`, `factory`, `borrowStrategy`, `repayStrategy`, `rebalanceStrategy`,
    ///`shortStrategy`, `singleLiquidationStrategy`, `batchLiquidationStrategy`, `externalRebalanceStrategy`, and `externalLiquidationStrategy`.
    constructor(uint16 protocolId_, address factory_,  address borrowStrategy_, address repayStrategy_, address rebalanceStrategy_,
        address shortStrategy_, address singleLiquidationStrategy_, address batchLiquidationStrategy_, address externalRebalanceStrategy_,
        address externalLiquidationStrategy_) GammaPool(protocolId_, factory_, borrowStrategy_, repayStrategy_, rebalanceStrategy_,
        shortStrategy_, singleLiquidationStrategy_, batchLiquidationStrategy_) {
        externalRebalanceStrategy = externalRebalanceStrategy_;
        externalLiquidationStrategy = externalLiquidationStrategy_;
    }

    /// @dev See {IGammaPoolExternal-rebalanceExternally}
    function rebalanceExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external override virtual returns(uint256 loanLiquidity, uint128[] memory tokensHeld) {
        return abi.decode(callStrategy(externalRebalanceStrategy, abi.encodeWithSelector(IExternalRebalanceStrategy._rebalanceExternally.selector, tokenId, amounts, lpTokens, to, data)), (uint256, uint128[]));
    }

    /// @dev See {IGammaPoolExternal-liquidateExternally}
    function liquidateExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external override virtual returns(uint256 loanLiquidity, uint256[] memory refund) {
        return abi.decode(callStrategy(externalLiquidationStrategy, abi.encodeWithSelector(IExternalLiquidationStrategy._liquidateExternally.selector, tokenId, amounts, lpTokens, to, data)), (uint256, uint256[]));
    }
}
