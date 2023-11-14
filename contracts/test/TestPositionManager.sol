// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../interfaces/periphery/ISendTokensCallback.sol";
import "../interfaces/IGammaPoolEvents.sol";
import "../libraries/AddressCalculator.sol";
import "./strategies/base/TestShortStrategy.sol";

contract TestPositionManager is IGammaPoolEvents, ISendTokensCallback {
    error ZeroAmount();
    error ZeroShares();
    error WrongTokenBalance(address token);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event DepositReserve(address indexed pool, uint256 reservesLen, uint256[] reserves, uint256 shares);

    address public immutable pool;
    address public immutable cfmm;
    uint16 public immutable protocolId;

    constructor(address _pool, address _cfmm, uint16 _protocolId) {
        pool = _pool;
        cfmm = _cfmm;
        protocolId = _protocolId;
    }

    function sendTokensCallback(address[] calldata tokens, uint256[] calldata amounts, address payee, bytes calldata data) external virtual override {
        SendTokensCallbackData memory decoded = abi.decode(data, (SendTokensCallbackData));
        for(uint256 i; i < tokens.length;) {
            if(amounts[i] > 0) {
                if(amounts[i] % 2 == 0) {
                    send(tokens[i], decoded.payer, payee, amounts[i]);
                } else {
                    send(tokens[i], decoded.payer, payee, amounts[i] - 1);
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    function depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin) external virtual returns(uint256[] memory reserves, uint256 shares) {
        (reserves, shares) = TestShortStrategy(pool)._depositReserves(to, amountsDesired, amountsMin,
            abi.encode(SendTokensCallbackData({cfmm: cfmm, protocolId: protocolId, payer: msg.sender})));
        emit DepositReserve(pool, reserves.length, reserves, shares);
    }

    function send(address token, address sender, address to, uint256 amount) internal {
        if (sender == address(this)) {
            // send with tokens already in the contract
            GammaSwapLibrary.safeTransfer(token, to, amount);
        } else {
            // pull transfer
            GammaSwapLibrary.safeTransferFrom(token, sender, to, amount);
        }
    }
}
