pragma solidity ^0.8.0;

import "../libraries/AddressCalculator.sol";
import "../PoolDeployer.sol";

contract TestGammaPoolFactory {

    address public deployer;
    address public cfmm;
    uint24 public protocolId;
    address[] public tokens;
    address public protocol;

    mapping(bytes32 => address) public getPool;//all GS Pools addresses can be predetermined
    address public owner;

    constructor(address _cfmm, uint24 _protocolId, address[] memory _tokens, address _protocol) {
        cfmm = _cfmm;
        protocolId = _protocolId;
        tokens = _tokens;
        protocol = _protocol;
        owner = msg.sender;
        deployer = address(new PoolDeployer());
    }

    function setProtocol(address _protocol) external {
        protocol = _protocol;
    }

    function parameters() external virtual view returns(address _cfmm, uint24 _protocolId, address[] memory _tokens, address _protocol) {
        _cfmm = cfmm;
        _protocolId = protocolId;
        _tokens = tokens;
        _protocol = protocol;
    }

    function createPool() external virtual returns (address pool) {
        bytes32 key = AddressCalculator.getGammaPoolKey(cfmm, protocolId);

        (bool success, bytes memory data) = deployer.delegatecall(abi.encodeWithSignature("createPool(bytes32)", key));
        require(success && (data.length > 0 && (pool = abi.decode(data, (address))) == AddressCalculator.calcAddress(address(this),key)), "DEPLOY");

        getPool[key] = pool;
    }
}
