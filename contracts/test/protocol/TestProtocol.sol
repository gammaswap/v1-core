// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;
pragma abicoder v2;

import "../../interfaces/IProtocol.sol";

contract TestProtocol is IProtocol {
    uint24 public override protocolId;
    address public override longStrategy;
    address public override shortStrategy;

    struct Params{
        uint256 val;
    }

    constructor(address _longStrategy, address _shortStrategy, uint24 _protocolId) {
        longStrategy = _longStrategy;
        shortStrategy = _shortStrategy;
        protocolId = _protocolId;
    }

    function initialize(bytes calldata stratData, bytes calldata rateData) external virtual override returns(bool) {
        return true;
    }

    function parameters() external virtual override view returns(bytes memory params1, bytes memory params2) {
        params1 = abi.encode(Params({ val: 1}));
        params2 = abi.encode(Params({ val: 2}));
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm) external virtual override view returns(address[] memory tokens) {
        tokens = _tokens;
    }
}
