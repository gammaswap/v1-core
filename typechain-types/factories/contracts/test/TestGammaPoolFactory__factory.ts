/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import {
  Signer,
  utils,
  Contract,
  ContractFactory,
  BigNumberish,
  Overrides,
} from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../../../common";
import type {
  TestGammaPoolFactory,
  TestGammaPoolFactoryInterface,
} from "../../../contracts/test/TestGammaPoolFactory";

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "_cfmm",
        type: "address",
      },
      {
        internalType: "uint16",
        name: "_protocolId",
        type: "uint16",
      },
      {
        internalType: "address[]",
        name: "_tokens",
        type: "address[]",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [],
    name: "DeployFailed",
    type: "error",
  },
  {
    inputs: [],
    name: "Forbidden",
    type: "error",
  },
  {
    inputs: [],
    name: "PoolExists",
    type: "error",
  },
  {
    inputs: [],
    name: "ProtocolExists",
    type: "error",
  },
  {
    inputs: [],
    name: "ProtocolNotSet",
    type: "error",
  },
  {
    inputs: [],
    name: "ProtocolRestricted",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroAddress",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroProtocol",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "pool",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "protocolFee",
        type: "uint16",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "origFeeShare",
        type: "uint16",
      },
      {
        indexed: false,
        internalType: "bool",
        name: "isSet",
        type: "bool",
      },
    ],
    name: "FeeUpdate",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "currentOwner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "OwnershipTransferStarted",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "OwnershipTransferred",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "pool",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "cfmm",
        type: "address",
      },
      {
        indexed: true,
        internalType: "uint16",
        name: "protocolId",
        type: "uint16",
      },
      {
        indexed: false,
        internalType: "address",
        name: "implementation",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address[]",
        name: "tokens",
        type: "address[]",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "count",
        type: "uint256",
      },
    ],
    name: "PoolCreated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "pool",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "origFee",
        type: "uint16",
      },
      {
        indexed: false,
        internalType: "uint8",
        name: "extSwapFee",
        type: "uint8",
      },
      {
        indexed: false,
        internalType: "uint8",
        name: "emaMultiplier",
        type: "uint8",
      },
      {
        indexed: false,
        internalType: "uint8",
        name: "minUtilRate1",
        type: "uint8",
      },
      {
        indexed: false,
        internalType: "uint8",
        name: "minUtilRate2",
        type: "uint8",
      },
      {
        indexed: false,
        internalType: "uint16",
        name: "feeDivisor",
        type: "uint16",
      },
      {
        indexed: false,
        internalType: "uint8",
        name: "liquidationFee",
        type: "uint8",
      },
      {
        indexed: false,
        internalType: "uint8",
        name: "ltvThreshold",
        type: "uint8",
      },
    ],
    name: "PoolParamsUpdate",
    type: "event",
  },
  {
    inputs: [],
    name: "acceptOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_protocol",
        type: "address",
      },
    ],
    name: "addProtocol",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "allPoolsLength",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [],
    name: "cfmm",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint16",
        name: "",
        type: "uint16",
      },
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "address[]",
        name: "",
        type: "address[]",
      },
      {
        internalType: "bytes",
        name: "",
        type: "bytes",
      },
    ],
    name: "createPool",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes",
        name: "_data",
        type: "bytes",
      },
    ],
    name: "createPool2",
    outputs: [
      {
        internalType: "address",
        name: "pool",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "decimals",
    outputs: [
      {
        internalType: "uint8",
        name: "",
        type: "uint8",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "deployer",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "fee",
    outputs: [
      {
        internalType: "uint16",
        name: "",
        type: "uint16",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "feeInfo",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "feeTo",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "feeToSetter",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "getKey",
    outputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes32",
        name: "",
        type: "bytes32",
      },
    ],
    name: "getPool",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "getPoolFee",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "start",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "end",
        type: "uint256",
      },
    ],
    name: "getPools",
    outputs: [
      {
        internalType: "address[]",
        name: "_pools",
        type: "address[]",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint16",
        name: "",
        type: "uint16",
      },
    ],
    name: "getProtocol",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint16",
        name: "",
        type: "uint16",
      },
    ],
    name: "isProtocolRestricted",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [],
    name: "origFeeShare",
    outputs: [
      {
        internalType: "uint16",
        name: "",
        type: "uint16",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "owner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_pool",
        type: "address",
      },
      {
        internalType: "uint8",
        name: "_functionId",
        type: "uint8",
      },
    ],
    name: "pausePoolFunction",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "pendingOwner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "protocol",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "protocolId",
    outputs: [
      {
        internalType: "uint16",
        name: "",
        type: "uint16",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint16",
        name: "",
        type: "uint16",
      },
    ],
    name: "removeProtocol",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint16",
        name: "_fee",
        type: "uint16",
      },
    ],
    name: "setFee",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_feeTo",
        type: "address",
      },
    ],
    name: "setFeeTo",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_feeToSetter",
        type: "address",
      },
    ],
    name: "setFeeToSetter",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint16",
        name: "",
        type: "uint16",
      },
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    name: "setIsProtocolRestricted",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint16",
        name: "_origFeeShare",
        type: "uint16",
      },
    ],
    name: "setOrigFeeShare",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_pool",
        type: "address",
      },
      {
        internalType: "address",
        name: "_to",
        type: "address",
      },
      {
        internalType: "uint16",
        name: "_protocolFee",
        type: "uint16",
      },
      {
        internalType: "uint16",
        name: "_origFeeShare",
        type: "uint16",
      },
      {
        internalType: "bool",
        name: "_isSet",
        type: "bool",
      },
    ],
    name: "setPoolFee",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_pool",
        type: "address",
      },
      {
        internalType: "uint16",
        name: "_origFee",
        type: "uint16",
      },
      {
        internalType: "uint8",
        name: "_extSwapFee",
        type: "uint8",
      },
      {
        internalType: "uint8",
        name: "_emaMultiplier",
        type: "uint8",
      },
      {
        internalType: "uint8",
        name: "_minUtilRate1",
        type: "uint8",
      },
      {
        internalType: "uint8",
        name: "_minUtilRate2",
        type: "uint8",
      },
      {
        internalType: "uint16",
        name: "_feeDivisor",
        type: "uint16",
      },
      {
        internalType: "uint8",
        name: "_liquidationFee",
        type: "uint8",
      },
      {
        internalType: "uint8",
        name: "_ltvThreshold",
        type: "uint8",
      },
    ],
    name: "setPoolParams",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "tokens",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "transferOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_pool",
        type: "address",
      },
      {
        internalType: "uint8",
        name: "_functionId",
        type: "uint8",
      },
    ],
    name: "unpausePoolFunction",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
] as const;

