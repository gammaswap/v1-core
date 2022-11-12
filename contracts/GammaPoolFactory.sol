// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./interfaces/IGammaPool.sol";
import "./interfaces/IProtocol.sol";
import "./base/AbstractGammaPoolFactory.sol";
import "./libraries/AddressCalculator.sol";

contract GammaPoolFactory is AbstractGammaPoolFactory {

    mapping(uint24 => address) public override getProtocol;//there's a protocol
    mapping(uint24 => bool) public override isProtocolRestricted;//a protocol creation can be restricted

    address[] public allPools;

    constructor(address _feeToSetter, address _implementation) {
        feeToSetter = _feeToSetter;
        feeTo = _feeToSetter;
        owner = msg.sender;
        implementation = _implementation;
    }

    function allPoolsLength() external virtual override view returns (uint) {
        return allPools.length;
    }

    function isRestricted(uint24 protocolId, address _owner) internal virtual view {
        if(isProtocolRestricted[protocolId] == true && msg.sender != _owner) {
            revert ProtocolRestricted();
        }
    }

    function isProtocolNotSet(uint24 protocolId) internal virtual view {
        if(getProtocol[protocolId] == address(0)) {
            revert ProtocolNotSet();
        }
    }

    function addProtocol(address protocol) external virtual override {
        isForbidden(owner);
        if(IProtocol(protocol).protocolId() == 0) {
            revert ZeroProtocol();
        }
        if(getProtocol[IProtocol(protocol).protocolId()] != address(0)) {
            revert ProtocolExists();
        }
        getProtocol[IProtocol(protocol).protocolId()] = protocol;
    }

    function removeProtocol(uint24 protocol) external virtual override {
        isForbidden(owner);
        getProtocol[protocol] = address(0);
    }

    function setIsProtocolRestricted(uint24 protocol, bool isRestricted) external virtual override {
        isForbidden(owner);
        isProtocolRestricted[protocol] = isRestricted;
    }

    function createPool(CreatePoolParams calldata params) external virtual override returns (address pool) {
        uint24 protocolId = params.protocol;

        isProtocolNotSet(protocolId);
        isRestricted(protocolId, owner);

        address protocol = getProtocol[protocolId];

        address cfmm = params.cfmm;

        IProtocol mProtocol = IProtocol(protocol);

        IGammaPool.InitializeParameters memory mParams = IGammaPool.InitializeParameters({
            cfmm: cfmm, protocolId: protocolId, tokens: new address[](0), protocol: protocol,
            longStrategy: mProtocol.longStrategy(), shortStrategy: mProtocol.shortStrategy(),
            stratParams: new bytes(0), rateParams: new bytes(0)});

        mParams.tokens = mProtocol.validateCFMM(params.tokens, cfmm);

        bytes32 key = AddressCalculator.getGammaPoolKey(cfmm, protocolId);

        hasPool(key);

        pool = cloneDeterministic(implementation, key);

        (mParams.stratParams, mParams.rateParams) = mProtocol.parameters();

        IGammaPool(pool).initialize(mParams);

        getPool[key] = pool;
        allPools.push(pool);
        emit PoolCreated(pool, cfmm, protocolId, protocol, allPools.length);
    }

    function feeInfo() external virtual override view returns(address _feeTo, uint _fee) {
        _feeTo = feeTo;
        _fee = fee;
    }

    function setFee(uint _fee) external {
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
