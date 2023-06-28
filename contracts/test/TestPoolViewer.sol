// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "../base/PoolViewer.sol";
import "./TestGammaPool.sol";
import "hardhat/console.sol";

contract TestPoolViewer is PoolViewer {

    event UpdatedLoan(uint256 tokenId, uint256 liquidity, uint256 collateral, bool canLiquidate, address token0, address token1);

    function testGetUpdatedLoans(address pool, uint96 accFeeIndex) external virtual {
        address liqStrat = IGammaPool(pool).singleLiquidationStrategy();
        IGammaPool.LoanData[] memory _loans = new IGammaPool.LoanData[](2);
        _loans[0].id = 1;
        _loans[0].tokenId = 10;
        _loans[0].poolId = pool;
        _loans[0].liquidity = 10**18;
        _loans[0].refAddr = address(0);
        _loans[0].refFee = 0;
        _loans[0].refTyp = 0;
        _loans[0].tokensHeld = new uint128[](2);
        _loans[0].tokensHeld[0] = 10**18;
        _loans[0].tokensHeld[1] = 2*(10**18);
        _loans[0].rateIndex = 10**18;
        _loans[0].liquidationStrategy = liqStrat;

        _loans[1].id = 2;
        _loans[1].tokenId = 20;
        _loans[1].poolId = pool;
        _loans[1].liquidity = 3*(10**18);
        _loans[1].refAddr = address(0);
        _loans[1].refFee = 0;
        _loans[1].refTyp = 0;
        _loans[1].tokensHeld = new uint128[](2);
        _loans[1].tokensHeld[0] = 0;
        _loans[1].tokensHeld[1] = 2*(10**18);
        _loans[1].rateIndex = 10**18;
        _loans[1].liquidationStrategy = liqStrat;

        TestGammaPool(pool).setAccFeeIndex(accFeeIndex);
        _loans = _getUpdatedLoans(pool, _loans);

        emit UpdatedLoan(_loans[0].tokenId, _loans[0].liquidity, _loans[0].collateral, _loans[0].canLiquidate, _loans[0].tokens[0], _loans[0].tokens[1]);
        emit UpdatedLoan(_loans[1].tokenId, _loans[1].liquidity, _loans[1].collateral, _loans[1].canLiquidate, _loans[1].tokens[0], _loans[1].tokens[1]);
    }

    function testGetLoanLastFeeIndex(address pool, uint256 _accFeeIndex) external virtual view returns(uint256 accFeeIndex) {
        IGammaPool.LoanData memory _loanData;
        _loanData.accFeeIndex = _accFeeIndex;
        _loanData.poolId = pool;
        _loanData.shortStrategy = IGammaPool(pool).shortStrategy();
        return _getLoanLastFeeIndex(_loanData);
    }

    function testGetLastFeeIndex(address pool) external virtual view returns(IGammaPool.RateData memory data) {
        return _getLastFeeIndex(pool);
    }

    function testCollateral(address pool, uint256 tokenId, uint128[] memory tokensHeld, address refAddr) external virtual view returns(uint256 collateral) {
        return _collateral(pool, tokenId, tokensHeld, refAddr);
    }

    function testUpdateLiquidity(uint256 liquidity, uint256 rateIndex, uint256 accFeeIndex) external virtual view returns(uint128) {
        return _updateLiquidity(liquidity, rateIndex, accFeeIndex);
    }
}
