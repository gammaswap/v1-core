// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./interfaces/IGammaPool.sol";
import "./base/AbstractGammaPoolFactory.sol";
import "./libraries/AddressCalculator.sol";

contract GammaPoolFactory is AbstractGammaPoolFactory {

    mapping(uint16 => address) public override getProtocol;//there's a protocol
    mapping(uint16 => bool) public override isProtocolRestricted;//a protocol creation can be restricted

    address[] public allPools;

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
        feeTo = _feeToSetter;
        owner = msg.sender;
    }

    function allPoolsLength() external virtual override view returns (uint) {
        return allPools.length;
    }

    function isRestricted(uint16 protocolId, address _owner) internal virtual view {
        if(isProtocolRestricted[protocolId] == true && msg.sender != _owner) {
            revert ProtocolRestricted();
        }
    }

    function isProtocolNotSet(uint16 protocolId) internal virtual view {
        if(getProtocol[protocolId] == address(0)) {
            revert ProtocolNotSet();
        }
    }

    function addProtocol(address implementation) external virtual override {
        isForbidden(owner);
        if(IGammaPool(implementation).protocolId() == 0) {
            revert ZeroProtocol();
        }
        if(getProtocol[IGammaPool(implementation).protocolId()] != address(0)) {
            revert ProtocolExists();
        }
        getProtocol[IGammaPool(implementation).protocolId()] = implementation;
    }

    function removeProtocol(uint16 protocolId) external virtual override {
        isForbidden(owner);
        getProtocol[protocolId] = address(0);
    }

    function setIsProtocolRestricted(uint16 protocolId, bool isRestricted) external virtual override {
        isForbidden(owner);
        isProtocolRestricted[protocolId] = isRestricted;
    }

    function createPool(uint16 protocolId, address cfmm, address[] calldata tokens) external virtual override returns (address pool) {
        isProtocolNotSet(protocolId);
        isRestricted(protocolId, owner);

        address implementation = getProtocol[protocolId];
        address[] memory _tokens = IGammaPool(implementation).validateCFMM(tokens, cfmm);

        bytes32 key = AddressCalculator.getGammaPoolKey(cfmm, protocolId);

        hasPool(key);

        pool = cloneDeterministic(implementation, key);

        IGammaPool(pool).initialize(cfmm, _tokens);

        getPool[key] = pool;
        allPools.push(pool);
        emit PoolCreated(pool, cfmm, protocolId, implementation, allPools.length);
    }

    function feeInfo() external virtual override view returns(address _feeTo, uint256 _fee) {
        _feeTo = feeTo;
        _fee = fee;
    }

    function setFee(uint16 _fee) external {
        isForbidden(feeToSetter);
        fee = _fee;
    }

    function setFeeTo(address _feeTo) external {
        isForbidden(feeToSetter);
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        isForbidden(feeToSetter);
        feeToSetter = _feeToSetter;
    }

}
