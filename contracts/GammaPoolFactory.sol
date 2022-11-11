// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "./GammaPool.sol";
import "./interfaces/IGammaPoolFactory.sol";
import "./interfaces/IProtocol.sol";
import "./libraries/AddressCalculator.sol";
import "./PoolDeployer.sol";
import "hardhat/console.sol";

contract GammaPoolFactory is IGammaPoolFactory {

    error Forbidden();
    error ZeroProtocol();
    error ProtocolNotSet();
    error ProtocolExists();
    error ProtocolRestricted();
    error PoolExists();
    error DeployFailed();

    address public override feeToSetter;
    address public override owner;
    address public override feeTo;
    uint256 public override fee = 5 * (10**16); //5% of borrowed interest gains by default

    mapping(uint24 => address) public override getProtocol;//there's a protocol
    mapping(bytes32 => address) public override getPool;//all GS Pools addresses can be predetermined
    mapping(uint24 => bool) public override isProtocolRestricted;//a protocol creation can be restricted

    address[] public allPools;

    Parameters private _params;

    address public deployer;

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
        feeTo = _feeToSetter;
        owner = msg.sender;
        deployer = address(new PoolDeployer());
    }

    function parameters() external virtual override view returns(address _cfmm, uint24 _protocolId, address[] memory _tokens, address _protocol) {
        _cfmm = _params.cfmm;
        _protocolId = _params.protocolId;
        _tokens = _params.tokens;
        _protocol = _params.protocol;
    }

    function allPoolsLength() external virtual override view returns (uint) {
        return allPools.length;
    }

    function isForbidden(address _owner) internal virtual view {
        if(msg.sender != _owner) {
            revert Forbidden();
        }
    }

    function isRestricted(uint24 protocolId, address _owner) internal virtual view {
        if(isProtocolRestricted[protocolId] == true && msg.sender != _owner) {
            revert ProtocolRestricted();
        }
    }

    function isProtocolNotSet(uint24 protocolId) internal virtual view {
        if(getProtocol[protocolId] == address(0)) {
            revert ProtocolNotSet();
        }
    }

    function hasPool(bytes32 key) internal virtual view {
        if(getPool[key] != address(0)) {
            revert PoolExists();
        }
    }

    function addProtocol(address protocol) external virtual override {
        isForbidden(owner);
        if(IProtocol(protocol).protocol() == 0) {
            revert ZeroProtocol();
        }
        if(getProtocol[IProtocol(protocol).protocol()] != address(0)) {
            revert ProtocolExists();
        }
        getProtocol[IProtocol(protocol).protocol()] = protocol;
    }

    function removeProtocol(uint24 protocol) external virtual override {
        isForbidden(owner);
        getProtocol[protocol] = address(0);
    }

    function setIsProtocolRestricted(uint24 protocol, bool isRestricted) external virtual override {
        isForbidden(owner);
        isProtocolRestricted[protocol] = isRestricted;
    }

    function createPool(CreatePoolParams calldata params) external virtual override returns (address pool) {
        uint24 protocolId = params.protocol;

        //require(getProtocol[protocolId] != address(0), "PROT_NOT_SET");
        isProtocolNotSet(protocolId);
        //require(isProtocolRestricted[protocolId] == false || msg.sender == owner, "RESTRICTED");
        isRestricted(protocolId, owner);

        address protocol = getProtocol[protocolId];

        address cfmm = params.cfmm;

        _params = Parameters({cfmm: cfmm, protocolId: protocolId, tokens: new address[](0), protocol: protocol});

        _params.tokens = IProtocol(protocol).validateCFMM(params.tokens, cfmm);
        bytes32 key = AddressCalculator.getGammaPoolKey(cfmm, protocolId);

        //require(getPool[key] == address(0), "POOL_EXISTS");
        hasPool(key);

        (bool success, bytes memory data) = deployer.delegatecall(abi.encodeWithSignature("createPool(bytes32)", key));
        if(!(success && (data.length > 0 && (pool = abi.decode(data, (address))) == AddressCalculator.calcAddress(address(this),key)))) {
            revert DeployFailed();
        }
        //require(success && (data.length > 0 && (pool = abi.decode(data, (address))) == AddressCalculator.calcAddress(address(this),key)), "DEPLOY");

        console.log("Pool created with key: ");
        console.logBytes32(key);
        //console.log("Changing greeting from '%s' ");
        delete _params;

        getPool[key] = pool;
        allPools.push(pool);
        emit PoolCreated(pool, cfmm, protocolId, protocol, allPools.length);
    }

    function feeInfo() external virtual override view returns(address _feeTo, uint _fee) {
        _feeTo = feeTo;
        _fee = fee;
    }

    function setFee(uint _fee) external {
        isForbidden(feeToSetter);
        fee = _fee;
    }

    function setFeeTo(address _feeTo) external {
        isForbidden(feeToSetter);
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        isForbidden(feeToSetter);
        feeToSetter = _feeToSetter;
    }

}
