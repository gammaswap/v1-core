// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "./AbstractLoanObserver.sol";
import "../interfaces/observer/ICollateralManager.sol";

/// @title Abstract Collateral Manager contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Abstract implementation of ILoanObserver interface, meant to be inherited by every LoanObserver implementation
/// @dev There can be two types of loan observer implementation, type 2 (does not track external collateral) and type 3 (tracks external collateral)
/// @notice onLoanUpdate function should perform GammaPool authentication every time it is called
/// @notice This contract is supposed to serve many GammaPools
abstract contract AbstractCollateralManager is ICollateralManager, AbstractLoanObserver {

    /// @dev Set `factory`, and `refId`
    constructor(address _factory, uint16 _refId) AbstractLoanObserver(_factory, _refId, 3) {
        _registerInterface(type(ICollateralManager).interfaceId);
    }

    /// @dev See {ICollateralManager.-getCollateral}
    function getCollateral(address gammaPool, uint256 tokenId) external virtual override view returns(uint256 collateral) {
        return _getCollateral(gammaPool, tokenId);
    }

    /// @dev See {ICollateralManager.-liquidateCollateral}
    function liquidateCollateral(address cfmm, uint16 protocolId, uint256 tokenId, uint256 amount, address to) external virtual override returns(uint256 collateral) {
        address gammaPool = getGammaPoolAddress(cfmm, protocolId);
        require(msg.sender == gammaPool, "FORBIDDEN");

        return _liquidateCollateral(gammaPool, tokenId, amount, to);
    }

    /// @dev Liquidate loan debt of loan identified by tokenId
    /// @param gammaPool - address of GammaPool loan identified by tokenId belongs to
    /// @param tokenId - unique identifier of loan in GammaPool
    /// @param amount - liquidity amount to liquidate
    /// @param to - address of liquidator
    /// @return collateral - loan collateral held outside of GammaPool (Only significant when the loan tracks collateral)
    function _liquidateCollateral(address gammaPool, uint256 tokenId, uint256 amount, address to) internal virtual returns(uint256 collateral);
}
