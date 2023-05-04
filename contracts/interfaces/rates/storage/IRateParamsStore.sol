// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title Interface of Interest Rate Model Store
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Interface of contract that saves and retrieves interest rate model parameters
interface IRateParamsStore {

    /// @dev Rate model parameters
    struct RateParams {
        /// @dev Model parameters as bytes, needs to be decoded into model's specific struct
        bytes data;
        /// @dev Boolean value specifying if model parameters from store should be used
        bool active;
    }

    /// @dev Event emitted when an interest rate model's parameters are updated
    /// @param pool - address of GammaPool whose rate model parameters will be updated
    /// @param data - rate parameter model
    /// @param active - set rate parameter model active (if false bytes(0) should be returned)
    event RateParamsUpdate(address indexed pool, bytes data, bool active);

    /// @dev Update rate model parameters of `pool`
    /// @param pool - address of GammaPool whose rate model parameters will be updated
    /// @param data - rate parameter model
    /// @param active - set rate parameter model active (if false bytes(0) should be returned)
    function setRateParams(address pool, bytes calldata data, bool active) external;

    /// @dev Get rate model parameters for `pool`
    /// @param pool - address of GammaPool whose rate model parameters will be returned
    /// @return params - rate model parameters for `pool` as bytes
    function getRateParams(address pool) external view returns(RateParams memory params);
}
