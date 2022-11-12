// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

interface IGammaPoolFactory {
    event PoolCreated(address indexed pool, address indexed cfmm, uint24 indexed protocolId, address protocol, uint256 count);

    struct CreatePoolParams {
        address cfmm;
        uint24 protocol;
        address[] tokens;
    }

    function isProtocolRestricted(uint24 protocol) external view returns(bool);
    function setIsProtocolRestricted(uint24 protocol, bool isRestricted) external;
    function addProtocol(address protocol) external;
    function removeProtocol(uint24 protocol) external;
    function getProtocol(uint24 protocol) external view returns (address);
    function createPool(CreatePoolParams calldata params) external returns(address);
    function getPool(bytes32 salt) external view returns(address);
    function allPoolsLength() external view returns (uint256);
    function feeToSetter() external view returns(address);
    function implementation() external view returns(address);
    function owner() external view returns(address);
    function fee() external view returns(uint256);
    function feeTo() external view returns(address);
    function feeInfo() external view returns(address,uint);
}