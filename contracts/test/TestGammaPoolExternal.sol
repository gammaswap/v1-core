// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../base/GammaPoolExternal.sol";
import "../base/GammaPool.sol";

contract TestGammaPoolExternal is GammaPool, GammaPoolExternal {

    using LibStorage for LibStorage.Storage;

    struct params {
        uint16 protocolId;
        address cfmm;
    }

    constructor(uint16 _protocolId, address _factory, address _borrowStrategy, address _repayStrategy, address _rebalanceStrategy,
        address _shortStrategy, address _singleLiquidationStrategy, address _batchLiquidationStrategy, address _viewer,
        address _externalRebalanceStrategy, address _externalLiquidationStrategy)
        GammaPool(_protocolId, _factory, _borrowStrategy, _repayStrategy, _rebalanceStrategy, _shortStrategy,
        _singleLiquidationStrategy, _batchLiquidationStrategy, _viewer)
        GammaPoolExternal(_externalRebalanceStrategy, _externalLiquidationStrategy) {
    }

    function _getLastCFMMPrice() internal virtual override view returns(uint256) {
        return 1;
    }

    function _calcInvariant(uint128[] memory tokensHeld) internal virtual override view returns(uint256) {
        return tokensHeld[0] * 100;
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm, bytes calldata _data) external virtual override view returns(address[] memory _tokensOrdered) {
        params memory decoded = abi.decode(_data, (params));
        require(decoded.cfmm == _cfmm, "Validation");
        _tokensOrdered = _tokens;
    }
}
