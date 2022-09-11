pragma solidity ^0.8.0;

import "../../protocols/AbstractProtocol.sol";
import "../storage/TestStrategyStorage.sol";
import "../storage/TestRateStorage.sol";

contract TestAbstractProtocol is AbstractProtocol {

    constructor(address gsFactory, uint24 _protocol, address _longStrategy, address _shortStrategy, uint8 val1, uint8 val2) AbstractProtocol(gsFactory, _protocol, _longStrategy, _shortStrategy) {
        TestStrategyStorage.init(val1);
        TestRateStorage.init(val2);
    }

    function strategyParams() internal virtual override view returns(bytes memory sParams) {
        TestStrategyStorage.Store storage sStore = TestStrategyStorage.store();
        sParams = abi.encode(TestStrategyStorage.Store({val: sStore.val}));
    }

    function rateParams() internal virtual override view returns(bytes memory rParams) {
        TestRateStorage.Store storage rStore = TestRateStorage.store();
        rParams = abi.encode(TestStrategyStorage.Store({val: rStore.val}));
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
