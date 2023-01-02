// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

interface ITransfers {
    function clearToken(address token, address to) external;
}
