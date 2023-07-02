// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../observer/AbstractLoanObserver.sol";

contract TestLoanObserver is AbstractLoanObserver {

    constructor(address _factory, uint16 _refId, uint16 _refType) AbstractLoanObserver(_factory, _refId, _refType) {
    }

    function _validate(address gammaPool) internal virtual override view returns(bool) {
        return true;
    }

    function _onLoanUpdate(address gammaPool, uint256 tokenId, LoanObserved memory loan) internal override virtual returns(uint256 collateral) {
        return 0;
    }
}
