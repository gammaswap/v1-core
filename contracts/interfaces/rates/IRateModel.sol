// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title Interface of Interest Rate Model Store
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Interface of contract that saves and retrieves interest rate model parameters
interface IRateModel {
    function validateParameters(bytes calldata _data) external view returns(bool);

    function rateParamsStore() external view returns(address);
}
