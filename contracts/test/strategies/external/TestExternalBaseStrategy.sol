// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "./TestExternalBaseLongStrategy.sol";

contract TestExternalBaseStrategy is TestExternalBaseLongStrategy {

    event SwapCollateral(uint256 collateral);
    event ExternalSwapFunc(uint256 liquiditySwapped, uint128[] tokensHeld);
    event SendLPTokens(uint256 lpTokens);

    // Test functions
    function testCalcExternalSwapFee(uint256 liquiditySwapped, uint256 loanLiquidity) public view virtual returns(uint256 fee) {
        fee = calcExternalSwapFee(liquiditySwapped, loanLiquidity);
    }

    function testSendAndCalcCollateralLPTokens(address to, uint128[] calldata amounts, uint256 lastCFMMTotalSupply) public virtual returns(uint256 swappedCollateralAsLPTokens) {
        swappedCollateralAsLPTokens = sendAndCalcCollateralLPTokens(to, amounts, lastCFMMTotalSupply);
        emit SwapCollateral(swappedCollateralAsLPTokens);
    }

    function testSendCFMMLPTokens(address _cfmm, address to, uint256 lpTokens) public virtual returns(uint256 sentLPTokens) {
        sentLPTokens = sendCFMMLPTokens(_cfmm, to, lpTokens);
        emit SendLPTokens(sentLPTokens);
    }

    function testExternalSwap(uint256 tokenId, address _cfmm, uint128[] calldata amounts, uint256 lpTokens, address to, bytes calldata data) public virtual returns(uint256 liquiditySwapped, uint128[] memory tokensHeld) {
        LibStorage.Loan storage _loan = s.loans[tokenId];
        (liquiditySwapped, tokensHeld) = externalSwap(_loan, _cfmm, amounts, lpTokens, to, data);
        emit ExternalSwapFunc(liquiditySwapped, tokensHeld);
    }

    function checkLPTokens(address _cfmm, uint256 prevLpTokenBalance, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) internal virtual override {
        uint256 newLpTokenBalance = GammaSwapLibrary.balanceOf(IERC20(_cfmm), address(this));
        if(prevLpTokenBalance > newLpTokenBalance) {
            revert WrongLPTokenBalance();
        }

        // Update CFMM LP Tokens in pool and the invariant it represents
        s.LP_TOKEN_BALANCE = newLpTokenBalance;
        s.LP_INVARIANT = uint128(convertLPToInvariant(newLpTokenBalance, lastCFMMInvariant, lastCFMMTotalSupply));
    }

    function checkMargin(uint256 collateral, uint256 liquidity) internal virtual override view {
        if(!hasMargin(collateral, liquidity, ltvThreshold())) { // if collateral is below ltvThreshold revert transaction
            revert Margin();
        }
    }

    // **** Not used **** //
    function beforeRepay(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual override {
    }

    function beforeSwapTokens(LibStorage.Loan storage _loan, int256[] calldata deltas) internal virtual override returns(uint256[] memory outAmts, uint256[] memory inAmts) {
    }

    function calcTokensToRepay(uint256 liquidity) internal virtual override view returns(uint256[] memory amounts) {
    }

    function depositToCFMM(address cfmm, address to, uint256[] memory amounts) internal virtual override returns(uint256 lpTokens) {
    }

    function swapTokens(LibStorage.Loan storage _loan, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual override {
    }

    function updateReserves(address cfmm) internal virtual override {
    }

    function withdrawFromCFMM(address cfmm, address to, uint256 lpTokens) internal virtual override returns(uint256[] memory amounts) {
    }

    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        return 0;
    }
}
