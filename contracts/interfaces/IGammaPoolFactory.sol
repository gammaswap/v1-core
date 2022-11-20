// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

interface IGammaPoolFactory {
    event PoolCreated(address indexed pool, address indexed cfmm, uint16 indexed protocolId, address implementation, uint256 count);

    function isProtocolRestricted(uint16 protocolId) external view returns(bool);
    function setIsProtocolRestricted(uint16 protocolId, bool isRestricted) external;
    function addProtocol(address implementation) external;
    function removeProtocol(uint16 protocolId) external;
    function getProtocol(uint16 protocolId) external view returns (address);
    function createPool(uint16 protocolId, address cfmm, address[] calldata tokens) external returns(address);
    function getPool(bytes32 salt) external view returns(address);
    function allPoolsLength() external view returns (uint256);
    function feeToSetter() external view returns(address);
    function owner() external view returns(address);
    function fee() external view returns(uint256);
    function feeTo() external view returns(address);
    function feeInfo() external view returns(address,uint);
}