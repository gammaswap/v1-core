// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../interfaces/observer/ILoanObserver.sol";
import "../interfaces/IGammaPool.sol";
import "../libraries/AddressCalculator.sol";

/// @title Abstract Loan Observer contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Abstract implementation of ILoanObserver interface, meant to be inherited by every LoanObserver implementation
/// @dev There can be two types of loan observer implementation, type 2 (does not track external collateral) and type 3 (tracks external collateral)
/// @notice onLoanUpdate function should perform GammaPool authentication every time it is called
abstract contract AbstractLoanObserver is ILoanObserver { // TODO: Should have an owner? Should factory be owner?

    /// @dev See {ILoanObserver-factory}
    address immutable public override factory;

    /// @dev See {ILoanObserver-refId}
    uint16 immutable public override refId;

    /// @dev See {ILoanObserver-refType}
    uint16 immutable public override refType;

    /// @dev Set `factory`, `refId`, and `refType`
    constructor(address _factory, uint16 _refId, uint16 _refType) {
        factory = _factory;
        refId = _refId;
        refType = _refType;
    }

    /// @dev Retrieves GammaPool address using cfmm address and protocolId
    /// @param cfmm - address of CFMM of GammaPool whose address we want to calculate
    /// @param protocolId - identifier of GammaPool implementation for the `cfmm`
    /// @return pool - address of GammaPool
    function getGammaPoolAddress(address cfmm, uint16 protocolId) internal virtual view returns(address) {
        return AddressCalculator.calcAddress(factory, protocolId, AddressCalculator.getGammaPoolKey(cfmm, protocolId));
    }

    /// @notice validate that GammaPool was built by factory, and that GammaPool is authorized to be added here
    /// @dev See {ILoanObserver.-validate}
    function validate(address gammaPool) external override virtual view returns(bool) {
        address cfmm = IGammaPool(gammaPool).cfmm();
        uint16 protocolId = IGammaPool(gammaPool).protocolId();
        if(gammaPool != getGammaPoolAddress(cfmm, protocolId)) {
            return false;
        }
        return _validate(gammaPool);
    }

    /// @dev Additional validation logic for observer. E.g. Non-Collateral Managing observers can return true right away
    /// @dev But CollateralManager contracts have to validate observer can handle collateral for this GammaPool
    /// @param gammaPool - address of GammaPool observer contract will observe
    /// @return validated - true if observer can work with `gammaPool`, false otherwise
    function _validate(address gammaPool) internal virtual view returns(bool);

    /// @dev See {ILoanObserver.-onLoanUpdate}
    function onLoanUpdate(address cfmm, uint16 protocolId, uint256 tokenId, bytes memory data) external override virtual returns(uint256 collateral) {
        address gammaPool = getGammaPoolAddress(cfmm, protocolId);
        require(msg.sender == gammaPool, "FORBIDDEN");

        LoanObserved memory loan = abi.decode(data, (LoanObserved));
        return _onLoanUpdate(gammaPool, tokenId, loan);
    }

    /// @dev Update observer when a loan update occurs
    /// @dev If an observer does not hold collateral for loan it should return 0
    /// @param gammaPool - address of GammaPool loan identified by tokenId belongs to
    /// @param tokenId - unique identifier of loan in GammaPool
    /// @param loan - loan observed
    /// @return collateral - loan collateral held outside of GammaPool (Only significant when the loan tracks collateral)
    function _onLoanUpdate(address gammaPool, uint256 tokenId, LoanObserved memory loan) internal virtual returns(uint256 collateral);

}
