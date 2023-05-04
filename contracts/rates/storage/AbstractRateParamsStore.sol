// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../../interfaces/rates/IRateModel.sol";
import "../../interfaces/rates/storage/IRateParamsStore.sol";

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

    function _validateParameters(address _pool, bytes calldata data) internal virtual view returns(bool) {
        try IRateModel(_pool).validateParameters(data) {
            return true;
        } catch {
            return false;
        }
        return true;
    }

    /// @dev See {IRateParamsStore-getRateParams}
    function getRateParams(address _pool) external override virtual view returns(RateParams memory) {
        return rateParams[_pool];
    }
}
