// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../interfaces/IGammaPoolExternal.sol";
import "../interfaces/strategies/external/IExternalLongStrategy.sol";
import "../interfaces/strategies/external/IExternalLiquidationStrategy.sol";
import "./GammaPool.sol";

/// @title Basic GammaPool smart contract with flash loan functionality
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used as template for building other GammaPool contract implementations with flash loan functionality for other CFMMs
abstract contract GammaPoolExternal is GammaPool, IGammaPoolExternal{

    /// @dev See {IGammaPool-externalLongStrategy}
    address immutable public override externalLongStrategy;

    /// @dev See {IGammaPool-externalLiquidationStrategy}
    address immutable public override externalLiquidationStrategy;

    /// @dev Initializes the contract by setting `protocolId`, `factory`, `longStrategy`, `shortStrategy`, `liquidationStrategy`, `externalLongStrategy`, and `externalLiquidationStrategy`.
    constructor(uint16 protocolId_, address factory_,  address longStrategy_, address shortStrategy_,
        address liquidationStrategy_, address externalLongStrategy_, address externalLiquidationStrategy_)
        GammaPool(protocolId_, factory_, longStrategy_, shortStrategy_, liquidationStrategy_) {
        externalLongStrategy = externalLongStrategy_;
        externalLiquidationStrategy = externalLiquidationStrategy_;
    }

    /// @dev See {IGammaPoolExternal-rebalanceExternally}
    function rebalanceExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external override virtual returns(uint256 loanLiquidity, uint128[] memory tokensHeld) {
        return abi.decode(callStrategy(externalLongStrategy, abi.encodeWithSelector(IExternalLongStrategy._rebalanceExternally.selector, tokenId, amounts, lpTokens, to, data)), (uint256, uint128[]));
    }

    /// @dev See {IGammaPoolExternal-liquidateExternally}
    function liquidateExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external override virtual returns(uint256 loanLiquidity, uint256[] memory refund) {
        return abi.decode(callStrategy(externalLiquidationStrategy, abi.encodeWithSelector(IExternalLiquidationStrategy._liquidateExternally.selector, tokenId, amounts, lpTokens, to, data)), (uint256, uint256[]));
    }
}
