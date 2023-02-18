// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title ISendTokensCallback interface to handle callbacks to send tokens
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Used by periphery contracts to transfer token amounts requested by a GammaPool
/// @dev Verifies sender is GammaPool by hashing SendTokensCallbackData contents into msg.sender
interface ISendTokensCallback {

    /// @dev Struct received in sendTokensCallback (`data`) used to identify caller as GammaPool
    struct SendTokensCallbackData {
        /// @dev sender of tokens
        address payer;

        /// @dev address of CFMM that will be used to identify GammaPool
        address cfmm;

        /// @dev protocolId that will be used to identify GammaPool
        uint16 protocolId;
    }

    /// @dev Transfer token `amounts` after verifying identity of caller using `data` is a GammaPool
    /// @param tokens - address of ERC20 tokens that will be transferred
    /// @param amounts - token amounts to be transferred
    /// @param payee - receiver of token `amounts`
    /// @param data - struct used to verify the function caller
    function sendTokensCallback(address[] calldata tokens, uint256[] calldata amounts, address payee, bytes calldata data) external;
}
