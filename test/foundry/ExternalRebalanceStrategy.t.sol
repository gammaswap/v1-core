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
    console.log("******");
  }

  function test_rebalance_externally() public {
    assertEq(strategy.swapFee(), 10);
    uint256 amount0 = 10 * 1e18;
    uint256 amount1 = 20 * 1e18;
    uint128 liquidity = 1e18;
    uint256 tokenId = _createLoan(amount0, amount1, liquidity);
    (,,uint128[] memory tokensHeld,,,,,) = strategy.getLoan(tokenId);
    // another loan
    _createLoan(amount0, amount1, liquidity);

    (uint128[] memory tokenBalances, uint128[] memory reserves,,,,) = strategy.getPoolBalances();
    console.log("@@@", tokenA.balanceOf(address(strategy)));
    assertEq(tokenBalances[0] - amount0, tokensHeld[0]);
  }

  function _createLoan(uint256 amount0, uint256 amount1, uint128 liquidity) internal returns (uint256 tokenId) {
    tokenA.transfer(address(strategy), amount0);
    tokenB.transfer(address(strategy), amount1);
    tokenId = strategy.createLoan(liquidity);
  }
}
