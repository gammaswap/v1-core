// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "./base/AbstractGammaPoolFactory.sol";
import "./rates/storage/AbstractRateParamsStore.sol";
import "./libraries/AddressCalculator.sol";
import "./libraries/GammaSwapLibrary.sol";
import "./observer/AbstractLoanObserverStore.sol";
import "./utils/LockableMinimalBeacon.sol";

/// @title Factory contract to create more GammaPool contracts.
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Creates new GammaPool instances as minimal proxy contracts (EIP-1167) to implementation contracts identified by a protocol id
contract GammaPoolFactory is AbstractGammaPoolFactory, AbstractRateParamsStore, AbstractLoanObserverStore {

    struct Fee {
        uint16 protocol;
        uint16 origFeeShare;
        address to;
        bool isSet;
    }

    /// @dev See {IGammaPoolFactory-getProtocol}
    mapping(uint16 => address) public override getProtocol;

    /// @dev See {IGammaPoolFactory-getProtocolBeacon}
    mapping(uint16 => address) public override getProtocolBeacon;

    /// @dev See {IGammaPoolFactory-isProtocolRestricted}
    mapping(uint16 => bool) public override isProtocolRestricted;

    /// @dev fee information by GammaPool
    mapping(address => Fee) private poolFee;

    /// @dev Array of all GammaPool instances created by this factory contract
    address[] public allPools;

    /// @dev Initializes the contract by setting `feeToSetter`, `feeTo`, and `owner`.
    constructor(address _feeTo) AbstractGammaPoolFactory(msg.sender, _feeTo, _feeTo){
    }

    /// @dev See {IGammaPoolFactory-allPoolsLength}
    function allPoolsLength() external virtual override view returns (uint256) {
        return allPools.length;
    }

    /// @dev Revert if GammaPool implementation (protocol) is restricted and msg.sender is not address with permission to create (e.g. owner)
    /// @param _protocolId - id of implementation contract being checked
    /// @param _address - address that has permission to bypass restricted protocol setting
    function isRestricted(uint16 _protocolId, address _address) internal virtual view {
        if(isProtocolRestricted[_protocolId] == true && msg.sender != _address) revert ProtocolRestricted();
    }

    /// @dev Revert if there is no implementation contract set for this _protocolId
    /// @param _protocolId - id of implementation contract being checked
    function isProtocolNotSet(uint16 _protocolId) internal virtual view {
        if(getProtocol[_protocolId] == address(0)) revert ProtocolNotSet();
    }

    /// @dev See {IGammaPoolFactory-addProtocol}
    function addProtocol(address implementation) external virtual override onlyOwner {
        uint16 _protocolId = IProtocol(implementation).protocolId();
        if(_protocolId == 0) revert ZeroProtocol();// implementation protocolId is zero
        if(getProtocol[_protocolId] != address(0)) revert ProtocolExists(); // protocolId already set

        getProtocol[_protocolId] = implementation; // store implementation
        if (_protocolId < 10000) {
            getProtocolBeacon[_protocolId] = address(new LockableMinimalBeacon(address(this), _protocolId)); // only set once
        }
    }

    /// @dev See {IGammaPoolFactory-updateProtocol}
    function updateProtocol(uint16 _protocolId, address _newImplementation) external virtual override onlyOwner {
        isProtocolNotSet(_protocolId);
        if(_protocolId >= 10000) revert NotUpgradable();
        if(IProtocol(_newImplementation).protocolId() == 0) revert ZeroProtocol();
        if(IProtocol(_newImplementation).protocolId() != _protocolId) revert ProtocolMismatch();
        if(getProtocol[_protocolId] == _newImplementation) revert ProtocolExists(); // protocolId already set with same implementation
        if(LockableMinimalBeacon(getProtocolBeacon[_protocolId]).protocol()!= address(0)) revert ProtocolLocked();
        getProtocol[_protocolId] = _newImplementation;
    }

    /// @dev See {IGammaPoolFactory-lockProtocol}
    function lockProtocol(uint16 _protocolId) external virtual override onlyOwner {
        isProtocolNotSet(_protocolId);
        if(_protocolId >= 10000) revert NotLockable();

        LockableMinimalBeacon(getProtocolBeacon[_protocolId]).lock();
    }

    /// @dev See {IGammaPoolFactory-setIsProtocolRestricted}
    function setIsProtocolRestricted(uint16 _protocolId, bool _isRestricted) external virtual override onlyOwner {
        isProtocolRestricted[_protocolId] = _isRestricted;
    }

    /// @dev See {IGammaPoolFactory-createPool}
    function createPool(uint16 _protocolId, address _cfmm, address[] calldata _tokens, bytes calldata _data) external virtual override returns (address pool) {
        isProtocolNotSet(_protocolId); // check there is an implementation contract mapped to _protocolId parameter
        isRestricted(_protocolId, owner); // if implementation is restricted only owner is allowed to create GammaPools for this _protocolId

        // get implementation contract for _protocolId parameter
        address implementation = getProtocol[_protocolId];

        // check GammaPool can be created with this implementation
        address[] memory _tokensOrdered = IProtocol(implementation).validateCFMM(_tokens, _cfmm, _data);

        // calculate unique identifier of GammaPool that will also be used as salt for instantiating the proxy contract address
        bytes32 key = AddressCalculator.getGammaPoolKey(_cfmm, _protocolId);

        hasPool(key); // check this instance hasn't already been created

        // instantiate GammaPool proxy contract address for protocol's implementation contract using unique key as salt for the pool's address
        if (_protocolId < 10000) {
            pool = cloneDeterministic(getProtocolBeacon[_protocolId], _protocolId, key);
        } else {
            pool = cloneDeterministic2(implementation, key);
        }

        uint8[] memory _decimals = getDecimals(_tokensOrdered);
        uint72 _minBorrow = uint72(10**((_decimals[0] + _decimals[1]) / 2));
        IProtocol(pool).initialize(_cfmm, _tokensOrdered, _decimals, _minBorrow, _data); // initialize GammaPool's state variables

        getPool[key] = pool; // map unique key to new instance of GammaPool
        getKey[pool] = key; // map unique key to new instance of GammaPool
        allPools.push(pool); // store new GammaPool instance in an array
        emit PoolCreated(pool, _cfmm, _protocolId, implementation, _tokensOrdered, allPools.length); // store creation details in blockchain
    }

    /// @dev Get decimals of ERC20 tokens of GammaPool's CFMM
    /// @param _tokens - tokens of CFMM tokens in pool
    /// @return _decimals - decimals of CFMM tokens, indices must match _tokens[] array
    function getDecimals(address[] memory _tokens) internal virtual returns(uint8[] memory _decimals) {
        _decimals = new uint8[](_tokens.length);
        for(uint256 i = 0; i < _tokens.length;) {
            _decimals[i] = GammaSwapLibrary.decimals(_tokens[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev See {IGammaPoolFactory-getPoolFee}
    function getPoolFee(address _pool) external view override returns (address _to, uint256 _protocolFee, uint256 _origFeeShare, bool _isSet) {
        Fee storage _fee = poolFee[_pool];
        _isSet = _fee.isSet;
        if(_isSet) {
            _to = _fee.to;
            _protocolFee = _fee.protocol;
            _origFeeShare = _fee.origFeeShare;
        } else {
            _to = feeTo;
            _protocolFee = fee;
            _origFeeShare = origFeeShare;
        }
    }

    /// @dev See {IGammaPoolFactory-setPoolFee}
    function setPoolFee(address _pool, address _to, uint16 _protocolFee, uint16 _origFeeShare, bool _isSet) external virtual override {
        isForbidden(feeToSetter); // only feeToSetter can set the protocol fee
        poolFee[_pool] = Fee({protocol: _protocolFee, origFeeShare: _origFeeShare, to: _to, isSet: _isSet});
        emit FeeUpdate(_pool, _to, _protocolFee, _origFeeShare, _isSet);
    }

    /// @dev See {IGammaPoolFactory-feeInfo}
    function feeInfo() external virtual override view returns(address _feeTo, uint256 _fee, uint256 _origFeeShare) {
        _feeTo = feeTo;
        _fee = fee;
        _origFeeShare = origFeeShare;
    }

    /// @dev See {IGammaPoolFactory-getPools}.
    function getPools(uint256 start, uint256 end) external virtual override view returns(address[] memory _pools) {
        if(start > end || allPools.length == 0) {
            return new address[](0);
        }
        uint256 lastIdx = allPools.length - 1;
        if(start <= lastIdx) {
            uint256 _start = start;
            uint256 _end = lastIdx < end ? lastIdx : end;
            uint256 _size = _end - _start + 1;
            _pools = new address[](_size);
            uint256 k = 0;
            for(uint256 i = _start; i <= _end;) {
                _pools[k] = allPools[i];
                unchecked {
                    ++k;
                    ++i;
                }
            }
        }
    }

    /// @dev See {AbstractRateParamsStore.-_rateParamsStoreOwner};
    function _rateParamsStoreOwner() internal override virtual view returns(address) {
        return owner;
    }

    /// @dev Return rate params store owner
    function rateParamsStoreOwner() external virtual view returns(address) {
        return _rateParamsStoreOwner();
    }

    /// @dev See {AbstractLoanObserverStore.-_loanObserverStoreOwner};
    function _loanObserverStoreOwner() internal override virtual view returns(address) {
        return owner;
    }

    /// @dev Return collateral reference store owner
    function loanObserverStoreOwner() external virtual view returns(address) {
        return _loanObserverStoreOwner();
    }
}
