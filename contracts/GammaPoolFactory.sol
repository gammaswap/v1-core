// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "./interfaces/IGammaPool.sol";
import "./base/AbstractGammaPoolFactory.sol";
import "./libraries/AddressCalculator.sol";

/// @title Factory contract to create more GammaPool contracts.
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Creates new GammaPool instances as minimal proxy contracts (EIP-1167) to implementation contracts identified by a protocol id
contract GammaPoolFactory is AbstractGammaPoolFactory {

    struct Fee {
        uint16 protocol;
        uint24 origMin;
        uint24 origMax;
        address to;
        bool isSet;
    }

    /// @dev See {IGammaPoolFactory-getProtocol}
    mapping(uint16 => address) public override getProtocol;

    /// @dev See {IGammaPoolFactory-isProtocolRestricted}
    mapping(uint16 => bool) public override isProtocolRestricted;

    /// @dev fee information by GammaPool
    mapping(address => Fee) private poolFee;

    /// @dev Array of all GammaPool instances created by this factory contract
    address[] public allPools;

    /// @dev Initializes the contract by setting `feeToSetter`, `feeTo`, and `owner`.
    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
        feeTo = _feeToSetter;
        owner = msg.sender;
    }

    /// @dev See {IGammaPoolFactory-allPoolsLength}
    function allPoolsLength() external virtual override view returns (uint256) {
        return allPools.length;
    }

    /// @dev Revert if GammaPool implementation (protocol) is restricted and msg.sender is not address with permission to create (e.g. owner)
    /// @param _protocolId - id of implementation contract being checked
    /// @param _address - address that has permission to bypass restricted protocol setting
    function isRestricted(uint16 _protocolId, address _address) internal virtual view {
        if(isProtocolRestricted[_protocolId] == true && msg.sender != _address) {
            revert ProtocolRestricted();
        }
    }

    /// @dev Revert if there is no implementation contract set for this _protocolId
    /// @param _protocolId - id of implementation contract being checked
    function isProtocolNotSet(uint16 _protocolId) internal virtual view {
        if(getProtocol[_protocolId] == address(0)) {
            revert ProtocolNotSet();
        }
    }

    /// @dev See {IGammaPoolFactory-addProtocol}
    function addProtocol(address implementation) external virtual override {
        isForbidden(owner); // only owner can add an implementation contract (e.g. Governance contract)
        if(IGammaPool(implementation).protocolId() == 0) {
            revert ZeroProtocol();// implementation contract cannot have zero as protocolId
        }
        if(getProtocol[IGammaPool(implementation).protocolId()] != address(0)) {
            revert ProtocolExists();// there cannot already exist an implementation for this protocolId
        }
        getProtocol[IGammaPool(implementation).protocolId()] = implementation; // store implementation
    }

    /// @dev See {IGammaPoolFactory-removeProtocol}
    function removeProtocol(uint16 _protocolId) external virtual override {
        isForbidden(owner); // only owner can remove an implementation contract (e.g. Governance contract)
        getProtocol[_protocolId] = address(0);
    }

    /// @dev See {IGammaPoolFactory-setIsProtocolRestricted}
    function setIsProtocolRestricted(uint16 _protocolId, bool _isRestricted) external virtual override {
        isForbidden(owner); // only owner can set an implementation as restricted (e.g. Governance contract)
        isProtocolRestricted[_protocolId] = _isRestricted;
    }

    /// @dev See {IGammaPoolFactory-createPool}
    function createPool(uint16 _protocolId, address _cfmm, address[] calldata _tokens, bytes calldata _data) external virtual override returns (address pool) {
        isProtocolNotSet(_protocolId); // check there is an implementation contract mapped to _protocolId parameter
        isRestricted(_protocolId, owner); // if implementation is restricted only owner is allowed to create GammaPools for this _protocolId

        // get implementation contract for _protocolId parameter
        address implementation = getProtocol[_protocolId];

        // check GammaPool can be created with this implementation
        (address[] memory _tokensOrdered, uint8[] memory _decimals) = IGammaPool(implementation).validateCFMM(_tokens, _cfmm, _data);

        // calculate unique identifier of GammaPool that will also be used as salt for instantiating the proxy contract address
        bytes32 key = AddressCalculator.getGammaPoolKey(_cfmm, _protocolId);

        hasPool(key); // check this instance hasn't already been created

        // instantiate GammaPool proxy contract address for protocol's implementation contract using unique key as salt for the pool's address
        pool = cloneDeterministic(implementation, key);

        IGammaPool(pool).initialize(_cfmm, _tokensOrdered, _decimals, _data); // initialize GammaPool's state variables

        getPool[key] = pool; // map unique key to new instance of GammaPool
        allPools.push(pool); // store new GammaPool instance in an array
        emit PoolCreated(pool, _cfmm, _protocolId, implementation, _tokensOrdered, allPools.length); // store creation details in blockchain
    }

    /// @dev See {IGammaPoolFactory-getPoolFee}
    function getPoolFee(address _pool) external view override returns (address _to, uint256 _protocolFee, uint256 _origMinFee, uint256 _origMaxFee, bool _isSet) {
        Fee storage _fee = poolFee[_pool];
        _isSet = _fee.isSet;
        if(_isSet) {
            _to = _fee.to;
            _protocolFee = _fee.protocol;
            _origMinFee = _fee.origMin;
            _origMaxFee = _fee.origMax;
        } else {
            _to = feeTo;
            _protocolFee = fee;
            _origMinFee = origMin;
            _origMaxFee = origMax;
        }
    }

    /// @dev See {IGammaPoolFactory-setPoolFee}
    function setPoolFee(address _pool, address _to, uint16 _protocolFee, uint24 _origMinFee, uint24 _origMaxFee, bool _isSet) external virtual override {
        isForbidden(feeToSetter); // only feeToSetter can set the protocol fee
        poolFee[_pool] = Fee({protocol: _protocolFee, origMin: _origMinFee, origMax: _origMaxFee, to: _to, isSet: _isSet});
    }

    /// @dev See {IGammaPoolFactory-feeInfo}
    function feeInfo() external virtual override view returns(address _feeTo, uint256 _fee, uint256 _origMin, uint256 _origMax) {
        _feeTo = feeTo;
        _fee = fee;
        _origMin = origMin;
        _origMax = origMax;
    }

    /// @dev See {IGammaPoolFactory-setFee}
    function setFee(uint16 _fee, uint24 _origMin, uint24 _origMax) external virtual {
        isForbidden(feeToSetter); // only feeToSetter can set the protocol fee
        fee = _fee;
        origMin = _origMin;
        origMax = _origMax;
    }

    /// @dev See {IGammaPoolFactory-setFeeTo}
    function setFeeTo(address _feeTo) external {
        isForbidden(feeToSetter); // only feeToSetter can set which address receives protocol fees
        feeTo = _feeTo;
    }

    /// @dev See {IGammaPoolFactory-setFeeToSetter}
    function setFeeToSetter(address _feeToSetter) external {
        isForbidden(owner); // only owner (e.g. Governance) can transfer feeToSetter privileges
        isZeroAddress(_feeToSetter); // protocol fee setting privileges can't be transferred to the zero address
        feeToSetter = _feeToSetter;
    }

}
