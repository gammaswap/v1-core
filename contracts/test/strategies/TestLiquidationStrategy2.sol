// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../interfaces/strategies/base/ILiquidationStrategy.sol";
import "../../interfaces/strategies/liquidation/ISingleLiquidationStrategy.sol";
import "../../interfaces/strategies/liquidation/IBatchLiquidationStrategy.sol";

contract TestLiquidationStrategy2 is ILiquidationStrategy, ISingleLiquidationStrategy, IBatchLiquidationStrategy  {

    function liquidationFee() external virtual override view returns(uint256) {
        return 250;
    }

    function canLiquidate(uint256 liquidity, uint256 collateral) external virtual override view returns(bool) {
        return liquidity > collateral;
    }

    function _liquidate(uint256 tokenId) external override virtual returns(uint256 loanLiquidity, uint256 refund) {
        uint128[] memory tokensHeld = new uint128[](2);
        tokensHeld[0] = 1;
        tokensHeld[1] = 2;
        loanLiquidity = 4;
        refund = 400;
        emit LoanUpdated(tokenId, tokensHeld, 777, 888, loanLiquidity, 5, TX_TYPE.LIQUIDATE);
        emit Liquidation(tokenId, 100, 200, 300, uint128(refund), TX_TYPE.LIQUIDATE);
    }

    function _liquidateWithLP(uint256 tokenId) external override virtual returns(uint256 loanLiquidity, uint128[] memory refund) {
        uint128[] memory tokensHeld = new uint128[](2);
        tokensHeld[0] = 6;
        tokensHeld[1] = 7;
        refund = new uint128[](2);
        refund[0] = 8;
        refund[1] = 9;
        loanLiquidity = 10;
        uint256 fee = 700;
        uint256 collateral = 12;
        emit LoanUpdated(tokenId, tokensHeld, refund[0], refund[1], loanLiquidity, 11, TX_TYPE.LIQUIDATE_WITH_LP);
        emit Liquidation(tokenId, 400, 500, 600, uint128(fee), TX_TYPE.LIQUIDATE_WITH_LP);
    }

    function _batchLiquidations(uint256[] calldata tokenIds) external returns(uint256 totalLoanLiquidity, uint128[] memory refund) {
        uint128[] memory tokensHeld = new uint128[](2);
        tokensHeld[0] = 11;
        tokensHeld[1] = 12;
        totalLoanLiquidity = 15;
        uint256 totalCollateral = 16;
        refund = new uint128[](2);
        refund[0] = 13;
        refund[1] = 14;
        uint128[] memory cfmmReserves = new uint128[](2);
        cfmmReserves[0] = 15;
        cfmmReserves[1] = 16;
        uint256 fee = 17;
        emit Liquidation(0, tokensHeld[0], tokensHeld[1], uint128(totalLoanLiquidity), uint128(fee), TX_TYPE.BATCH_LIQUIDATION);
        emit PoolUpdated(totalCollateral, refund[0], uint40(refund[1]), 700, 800, 900, 1000, cfmmReserves, TX_TYPE.BATCH_LIQUIDATION);
    }
}
