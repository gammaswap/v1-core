pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../contracts/interfaces/observer/ILoanObserverStore.sol";
import "../../contracts/interfaces/observer/ILoanObserver.sol";
import "../../contracts/test/TestLoanObserverStore.sol";
import "../../contracts/test/TestLoanObserver.sol";
import "../../contracts/test/TestCollateralManager.sol";
import "../../contracts/test/TestERC165.sol";

contract LoanObserverStoreTest is Test {

    ILoanObserverStore loanObserverStore;
    ILoanObserver loanObserverType2a;
    ILoanObserver loanObserverType2b;
    ILoanObserver loanObserverType3a;
    ILoanObserver loanObserverType3b;
    IERC165 falseLoanObserver;

    address factory;
    address owner;
    address addr1;
    address addr2;

    function setUp() public {
        owner = address(this);
        addr1 = vm.addr(1);
        addr2 = vm.addr(2);
        factory = vm.addr(3);

        loanObserverStore = new TestLoanObserverStore(owner);

        loanObserverType2a = new TestLoanObserver(factory, 1, 2, true); // factory, refId, refType
        loanObserverType2b = new TestLoanObserver(factory, 2, 2, false);

        loanObserverType3a = new TestCollateralManager(factory, 3, true); // factory, refId
        loanObserverType3b = new TestCollateralManager(factory, 4, false);

        falseLoanObserver = new TestERC165();
    }

    function testAllowToBeObservedForbidden() public {
        vm.prank(addr1);
        vm.expectRevert("FORBIDDEN");
        loanObserverStore.allowToBeObserved(1, addr2, true);
    }

    function testAllowToBeObservedRefId() public {
        vm.expectRevert("REF_ID");
        loanObserverStore.allowToBeObserved(0, addr1, false);
    }

    function testAllowToBeObservedNotExists() public {
        vm.expectRevert("NOT_EXISTS");
        loanObserverStore.allowToBeObserved(1, addr1, false);
    }

    function testAllowToBeObservedZeroAddress() public {
        vm.expectRevert("ZERO_ADDRESS");
        loanObserverStore.allowToBeObserved(1, address(0), false);
    }

    function testAllowToBeObserved() public {
        loanObserverStore.setLoanObserver(1, address(0), 10, 1, true, false);
        loanObserverStore.allowToBeObserved(1, addr1, false);
        assertEq(false,loanObserverStore.isAllowedToBeObserved(1,addr1));
        loanObserverStore.allowToBeObserved(1, addr1, true);
        assertEq(true,loanObserverStore.isAllowedToBeObserved(1,addr1));

        loanObserverStore.setLoanObserver(2, address(loanObserverType2b), 20, 2, true, false);
        loanObserverStore.allowToBeObserved(2, addr1, false);
        assertEq(false,loanObserverStore.isAllowedToBeObserved(2,addr1));
        loanObserverStore.allowToBeObserved(2, addr1, true);
        assertEq(true,loanObserverStore.isAllowedToBeObserved(2,addr1));

        loanObserverStore.allowToBeObserved(1, addr2, false);
        assertEq(false,loanObserverStore.isAllowedToBeObserved(1,addr2));
        loanObserverStore.allowToBeObserved(1, addr2, true);
        assertEq(true,loanObserverStore.isAllowedToBeObserved(1,addr2));
    }

    function testSetLoanObserverForbidden() public {
        vm.prank(addr1);
        vm.expectRevert("FORBIDDEN");
        loanObserverStore.setLoanObserver(1, addr1, 1, 1, true, false);
    }

    function testSetLoanObserverInvalidType() public {
        vm.expectRevert("INVALID_TYPE");
        loanObserverStore.setLoanObserver(1, addr1, 1, 0, true, false);
        vm.expectRevert("INVALID_TYPE");
        loanObserverStore.setLoanObserver(1, addr1, 1, 4, true, false);
    }

    function testSetLoanObserverInvalidRefId() public {
        vm.expectRevert("INVALID_REF_ID");
        loanObserverStore.setLoanObserver(0, addr1, 1, 1, true, false);
    }

    function testSetLoanObserverRefType1(uint16 refFee, bool active, bool restricted) public {
        vm.expectRevert("NOT_ZERO_ADDRESS");
        loanObserverStore.setLoanObserver(1, addr1, refFee, 1, active, restricted);

        loanObserverStore.setLoanObserver(1, address(0), refFee, 1, active, restricted);
        (address _refAddr, uint16 _refFee, uint8 _refType, bool _active,
            bool _restricted) = loanObserverStore.getLoanObserver(1);
        assertEq(_refAddr, address(0));
        assertEq(_refFee, refFee);
        assertEq(_refType, 1);
        assertEq(_active, active);
        assertEq(_restricted, restricted);

        vm.expectRevert("INVALID_REF_ADDR");
        loanObserverStore.setLoanObserver(1, addr1, refFee/2, 3, !active, !restricted);

        vm.expectRevert("REF_TYPE_UPDATE");
        loanObserverStore.setLoanObserver(1, address(0), refFee/2, 3, !active, !restricted);

        loanObserverStore.setLoanObserver(1, address(0), refFee/2, 1, !active, !restricted);
        (_refAddr, _refFee, _refType, _active, _restricted) = loanObserverStore.getLoanObserver(1);
        assertEq(_refAddr, address(0));
        assertEq(_refFee, refFee/2);
        assertEq(_refType, 1);
        assertEq(_active, !active);
        assertEq(_restricted, !restricted);
    }

    function testSetLoanObserverRefType2(uint16 refFee, bool active, bool restricted) public {
        loanObserverStore.setLoanObserver(1, address(loanObserverType2a), refFee, 2, active, restricted);
        (address _refAddr, uint16 _refFee, uint8 _refType, bool _active,
            bool _restricted) = loanObserverStore.getLoanObserver(1);
        assertEq(_refAddr, address(loanObserverType2a));
        assertEq(_refFee, refFee);
        assertEq(_refType, 2);
        assertEq(_active, active);
        assertEq(_restricted, restricted);

        loanObserverStore.setLoanObserver(2, address(loanObserverType2b), refFee, 2, active, restricted);
        (_refAddr, _refFee, _refType, _active, _restricted) = loanObserverStore.getLoanObserver(2);
        assertEq(_refAddr, address(loanObserverType2b));
        assertEq(_refFee, refFee);
        assertEq(_refType, 2);
        assertEq(_active, active);
        assertEq(_restricted, restricted);

        vm.expectRevert("INVALID_REF_ADDR");
        loanObserverStore.setLoanObserver(1, addr2, refFee/2, 3, !active, !restricted);

        vm.expectRevert("REF_TYPE_UPDATE");
        loanObserverStore.setLoanObserver(1, address(loanObserverType2a), refFee/2, 3, !active, !restricted);

        loanObserverStore.setLoanObserver(1, address(loanObserverType2a), refFee/2, 2, !active, !restricted);
        (_refAddr, _refFee, _refType, _active, _restricted) = loanObserverStore.getLoanObserver(1);
        assertEq(_refAddr, address(loanObserverType2a));
        assertEq(_refFee, refFee/2);
        assertEq(_refType, 2);
        assertEq(_active, !active);
        assertEq(_restricted, !restricted);
    }

    function testSetLoanObserverRefType3(uint16 refFee, bool active, bool restricted) public {
        loanObserverStore.setLoanObserver(3, address(loanObserverType3a), refFee, 3, active, restricted);
        (address _refAddr, uint16 _refFee, uint8 _refType, bool _active,
        bool _restricted) = loanObserverStore.getLoanObserver(3);
        assertEq(_refAddr, address(loanObserverType3a));
        assertEq(_refFee, refFee);
        assertEq(_refType, 3);
        assertEq(_active, active);
        assertEq(_restricted, restricted);

        loanObserverStore.setLoanObserver(4, address(loanObserverType3b), refFee, 3, active, restricted);
        (_refAddr, _refFee, _refType, _active, _restricted) = loanObserverStore.getLoanObserver(4);
        assertEq(_refAddr, address(loanObserverType3b));
        assertEq(_refFee, refFee);
        assertEq(_refType, 3);
        assertEq(_active, active);
        assertEq(_restricted, restricted);

        vm.expectRevert("INVALID_REF_ADDR");
        loanObserverStore.setLoanObserver(3, addr2, refFee/2, 3, !active, !restricted);

        vm.expectRevert("REF_TYPE_UPDATE");
        loanObserverStore.setLoanObserver(3, address(loanObserverType3a), refFee/2, 2, !active, !restricted);

        loanObserverStore.setLoanObserver(3, address(loanObserverType3a), refFee/2, 3, !active, !restricted);
        (_refAddr, _refFee, _refType, _active, _restricted) = loanObserverStore.getLoanObserver(3);
        assertEq(_refAddr, address(loanObserverType3a));
        assertEq(_refFee, refFee/2);
        assertEq(_refType, 3);
        assertEq(_active, !active);
        assertEq(_restricted, !restricted);
    }

    function testSetLoanObserverRefTypeGt1ZeroAddress() public {
        vm.expectRevert("ZERO_ADDRESS");
        loanObserverStore.setLoanObserver(1, address(0), 10, 2, true, false);
        vm.expectRevert("ZERO_ADDRESS");
        loanObserverStore.setLoanObserver(1, address(0), 10, 3, true, false);
    }

    function testSetLoanObserverRefTypeGt1NotLoanObserver() public {
        vm.expectRevert("NOT_LOAN_OBSERVER");
        loanObserverStore.setLoanObserver(1, address(falseLoanObserver), 10, 2, true, false);
    }

    function testSetLoanObserverRefTypeGt1NotCollateralManager() public {
        vm.expectRevert("NOT_COLLATERAL_MANAGER");
        loanObserverStore.setLoanObserver(1, address(loanObserverType2a), 10, 3, true, false);
    }

    function testSetLoanObserverRefTypeGt1RefId() public {
        vm.expectRevert("REF_ID");
        loanObserverStore.setLoanObserver(2, address(loanObserverType2a), 10, 2, true, false);
        vm.expectRevert("REF_ID");
        loanObserverStore.setLoanObserver(4, address(loanObserverType3a), 10, 3, true, false);
    }

    function testSetPoolObservedForbidden() public {
        vm.prank(addr2);
        vm.expectRevert("FORBIDDEN");
        loanObserverStore.setPoolObserved(1, addr1);
    }

    function testSetPoolObservedZeroAddress() public {
        vm.expectRevert("ZERO_ADDRESS");
        loanObserverStore.setPoolObserved(1, address(0));
    }

    function testSetPoolObservedRefId() public {
        vm.expectRevert("INVALID_REF_ID");
        loanObserverStore.setPoolObserved(0, addr2);
    }

    function testSetPoolObservedNotExists() public {
        vm.expectRevert("NOT_EXISTS");
        loanObserverStore.setPoolObserved(10, addr2);
    }

    function testSetPoolObservedInvalidPool() public {
        loanObserverStore.setLoanObserver(2, address(loanObserverType2b), 10, 2, true, false);
        vm.expectRevert("INVALID_POOL");
        loanObserverStore.setPoolObserved(2, addr2);

        loanObserverStore.setLoanObserver(4, address(loanObserverType3b), 10, 3, true, false);
        vm.expectRevert("INVALID_POOL");
        loanObserverStore.setPoolObserved(4, addr2);
    }

    function testUnsetPoolObservedForbidden() public {
        vm.prank(addr1);
        vm.expectRevert("FORBIDDEN");
        loanObserverStore.unsetPoolObserved(4, addr2);
    }

    function testUnsetPoolObserved() public {
        loanObserverStore.setLoanObserver(1, address(loanObserverType2a), 10, 2, true, false);
        loanObserverStore.setPoolObserved(1, addr2);
        assertEq(loanObserverStore.isPoolObserved(1,addr2), true);

        loanObserverStore.setLoanObserver(3, address(loanObserverType3a), 10, 3, true, false);
        loanObserverStore.setPoolObserved(3, addr2);
        assertEq(loanObserverStore.isPoolObserved(3,addr2), true);

        loanObserverStore.setLoanObserver(4, address(0), 10, 1, true, false);
        loanObserverStore.setPoolObserved(4, addr2);
        assertEq(loanObserverStore.isPoolObserved(4,addr2), true);

        loanObserverStore.unsetPoolObserved(1, addr2);
        assertEq(loanObserverStore.isPoolObserved(1,addr2), false);
        loanObserverStore.unsetPoolObserved(3, addr2);
        assertEq(loanObserverStore.isPoolObserved(3,addr2), false);
        loanObserverStore.unsetPoolObserved(4, addr2);
        assertEq(loanObserverStore.isPoolObserved(4,addr2), false);
    }

    function testGetPoolObserverByUserRefId() public {
        vm.expectRevert("REF_ID");
        loanObserverStore.getPoolObserverByUser(0, addr1, addr2);
    }

    function testGetPoolObserverByUserZeroAddressPool() public {
        vm.expectRevert("ZERO_ADDRESS_POOL");
        loanObserverStore.getPoolObserverByUser(1, address(0), addr2);
    }

    function testGetPoolObserverByUserZeroAddressUser() public {
        vm.expectRevert("ZERO_ADDRESS_USER");
        loanObserverStore.getPoolObserverByUser(1, addr1, address(0));
    }

    function testGetPoolObserverByUserNotSet() public {
        vm.expectRevert("NOT_SET");
        loanObserverStore.getPoolObserverByUser(1, addr1, addr2);
    }

    function testGetPoolObserverByUserActive() public {
        loanObserverStore.setLoanObserver(3, address(loanObserverType3a), 10, 3, true, false);
        loanObserverStore.setPoolObserved(3, addr1);
        (address refAddr, uint16 refFee, uint8 refType) = loanObserverStore.getPoolObserverByUser(3, addr1, addr2);
        assertEq(refAddr, address(loanObserverType3a));
        assertEq(refFee, 10);
        assertEq(refType, 3);
    }

    function testGetPoolObserverByUserNotActive() public {
        loanObserverStore.setLoanObserver(3, address(loanObserverType3a), 10, 3, false, false);
        loanObserverStore.setPoolObserved(3, addr1);
        (address refAddr, uint16 refFee, uint8 refType) = loanObserverStore.getPoolObserverByUser(3, addr1, addr2);
        assertEq(refAddr, address(0));
        assertEq(refFee, 0);
        assertEq(refType, 0);
    }

    function testGetPoolObserverByUserForbidden() public {
        loanObserverStore.setLoanObserver(3, address(loanObserverType3a), 10, 3, true, true);
        loanObserverStore.setPoolObserved(3, addr1);
        vm.expectRevert("FORBIDDEN");
        loanObserverStore.getPoolObserverByUser(3, addr1, addr2);
    }

    function testGetPoolObserverByUserRestricted() public {
        loanObserverStore.setLoanObserver(3, address(loanObserverType3a), 10, 3, true, true);
        loanObserverStore.setPoolObserved(3, addr1);
        loanObserverStore.allowToBeObserved(3, addr2, true);
        (address refAddr, uint16 refFee, uint8 refType) = loanObserverStore.getPoolObserverByUser(3, addr1, addr2);
        assertEq(refAddr, address(loanObserverType3a));
        assertEq(refFee, 10);
        assertEq(refType, 3);

        loanObserverStore.allowToBeObserved(3, addr2, false);
        vm.expectRevert("FORBIDDEN");
        loanObserverStore.getPoolObserverByUser(3, addr1, addr2);
    }
}