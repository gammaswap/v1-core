pragma solidity ^0.8.0;

import "../GammaPool.sol";

contract TestGammaPool is GammaPool {

    constructor(address _factory, uint16 _protocolId, address _longStrategy, address _shortStrategy)
        GammaPool(_factory, _protocolId, _longStrategy, _shortStrategy) {
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm) external virtual override view returns(address[] memory tokens) {
        tokens = _tokens;
    }
}
