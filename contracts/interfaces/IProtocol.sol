// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

interface IProtocol {
    function protocolId() external view returns(uint16);
    function longStrategy() external view returns(address);
    function shortStrategy() external view returns(address);
    function validateCFMM(address[] calldata _tokens, address _cfmm) external view returns(address[] memory tokens);
}
