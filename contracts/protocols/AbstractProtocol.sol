// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;
pragma abicoder v2;

import "../interfaces/IProtocol.sol";
import "../libraries/storage/ProtocolStorage.sol";

abstract contract AbstractProtocol is IProtocol {

    constructor(uint24 _protocol, address _longStrategy, address _shortStrategy) {
        ProtocolStorage.init(_protocol, _longStrategy, _shortStrategy);
    }

    function protocolId() external virtual override view returns(uint24) {
        return ProtocolStorage.store().protocolId;
    }

    function longStrategy() external virtual override view returns(address) {
        return ProtocolStorage.store().longStrategy;
    }

    function shortStrategy() external virtual override view returns(address) {
        return ProtocolStorage.store().shortStrategy;
    }

    function parameters() external virtual override view returns(bytes memory sParams, bytes memory rParams) {
        sParams = strategyParams();
        rParams = rateParams();
    }

    function initialize(bytes calldata sData, bytes calldata rData) external virtual override returns(bool) {

        initializeStrategyParams(sData);
        initializeRateParams(rData);

        return true;
    }

    function isContract(address account) internal virtual view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. keccak256('')
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    function strategyParams() internal virtual view returns(bytes memory sParams);

    function rateParams() internal virtual view returns(bytes memory rParams);

    function initializeStrategyParams(bytes calldata sData) internal virtual;

    function initializeRateParams(bytes calldata rData) internal virtual;
}
