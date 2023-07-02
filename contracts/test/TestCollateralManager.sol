// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../observer/AbstractLoanObserver.sol";
import "../observer/AbstractCollateralManager.sol";

contract TestCollateralManager is AbstractCollateralManager {

    constructor(address _factory, uint16 _refId) AbstractCollateralManager(_factory, _refId) {
    }

    // TODO: must have some logic to validate GammaPool's collateral
    function _validate(address gammaPool) internal virtual override view returns(bool) {
        return true;
    }

    // TODO: must return right collateral
    function _onLoanUpdate(address gammaPool, uint256 tokenId, LoanObserved memory loan) internal virtual override returns(uint256 collateral) {
        return 0;
    }

    // TODO: must liquidate collateral
    function _liquidateCollateral(address gammaPool, uint256 tokenId, uint256 amount, address to) internal virtual override returns(uint256 collateral) {
        return 0;
    }
}
