// SPDX-License-Identifier: GPL-v3
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../contracts/libraries/GammaSwapLibrary.sol";
import "../../contracts/base/PoolViewer.sol";

contract TokenMetaDataTest is Test {
    ITokenMetaData viewer = new PoolViewer();

    Token0 token0 = new Token0();
    Token1 token1 = new Token1();
    Token2 token2 = new Token2();
    Token3 token3 = new Token3();

    function testFailDecimalsToken1() public {
        GammaSwapLibrary.decimals(address(token1));
    }

    function testFailDecimals256() public {
        Token4 token = new Token4(256);
        GammaSwapLibrary.decimals(address(token));
    }

    function testFailTokenDecimalsToken1() public {
        viewer.getTokenDecimals(address(token1));
    }

    function testFailTokenDecimals256() public {
        Token4 token = new Token4(256);
        viewer.getTokenDecimals(address(token));
    }

    function testDecimalsUint8(uint8 num) public {
        Token4 token = new Token4(num);
        assertEq(GammaSwapLibrary.decimals(address(token)),num);
        assertEq(viewer.getTokenDecimals(address(token)),num);
    }

    function testDecimals() public {
        assertEq(GammaSwapLibrary.decimals(address(token0)),12);
        assertEq(GammaSwapLibrary.decimals(address(token2)),32);
        assertEq(GammaSwapLibrary.decimals(address(token3)),6);

        assertEq(viewer.getTokenDecimals(address(token0)),12);
        assertEq(viewer.getTokenDecimals(address(token2)),32);
        assertEq(viewer.getTokenDecimals(address(token3)),6);
    }

    function testFailNameToken1() public {
        GammaSwapLibrary.name(address(token1));
    }

    function testFailNameToken3() public {
        GammaSwapLibrary.name(address(token3));
    }

    function testName() public {
        assertEq(GammaSwapLibrary.name(address(token0)),'Test Token0');
        assertEq(GammaSwapLibrary.name(address(token2)),'Test Token2');

        assertEq(viewer.getTokenName(address(token0)),'Test Token0');
        assertEq(viewer.getTokenName(address(token1)),'Test Token1');
        assertEq(viewer.getTokenName(address(token2)),'Test Token2');
        assertEq(viewer.getTokenName(address(token3)),'');
    }

    function testFailSymbolToken1() public {
        GammaSwapLibrary.symbol(address(token1));
    }

    function testFailSymbolToken3() public {
        GammaSwapLibrary.symbol(address(token3));
    }

    function testSymbol() external {
        assertEq(GammaSwapLibrary.symbol(address(token0)),'TERC0');
        assertEq(GammaSwapLibrary.symbol(address(token2)),'TERC2');

        assertEq(viewer.getTokenSymbol(address(token0)),'TERC0');
        assertEq(viewer.getTokenSymbol(address(token1)),'TERC1');
        assertEq(viewer.getTokenSymbol(address(token2)),'TERC2');
        assertEq(viewer.getTokenSymbol(address(token3)),'');
    }
}

contract Token0 {

    string public name = 'Test Token0';
    string public symbol = 'TERC0';
    uint8 public decimals = 12;

    constructor(){
    }

}

contract Token1 {

    bytes32 public name = 'Test Token1';
    bytes32 public symbol = 'TERC1';
    bytes32 public decimals = '13';

    constructor(){
    }

}

contract Token2 {

    bytes public name = 'Test Token2';
    bytes public symbol = 'TERC2';
    bytes public decimals = new bytes(13);

    constructor(){
    }

}

contract Token3 {

    uint256 public name = 513;
    uint256 public symbol = 354;
    uint256 public decimals = 6;

    constructor(){
    }

}

contract Token4 {

    string public name = 'Test Token0';
    string public symbol = 'TERC0';
    uint256 public decimals;

    constructor(uint256 num){
        decimals = num;
    }

}
