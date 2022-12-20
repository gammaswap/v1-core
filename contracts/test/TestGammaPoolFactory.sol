// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../libraries/AddressCalculator.sol";
import "../base/AbstractGammaPoolFactory.sol";
import "../interfaces/IGammaPool.sol";

contract TestGammaPoolFactory is AbstractGammaPoolFactory {

    address public deployer;
    address public cfmm;
    uint16 public protocolId;
    address[] public tokens;
    address public protocol;
    uint8[] public decimals;

    constructor(address _cfmm, uint16 _protocolId, address[] memory _tokens) {
        cfmm = _cfmm;
        protocolId = _protocolId;
        tokens = _tokens;
        owner = msg.sender;
        feeTo = owner;
        feeToSetter = owner;
        decimals = new uint8[](2);
    }

    function createPool2() external virtual returns(address pool) {
        bytes32 key = AddressCalculator.getGammaPoolKey(cfmm, protocolId);

        pool = cloneDeterministic(protocol, key);
        decimals[0] = 18;
        decimals[1] = 18;
        IGammaPool(pool).initialize(cfmm, tokens, decimals);

        getPool[key] = pool;
    }

    function createPool(uint16 protocolId, address cfmm, address[] calldata tokens) external override virtual returns(address pool) {
    }

    function isProtocolRestricted(uint16 protocolId) external view override returns(bool) {
        return false;
    }

    function setIsProtocolRestricted(uint16 protocolId, bool isRestricted) external override {
    }

    function addProtocol(address _protocol) external override {
        protocol = _protocol;
    }

    function removeProtocol(uint16 protocolId) external override {
      protocol = address(0);
    }

    function getProtocol(uint16 protocolId) external override view returns (address) {
        return protocol;
    }

    function allPoolsLength() external override view returns (uint256) {
        return 0;
    }

    function feeInfo() external override view returns(address,uint) {
        return(feeTo, 0);
    }
}
