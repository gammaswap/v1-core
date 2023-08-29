// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../observer/AbstractLoanObserver.sol";

contract TestLoanObserver is AbstractLoanObserver {

    bool mValidate;

    constructor(address _factory, uint16 _refId, uint16 _refType, bool validate_) AbstractLoanObserver(_factory, _refId, _refType) {
        mValidate = validate_;
    }

    function validate(address gammaPool) external override(AbstractLoanObserver) virtual view returns(bool) {
        return mValidate;
    }

    function _validate(address gammaPool) internal virtual override view returns(bool) {
        return true;
    }

    function _onLoanUpdate(address gammaPool, uint256 tokenId, LoanObserved memory loan) internal override virtual {
    }
}
