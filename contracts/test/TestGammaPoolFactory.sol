pragma solidity 0.8.4;

import "../libraries/AddressCalculator.sol";
import "../base/AbstractGammaPoolFactory.sol";
import "../interfaces/IGammaPool.sol";
import "../interfaces/IProtocol.sol";

contract TestGammaPoolFactory is AbstractGammaPoolFactory {

    address public deployer;
    address public cfmm;
    uint24 public protocolId;
    address[] public tokens;
    address public protocol;

    constructor(address _cfmm, uint24 _protocolId, address[] memory _tokens, address _protocol, address _implementation) {
        cfmm = _cfmm;
        protocolId = _protocolId;
        tokens = _tokens;
        protocol = _protocol;
        owner = msg.sender;
        feeTo = owner;
        feeToSetter = owner;
        implementation = _implementation;
    }

    function setProtocol(address _protocol) external {
        protocol = _protocol;
    }

    function createPool2() external virtual returns(address pool) {
        bytes32 key = AddressCalculator.getGammaPoolKey(cfmm, protocolId);

        IProtocol mProtocol = IProtocol(protocol);

        IGammaPool.InitializeParameters memory mParams = IGammaPool.InitializeParameters({
        cfmm: cfmm, protocolId: protocolId, tokens: tokens, protocol: protocol,
        longStrategy: mProtocol.longStrategy(), shortStrategy: mProtocol.shortStrategy()});

        pool = cloneDeterministic(implementation, key);
        IGammaPool(pool).initialize(mParams);

        getPool[key] = pool;
    }

    function createPool(CreatePoolParams calldata params) external override virtual returns(address pool) {
    }

    function isProtocolRestricted(uint24 protocol) external view override returns(bool) {
        return false;
    }

    function setIsProtocolRestricted(uint24 protocol, bool isRestricted) external override {
    }

    function addProtocol(address _protocol) external override {
        protocol = _protocol;
    }

    function removeProtocol(uint24 protocolId) external override {
      protocol = address(0);
    }

    function getProtocol(uint24 protocolId) external override view returns (address) {
        return protocol;
    }

    function allPoolsLength() external override view returns (uint256) {
        return 0;
    }

    function feeInfo() external override view returns(address,uint) {
        return(feeTo, 0);
    }
}
