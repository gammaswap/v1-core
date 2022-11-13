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

    function strategyParams() internal virtual override view returns(bytes memory sParams) {
        sParams = abi.encode(TestStrategyStorage.Store({val: val1}));
    }

    function rateParams() internal virtual override view returns(bytes memory rParams) {
        rParams = abi.encode(TestStrategyStorage.Store({val: val2}));
    }

    function initializeStrategyParams(bytes calldata sData) internal virtual override {
        TestStrategyStorage.Store memory sParams = abi.decode(sData, (TestStrategyStorage.Store));
        TestStrategyStorage.init(sParams.val);
    }

    function initializeRateParams(bytes calldata rData) internal virtual override {
        TestRateStorage.Store memory rParams = abi.decode(rData, (TestRateStorage.Store));
        TestRateStorage.init(rParams.val);
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm) external override view returns(address[] memory tokens) {
        require(isContract(_cfmm), "NOT_CONTRACT");
        tokens = new address[](2);
        tokens[0] = _tokens[1];
        tokens[1] = _tokens[0];
    }

}
