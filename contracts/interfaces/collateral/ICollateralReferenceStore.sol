// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

/// @title Interface for CollateralReferenceStore
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Interface used for CollateralReferenceStore implementations
interface ICollateralReferenceStore {

    /// @dev Get external collateral reference for a new position being opened
    /// @param refId - address of GammaPool we're setting an external reference for
    /// @param refAddr - address asking collateral reference for (if not permissioned, it should revert. Normally a PositionManager)
    /// @param fee - discount on origination fee to be applied to loans using collateral reference address
    /// @param typ - discount on origination fee to be applied to loans using collateral reference address
    /// @param active - discount on origination fee to be applied to loans using collateral reference address
    /// @param restricted - discount on origination fee to be applied to loans using collateral reference address
    function setExternalReference(uint256 refId, address refAddr, uint16 fee, uint8 typ, bool active, bool restricted) external;

    /// @dev Get external collateral reference for a new position being opened
    /// @param refId - address of GammaPool we're setting an external reference for
    /// @param pool - address of GammaPool we're setting an external reference for
    function setPoolExternalReference(uint256 refId, address pool) external;

    /// @dev Get external collateral reference for a new position being opened
    /// @param refId - address of GammaPool we're setting an external reference for
    /// @param pool - address of GammaPool we're setting an external reference for
    function unsetPoolExternalReference(uint256 refId, address pool) external;

    /// @dev Get external collateral reference for a new position being opened
    /// @param refId - address of GammaPool we're setting an external reference for
    /// @param addr - address of GammaPool we're setting an external reference for
    /// @param isAllowed - address of GammaPool we're setting an external reference for
    function setAllowedAddress(uint256 refId, address addr, bool isAllowed) external;

    /// @dev Get external collateral reference for a new position being opened
    /// @param refId - reference id of information containing collateral reference
    /// @param pool - address asking collateral reference for (if not permissioned, it should revert. Normally a PositionManager)
    /// @param requester - address asking collateral reference for
    /// @return refAddr - address of ICollateralManager contract. Provides external collateral information
    /// @return fee - discount for loan associated with this reference id
    /// @return typ - discount for loan associated with this reference id
    function externalReference(uint16 refId, address pool, address requester) external view returns(address, uint16, uint8);
}
