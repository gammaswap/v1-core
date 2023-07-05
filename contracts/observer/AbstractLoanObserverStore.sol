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

    /// @dev struct containing information about LoanObserver that will run after every state update to a loan
    struct LoanObserver {
        /// @dev address of observer contract, can be null in which case the observer is not used
        address refAddr; // address of observer
        /// @dev fee discount in basis points, when refAddr is address(0), only fee discount is used
        uint16 refFee;
        /// @dev observer type, when set to 1 refAddr is expected to be the zero address
        uint8 refType; // 0 = not set, 1 = discount only (null observer), 2 = observer does not track collateral (has addr), 3 = observer tracks collateral (has addr, collMgr, can have discount)
        /// @dev if true loans can be observed by observer, otherwise it will always return the zero values when called by observed contract
        bool active;
        /// @dev if true, an address must have permission to request its loan to be observed by this observer
        bool restricted;
    }

    /// @dev mapping of observers to reference ids
    mapping(uint256 => LoanObserver) observers;
    /// @dev address of pools registered with observer
    mapping(uint256 => mapping(address => bool)) public override isPoolObserved;
    /// @dev addresses allowed to create observed loans
    mapping(uint256 => mapping(address => bool)) public override isAllowedToBeObserved;

    bytes4 private constant COLLATERAL_MANAGER_INTERFACE = type(ICollateralManager).interfaceId;
    bytes4 private constant LOAN_OBSERVER_INTERFACE = type(ILoanObserver).interfaceId;

    /// @dev Get owner of LoanObserverStoreOwner contract to perform permissioned transactions
    function _loanObserverStoreOwner() internal virtual view returns(address);

    /// @dev See {ILoanObserverStore.-getLoanObserver};
    function getLoanObserver(uint256 refId) external override virtual view returns(address, uint16, uint8, bool, bool) {
        LoanObserver memory exRef = observers[refId];
        return(exRef.refAddr, exRef.refFee, exRef.refType, exRef.active, exRef.restricted);
    }

    /// @dev See {ILoanObserverStore.-setLoanObserver};
    function setLoanObserver(uint256 refId, address refAddr, uint16 refFee, uint8 refType, bool active, bool restricted) external override virtual {
        require(msg.sender == _loanObserverStoreOwner(), "FORBIDDEN");
        require(refType > 0 && refType < 4, "INVALID_TYPE");
        require(refId > 0, "INVALID_REF_ID");

        LoanObserver storage exRef = observers[refId];
        if(exRef.refType == 0) {
            if(refType == 1) {
                require(refAddr == address(0), "NOT_ZERO_ADDRESS");
                observers[refId] = LoanObserver({ refAddr: address(0), refFee: refFee, refType: refType, active: active, restricted: restricted });
            } else if(refType == 2 || refType == 3) {
                require(refAddr != address(0), "ZERO_ADDRESS");
                require(IERC165(refAddr).supportsInterface(LOAN_OBSERVER_INTERFACE), "NOT_LOAN_OBSERVER");
                require(refType != 3 || IERC165(refAddr).supportsInterface(COLLATERAL_MANAGER_INTERFACE), "NOT_COLLATERAL_MANAGER");
                require(ILoanObserver(refAddr).refId() == refId, "REF_ID");
                observers[refId] = LoanObserver({ refAddr: refAddr, refFee: refFee, refType: refType, active: active, restricted: restricted });
            }
        } else { // refId, refAddr, and refType do not change
            require(exRef.refAddr == refAddr, "INVALID_REF_ADDR");
            require(exRef.refType == refType, "REF_TYPE_UPDATE");
            exRef.refFee = refFee;
            exRef.active = active;
            exRef.restricted = restricted;
        }
    }

    /// @dev See {ILoanObserverStore.-getPoolObserverByUser};
    function getPoolObserverByUser(uint16 refId, address pool, address user) external override virtual view returns(address, uint16, uint8) {
        require(refId > 0, "REF_ID");
        require(pool != address(0), "ZERO_ADDRESS_POOL");
        require(user != address(0), "ZERO_ADDRESS_USER");
        require(isPoolObserved[refId][pool], "NOT_SET");

        LoanObserver memory exRef = observers[refId];
        if(!exRef.active) {
            return(address(0), 0, 0);
        }

        require(!exRef.restricted || isAllowedToBeObserved[refId][user], "FORBIDDEN");

        return(exRef.refAddr, exRef.refFee, exRef.refType);
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
        require(refId > 0, "INVALID_REF_ID");

        LoanObserver storage ref = observers[refId];

        require(ref.refType > 0, "NOT_EXISTS");
        require(ref.refType < 2 || ILoanObserver(ref.refAddr).validate(pool), "INVALID_POOL") ;

        isPoolObserved[refId][pool] = true;
    }

    /// @dev See {ILoanObserverStore.-allowToBeObserved};
    function allowToBeObserved(uint256 refId, address user, bool isAllowed) external override virtual {
        require(msg.sender == _loanObserverStoreOwner(), "FORBIDDEN");
        require(refId > 0, "REF_ID");
        require(user != address(0), "ZERO_ADDRESS");
        require(observers[refId].refType > 0, "NOT_EXISTS");

        isAllowedToBeObserved[refId][user] = isAllowed;
    }

}
