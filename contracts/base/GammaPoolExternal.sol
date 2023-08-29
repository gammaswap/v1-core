// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.13;

import "../interfaces/IGammaPoolExternal.sol";
import "../interfaces/strategies/rebalance/IExternalRebalanceStrategy.sol";
import "../interfaces/strategies/liquidation/IExternalLiquidationStrategy.sol";
import "../utils/DelegateCaller.sol";
import "../utils/Pausable.sol";

/// @title Basic GammaPool smart contract with flash loan functionality
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Used as template for building other GammaPool contract implementations with flash loan functionality for other CFMMs
abstract contract GammaPoolExternal is IGammaPoolExternal, DelegateCaller, Pausable {

    /// @dev See {IGammaPool-externalRebalanceStrategy}
    address immutable public override externalRebalanceStrategy;

    /// @dev See {IGammaPool-externalLiquidationStrategy}
    address immutable public override externalLiquidationStrategy;

    /// @dev Initializes the contract by setting `externalRebalanceStrategy`, and `externalLiquidationStrategy`
    constructor(address externalRebalanceStrategy_, address externalLiquidationStrategy_) {
        externalRebalanceStrategy = externalRebalanceStrategy_;
        externalLiquidationStrategy = externalLiquidationStrategy_;
    }

    /// @dev See {IGammaPoolExternal-rebalanceExternally}
    function rebalanceExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external override virtual whenNotPaused(24) returns(uint256 loanLiquidity, uint128[] memory tokensHeld) {
        return abi.decode(callStrategy(externalRebalanceStrategy, abi.encodeCall(IExternalRebalanceStrategy._rebalanceExternally, (tokenId, amounts, lpTokens, to, data))), (uint256, uint128[]));
    }

    /// @dev See {IGammaPoolExternal-liquidateExternally}
    function liquidateExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external override virtual whenNotPaused(25) returns(uint256 loanLiquidity, uint256[] memory refund) {
        return abi.decode(callStrategy(externalLiquidationStrategy, abi.encodeCall(IExternalLiquidationStrategy._liquidateExternally, (tokenId, amounts, lpTokens, to, data))), (uint256, uint256[]));
    }
}
