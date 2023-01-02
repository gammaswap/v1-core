// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ITransfers.sol";

abstract contract Transfers is ITransfers {

    error ST_Fail();
    error RestrictedToken();

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(token.transfer.selector, to, value));
        if(!(success && (data.length == 0 || abi.decode(data, (bool))))) {
            revert ST_Fail();
        }
    }

    function skim(address token, uint256 balance, address to) internal {
        uint256 newBalance = IERC20(token).balanceOf(address(this));
        if(newBalance > balance) {
            uint256 excessBalance;
            unchecked {
                excessBalance = newBalance - balance;
            }
            safeTransfer(IERC20(token), to, excessBalance);
        }
    }

    function clearToken(address token, address to) external override {
        if(isCFMMToken(token) || isCollateralToken(token)) { // can't clear AMM LP Tokens or reserve tokens
            revert RestrictedToken();
        }

        uint256 tokenBal = IERC20(token).balanceOf(address(this));
        if (tokenBal > 0) safeTransfer(IERC20(token), to, tokenBal);
    }

    function isCFMMToken(address token) internal virtual view returns(bool);

    function isCollateralToken(address token) internal virtual view returns(bool);
}
