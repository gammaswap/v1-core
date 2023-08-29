// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../observer/AbstractLoanObserver.sol";
import "../observer/AbstractCollateralManager.sol";

contract TestCollateralManager is AbstractCollateralManager {

    bool mValidate;

    constructor(address _factory, uint16 _refId, bool validate_) AbstractCollateralManager(_factory, _refId) {
        mValidate = validate_;
    }

    function validate(address gammaPool) external override(AbstractLoanObserver,ILoanObserver) virtual view returns(bool) {
        return mValidate;
    }

    function _validate(address gammaPool) internal virtual override view returns(bool) {
        return true;
    }

    function _getCollateral(address gammaPool, uint256 tokenId) internal virtual override view returns(uint256 collateral) {
        collateral = 100;
    }

    function _onLoanUpdate(address gammaPool, uint256 tokenId, LoanObserved memory loan) internal virtual override {
    }

    function _liquidateCollateral(address gammaPool, uint256 tokenId, uint256 amount, address to) internal virtual override returns(uint256 collateral) {
        return 0;
    }
}
