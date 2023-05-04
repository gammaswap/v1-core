// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../contracts/GammaPoolFactory.sol";

contract GammaPoolFactoryTest is Test {

    GammaPoolFactory factory;

    function setUp() public {
        factory = new GammaPoolFactory(address(this));
    }

    function testOwner() public {
        assertEq(factory.owner(),address(this));
    }
}