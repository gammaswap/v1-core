// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Library used to perform common ERC20 transactions
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Library performs approvals, transfers and views ERC20 state fields
library GammaSwapLibrary {

    error ST_Fail();
    error STF_Fail();
    error SA_Fail();
    error STE_Fail();

    /// @dev Selector of decimals function in ERC20 implementation
    bytes4 private constant DECIMALS = bytes4(keccak256(bytes('decimals()')));

    /// @dev Selector of symbol function in ERC20 implementation
    bytes4 private constant SYMBOL = bytes4(keccak256(bytes('symbol()')));

    /// @dev Selector of name function in ERC20 implementation
    bytes4 private constant NAME = bytes4(keccak256(bytes('name()')));

    /// @dev Check the ERC20 balance of an address
    /// @param _token - address of ERC20 token we're checking the balance of
    /// @param _address - Ethereum address we're checking for balance of ERC20 token
    /// @return balanceOf - amount of _token held in _address
    function balanceOf(IERC20 _token, address _address) internal view returns (uint256) {
        (bool success, bytes memory data) =
        address(_token).staticcall(abi.encodeWithSelector(_token.balanceOf.selector, _address));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @dev Get how much of an ERC20 token is in existence (minted)
    /// @param _token - address of ERC20 token we're checking the total minted amount of
    /// @return totalSupply - total amount of _token that is in existence (minted and not burned)
    function totalSupply(IERC20 _token) internal view returns (uint256) {
        (bool success, bytes memory data) =
        address(_token).staticcall(abi.encodeWithSelector(_token.totalSupply.selector));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @dev Get decimals of ERC20 token
    /// @param _token - address of ERC20 token we are getting the decimal information from
    /// @return decimals - decimals of ERC20 token
    function decimals(address _token) internal view returns (uint8) {
        (bool success, bytes memory data) =
        _token.staticcall(abi.encodeWithSelector(DECIMALS)); // requesting via ERC20 decimals implementation
        require(success && data.length >= 1);
        return abi.decode(data, (uint8));
    }

    /// @dev Get symbol of ERC20 token
    /// @param _token - address of ERC20 token we are getting the symbol information from
    /// @return symbol - symbol of ERC20 token
    function symbol(address _token) internal view returns (string memory) {
        (bool success, bytes memory data) =
        _token.staticcall(abi.encodeWithSelector(SYMBOL)); // requesting via ERC20 symbol implementation
        require(success && data.length >= 1);
        return abi.decode(data, (string));
    }

    /// @dev Get name of ERC20 token
    /// @param _token - address of ERC20 token we are getting the name information from
    /// @return name - name of ERC20 token
    function name(address _token) internal view returns (string memory) {
        (bool success, bytes memory data) =
        _token.staticcall(abi.encodeWithSelector(NAME)); // requesting via ERC20 name implementation
        require(success && data.length >= 1);
        return abi.decode(data, (string));
    }

    /// @dev Safe transfer any ERC20 token, only used internally
    /// @param _token - address of ERC20 token that will be transferred
    /// @param _to - destination address where ERC20 token will be sent to
    /// @param _amount - quantity of ERC20 token to be transferred
    function safeTransfer(IERC20 _token, address _to, uint256 _amount) internal {
        (bool success, bytes memory data) = address(_token).call(abi.encodeWithSelector(_token.transfer.selector, _to, _amount));
        if(!(success && (data.length == 0 || abi.decode(data, (bool))))) {
            revert ST_Fail();
        }
    }

    /// @dev Moves `amount` of ERC20 token `_token` from `_from` to `_to` using the allowance mechanism. `_amount` is then deducted from the caller's allowance.
    /// @param _token - address of ERC20 token that will be transferred
    /// @param _from - address sending _token (not necessarily caller's address)
    /// @param _to - address receiving _token
    /// @param _amount - amount of _token being sent
    function safeTransferFrom(IERC20 _token, address _from, address _to, uint256 _amount) internal {
        (bool success, bytes memory data) =
        address(_token).call(abi.encodeWithSelector(_token.transferFrom.selector, _from, _to, _amount));
        if(!(success && (data.length == 0 || abi.decode(data, (bool))))) {
            revert STF_Fail();
        }
    }

    /// @dev Safe approve any ERC20 token to be spent by another address (`_spender`), only used internally
    /// @param _token - address of ERC20 token that will be approved
    /// @param _spender - address that will be granted approval to spend msg.sender tokens
    /// @param _amount - quantity of ERC20 token that `_spender` will be approved to spend
    function safeApprove(IERC20 _token, address _spender, uint256 _amount) internal {
        (bool success, bytes memory data) = address(_token).call(abi.encodeWithSelector(_token.approve.selector, _spender, _amount));
        if(!(success && (data.length == 0 || abi.decode(data, (bool))))) {
            revert SA_Fail();
        }
    }

    /// @dev Safe transfer any ERC20 token, only used internally
    /// @param _to - destination address where ETH will be sent to
    /// @param _amount - quantity of ERC20 token to be transferred
    function safeTransferETH(address _to, uint256 _amount) internal {
        (bool success, ) = _to.call{value: _amount}(new bytes(0));
        if(!success) {
            revert STE_Fail();
        }
    }

    /// @dev Check if `account` is a smart contract's address and it has been instantiated (has code)
    /// @param account - Ethereum address to check if it's a smart contract address
    /// @return bool - true if it is a smart contract address
    function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. keccak256('')
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }
}