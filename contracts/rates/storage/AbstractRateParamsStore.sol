// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../../interfaces/rates/IRateModel.sol";
import "../../interfaces/rates/storage/IRateParamsStore.sol";

/// @title Contract to implement common functions from IRateParamsStore
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Abstract contract meant to be inherited by every Rate Parameter store contract
abstract contract AbstractRateParamsStore is IRateParamsStore {

    /// @dev rate information by GammaPool
    mapping(address => RateParams) private rateParams;

    /// @dev Get owner of RateParamsStore contract to perform permissioned transactions
    function _rateParamsStoreOwner() internal virtual view returns(address);

    /// @dev See {IRateParamsStore-setRateParams}
    function setRateParams(address _pool, bytes calldata data, bool active) external override virtual {
        require(msg.sender == _rateParamsStoreOwner(), "FORBIDDEN");
        require(_validateParameters(_pool, data), "VALIDATE");
        rateParams[_pool] = RateParams({ data: data, active: active});
        emit RateParamsUpdate(_pool, data, active);
    }

    /// @dev validate the rate model parameters that we'll store for the pool
    /// @param _rateModel - address of rate model
    /// @param _data - rate model parameters in bytes
    /// @return validated - true if parameters are validated by the rate model
    function _validateParameters(address _rateModel, bytes calldata _data) internal virtual view returns(bool validated) {
        try IRateModel(_rateModel).validateParameters(_data) returns (bool _validated){
            validated = _validated;
        } catch {
            validated = false;
        }
    }

    /// @dev See {IRateParamsStore-getRateParams}
    function getRateParams(address _pool) external override virtual view returns(RateParams memory) {
        return rateParams[_pool];
    }
}
