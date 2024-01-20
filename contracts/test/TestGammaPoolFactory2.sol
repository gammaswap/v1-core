// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../libraries/AddressCalculator.sol";
import "../base/AbstractGammaPoolFactory.sol";
import "../interfaces/IGammaPool.sol";

contract TestGammaPoolFactory2 is AbstractGammaPoolFactory {

    address public deployer;
    address public cfmm;
    uint16 public protocolId;
    address[] public tokens;
    address public protocol;
    uint8[] public decimals;
    uint16 private origFeeShare2;

    constructor() AbstractGammaPoolFactory(msg.sender, msg.sender, msg.sender) {
    }

    function createPool2(bytes calldata _data) external virtual returns(address pool) {
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

    function getPoolFee(address) external view override returns (address _feeTo, uint256 _protocolFee, uint256 _origFeeShare, bool _isActive) {
        return(feeTo, 0, origFeeShare2, false);
    }

    function setOrigFeeShare2(uint16 _origFeeShare) external virtual {
        origFeeShare2 = _origFeeShare;
    }

    function setPoolFee(address _pool, address _to, uint16 _protocolFee, uint16 _origFeeShare, bool _isSet) external override {
    }

    function getPools(uint256 start, uint256 end) external override view returns(address[] memory _pools) {
    }
}