const _bytecode =
  "0x60806040526004805463ffffffff191663025827101790553480156200002457600080fd5b5060405162001b8438038062001b84833981016040819052620000479162000256565b60008054336001600160a01b0319918216811790925560048054600160201b600160c01b0319166401000000008402179055600580549091169091179055600780546001600160a01b0385166001600160b01b031990911617600160a01b61ffff8516021790558051620000c3906008906020840190620000ff565b50604080516002808252606082018352909160208301908036833750508151620000f592600a92506020019062000169565b5050505062000358565b82805482825590600052602060002090810192821562000157579160200282015b828111156200015757825182546001600160a01b0319166001600160a01b0390911617825560209092019160019091019062000120565b50620001659291506200020c565b5090565b82805482825590600052602060002090601f01602090048101928215620001575791602002820160005b83821115620001d357835183826101000a81548160ff021916908360ff160217905550926020019260010160208160000104928301926001030262000193565b8015620002025782816101000a81549060ff0219169055600101602081600001049283019260010302620001d3565b5050620001659291505b5b808211156200016557600081556001016200020d565b80516001600160a01b03811681146200023b57600080fd5b919050565b634e487b7160e01b600052604160045260246000fd5b6000806000606084860312156200026c57600080fd5b620002778462000223565b925060208085015161ffff811681146200029057600080fd5b60408601519093506001600160401b0380821115620002ae57600080fd5b818701915087601f830112620002c357600080fd5b815181811115620002d857620002d862000240565b8060051b604051601f19603f8301168101818110858211171562000300576200030062000240565b60405291825284820192508381018501918a8311156200031f57600080fd5b938501935b828510156200034857620003388562000223565b8452938501939285019262000324565b8096505050505050509250925092565b61181c80620003686000396000f3fe608060405234801561001057600080fd5b50600436106101d15760003560e01c806393790f4411610105578063d7d1e1261161009d578063d7d1e126146104c8578063da1f12ab146104ec578063ddca3f4314610501578063e30c39781461050f578063efde4e6414610522578063f2fde38b14610529578063f46901ed1461053c578063f4bff5f11461054f578063f6c009271461056957600080fd5b806393790f44146103c6578063995b5aae146103e6578063a2e74af614610415578063a4cb11e314610428578063abc41b3f1461044f578063b3d5d66b14610462578063bbe9583714610474578063d2c7c2a414610497578063d5f39488146104b557600080fd5b80634f64b2be116101785780634f64b2be146103075780635c00e2831461031a57806360fe2ae71461032f578063771d4c281461034257806379ba509714610372578063816612fd1461037a5780638ce744261461038d5780638da5cb5b146103a05780638e005553146103b357600080fd5b8063017e7e58146101d6578063094b74151461020d5780630f6550a914610220578063294da387146102415780633035aa9c146102545780633f47e6621461026757806342fcc6fb1461028c578063466e0c0a146102e4575b600080fd5b6004546101f090600160201b90046001600160a01b031681565b6040516001600160a01b0390911681526020015b60405180910390f35b6005546101f0906001600160a01b031681565b61023361022e366004610d4c565b610592565b604051908152602001610204565b6101f061024f366004610dc8565b610613565b6007546101f0906001600160a01b031681565b61027a610275366004610e0a565b6107b0565b60405160ff9091168152602001610204565b6102b861029a366004610e23565b50600454600160201b90046001600160a01b03169060009081908190565b604080516001600160a01b03909516855260208501939093529183015215156060820152608001610204565b6103056102f2366004610e50565b50600980546001600160a01b0319169055565b005b6101f0610315366004610e0a565b6107e4565b610305610328366004610e7b565b5050505050565b61023361033d366004610d4c565b61080e565b610305610350366004610e23565b600980546001600160a01b0319166001600160a01b0392909216919091179055565b610305610847565b610305610388366004610ee0565b6108f0565b6009546101f0906001600160a01b031681565b6000546101f0906001600160a01b031681565b6103056103c1366004610e50565b6109cb565b6102336103d4366004610e23565b60036020526000908152604090205481565b60045460408051600160201b9092046001600160a01b0316825260006020830181905290820152606001610204565b610305610423366004610e23565b610a45565b60045461043c9062010000900461ffff1681565b60405161ffff9091168152602001610204565b61030561045d366004610e50565b610a78565b610305610470366004610f88565b5050565b61048a610482366004610fb2565b606092915050565b6040516102049190610fd4565b6101f06104a5366004610e50565b506009546001600160a01b031690565b6006546101f0906001600160a01b031681565b6104dc6104d6366004610e50565b50600090565b6040519015158152602001610204565b60075461043c90600160a01b900461ffff1681565b60045461043c9061ffff1681565b6001546101f0906001600160a01b031681565b6000610233565b610305610537366004610e23565b610af8565b61030561054a366004610e23565b610b95565b6101f061055d366004611021565b60009695505050505050565b6101f0610577366004610e0a565b6002602052600090815260409020546001600160a01b031681565b600061059c610c16565b60405163301c7e5d60e01b815260ff831660048201526001600160a01b0384169063301c7e5d906024015b6020604051808303816000875af11580156105e6573d6000803e3d6000fd5b505050506040513d601f19601f8201168201806040525081019061060a91906110e3565b90505b92915050565b600754604080516001600160a01b038316602080830191909152600160a01b90930461ffff1681830152815180820383018152606090910190915280519101206000908190600954909150610671906001600160a01b031682610c5e565b91506012600a600081548110610689576106896110fc565b90600052602060002090602091828204019190066101000a81548160ff021916908360ff1602179055506012600a6001815481106106c9576106c96110fc565b90600052602060002090602091828204019190066101000a81548160ff021916908360ff160217905550816001600160a01b03166340894f17600760009054906101000a90046001600160a01b03166008600a88886040518663ffffffff1660e01b815260040161073e95949392919061113b565b600060405180830381600087803b15801561075857600080fd5b505af115801561076c573d6000803e3d6000fd5b505050600082815260026020908152604080832080546001600160a01b0319166001600160a01b038816908117909155835260039091529020919091555092915050565b600a81815481106107c057600080fd5b9060005260206000209060209182820401919006915054906101000a900460ff1681565b600881815481106107f457600080fd5b6000918252602090912001546001600160a01b0316905081565b6000610818610c16565b60405163edf07f1560e01b815260ff831660048201526001600160a01b0384169063edf07f15906024016105c7565b60015433906001600160a01b031681146108965760405162461bcd60e51b815260206004820152600b60248201526a2737ba2732bba7bbb732b960a91b60448201526064015b60405180910390fd5b600080546001600160a01b038381166001600160a01b031980841682178555600180549091169055604051919092169283917f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e09190a35050565b600554610905906001600160a01b0316610ccc565b60405163290e103b60e21b81526001600160a01b038a169063a43840ec9061093f908b908b908b908b908b908b908b908b9060040161177e565b600060405180830381600087803b15801561095957600080fd5b505af115801561096d573d6000803e3d6000fd5b50505050886001600160a01b03167feaef1c0940c97639799e6b040be4caf1e35786281ffe4087795f3cbefbac10a989898989898989896040516109b898979695949392919061177e565b60405180910390a2505050505050505050565b6005546109e0906001600160a01b0316610ccc565b6004805461ffff191661ffff838116918217928390556040805192835262010000840490911660208301526000908201819052600160201b9092046001600160a01b031691906000805160206117c7833981519152906060015b60405180910390a350565b610a4d610c16565b610a5681610cf8565b600580546001600160a01b0319166001600160a01b0392909216919091179055565b600554610a8d906001600160a01b0316610ccc565b6004805463ffff00001981166201000061ffff858116820292831794859055604080519482169382169390931784529084041660208301526000908201819052600160201b9092046001600160a01b031691906000805160206117c783398151915290606001610a3a565b610b00610c16565b6001600160a01b038116610b445760405162461bcd60e51b815260206004820152600b60248201526a5a65726f4164647265737360a81b604482015260640161088d565b600180546001600160a01b0319166001600160a01b0383811691821790925560008054604051929316917f38d16b8cac22d99fc7c124b9cd0de2d3fa1faef420bfe791d8c362d765e227009190a350565b600554610baa906001600160a01b0316610ccc565b600480546001600160a01b038316600160201b8102640100000000600160c01b031983168117938490556040805161ffff92831694831694909417845262010000909404166020830152600092820183905291906000805160206117c783398151915290606001610a3a565b6000546001600160a01b03163314610c5c5760405162461bcd60e51b81526020600482015260096024820152682337b93134b23232b760b91b604482015260640161088d565b565b6000763d602d80600a3d3981f3363d3d373d3d3d363d730000008360601b60e81c176000526e5af43d82803e903d91602b57fd5bf38360781b1760205281603760096000f590506001600160a01b03811661060d5760405163b4f5411160e01b815260040160405180910390fd5b336001600160a01b03821614610cf557604051631dd2188d60e31b815260040160405180910390fd5b50565b6001600160a01b038116610cf55760405163d92e233d60e01b815260040160405180910390fd5b80356001600160a01b0381168114610d3657600080fd5b919050565b803560ff81168114610d3657600080fd5b60008060408385031215610d5f57600080fd5b610d6883610d1f565b9150610d7660208401610d3b565b90509250929050565b60008083601f840112610d9157600080fd5b50813567ffffffffffffffff811115610da957600080fd5b602083019150836020828501011115610dc157600080fd5b9250929050565b60008060208385031215610ddb57600080fd5b823567ffffffffffffffff811115610df257600080fd5b610dfe85828601610d7f565b90969095509350505050565b600060208284031215610e1c57600080fd5b5035919050565b600060208284031215610e3557600080fd5b61060a82610d1f565b803561ffff81168114610d3657600080fd5b600060208284031215610e6257600080fd5b61060a82610e3e565b80358015158114610d3657600080fd5b600080600080600060a08688031215610e9357600080fd5b610e9c86610d1f565b9450610eaa60208701610d1f565b9350610eb860408701610e3e565b9250610ec660608701610e3e565b9150610ed460808701610e6b565b90509295509295909350565b60008060008060008060008060006101208a8c031215610eff57600080fd5b610f088a610d1f565b9850610f1660208b01610e3e565b9750610f2460408b01610d3b565b9650610f3260608b01610d3b565b9550610f4060808b01610d3b565b9450610f4e60a08b01610d3b565b9350610f5c60c08b01610e3e565b9250610f6a60e08b01610d3b565b9150610f796101008b01610d3b565b90509295985092959850929598565b60008060408385031215610f9b57600080fd5b610fa483610e3e565b9150610d7660208401610e6b565b60008060408385031215610fc557600080fd5b50508035926020909101359150565b6020808252825182820181905260009190848201906040850190845b818110156110155783516001600160a01b031683529284019291840191600101610ff0565b50909695505050505050565b6000806000806000806080878903121561103a57600080fd5b61104387610e3e565b955061105160208801610d1f565b9450604087013567ffffffffffffffff8082111561106e57600080fd5b818901915089601f83011261108257600080fd5b81358181111561109157600080fd5b8a60208260051b85010111156110a657600080fd5b6020830196508095505060608901359150808211156110c457600080fd5b506110d189828a01610d7f565b979a9699509497509295939492505050565b6000602082840312156110f557600080fd5b5051919050565b634e487b7160e01b600052603260045260246000fd5b81835281816020850137506000828201602090810191909152601f909101601f19169091010190565b60006080820160018060a01b038089168452602060808186015282895480855260a0945084870191508a6000528260002060005b8281101561118d57815486168452928401926001918201910161116f565b50505060409250858103838701528089546111ac818490815260200190565b60008c81526020812094509092505b81601f8201101561142657835460ff8082168552600882901c811687860152601082901c81168886015260606111fa818701838560181c1660ff169052565b60ff83891c831616608087015261121a8a8701838560281c1660ff169052565b60c061122f818801848660301c1660ff169052565b60e0611244818901858760381c1660ff169052565b60ff858c1c8516166101008901526112676101208901858760481c1660ff169052565b61127c6101408901858760501c1660ff169052565b6112916101608901858760581c1660ff169052565b60ff85841c8516166101808901526112b46101a08901858760681c1660ff169052565b6112c96101c08901858760701c1660ff169052565b6112de6101e08901858760781c1660ff169052565b6112f36102008901858760801c1660ff169052565b6113086102208901858760881c1660ff169052565b61131d6102408901858760901c1660ff169052565b6113326102608901858760981c1660ff169052565b60ff858d1c8516166102808901526113556102a08901858760a81c1660ff169052565b61136a6102c08901858760b01c1660ff169052565b61137f6102e08901858760b81c1660ff169052565b60ff85831c8516166103008901526113a26103208901858760c81c1660ff169052565b6113b76103408901858760d01c1660ff169052565b6113cc6103608901858760d81c1660ff169052565b60ff85821c8516166103808901525050506113f26103a08601828460e81c1660ff169052565b6114076103c08601828460f01c1660ff169052565b5060f81c6103e0840152600193909301926104009092019184016111bb565b9254928181101561143f5760ff84168352918401916001015b8181101561145957600884901c60ff168352918401916001015b8181101561147357601084901c60ff168352918401916001015b8181101561148d57601884901c60ff168352918401916001015b818110156114a55783851c60ff168352918401916001015b818110156114bf57602884901c60ff168352918401916001015b818110156114d957603084901c60ff168352918401916001015b818110156114f357603884901c60ff168352918401916001015b8181101561150b5783861c60ff168352918401916001015b8181101561152557604884901c60ff168352918401916001015b8181101561153f57605084901c60ff168352918401916001015b8181101561155957605884901c60ff168352918401916001015b8181101561157357606084901c60ff168352918401916001015b8181101561158d57606884901c60ff168352918401916001015b818110156115a757607084901c60ff168352918401916001015b818110156115c157607884901c60ff168352918401916001015b818110156115db57608084901c60ff168352918401916001015b818110156115f557608884901c60ff168352918401916001015b8181101561160f57609084901c60ff168352918401916001015b8181101561162957609884901c60ff168352918401916001015b818110156116415783871c60ff168352918401916001015b8181101561165b5760a884901c60ff168352918401916001015b818110156116755760b084901c60ff168352918401916001015b8181101561168f5760b884901c60ff168352918401916001015b818110156116a95760c084901c60ff168352918401916001015b818110156116c35760c884901c60ff168352918401916001015b818110156116dd5760d084901c60ff168352918401916001015b818110156116f75760d884901c60ff168352918401916001015b818110156117115760e084901c60ff168352918401916001015b8181101561172b5760e884901c60ff168352918401916001015b818110156117455760f084901c60ff168352918401916001015b818110156117595760f884901c8352918401915b5050868103606088015261176e81898b611112565b9c9b505050505050505050505050565b61ffff988916815260ff978816602082015295871660408701529386166060860152918516608085015290941660a083015292821660c0820152911660e0820152610100019056fea5496de2837be224471588bd6168f46e8717a914dd4f989250ac6f198284903ea26469706673582212207ed23562834fdf86ef85710af6ff8aea56bfc71a98c5c1dc1eccd20567849cf464736f6c63430008130033";

type TestGammaPoolFactoryConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: TestGammaPoolFactoryConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class TestGammaPoolFactory__factory extends ContractFactory {
  constructor(...args: TestGammaPoolFactoryConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    _cfmm: PromiseOrValue<string>,
    _protocolId: PromiseOrValue<BigNumberish>,
    _tokens: PromiseOrValue<string>[],
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<TestGammaPoolFactory> {
    return super.deploy(
      _cfmm,
      _protocolId,
      _tokens,
      overrides || {}
    ) as Promise<TestGammaPoolFactory>;
  }
  override getDeployTransaction(
    _cfmm: PromiseOrValue<string>,
    _protocolId: PromiseOrValue<BigNumberish>,
    _tokens: PromiseOrValue<string>[],
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(
      _cfmm,
      _protocolId,
      _tokens,
      overrides || {}
    );
  }
  override attach(address: string): TestGammaPoolFactory {
    return super.attach(address) as TestGammaPoolFactory;
  }
  override connect(signer: Signer): TestGammaPoolFactory__factory {
    return super.connect(signer) as TestGammaPoolFactory__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): TestGammaPoolFactoryInterface {
    return new utils.Interface(_abi) as TestGammaPoolFactoryInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): TestGammaPoolFactory {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as TestGammaPoolFactory;
  }
}
