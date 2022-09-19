// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "../../interfaces/IGammaPoolFactory.sol";
import "../../interfaces/IProtocol.sol";
import "../../interfaces/strategies/base/IShortStrategy.sol";
import "../../interfaces/strategies/base/ILongStrategy.sol";

library GammaPoolStorage {
    bytes32 constant STRUCT_POSITION = keccak256("com.gammaswap.gammapool");

    struct Loan {
        uint256 id;
        address poolId;
        uint256[] tokensHeld;
        uint256 heldLiquidity;
        uint256 liquidity;
        uint256 lpTokens;
        uint256 rateIndex;
        uint256 blockNum;
    }

    struct Store {
        address factory;
        address[] tokens;
        uint24 protocolId;
        address protocol;
        address cfmm;
        address longStrategy;
        address shortStrategy;

        uint256[] TOKEN_BALANCE;
        uint256 LP_TOKEN_BALANCE;//LP Tokens in GS
        uint256 LP_TOKEN_BORROWED;//LP Tokens that have been borrowed (Principal)
        uint256 LP_TOKEN_BORROWED_PLUS_INTEREST;//(LP Tokens that have been borrowed (principal) plus interest in LP Tokens)
        uint256 LP_TOKEN_TOTAL;//LP_TOKEN_BALANCE + LP_TOKEN_BORROWED_PLUS_INTEREST
        uint256 BORROWED_INVARIANT;
        uint256 LP_INVARIANT;//Invariant from LP Tokens
        uint256 TOTAL_INVARIANT;//BORROWED_INVARIANT + LP_INVARIANT
        uint256[] CFMM_RESERVES;
        uint256 borrowRate;
        uint256 accFeeIndex;
        uint256 lastFeeIndex;
        uint256 lastCFMMFeeIndex;
        uint256 lastCFMMInvariant;
        uint256 lastCFMMTotalSupply;
        uint256 lastBlockTimestamp;
        uint256 yieldTWAP;
        uint256 LAST_BLOCK_NUMBER;

        uint256 ONE;
        bool isSet;

        /// @dev The token ID position data
        mapping(uint256 => Loan) loans;

        address owner;

        /// @dev The ID of the next loan that will be minted. Skips 0
        uint256 nextId;//should be 1

        uint256 unlocked;//should be 1


        //ERC20 fields
        string name;// = 'GammaSwap V1';
        string symbol;// = 'GAMA-V1';
        uint8 decimals;// = 18;
        uint256 totalSupply;
        mapping(address => uint256) balanceOf;
        mapping(address => mapping(address => uint256)) allowance;
    }

    function store() internal pure returns (Store storage _store) {
        bytes32 position = STRUCT_POSITION;
        assembly {
            _store.slot := position
        }
    }

    function init() internal {
        Store storage _store = store();
        require(_store.isSet == false, "GP_SET");
        _store.isSet = true;
        _store.name = "GammaSwap V1";
        _store.symbol = "GAMA-V1";
        _store.decimals = 18;
        _store.factory = msg.sender;
        (_store.cfmm, _store.protocolId, _store.tokens, _store.protocol) = IGammaPoolFactory(msg.sender).parameters();
        address protocol = _store.protocol;
        _store.longStrategy = IProtocol(protocol).longStrategy();
        _store.shortStrategy = IProtocol(protocol).shortStrategy();
        _store.TOKEN_BALANCE = new uint256[](_store.tokens.length);
        _store.CFMM_RESERVES = new uint256[](_store.tokens.length);
        _store.accFeeIndex = 10**18;
        _store.lastFeeIndex = 10**18;
        _store.lastCFMMFeeIndex = 10**18;
        _store.LAST_BLOCK_NUMBER = block.number;
        _store.owner = msg.sender;
        _store.nextId = 1;
        _store.unlocked = 1;
        _store.ONE = 10**18;
    }

    function lockit() internal {
        Store storage _store = store();
        require(_store.unlocked == 1, "LOCK");
        _store.unlocked = 0;
    }

    function unlockit() internal {
        store().unlocked = 1;
    }

    function createLoan() internal returns(uint256 tokenId) {
        Store storage _store = store();
        uint256 id = _store.nextId++;
        tokenId = uint256(keccak256(abi.encode(msg.sender, address(this), id)));

        _store.loans[tokenId] = Loan({
            id: id,
            poolId: address(this),
            tokensHeld: new uint[](_store.tokens.length),
            heldLiquidity: 0,
            liquidity: 0,
            lpTokens: 0,
            rateIndex: _store.accFeeIndex,
            blockNum: block.number
        });
    }
}
