pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../contracts/test/TestGammaPoolFactory2.sol";
import "../../contracts/test/TestERC20.sol";
import "../../contracts/test/TestCFMM.sol";
import "../../contracts/test/strategies/external/TestExternalRebalanceStrategy.sol";
import "../../contracts/test/strategies/external/TestExternalCallee2.sol";
import "../../contracts/strategies/rebalance/ExternalRebalanceStrategy.sol";

contract ExternalRebalanceStrategyTest is Test {
  TestExternalRebalanceStrategy strategy;
  IExternalCallee callee;
  TestCFMM cfmm;

  IERC20 tokenA;
  IERC20 tokenB;

  address user;

  function setUp() public {
    tokenA = new TestERC20("Test Token A", "TOKA");
    tokenB = new TestERC20("Test Token B", "TOKB");
    address[] memory tokens = new address[](2);
    tokens[0] = address(tokenA);
    tokens[1] = address(tokenB);
    uint8[] memory decimals = new uint8[](2);
    decimals[0] = 18;
    decimals[1] = 18;

    cfmm = new TestCFMM(address(tokenA), address(tokenB), "Test CFMM", "TCFMM");
    callee = new TestExternalCallee2();

    address factory = address(new TestGammaPoolFactory2());

    strategy = new TestExternalRebalanceStrategy();

    strategy.initialize(factory, address(cfmm), 1, tokens, decimals);
    strategy.setExternalSwapFee(10);
    user = vm.addr(1);

    tokenA.transfer(address(cfmm), 200 * 1e18);
    tokenB.transfer(address(cfmm), 400 * 1e18);
    cfmm.mint(200 * 1e18, address(this));
    cfmm.transfer(address(strategy), 100 * 1e18);

    strategy.updatePoolBalances();
  }

  function test_rebalance_externally(uint256 amt0, uint256 amt1, uint256 lpAmt) public {
    assertEq(strategy.swapFee(), 10);
    uint256 amount0 = 10 * 1e18;
    uint256 amount1 = 20 * 1e18;
    uint128 liquidity = 1e18;
    uint256 tokenId = _createLoan(amount0, amount1, liquidity);
    (,,uint128[] memory tokensHeld,,,,,) = strategy.getLoan(tokenId);
    // another loan
    _createLoan(amount0, amount1, liquidity);

    (uint128[] memory tokenBalances,,,, uint256 lpTokenBalance,) = strategy.getPoolBalances();
    assertEq(tokenBalances[0] - amount0, tokensHeld[0]);

    amt0 = bound(amt0, 0, tokenBalances[0]);
    amt1 = bound(amt1, 0, tokenBalances[1]);
    lpAmt = bound(lpAmt, 0, lpTokenBalance);

    uint128[] memory amounts = new uint128[](2);
    amounts[0] = uint128(amt0);
    amounts[1] = uint128(amt1);

    TestExternalCallee2.SwapData memory swapData = TestExternalCallee2.SwapData({ strategy: address(strategy),
      cfmm: address(cfmm), token0: address(tokenA), token1: address(tokenB), amount0: amounts[0], amount1: amounts[1],
      lpTokens: lpAmt});

    strategy._rebalanceExternally(
      tokenId,
      amounts,
      lpAmt,
      address(callee),
      abi.encode(swapData)
    );

    (uint128[] memory postTokenBalances,,,,
    uint256 postLpTokenBalance,) = strategy.getPoolBalances();

    assertEq(postTokenBalances[0], tokenBalances[0]);
    assertEq(postTokenBalances[1], tokenBalances[1]);
    assertEq(postLpTokenBalance, lpTokenBalance);
  }


  function test_rebalance_externally2(uint256 amt0, uint256 amt1, uint256 lpAmt) public {
    assertEq(strategy.swapFee(), 10);
    uint256 amount0 = 10 * 1e18;
    uint256 amount1 = 20 * 1e18;
    uint128 liquidity = 1e18;
    uint256 tokenId = _createLoan(amount0, amount1, liquidity);
    (,,uint128[] memory tokensHeld,,,,,) = strategy.getLoan(tokenId);
    // another loan
    _createLoan(amount0, amount1, liquidity);

    (uint128[] memory tokenBalances,,,,uint256 lpTokenBalance,) = strategy.getPoolBalances();
    assertEq(tokenBalances[0] - amount0, tokensHeld[0]);

    amt0 = bound(amt0, 0, tokensHeld[0]);
    amt1 = bound(amt1, 0, tokensHeld[1]);
    lpAmt = bound(lpAmt, 0, lpTokenBalance);

    TestExternalCallee2.SwapData memory swapData = TestExternalCallee2.SwapData({ strategy: address(strategy),
    cfmm: address(cfmm), token0: address(tokenA), token1: address(tokenB), amount0: amt0, amount1: amt1,
    lpTokens: lpAmt});

    if(GSMath.sqrt(uint256(amt0) * amt1) * strategy.ltvThreshold() / 10000 >= liquidity) {
      strategy._rebalanceExternally(
        tokenId,
        tokensHeld,
        lpAmt,
        address(callee),
        abi.encode(swapData)
      );

      (uint128[] memory postTokenBalances,,,,
      uint256 postLpTokenBalance,) = strategy.getPoolBalances();

      assertEq(postTokenBalances[0], tokenBalances[0] - (tokensHeld[0] - amt0));
      assertEq(postTokenBalances[1], tokenBalances[1] - (tokensHeld[1] - amt1));
      assertEq(postLpTokenBalance, lpTokenBalance);
    } else {
      vm.expectRevert(bytes4(keccak256("Margin()")));
      strategy._rebalanceExternally(
        tokenId,
        tokensHeld,
        lpAmt,
        address(callee),
        abi.encode(swapData)
      );

      (uint128[] memory postTokenBalances,,,,
      uint256 postLpTokenBalance,) = strategy.getPoolBalances();

      assertEq(postTokenBalances[0], tokenBalances[0]);
      assertEq(postTokenBalances[1], tokenBalances[1]);
      assertEq(postLpTokenBalance, lpTokenBalance);
    }

  }

  function _createLoan(uint256 amount0, uint256 amount1, uint128 liquidity) internal returns (uint256 tokenId) {
    tokenA.transfer(address(strategy), amount0);
    tokenB.transfer(address(strategy), amount1);
    tokenId = strategy.createLoan(liquidity);
  }
}