// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import "../interfaces/observer/ILoanObserverStore.sol";
import "../interfaces/observer/ILoanObserver.sol";
import "../interfaces/observer/ICollateralManager.sol";

/// @title Collateral Tracker Store contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Stores Collateral Manager (CM) addresses that can be used by GammaPools (GP) mapped to reference ids.
/// @notice The mapping can be many to many, depending on the implementation of the CM but preferably one GP to many CMs
/// @notice Collateral References can use a discount to lower the origination fees charged by GammaPools
abstract contract AbstractLoanObserverStore is ILoanObserverStore {

    struct LoanObserver {
        address refAddr; // address of observer
        uint16 refFee; // in basis points
        uint8 refTyp; // 0 = not set, 1 = discount only (null observer), 2 = observer does not track collateral (has addr), 3 = observer tracks collateral (has addr, collMgr, can have discount)
        bool active; // if true loans can be observed by observer
        bool restricted; // If restricted, look up permissioned address, the auth check happens here
    }

    mapping(uint256 => LoanObserver) observers;
    mapping(uint256 => mapping(address => bool)) isPoolObserved;
    mapping(uint256 => mapping(address => bool)) allowedToBeObserved; // allowed addresses to create observed loans

    bytes4 private constant COLLATERAL_MANAGER_INTERFACE = type(ICollateralManager).interfaceId;
    bytes4 private constant LOAN_OBSERVER_INTERFACE = type(ILoanObserver).interfaceId;

    /// @dev Get owner of LoanObserverStoreOwner contract to perform permissioned transactions
    function _loanObserverStoreOwner() internal virtual view returns(address);

    /// @dev See {ILoanObserverStore.-setLoanObserver};
    function setLoanObserver(uint256 refId, address refAddr, uint16 refFee, uint8 refTyp, bool active, bool restricted) external override virtual {
        require(msg.sender == _loanObserverStoreOwner(), "FORBIDDEN");
        require(refTyp > 0 && refTyp < 4, "INVALID_TYPE");

        LoanObserver storage exRef = observers[refId];
        if(exRef.refTyp == 0) {
            if(refTyp == 1) {
                observers[refId] = LoanObserver({ refAddr: address(0), refFee: refFee, refTyp: refTyp, active: active, restricted: restricted });
            } else if(refTyp == 2 || refTyp == 3) {
                require(refAddr != address(0), "ZERO_ADDRESS");
                require(ILoanObserver(refAddr).refId() == refId, "REF_ID");
                require(IERC165(refAddr).supportsInterface(LOAN_OBSERVER_INTERFACE), "NOT_LOAN_OBSERVER");
                require(refTyp != 3 || IERC165(refAddr).supportsInterface(COLLATERAL_MANAGER_INTERFACE), "NOT_COLLATERAL_MANAGER");
                observers[refId] = LoanObserver({ refAddr: refAddr, refFee: refFee, refTyp: refTyp, active: active, restricted: restricted });
            }
        } else { // refId, refAddr, and refType do not change
            exRef.refFee = refFee;
            exRef.active = active;
            exRef.restricted = restricted;
        }
    }

    /// @dev See {ILoanObserverStore.-getLoanObserver};
    function getLoanObserver(uint16 refId, address pool, address requester) external override virtual view returns(address, uint16, uint8) {
        require(isPoolObserved[refId][pool], "NOT_SET");

        LoanObserver memory exRef = observers[refId];
        if(!exRef.active) {
            return(address(0), 0, 0);
        }

        require(!exRef.restricted || allowedToBeObserved[refId][requester], "FORBIDDEN");

        return(exRef.refAddr, exRef.refFee, exRef.refTyp);
    }

    /// @dev See {ILoanObserverStore.-unsetPoolObserved};
    function unsetPoolObserved(uint256 refId, address pool) external override virtual {
        require(msg.sender == _loanObserverStoreOwner(), "FORBIDDEN");
        isPoolObserved[refId][pool] = false;
    }

    /// @dev See {ILoanObserverStore.-setPoolObserved};
    function setPoolObserved(uint256 refId, address pool) external override virtual {
        require(msg.sender == _loanObserverStoreOwner(), "FORBIDDEN");
        require(pool != address(0), "ZERO_ADDRESS");
        require(refId > 0, "REF_ID");

        LoanObserver storage ref = observers[refId];

        require(ref.refTyp < 2 || ILoanObserver(ref.refAddr).validate(pool), "INVALID_POOL") ;

        isPoolObserved[refId][pool] = true;
    }

    /// @dev See {ILoanObserverStore.-setAllowedAddress};
    function setAllowedAddress(uint256 refId, address addr, bool isAllowed) external override virtual {
        require(msg.sender == _loanObserverStoreOwner(), "FORBIDDEN");
        allowedToBeObserved[refId][addr] = isAllowed;
    }

}
