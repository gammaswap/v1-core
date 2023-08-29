// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title Interface for Loan Observer Store
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Interface used for Loan Observer Store implementations
interface ILoanObserverStore {

    /// @dev Get external collateral reference for a new position being opened
    /// @param refId - address of GammaPool we're setting an external reference for
    /// @param refAddr - address asking collateral reference for (if not permissioned, it should revert. Normally a PositionManager)
    /// @param refFee - discount on origination fee to be applied to loans using collateral reference address
    /// @param refType - discount on origination fee to be applied to loans using collateral reference address
    /// @param active - discount on origination fee to be applied to loans using collateral reference address
    /// @param restricted - discount on origination fee to be applied to loans using collateral reference address
    function setLoanObserver(uint256 refId, address refAddr, uint16 refFee, uint8 refType, bool active, bool restricted) external;

    /// @dev Allow users to create loans in pool that will be observed by observer with reference id `refId`
    /// @param refId - reference id of observer
    /// @param pool - address of GammaPool we are requesting information for
    function setPoolObserved(uint256 refId, address pool) external;

    /// @dev Prohibit users to create loans in pool that will be observed by observer with reference id `refId`
    /// @param refId - reference id of observer
    /// @param pool - address of GammaPool we are requesting information for
    function unsetPoolObserved(uint256 refId, address pool) external;

    /// @dev Check if a pool can use observer
    /// @param refId - reference id of observer
    /// @param pool - address of GammaPool we are requesting information for
    /// @return observed - if true observer can observe loans from pool
    function isPoolObserved(uint256 refId, address pool) external view returns(bool);

    /// @dev Allow a user address to open loans that can be observed by observer
    /// @param refId - reference id of observer
    /// @param user - address that can open loans that use observer
    /// @param isAllowed - if true observer can observe loans created by user
    function allowToBeObserved(uint256 refId, address user, bool isAllowed) external;

    /// @dev Check if a user can open loans that are observed by observer
    /// @param refId - reference id of observer
    /// @param user - address that can open loans that use observer
    /// @return allowed - if true observer can observe loans created by user
    function isAllowedToBeObserved(uint256 refId, address user) external view returns(bool);

    /// @dev Get observer identified with reference id `refId`
    /// @param refId - reference id of information containing collateral reference
    /// @return refAddr - address of ICollateralManager contract. Provides external collateral information
    /// @return refFee - discount for loan associated with this reference id
    /// @return refType - discount for loan associated with this reference id
    /// @return active - discount on origination fee to be applied to loans using collateral reference address
    /// @return restricted - discount on origination fee to be applied to loans using collateral reference address
    function getLoanObserver(uint256 refId) external view returns(address, uint16, uint8, bool, bool);

    /// @dev Get observer for a new loan being opened if the observer exists, the pool is registered with the observer,
    /// @dev and the user is allowed to create loans observed by observer identified by `refId`
    /// @param refId - reference id of information containing collateral reference
    /// @param pool - address asking collateral reference for (if not permissioned, it should revert. Normally a PositionManager)
    /// @param user - address asking collateral reference for
    /// @return refAddr - address of ICollateralManager contract. Provides external collateral information
    /// @return refFee - discount for loan associated with this reference id
    /// @return refType - discount for loan associated with this reference id
    function getPoolObserverByUser(uint16 refId, address pool, address user) external view returns(address, uint16, uint8);
}
