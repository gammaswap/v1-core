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

    function isRestricted(uint16 _protocolId, address _owner) internal virtual view {
        if(isProtocolRestricted[_protocolId] == true && msg.sender != _owner) {
            revert ProtocolRestricted();
        }
    }

    function isProtocolNotSet(uint16 _protocolId) internal virtual view {
        if(getProtocol[_protocolId] == address(0)) {
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

    function removeProtocol(uint16 _protocolId) external virtual override {
        isForbidden(owner);
        getProtocol[_protocolId] = address(0);
    }

    function setIsProtocolRestricted(uint16 _protocolId, bool _isRestricted) external virtual override {
        isForbidden(owner);
        isProtocolRestricted[_protocolId] = _isRestricted;
    }

    function createPool(uint16 _protocolId, address _cfmm, address[] calldata _tokens) external virtual override returns (address pool) {
        isProtocolNotSet(_protocolId);
        isRestricted(_protocolId, owner);

        address implementation = getProtocol[_protocolId];
        (address[] memory _tokensOrdered, uint8[] memory _decimals) = IGammaPool(implementation).validateCFMM(_tokens, _cfmm);

        bytes32 key = AddressCalculator.getGammaPoolKey(_cfmm, _protocolId);

        hasPool(key);

        pool = cloneDeterministic(implementation, key);

        IGammaPool(pool).initialize(_cfmm, _tokensOrdered, _decimals);

        getPool[key] = pool;
        allPools.push(pool);
        emit PoolCreated(pool, _cfmm, _protocolId, implementation, allPools.length);
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
        isZeroAddress(_feeToSetter);
        feeToSetter = _feeToSetter;
    }

}
