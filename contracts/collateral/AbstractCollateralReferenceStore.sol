// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../interfaces/collateral/ICollateralManager.sol";
import "../interfaces/collateral/ICollateralReferenceStore.sol";

/// @title Collateral Reference Store contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Stores Collateral Manager (CM) addresses that can be used by GammaPools (GP) mapped to reference ids.
/// @notice The mapping can be many to many, depending on the implementation of the CM but preferably one GP to many CMs
/// @notice Collateral References can use a discount to lower the origination fees charged by GammaPools
abstract contract AbstractCollateralReferenceStore is ICollateralReferenceStore {

    /*So if we set the collateralManager, can it be set to discount only? Should be able to right?
    we want to avoid refId being and address in one pool and not being an address in another pool
    The collateralRef should be able to do 4 things
        -apply origination fee discounts with/without collateralRef address
        -apply origination fee referrals/rebates with/without collateralRef address
        -handle rewards program through additional collateral (i.e. track outstanding loan balance)
        -vault strategies (loan insurance, Hedged LPing, etc.)
        -permissioned to a specific address
        *Referrals are performed by human users (not desirable), so they have their own way (doesn't auto stake or use any other logic)
            -refAddress: receiver of referral
            -discount: % of orig fee sent to referrer
            -auth: PM
        *Discounts:
            -refAddress: 0
            -discount: % of orig fee
            -auth: PM (handles NFT, etc.)
        *Vaults/Apps/AutoStaking:
            -refAddress: collMgr holding the collateral / collMgr issuing additional tokens (will track balance as it is repaid)
            -discount: % applied to this collMgr
            -auth: PM
        *This can tell us about how the loan was closed but if it was partially closed, it won't be useful
    */

    struct ExternalReference {
        address refAddr;
        uint16 refFee; // in basis points
        uint8 refTyp; // 0 = not set, 1 = discount, 2 = referral (has addr), 3 = app (has addr, collMgr, can have discount)
        bool active;
        bool restricted; // If restricted, look up permissioned address, the auth check happens here
    }

    mapping(uint256 => ExternalReference) references;
    mapping(uint256 => mapping(address => bool)) poolReferences;
    mapping(uint256 => mapping(address => bool)) allowed; // allowed addresses

    /// @dev Get owner of CollateralReferenceStore contract to perform permissioned transactions
    function _collateralReferenceStoreOwner() internal virtual view returns(address);

    /// @dev See {ICollateralReferenceStore.-addExternalReference};
    function setExternalReference(uint256 refId, address refAddr, uint16 refFee, uint8 refTyp, bool active, bool restricted) external override virtual {
        require(refTyp > 0 && refTyp < 4, "INVALID_TYPE");

        ExternalReference storage exRef = references[refId];
        if(exRef.refTyp == 0) {
            if(refTyp == 1) {
                references[refId] = ExternalReference({ refAddr: address(0), refFee: refFee, refTyp: refTyp, active: active, restricted: restricted });
            } else if(refTyp == 2 || refTyp == 3) {
                require(refAddr != address(0), "ZERO_ADDRESS");
                require(refTyp < 3 || ICollateralManager(refAddr).refId() == refId, "REF_ID");
                references[refId] = ExternalReference({ refAddr: refAddr, refFee: refFee, refTyp: refTyp, active: active, restricted: restricted });
            }
        } else { // refId, refAddr, and refTyp do not change
            exRef.refFee = refFee;
            exRef.active = active;
            exRef.restricted = restricted;
        }
    }

    /// @dev See {ICollateralReferenceStore.-setAllowedAddress};
    function setAllowedAddress(uint256 refId, address addr, bool isAllowed) external override virtual {
        allowed[refId][addr] = isAllowed;
    }

    /// @dev See {ICollateralReferenceStore.-setExternalReference};
    function unsetPoolExternalReference(uint256 refId, address pool) external override virtual {
        require(msg.sender == _collateralReferenceStoreOwner(), "FORBIDDEN");
        poolReferences[refId][pool] = false;
    }

    /// @dev See {ICollateralReferenceStore.-setExternalReference};
    function setPoolExternalReference(uint256 refId, address pool) external override virtual {
        require(msg.sender == _collateralReferenceStoreOwner(), "FORBIDDEN");
        require(pool != address(0), "ZERO_ADDRESS");
        require(refId > 0, "REF_ID");

        ExternalReference storage ref = references[refId];

        require(ref.refTyp < 3 || ICollateralManager(ref.refAddr).validate(pool), "INVALID_POOL") ;

        poolReferences[refId][pool] = true;
    }

    /// @dev See {ICollateralReferenceStore.-externalReference};
    function externalReference(uint16 refId, address pool, address requester) external override virtual view returns(address, uint16, uint8) {
        require(poolReferences[refId][pool], "NOT_SET");

        ExternalReference memory exRef = references[refId];
        if(!exRef.active) {
            return(address(0), 0, 0);
        }

        require(!exRef.restricted || allowed[refId][requester], "FORBIDDEN");

        return(exRef.refAddr, exRef.refFee, exRef.refTyp);
    }
}
