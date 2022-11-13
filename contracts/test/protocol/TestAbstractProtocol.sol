pragma solidity 0.8.4;

import "../../protocols/AbstractProtocol.sol";
import "../storage/TestStrategyStorage.sol";
import "../storage/TestRateStorage.sol";

contract TestAbstractProtocol is AbstractProtocol {

    uint8 immutable public val1;
    uint8 immutable public val2;

    constructor(uint24 _protocolId, address _longStrategy, address _shortStrategy, uint8 _val1, uint8 _val2) AbstractProtocol(_protocolId, _longStrategy, _shortStrategy) {
        val1 = _val1;
        val2 = _val2;
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm) external override view returns(address[] memory tokens) {
        require(isContract(_cfmm), "NOT_CONTRACT");
        tokens = new address[](2);
        tokens[0] = _tokens[1];
        tokens[1] = _tokens[0];
    }

}
