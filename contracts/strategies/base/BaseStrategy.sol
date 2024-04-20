// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../../interfaces/IGammaPoolFactory.sol";
import "../../storage/AppStorage.sol";
import "../../libraries/GammaSwapLibrary.sol";
import "../../libraries/GSMath.sol";
import "../../rates/AbstractRateModel.sol";

/// @title Base Strategy abstract contract
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Common functions used by all strategy implementations
/// @dev Root Strategy contract. Only place where AppStorage and AbstractRateModel should be inherited
abstract contract BaseStrategy is AppStorage, AbstractRateModel {
    error ZeroAmount();
    error ZeroAddress();
    error ExcessiveBurn();
    error NotEnoughLPDeposit();
    error NotEnoughBalance();
    error NotEnoughCollateral();
    error MaxUtilizationRate();
    error NotEnoughLPInvariant();

    /// @dev Emitted when transferring GS LP token from one address (`from`) to another (`to`)
    /// @param from - address sending `amount`
    /// @param to - address receiving `to`
    /// @param amount - amount of GS LP tokens transferred
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @dev Update token balances in CFMM
    /// @param cfmm - address of GammaPool's CFMM
    function syncCFMM(address cfmm) internal virtual;

    /// @dev Get reserves token quantities from CFMM
    /// @param cfmm - address of GammaPool's CFMM
    /// @return reserves - amounts that will be deposited in CFMM
    function getReserves(address cfmm) internal virtual view returns(uint128[] memory);

    /// @dev Get LP reserves token quantities from CFMM
    /// @param cfmm - address of GammaPool's CFMM
    /// @param isLatest - if true get latest reserves information
    /// @return reserves - amounts that will be deposited in CFMM
    function getLPReserves(address cfmm, bool isLatest) internal virtual view returns(uint128[] memory);

    /// @dev Calculates liquidity invariant from amounts quantities
    /// @param cfmm - address sending `amount`
    /// @param amounts - amount of GS LP tokens transferred
    /// @return invariant - liquidity invariant from CFMM
    function calcInvariant(address cfmm, uint128[] memory amounts) internal virtual view returns(uint256);

    /// @dev Deposits amounts of reserve tokens to CFMM to get CFMM LP tokens and send them to recipient (`to`)
    /// @param cfmm - address of CFMM
    /// @param to - receiver of CFMM LP tokens that will be minted after reserves deposit
    /// @param amounts - amount of reserve tokens deposited in CFMM
    /// @return lpTokens - LP tokens issued by CFMM for liquidity deposit
    function depositToCFMM(address cfmm, address to, uint256[] memory amounts) internal virtual returns(uint256 lpTokens);

    /// @dev Deposits amounts of reserve tokens to CFMM to get CFMM LP tokens and send them to recipient (`to`)
    /// @param cfmm - address of CFMM
    /// @param to - receiver of reserve tokens withdrawn from CFMM
    /// @param lpTokens - CFMM LP token amount redeemed from CFMM to withdraw reserve tokens
    /// @return amounts - amounts of reserve tokens withdrawn from CFMM
    function withdrawFromCFMM(address cfmm, address to, uint256 lpTokens) internal virtual returns(uint256[] memory amounts);

    /// @return maxTotalApy - maximum combined APY of CFMM fees and GammaPool's interest rate
    function maxTotalApy() internal virtual view returns(uint256);

    /// @return blocksPerYear - blocks created per year by network
    function blocksPerYear() internal virtual view returns(uint256);

    /// @dev See {AbstractRateModel-_rateParamsStore}
    function _rateParamsStore() internal override virtual view returns(address) {
        return s.factory;
    }

    /// @dev Update CFMM_RESERVES with reserve quantities in CFMM
    /// @param cfmm - address of CFMM
    function updateReserves(address cfmm) internal virtual {
        syncCFMM(cfmm);
        s.CFMM_RESERVES = getReserves(cfmm);
    }

    /// @dev Calculate fees accrued from fees in CFMM, and if leveraged, cap the leveraged yield at max yield leverage
    /// @param borrowedInvariant - liquidity invariant borrowed from CFMM
    /// @param lastCFMMInvariant - current liquidity invariant in CFMM
    /// @param lastCFMMTotalSupply - current CFMM LP token supply
    /// @param prevCFMMInvariant - liquidity invariant in CFMM in previous GammaPool update
    /// @param prevCFMMTotalSupply - CFMM LP token supply in previous GammaPool update
    /// @param maxCFMMFeeLeverage - max leverage of CFMM yield with 3 decimals. E.g. 5000 = 5
    /// @return cfmmFeeIndex - index tracking accrued fees from CFMM since last GammaPool update
    ///
    /// CFMM Fee Index = 1 + CFMM Yield = (cfmmInvariant1 / cfmmInvariant0) * (cfmmTotalSupply0 / cfmmTotalSupply1)
    ///
    /// Leverage Multiplier = (cfmmInvariant0 + borrowedInvariant) / cfmmInvariant0
    ///
    /// Deleveraged CFMM Yield = CFMM Yield / Leverage Multiplier = CFMM Yield * prevCFMMInvariant / (prevCFMMInvariant + borrowedInvariant)
    ///
    /// Releveraged CFMM Yield = Deleveraged CFMM Yield * Max CFMM Yield Leverage = Deleveraged CFMM Yield * maxCFMMFeeLeverage / 1000
    ///
    /// Releveraged CFMM Fee Index = 1 + Releveraged CFMM Yield
    function calcCFMMFeeIndex(uint256 borrowedInvariant, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply, uint256 maxCFMMFeeLeverage) internal virtual view returns(uint256) {
        if(lastCFMMInvariant > 0 && lastCFMMTotalSupply > 0 && prevCFMMInvariant > 0 && prevCFMMTotalSupply > 0) {
            uint256 cfmmFeeIndex = lastCFMMInvariant * prevCFMMTotalSupply * 1e18 / (prevCFMMInvariant * lastCFMMTotalSupply);
            if(cfmmFeeIndex > 1e18 && borrowedInvariant > maxCFMMFeeLeverage * prevCFMMInvariant / 1000) { // exceeds max cfmm yield leverage
                unchecked {
                    cfmmFeeIndex = cfmmFeeIndex - 1e18;
                }
                cfmmFeeIndex = 1e18 + cfmmFeeIndex * prevCFMMInvariant * maxCFMMFeeLeverage / ((prevCFMMInvariant + borrowedInvariant) * 1000); // cap leverage
            }
            return cfmmFeeIndex;
        }
        return 1e18; // first update
    }

    /// @dev Add spread to lastCFMMFeeIndex based on borrowRate. If such logic is defined
    /// @notice borrowRate depends on utilization rate and BaseStrategy inherits AbstractRateModel
    /// @notice Therefore, utilization rate information is included in borrow rate to calculate spread
    /// @param lastCFMMFeeIndex - percentage of fees accrued in CFMM since last update to GammaPool
    /// @param spread - spread to add to cfmmFeeIndex
    /// @return cfmmFeeIndex - cfmmFeeIndex + spread
    function addSpread(uint256 lastCFMMFeeIndex, uint256 spread) internal virtual view returns(uint256) {
        if(lastCFMMFeeIndex > 1e18 && spread > 1e18) {
            unchecked {
                lastCFMMFeeIndex = lastCFMMFeeIndex - 1e18;
            }
            return lastCFMMFeeIndex * spread / 1e18 + 1e18;
        }
        return lastCFMMFeeIndex;
    }

    /// @dev Calculate total interest rate charged by GammaPool since last update
    /// @param lastCFMMFeeIndex - percentage of fees accrued in CFMM since last update to GammaPool
    /// @param borrowRate - annual borrow rate calculated from utilization rate of GammaPool
    /// @param blockDiff - change in blcoks since last update
    /// @param spread - spread fee to add to CFMM Fee Index
    /// @return feeIndex - (1 + total fee yield) since last update
    function calcFeeIndex(uint256 lastCFMMFeeIndex, uint256 borrowRate, uint256 blockDiff, uint256 spread) internal virtual view returns(uint256) {
        uint256 _blocksPerYear = blocksPerYear(); // Expected network blocks per year
        uint256 adjBorrowRate = 1e18 + blockDiff * borrowRate / _blocksPerYear; // De-annualized borrow rate
        uint256 _maxTotalApy = 1e18 + (blockDiff * maxTotalApy()) / _blocksPerYear; // De-annualized APY cap

        // Minimum of max de-annualized Max APY or max of CFMM fee yield + spread or de-annualized borrow yield
        return GSMath.min(_maxTotalApy, GSMath.max(addSpread(lastCFMMFeeIndex, spread), adjBorrowRate));
    }

    /// @dev Calculate total interest rate charged by GammaPool since last update
    /// @param borrowedInvariant - liquidity invariant borrowed in the GammaPool
    /// @param maxCFMMFeeLeverage - max leverage of CFMM yield
    /// @return lastCFMMFeeIndex - (1 + cfmm fee yield) since last update
    /// @return lastCFMMInvariant - current liquidity invariant in CFMM
    /// @return lastCFMMTotalSupply - current CFMM LP token supply
    function updateCFMMIndex(uint256 borrowedInvariant, uint256 maxCFMMFeeLeverage) internal virtual returns(uint256 lastCFMMFeeIndex, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) {
        address cfmm = s.cfmm; // Saves gas
        updateReserves(cfmm); // Update CFMM_RESERVES with reserves in CFMM
        lastCFMMInvariant = calcInvariant(cfmm, getLPReserves(cfmm,false)); // Calculate current total invariant in CFMM
        lastCFMMTotalSupply = GammaSwapLibrary.totalSupply(cfmm); // Get current total CFMM LP token supply

        // Get CFMM fee yield growth since last update by checking current invariant vs previous invariant discounting with change in total supply
        lastCFMMFeeIndex = calcCFMMFeeIndex(borrowedInvariant, lastCFMMInvariant, lastCFMMTotalSupply, s.lastCFMMInvariant, s.lastCFMMTotalSupply, maxCFMMFeeLeverage);

        // Update storage
        s.lastCFMMInvariant = uint128(lastCFMMInvariant);
        s.lastCFMMTotalSupply = lastCFMMTotalSupply;
    }

    /// @dev Accrue interest to borrowed invariant amount
    /// @param borrowedInvariant - liquidity invariant borrowed in the GammaPool
    /// @param lastFeeIndex - interest accrued to loans in GammaPool
    /// @return newBorrowedInvariant - borrowed invariant with accrued interest
    function accrueBorrowedInvariant(uint256 borrowedInvariant, uint256 lastFeeIndex) internal virtual pure returns(uint256) {
        return  borrowedInvariant * lastFeeIndex / 1e18;
    }

    /// @notice Convert CFMM LP tokens into liquidity invariant units.
    /// @dev In case of CFMM where convertInvariantToLP calculation is different from convertLPToInvariant
    /// @param liquidityInvariant - liquidity invariant borrowed in the GammaPool
    /// @param lastCFMMTotalSupply - total supply of LP tokens issued by CFMM
    /// @param lastCFMMInvariant - liquidity invariant in CFMM
    /// @return lpTokens - liquidity invariant in terms of LP tokens
    function convertInvariantToLP(uint256 liquidityInvariant, uint256 lastCFMMTotalSupply, uint256 lastCFMMInvariant) internal virtual pure returns(uint256) {
        return lastCFMMInvariant == 0 ? 0 : (liquidityInvariant * lastCFMMTotalSupply) / lastCFMMInvariant;
    }

    /// @notice Convert CFMM LP tokens into liquidity invariant units.
    /// @dev In case of CFMM where convertLPToInvariant calculation is different from convertInvariantToLP
    /// @param lpTokens - liquidity invariant borrowed in the GammaPool
    /// @param lastCFMMInvariant - liquidity invariant in CFMM
    /// @param lastCFMMTotalSupply - total supply of LP tokens issued by CFMM
    /// @return liquidityInvariant - liquidity invariant lpTokens represents
    function convertLPToInvariant(uint256 lpTokens, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) internal virtual pure returns(uint256) {
        return convertLPToInvariantRoundUp(lpTokens, lastCFMMInvariant, lastCFMMTotalSupply, false);
    }

    /// @notice Convert CFMM LP tokens into liquidity invariant units, with option to round up
    /// @dev In case of CFMM where convertLPToInvariant calculation is different from convertInvariantToLP
    /// @param lpTokens - liquidity invariant borrowed in the GammaPool
    /// @param lastCFMMInvariant - liquidity invariant in CFMM
    /// @param lastCFMMTotalSupply - total supply of LP tokens issued by CFMM
    /// @param roundUp - if true, round invariant up
    /// @return liquidityInvariant - liquidity invariant lpTokens represents
    function convertLPToInvariantRoundUp(uint256 lpTokens, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, bool roundUp) internal virtual pure returns(uint256) {
        return lastCFMMTotalSupply == 0 ? 0 : ((lpTokens * lastCFMMInvariant) * 10 / lastCFMMTotalSupply + (roundUp ? 9 : 0)) / 10;
    }

    /// @dev Update pool invariant, LP tokens borrowed plus interest, interest rate index, and last block update
    /// @param lastFeeIndex - interest accrued to loans in GammaPool
    /// @param borrowedInvariant - liquidity invariant borrowed in the GammaPool
    /// @param lastCFMMInvariant - liquidity invariant in CFMM
    /// @param lastCFMMTotalSupply - total supply of LP tokens issued by CFMM
    /// @return accFeeIndex - liquidity invariant lpTokenBalance represents
    /// @return newBorrowedInvariant - borrowed liquidity invariant after interest accrual
    function updateStore(uint256 lastFeeIndex, uint256 borrowedInvariant, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) internal virtual returns(uint256 accFeeIndex, uint256 newBorrowedInvariant) {
        // Accrue interest to borrowed liquidity
        newBorrowedInvariant = accrueBorrowedInvariant(borrowedInvariant, lastFeeIndex);
        s.BORROWED_INVARIANT = uint128(newBorrowedInvariant);

        // Convert borrowed liquidity to corresponding CFMM LP tokens using current conversion rate
        s.LP_TOKEN_BORROWED_PLUS_INTEREST = convertInvariantToLP(newBorrowedInvariant, lastCFMMTotalSupply, lastCFMMInvariant);
        uint256 lpInvariant = convertLPToInvariant(s.LP_TOKEN_BALANCE, lastCFMMInvariant, lastCFMMTotalSupply);
        s.LP_INVARIANT = uint128(lpInvariant);

        // Update GammaPool's interest rate index and update last block updated
        accFeeIndex = s.accFeeIndex * lastFeeIndex / 1e18;
        s.accFeeIndex = uint80(accFeeIndex);
        s.emaUtilRate = uint32(_calcUtilRateEma(calcUtilizationRate(lpInvariant, newBorrowedInvariant), s.emaUtilRate,
            GSMath.max(block.number - s.LAST_BLOCK_NUMBER, s.emaMultiplier)));
        s.LAST_BLOCK_NUMBER = uint40(block.number);
    }

    /// @dev Update pool invariant, LP tokens borrowed plus interest, interest rate index, and last block update
    /// @param utilizationRate - interest accrued to loans in GammaPool
    /// @param emaUtilRateLast - interest accrued to loans in GammaPool
    /// @param emaMultiplier - interest accrued to loans in GammaPool
    /// @return emaUtilRate - interest accrued to loans in GammaPool
    function _calcUtilRateEma(uint256 utilizationRate, uint256 emaUtilRateLast, uint256 emaMultiplier) internal virtual view returns(uint256) {
        utilizationRate = utilizationRate / 1e12; // convert to 6 decimals
        if(emaUtilRateLast == 0) {
            return utilizationRate;
        } else {
            uint256 prevWeight;
            unchecked {
                emaMultiplier = GSMath.min(100, emaMultiplier);
                prevWeight = 100 - emaMultiplier;
            }
            // EMA_1 = val * mult + EMA_0 * (1 - mult)
            return utilizationRate * emaMultiplier / 100 + emaUtilRateLast * prevWeight / 100;
        }
    }

    /// @dev Calculate intra block CFMM FeeIndex capped at ~18.44x
    /// @param curCFMMFeeIndex - current lastCFMMFeeIndex (accrued from last intra block update)
    /// @param lastCFMMFeeIndex - lastCFMMFeeIndex that will accrue to curCFMMFeeIndex
    /// @return updLastCFMMFeeIndex - updated lastCFMMFeeIndex
    function calcIntraBlockCFMMFeeIndex(uint256 curCFMMFeeIndex, uint256 lastCFMMFeeIndex) internal pure returns(uint256) {
        return GSMath.min(curCFMMFeeIndex * GSMath.max(lastCFMMFeeIndex, 1e18) / 1e18, type(uint64).max);
    }

    /// @dev Update GammaPool's state variables and pay protocol fee
    /// @return accFeeIndex - liquidity invariant lpTokenBalance represents
    /// @return lastFeeIndex - interest accrued to loans in GammaPool
    /// @return lastCFMMFeeIndex - interest accrued to loans in GammaPool
    function updateIndex() internal virtual returns(uint256 accFeeIndex, uint256 lastFeeIndex, uint256 lastCFMMFeeIndex) {
        uint256 borrowedInvariant = s.BORROWED_INVARIANT;
        uint256 lastCFMMInvariant;
        uint256 lastCFMMTotalSupply;
        uint256 borrowRate;
        uint256 utilizationRate;
        uint256 maxCFMMFeeLeverage;
        uint256 spread;
        (borrowRate, utilizationRate, maxCFMMFeeLeverage, spread) = calcBorrowRate(s.LP_INVARIANT, borrowedInvariant, s.factory, address(this));
        (lastCFMMFeeIndex, lastCFMMInvariant, lastCFMMTotalSupply) = updateCFMMIndex(borrowedInvariant, maxCFMMFeeLeverage);
        uint256 blockDiff = block.number - s.LAST_BLOCK_NUMBER; // Time passed in blocks
        if(blockDiff > 0) {
            lastCFMMFeeIndex = uint256(s.lastCFMMFeeIndex) * lastCFMMFeeIndex / 1e18;
            s.lastCFMMFeeIndex = 1e18;
            lastFeeIndex = calcFeeIndex(lastCFMMFeeIndex, borrowRate, blockDiff, spread);
            (accFeeIndex, borrowedInvariant) = updateStore(lastFeeIndex, borrowedInvariant, lastCFMMInvariant, lastCFMMTotalSupply);
            if(borrowedInvariant > 0) { // Only pay protocol fee if there are loans
                mintToDevs(lastFeeIndex, lastCFMMFeeIndex, utilizationRate);
            }
        } else {
            s.lastCFMMFeeIndex = uint64(calcIntraBlockCFMMFeeIndex(s.lastCFMMFeeIndex, lastCFMMFeeIndex));
            lastFeeIndex = 1e18;
            accFeeIndex = s.accFeeIndex;
            s.LP_TOKEN_BORROWED_PLUS_INTEREST = convertInvariantToLP(borrowedInvariant, lastCFMMTotalSupply, lastCFMMInvariant);
            s.LP_INVARIANT = uint128(convertLPToInvariant(s.LP_TOKEN_BALANCE, lastCFMMInvariant, lastCFMMTotalSupply));
        }
    }

    /// @dev Calculate amount to dilute GS LP tokens as protocol revenue payment
    /// @param lastFeeIndex - interest accrued to loans in GammaPool
    /// @param lastCFMMIndex - liquidity invariant lpTokenBalance represents
    /// @param utilizationRate - utilization rate of the pool (borrowedInvariant/totalInvariant)
    /// @param protocolFee - fee to charge as protocol revenue from interest growth in GammaSwap
    /// @return pctToPrint - percent of total GS LP token shares to print as dilution to pay protocol revenue
    function _calcProtocolDilution(uint256 lastFeeIndex, uint256 lastCFMMIndex, uint256 utilizationRate, uint256 protocolFee) internal virtual view returns(uint256 pctToPrint) {
        if(lastFeeIndex <= lastCFMMIndex || protocolFee == 0) {
            return 0;
        }

        uint256 lastFeeIndexAdj;
        uint256 lastCFMMIndexWeighted = lastCFMMIndex * (1e18 > utilizationRate ? (1e18 - utilizationRate) : 0);
        unchecked {
            lastFeeIndexAdj = lastFeeIndex - (lastFeeIndex - lastCFMMIndex) * GSMath.min(protocolFee, 100000) / 100000; // _protocolFee is 10000 by default (10%)
        }
        uint256 numerator = (lastFeeIndex * utilizationRate + lastCFMMIndexWeighted) / 1e18;
        uint256 denominator = (lastFeeIndexAdj * utilizationRate + lastCFMMIndexWeighted)/ 1e18;
        pctToPrint = GSMath.max(numerator * 1e18 / denominator, 1e18) - 1e18;// Result always is percentage as 18 decimals number or zero
    }

    /// @dev Mint GS LP tokens as protocol fee payment
    /// @param lastFeeIndex - interest accrued to loans in GammaPool
    /// @param lastCFMMIndex - liquidity invariant lpTokenBalance represents
    /// @param utilizationRate - utilization rate of the pool (borrowedInvariant/totalInvariant)
    function mintToDevs(uint256 lastFeeIndex, uint256 lastCFMMIndex, uint256 utilizationRate) internal virtual {
        (address _to, uint256 _protocolFee,,) = IGammaPoolFactory(s.factory).getPoolFee(address(this));
        if(_to != address(0) && _protocolFee > 0) {
            uint256 devShares = s.totalSupply * _calcProtocolDilution(lastFeeIndex, lastCFMMIndex, utilizationRate, _protocolFee) / 1e18;
            if(devShares > 0) {
                _mint(_to, devShares); // protocol fee is paid as dilution
            }
        }
    }

    /// @dev Revert if lpTokens withdrawal causes utilization rate to go over 98%
    /// @param lpTokens - lpTokens expected to change utilization rate
    /// @param isLoan - true if lpTokens are being borrowed
    function checkExpectedUtilizationRate(uint256 lpTokens, bool isLoan) internal virtual view {
        uint256 lpTokenInvariant = convertLPToInvariant(lpTokens, s.lastCFMMInvariant, s.lastCFMMTotalSupply);
        uint256 lpInvariant = s.LP_INVARIANT;
        if(lpInvariant < lpTokenInvariant) revert NotEnoughLPInvariant();
        unchecked {
            lpInvariant = lpInvariant - lpTokenInvariant;
        }
        uint256 borrowedInvariant = s.BORROWED_INVARIANT + (isLoan ? lpTokenInvariant : 0);
        if(calcUtilizationRate(lpInvariant, borrowedInvariant) > 98e16) {
            revert MaxUtilizationRate();
        }
    }

    /// @dev Mint `amount` of GS LP tokens to `account`
    /// @param account - recipient address
    /// @param amount - amount of GS LP tokens to mint
    function _mint(address account, uint256 amount) internal virtual {
        if(amount == 0) revert ZeroAmount();
        s.totalSupply += amount;
        s.balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    /// @dev Burn `amount` of GS LP tokens from `account`
    /// @param account - address that owns GS LP tokens to burn
    /// @param amount - amount of GS LP tokens to burn
    function _burn(address account, uint256 amount) internal virtual {
        if(account == address(0)) revert ZeroAddress();

        uint256 accountBalance = s.balanceOf[account];
        if(amount > accountBalance) revert ExcessiveBurn();

        unchecked {
            s.balanceOf[account] = accountBalance - amount;
        }
        s.totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }
}