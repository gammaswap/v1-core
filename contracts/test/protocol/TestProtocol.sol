// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;
pragma abicoder v2;

import "../../interfaces/IProtocol.sol";

contract TestProtocol is IProtocol {

    uint24 immutable public override protocolId;
    address immutable public override longStrategy;
    address immutable public override shortStrategy;

    constructor(address _longStrategy, address _shortStrategy, uint24 _protocolId) {
        longStrategy = _longStrategy;
        shortStrategy = _shortStrategy;
        protocolId = _protocolId;
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm) external virtual override view returns(address[] memory tokens) {
        tokens = _tokens;
    }
}
