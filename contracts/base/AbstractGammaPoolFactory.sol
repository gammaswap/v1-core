// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../interfaces/IGammaPoolFactory.sol";
import "../interfaces/IGammaPool.sol";
import "../interfaces/IPausable.sol";
import "../utils/TwoStepOwnable.sol";

/// @title Abstract factory contract to create more GammaPool contracts.
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev If another GammaPoolFactory contract is created it is recommended to inherit from this contract
abstract contract AbstractGammaPoolFactory is IGammaPoolFactory, TwoStepOwnable {

    error Forbidden();
    error ZeroProtocol();
    error ProtocolNotSet();
    error ProtocolExists();
    error ProtocolMismatch();
    error ProtocolRestricted();
    error PoolExists();
    error DeployFailed();
    error ZeroAddress();

    /// @dev See {IGammaPoolFactory-getPool}
    mapping(bytes32 => address) public override getPool; // all GS Pools addresses can be predetermined through key

    /// @dev See {IGammaPoolFactory-getKey}
    mapping(address => bytes32) public override getKey; // predetermined key maps to pool address

    /// @dev See {IGammaPoolFactory-fee}
    uint16 public override fee = 10000; // Default value is 10,000 basis points or 10%

    /// @dev See {IGammaPoolFactory-origFeeShare}
    uint16 public override origFeeShare = 600; // Default value is 600 basis points or 60%

    /// @dev See {IGammaPoolFactory-feeTo}
    address public override feeTo;

    /// @dev See {IGammaPoolFactory-feeToSetter}
    address public override feeToSetter;

    /// @dev Initialize `owner` of factory contract
    constructor(address _owner, address _feeTo, address _feeToSetter) TwoStepOwnable(_owner) {
        feeTo = _feeTo;
        feeToSetter = _feeToSetter;
    }

    /// @dev Revert if sender is not the required address in parameter (e.g. sender not owner or feeToSetter)
    /// @param _address - address transaction sender must be in order to not revert
    function isForbidden(address _address) internal virtual view {
        if(msg.sender != _address) revert Forbidden();
    }

    /// @dev Revert if address parameter is zero address. This is used transaction that are changing an address state variable
    /// @param _address - address that must not be zero
    function isZeroAddress(address _address) internal virtual view {
        if(_address == address(0)) revert ZeroAddress();
    }

    /// @dev Revert if key already maps to a GammaPool. This is used to avoid duplicating GammaPool instances
    /// @param key - unique key used to identify GammaPool instance (e.g. salt)
    function hasPool(bytes32 key) internal virtual view {
        if(getPool[key] != address(0)) revert PoolExists();
    }

    /// @dev See {IGammaPoolFactory-pausePoolFunction}
    function pausePoolFunction(address _pool, uint8 _functionId) external virtual override onlyOwner returns(uint256) {
        return IPausable(_pool).pause(_functionId);
    }

    /// @dev See {IGammaPoolFactory-unpausePoolFunction}
    function unpausePoolFunction(address _pool, uint8 _functionId) external virtual override onlyOwner returns(uint256) {
        return IPausable(_pool).unpause(_functionId);
    }

    /// @dev See {IGammaPoolFactory-setPoolParams}
    function setPoolParams(address _pool, uint16 _origFee, uint8 _extSwapFee, uint8 _emaMultiplier, uint8 _minUtilRate1, uint8 _minUtilRate2, uint16 _feeDivisor, uint8 _liquidationFee, uint8 _ltvThreshold) external virtual override {
        isForbidden(feeToSetter); // only feeToSetter can update origination fee parameters
        IGammaPool(_pool).setPoolParams(_origFee, _extSwapFee, _emaMultiplier, _minUtilRate1, _minUtilRate2, _feeDivisor, _liquidationFee, _ltvThreshold);
        emit PoolParamsUpdate(_pool, _origFee, _extSwapFee, _emaMultiplier, _minUtilRate1, _minUtilRate2, _feeDivisor, _liquidationFee, _ltvThreshold);
    }

    /// @dev See {IGammaPoolFactory-setFee}
    function setFee(uint16 _fee) external virtual override {
        isForbidden(feeToSetter); // only feeToSetter can set the protocol fee
        fee = _fee;
        emit FeeUpdate(address(0), feeTo, _fee, origFeeShare, false);
    }

    /// @dev See {IGammaPoolFactory-setFeeTo}
    function setFeeTo(address _feeTo) external virtual override {
        isForbidden(feeToSetter); // only feeToSetter can set which address receives protocol fees
        feeTo = _feeTo;
        emit FeeUpdate(address(0), _feeTo, fee, origFeeShare, false);
    }

    /// @dev See {IGammaPoolFactory-setOrigFeeShare}
    function setOrigFeeShare(uint16 _origFeeShare) external virtual override {
        isForbidden(feeToSetter); // only feeToSetter can set which address receives protocol fees
        origFeeShare = _origFeeShare;
        emit FeeUpdate(address(0), feeTo, fee, origFeeShare, false);
    }

    /// @dev See {IGammaPoolFactory-setFeeToSetter}
    function setFeeToSetter(address _feeToSetter) external virtual override onlyOwner {
        isZeroAddress(_feeToSetter); // protocol fee setting privileges can't be transferred to the zero address
        feeToSetter = _feeToSetter;
    }

    function cloneDeterministic(address, bytes32 salt) internal virtual returns (address result) {

        bytes memory bytecode = abi.encodePacked(
            hex"608060405234801561001057600080fd5b5060f68061001f6000396000f3fe60",
            hex"806040819052635c60da1b60e01b815260009073",
            address(this),
            hex"90635c60da1b90608490602090600481865afa158015604b573d6000803e3d60",
            hex"00fd5b505050506040513d601f19601f82011682018060405250810190606d91",
            hex"906092565b90503660008037600080366000845af43d6000803e808015608d57",
            hex"3d6000f35b3d6000fd5b60006020828403121560a357600080fd5b8151600160",
            hex"0160a01b038116811460b957600080fd5b939250505056fea264697066735822",
            hex"1220e00b97edf2feacc64cc08f7e5b1dc6fce1cb12cd365908bdd712927eb036",
            hex"ddb264736f6c63430008150033"
        );

        assembly {
            result := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     *
     * @param implementation - implementation address of GammaPool. Because all GammaPools are created as proxy contracts
     * @param salt - the bytes32 key that is unique to the GammaPool and therefore also used as a unique identifier of the GammaPool
     * @return instance - address of GammaPool that was created
     */
    function cloneDeterministic2(address implementation, bytes32 salt) internal virtual returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            // Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
            // of the `implementation` address with the bytecode before the address.
            mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
            // Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
            mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
            instance := create2(0, 0x09, 0x37, salt)
        }
        if(instance == address(0)) revert DeployFailed(); // revert if failed to instantiate GammaPool
    }
}
