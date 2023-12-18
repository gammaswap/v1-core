// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";

import "./GammaPoolFactory.sol";

contract GammaPoolBeaconFactory is GammaPoolFactory {
    constructor(address _feeTo) GammaPoolFactory(_feeTo){
    }

    function addProtocol(address beacon) external virtual override onlyOwner {
        address implementation = IBeacon(beacon).implementation();
        if(IGammaPool(implementation).protocolId() == 0) revert ZeroProtocol();// implementation protocolId is zero
        if(getProtocol[IGammaPool(implementation).protocolId()] != address(0)) revert ProtocolExists(); // protocolId already set

        getProtocol[IGammaPool(implementation).protocolId()] = beacon; // store implementation
    }

    function getPoolImplementation(address beacon) internal virtual override returns(address) {
        return IBeacon(beacon).implementation();
    }

    function cloneDeterministic(address implementation, bytes32 salt) internal override returns (address result) {

        bytes memory bytecode = abi.encodePacked(
            hex"608060405234801561001057600080fd5b5060f68061001f6000396000f3fe60",
            hex"806040819052635c60da1b60e01b815260009073",
            implementation,
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

    // custom minimal proxy, only used for proof of concept
    function cloneDeterministic2(address implementation, bytes32 salt) internal virtual returns (address result) {

        bytes memory bytecode = abi.encodePacked(
            hex"6080604052348015600f57600080fd5b50606d80601d6000396000f3fe608060",
            hex"40526000368182378081368373",
            implementation,
            hex"5af43d82833e8080156033573d83f35b3d83fdfea2646970667358221220464f",
            hex"28377c2fca72af73b668c7b0478422b822de2bef99b3e38362698c1544326473",
            hex"6f6c63430008150033"
        );

        assembly {
            result := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
    }
}
