// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

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

    constructor() AbstractGammaPoolFactory(msg.sender, msg.sender, msg.sender)  {
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

    function removeProtocol(uint16) external override {
        protocol = address(0);
    }

    function getProtocol(uint16) external override view returns (address) {
        return protocol;
    }

    function allPoolsLength() external override pure returns (uint256) {
        return 0;
    }

    function feeInfo() external override view returns(address,uint256) {
        return(feeTo, 0);
    }

    function getPoolFee(address) external view override returns (address, uint256, bool) {
        return(feeTo, 0, false);
    }

    function setPoolFee(address _pool, address _to, uint16 _protocolFee, bool _isSet) external override {
    }

    function getPools(uint256 start, uint256 end) external override view returns(address[] memory _pools) {
    }
}
