// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

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

    constructor(address _cfmm, uint16 _protocolId, address[] memory _tokens) AbstractGammaPoolFactory(msg.sender, msg.sender, msg.sender) {
        cfmm = _cfmm;
        protocolId = _protocolId;
        tokens = _tokens;
        decimals = new uint8[](2);
    }

    function createPool2(bytes calldata _data) external virtual returns(address pool) {
        bytes32 key = AddressCalculator.getGammaPoolKey(cfmm, protocolId);

        pool = cloneDeterministic(address(0), protocolId, key);
        decimals[0] = 18;
        decimals[1] = 18;
        IGammaPool(pool).initialize(cfmm, tokens, decimals, uint72(1e3), _data);

        getPool[key] = pool;
        getKey[pool] = key;
    }

    function createPool(uint16, address, address[] calldata, bytes calldata) external override virtual returns(address) {
    }

    function isProtocolRestricted(uint16) external pure override returns(bool) {
        return false;
    }

    function setIsProtocolRestricted(uint16, bool) external override {
    }

    function addProtocol(address _protocol) external override {
        protocol = _protocol;
    }

    function updateProtocol(uint16 _protocolId, address _newImpl) external override {
    }

    function lockProtocol(uint16) external override {
    }

    function getProtocol(uint16) external override view returns (address) {
        return protocol;
    }

    function getProtocolBeacon(uint16) external override view returns (address) {
        return address(0);
    }

    function allPoolsLength() external override pure returns (uint256) {
        return 0;
    }

    function feeInfo() external override view returns(address,uint256,uint256) {
        return(feeTo, 0, 0);
    }

    function getPoolFee(address) external view override returns (address, uint256, uint256, bool) {
        return(feeTo, 0, 0, false);
    }

    function setPoolFee(address _pool, address _to, uint16 _protocolFee, uint16 _origFeeShare, bool _isSet) external override {
    }

    function getPools(uint256 start, uint256 end) external override view returns(address[] memory _pools) {
    }

}
