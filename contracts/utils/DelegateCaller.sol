// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

/// @title Abstract DelegateCaller contract.
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Parent contract to contracts that perform delegate calls. All delegate call logic handled here
abstract contract DelegateCaller {

    /// @dev Implement contract logic via delegate calls of implementation contracts
    /// @param strategy - address of implementation contract
    /// @param data - bytes containing function call and parameters at implementation (`strategy`) contract
    /// @return result - returned data from delegate function call
    function callStrategy(address strategy, bytes memory data) internal virtual returns(bytes memory result) {
        bool success;
        (success, result) = strategy.delegatecall(data);
        if (!success) {
            if (result.length == 0) revert();
            assembly {
                revert(add(32, result), mload(result))
            }
        }
        return result;
    }

}
