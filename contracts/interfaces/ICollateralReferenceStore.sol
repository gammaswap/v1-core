pragma solidity >=0.8.4;

/// @title Interface for CollateralReferenceStore
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Interface used for CollateralReferenceStore implementations
interface ICollateralReferenceStore {
    /// @dev Get external collateral reference for a new position being opened
    /// @param refId - reference id of information containing collateral reference
    /// @param requester - address asking collateral reference for (if not permissioned, it should revert. Normally a PositionManager)
    /// @return collateralRef - address of ICollateralManager contract. Provides external collateral information
    /// @return feeDiscount - discount for loan associated with this reference id
    function externalReference(uint16 refId, address requester) external view returns(address, uint16);
}
