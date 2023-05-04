pragma solidity ^0.8.0;

import "./TestGammaPool.sol";
import "../interfaces/rates/IRateModel.sol";

contract TestRateModel is IRateModel {

    address public owner;

    constructor(address _owner){
        owner = _owner;
    }


    function validateParameters(bytes calldata _data) external view returns(bool) {
        return true;
    }

    function rateParamsStore() external view returns(address) {
        return owner;
    }
}
