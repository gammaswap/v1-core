pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../contracts/interfaces/rates/storage/IRateParamsStore.sol";
import "../../contracts/interfaces/rates/ILogDerivativeRateModel.sol";
import "../../contracts/interfaces/rates/ILinearKinkedRateModel.sol";
import "../../contracts/test/TestRateParamsStore.sol";
import "../../contracts/test/rates/TestLogDerivativeRateModel.sol";
import "../../contracts/test/rates/TestLinearKinkedRateModel.sol";

contract RateParamsStoreTest is Test {

    IRateParamsStore paramsStore;
    ILogDerivativeRateModel rateModel;
    ILinearKinkedRateModel rateModel2;

    address owner;
    address addr1;

    struct TestFailParams1 {
        uint256 num1;
    }

    struct TestFailParams2 {
        uint64 num1;
        uint80 num2;
        uint256 num3;
    }

    struct TestParams {
        uint64 num1;
        uint80 num2;
        uint80 num3;
    }

    struct TestFail2Params1 {
        uint256 num1;
    }

    struct TestFail2Params2 {
        uint64 num1;
        uint64 num2;
        uint64 num3;
        uint256 num4;
    }

    struct TestParams2 {
        uint64 num1;
        uint64 num2;
        uint64 num3;
        uint64 num4;
    }

    function setUp() public {
        owner = address(this);
        addr1 = vm.addr(1);
        paramsStore = new TestRateParamsStore(owner);
        rateModel = new TestLogDerivativeRateModel(1,2,3);
        TestLogDerivativeRateModel(address(rateModel)).setRateParamsStore(address(paramsStore));

        rateModel2 = new TestLinearKinkedRateModel(1,2,3,4);
        TestLinearKinkedRateModel(address(rateModel2)).setRateParamsStore(address(paramsStore));
    }

    function testFailSetRateParams() public {
        TestParams memory params = TestParams({ num1: 10, num2: 20, num3: 40 });
        vm.prank(addr1);
        paramsStore.setRateParams(address(rateModel), abi.encode(params), false);
    }

    function testFailSetRateParams1() public {
        TestFailParams1 memory params = TestFailParams1({ num1: 12345 });
        paramsStore.setRateParams(address(rateModel), abi.encode(params), false);
    }

    function testFailSetRateParams2() public {
        TestFailParams2 memory params = TestFailParams2({ num1: 100, num2: 200, num3: 1e36 });
        paramsStore.setRateParams(address(rateModel), abi.encode(params), false);
    }

    function testSetRateParams(uint64 _num1, uint80 _num2, uint80 _num3, bool active) public {
        _num1 = uint64(bound(_num1, 1, 1e18));
        _num2 = uint80(bound(_num2, 1, 1e19));
        _num3 = uint80(bound(_num1, 1, type(uint80).max));
        if(_num1 > _num3) {
            _num1 = uint64(_num3);
        }

        TestParams memory params = TestParams({ num1: _num1, num2: _num2, num3: _num3 });
        paramsStore.setRateParams(address(rateModel), abi.encode(params), active);

        (uint256 baseRate, uint256 factor, uint256 maxApy) = rateModel.getRateModelParams(address(paramsStore), address(rateModel));
        if(active) {
            assertEq(baseRate, _num1);
            assertEq(factor, _num2);
            assertEq(maxApy, _num3);
        } else {
            assertEq(baseRate, 1);
            assertEq(factor, 2);
            assertEq(maxApy, 3);
        }
    }

    function testSetRateParamsUpdate() public {
        TestParams memory params = TestParams({ num1: 10, num2: 20, num3: 40 });
        paramsStore.setRateParams(address(rateModel), abi.encode(params), false);

        (uint256 baseRate, uint256 factor, uint256 maxApy) = rateModel.getRateModelParams(address(paramsStore), address(rateModel));
        assertEq(baseRate, 1);
        assertEq(factor, 2);
        assertEq(maxApy, 3);

        paramsStore.setRateParams(address(rateModel), abi.encode(params), true);

        (baseRate, factor, maxApy) = rateModel.getRateModelParams(address(paramsStore), address(rateModel));
        assertEq(baseRate, 10);
        assertEq(factor, 20);
        assertEq(maxApy, 40);
    }

    function testFailSetRate2Params() public {
        TestParams2 memory params = TestParams2({ num1: 10, num2: 20, num3: 40 , num4: 50});
        vm.prank(addr1);
        paramsStore.setRateParams(address(rateModel2), abi.encode(params), false);
    }

    function testFailSetRate2Params1() public {
        TestFail2Params1 memory params = TestFail2Params1({ num1: 12345 });
        paramsStore.setRateParams(address(rateModel2), abi.encode(params), false);
    }

    function testFailSetRate2Params2() public {
        TestFail2Params2 memory params = TestFail2Params2({ num1: 100, num2: 200, num3: 1e18, num4: 1e38 });
        paramsStore.setRateParams(address(rateModel2), abi.encode(params), false);
    }

    function testSetRateParams2(uint64 _num1, uint64 _num2, uint64 _num3, uint64 _num4, bool active) public {
        _num1 = uint64(bound(_num1, 1, type(uint64).max));
        _num2 = uint64(bound(_num2, 1, 1e18 - 1));
        _num3 = uint64(bound(_num3, 1, type(uint64).max));
        _num4 = uint64(bound(_num4, 1, type(uint64).max));
        if(_num3 > _num4) {
            _num3 = uint64(_num4);
        }

        TestParams2 memory params = TestParams2({ num1: _num1, num2: _num2, num3: _num3, num4: _num4 });
        paramsStore.setRateParams(address(rateModel2), abi.encode(params), active);

        (uint64 baseRate, uint64 optimalUtilRate, uint64 slope1, uint64 slope2) = rateModel2.getRateModelParams(address(paramsStore), address(rateModel2));
        if(active) {
            assertEq(baseRate, _num1);
            assertEq(optimalUtilRate, _num2);
            assertEq(slope1, _num3);
            assertEq(slope2, _num4);
        } else {
            assertEq(baseRate, 1);
            assertEq(optimalUtilRate, 2);
            assertEq(slope1, 3);
            assertEq(slope2, 4);
        }
    }

    function testSetRateParams2Update() public {
        TestParams2 memory params = TestParams2({ num1: 10, num2: 20, num3: 40, num4: 50 });
        paramsStore.setRateParams(address(rateModel2), abi.encode(params), false);

        (uint64 baseRate, uint64 optimalUtilRate, uint64 slope1, uint64 slope2) = rateModel2.getRateModelParams(address(paramsStore), address(rateModel2));
        assertEq(baseRate, 1);
        assertEq(optimalUtilRate, 2);
        assertEq(slope1, 3);
        assertEq(slope2, 4);

        paramsStore.setRateParams(address(rateModel2), abi.encode(params), true);

        (baseRate, optimalUtilRate, slope1, slope2) = rateModel2.getRateModelParams(address(paramsStore), address(rateModel2));
        assertEq(baseRate, 10);
        assertEq(optimalUtilRate, 20);
        assertEq(slope1, 40);
        assertEq(slope2, 50);
    }
}
