// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../interfaces/IGammaPoolExternal.sol";
import "../interfaces/strategies/external/IExternalLongStrategy.sol";
import "../interfaces/strategies/external/IExternalLiquidationStrategy.sol";
import "./GammaPool.sol";

abstract contract GammaPoolExternal is GammaPool, IGammaPoolExternal{
    /// @dev Initializes the contract by setting `protocolId`, `factory`, `longStrategy`, `shortStrategy`, and `liquidationStrategy`.
    constructor(uint16 _protocolId, address _factory,  address _longStrategy, address _shortStrategy, address _liquidationStrategy)
        GammaPool(_protocolId, _factory, _longStrategy, _shortStrategy, _liquidationStrategy) {
    }

    /// @dev See {IGammaPoolExternal-rebalanceExternally}
    function rebalanceExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external override virtual returns(uint256 loanLiquidity, uint128[] memory tokensHeld) {
        return abi.decode(callStrategy(longStrategy, abi.encodeWithSelector(IExternalLongStrategy._rebalanceExternally.selector, tokenId, amounts, lpTokens, to, data)), (uint256, uint128[]));
    }


    /// @dev See {IGammaPoolExternal-liquidateExternally}
    function liquidateExternally(uint256 tokenId, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) external override virtual returns(uint256 loanLiquidity, uint256[] memory refund) {
        return abi.decode(callStrategy(liquidationStrategy, abi.encodeWithSelector(IExternalLiquidationStrategy._liquidateExternally.selector, tokenId, amounts, lpTokens, to, data)), (uint256, uint256[]));
    }
}
