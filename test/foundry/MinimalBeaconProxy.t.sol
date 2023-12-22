// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../contracts/GammaPoolFactory.sol";
import "../../contracts/test/TestGammaPool.sol";
import "../../contracts/test/TestERC20.sol";

contract MinimalBeaconProxyTest is Test {
    GammaPoolFactory factory;
    TestERC20 tokenA;
    TestERC20 tokenB;

    function setUp() public {
        factory = new GammaPoolFactory(vm.addr(1));
        tokenA = new TestERC20("Test Token A", "TOKA");
        tokenB = new TestERC20("Test Token B", "TOKB");
    }

    function testMinimalBeaconProxy(uint16 protocolId) public {
        protocolId = uint16(bound(protocolId, 1, 9999));
        TestGammaPool protocol = new TestGammaPool(protocolId, address(factory), vm.addr(2), vm.addr(3), vm.addr(4), vm.addr(5), vm.addr(6), vm.addr(7), vm.addr(8));
        factory.addProtocol(address(protocol));

        address cfmm = vm.addr(9);
        address[] memory tokens = new address[](2);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        TestGammaPool.params memory data = TestGammaPool.params({
            protocolId: protocolId,
            cfmm: cfmm
        });
        TestGammaPool pool = TestGammaPool(factory.createPool(protocolId, cfmm, tokens, abi.encode(data)));

        assertEq(pool.protocolId(), protocolId);
        assertEq(pool.factory(), address(factory));
    }
}