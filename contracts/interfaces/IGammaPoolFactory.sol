// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IGammaPoolFactory {
    struct CreatePoolParams {
        address cfmm;
        uint24 protocol;
        address[] tokens;
    }

    struct Parameters {
        address cfmm;
        uint24 protocolId;
        address[] tokens;
        address protocol;
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
    function owner() external view returns(address);
    function fee() external view returns(uint256);
    function feeTo() external view returns(address);
    function feeInfo() external view returns(address,uint);
    function parameters() external view returns (address cfmm, uint24 protocolId, address[] memory tokens, address protocol);//, address longStrategy, address shortStrategy);
}