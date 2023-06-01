// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "../interfaces/IGammaPoolFactory.sol";
import "../storage/AppStorage.sol";
import "../libraries/GammaSwapLibrary.sol";
import "../libraries/Math.sol";
import "../rates/AbstractRateModel.sol";

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

    /// @dev Emitted when transferring GS LP token from one address (`from`) to another (`to`)
    /// @param from - address sending `amount`
    /// @param to - address receiving `to`
    /// @param amount - amount of GS LP tokens transferred
    event Transfer(address indexed from, address indexed to, uint256 amount);

    /// @dev Get reserves token quantities from CFMM
    /// @param cfmm - address of GammaPool's CFMM
    /// @return reserves - amounts that will be deposited in CFMM
    function getReserves(address cfmm) internal virtual view returns(uint128[] memory);

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
        s.CFMM_RESERVES = getReserves(cfmm);
    }

    /// @dev Calculate fees accrued from fees in CFMM
    /// @param borrowedInvariant - liquidity invariant borrowed from CFMM
    /// @param lastCFMMInvariant - current liquidity invariant in CFMM
    /// @param lastCFMMTotalSupply - current CFMM LP token supply
    /// @param prevCFMMInvariant - liquidity invariant in CFMM in previous GammaPool update
    /// @param prevCFMMTotalSupply - CFMM LP token supply in previous GammaPool update
    /// @return cfmmFeeIndex - index tracking accrued fees from CFMM since last GammaPool update
    ///
    /// CFMM Fee Index = 1 + CFMM Yield = (cfmmInvariant1 / cfmmInvariant0) * (cfmmTotalSupply0 / cfmmTotalSupply1)
    ///
    /// Deleveraged CFMM Fee Index = 1 + Deleveraged CFMM Yield
    ///
    /// Deleveraged CFMM Fee Index = 1 + [(cfmmInvariant1 / cfmmInvariant0) * (cfmmTotalSupply0 / cfmmTotalSupply1) - 1] * (cfmmInvariant0 / borrowedInvariant)
    ///
    /// Deleveraged CFMM Fee Index = [cfmmInvariant1 * cfmmTotalSupply0 + (borrowedInvariant - cfmmInvariant0) * cfmmTotalSupply1] / (borrowedInvariant * cfmmTotalSupply1)
    function calcCFMMFeeIndex(uint256 borrowedInvariant, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint256 prevCFMMInvariant, uint256 prevCFMMTotalSupply) internal virtual view returns(uint256) {
        if(lastCFMMInvariant > 0 && lastCFMMTotalSupply > 0 && prevCFMMInvariant > 0 && prevCFMMTotalSupply > 0) {
            uint256 prevInvariant = borrowedInvariant > prevCFMMInvariant ? borrowedInvariant : prevCFMMInvariant; // Deleverage CFMM Yield
            uint256 denominator = prevInvariant * lastCFMMTotalSupply;
            return (lastCFMMInvariant * prevCFMMTotalSupply + lastCFMMTotalSupply * (prevInvariant - prevCFMMInvariant)) * 1e18 / denominator;
        }
        return 1e18; // first update
    }

    /// @dev Calculate total interest rate charged by GammaPool since last update
    /// @param lastCFMMFeeIndex - percentage of fees accrued in CFMM since last update to GammaPool
    /// @param borrowRate - annual borrow rate calculated from utilization rate of GammaPool
    /// @param blockDiff - change in blcoks since last update
    /// @return feeIndex - (1 + total fee yield) since last update
    function calcFeeIndex(uint256 lastCFMMFeeIndex, uint256 borrowRate, uint256 blockDiff) internal virtual view returns(uint256) {
        uint256 _blocksPerYear = blocksPerYear(); // Expected network blocks per year
        uint256 adjBorrowRate = blockDiff * borrowRate / _blocksPerYear; // De-annualized borrow rate
        uint256 _maxTotalApy = 1e18 + (blockDiff * maxTotalApy()) / _blocksPerYear; // De-annualized APY cap

        // Minimum of max de-annualized APY or CFMM fee yield + de-annualized borrow yield
        return Math.min(_maxTotalApy, lastCFMMFeeIndex + adjBorrowRate);
    }

    /// @dev Calculate total interest rate charged by GammaPool since last update
    /// @param borrowedInvariant - liquidity invariant borrowed in the GammaPool
    /// @return lastCFMMFeeIndex - (1 + cfmm fee yield) since last update
    /// @return lastCFMMInvariant - current liquidity invariant in CFMM
    /// @return lastCFMMTotalSupply - current CFMM LP token supply
    function updateCFMMIndex(uint256 borrowedInvariant) internal virtual returns(uint256 lastCFMMFeeIndex, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) {
        address cfmm = s.cfmm; // Saves gas
        updateReserves(cfmm); // Update CFMM_RESERVES with reserves in CFMM
        lastCFMMInvariant = calcInvariant(cfmm, s.CFMM_RESERVES); // Calculate current total invariant in CFMM
        lastCFMMTotalSupply = GammaSwapLibrary.totalSupply(cfmm); // Get current total CFMM LP token supply

        // Get CFMM fee yield growth since last update by checking current invariant vs previous invariant discounting with change in total supply
        lastCFMMFeeIndex = calcCFMMFeeIndex(borrowedInvariant, lastCFMMInvariant, lastCFMMTotalSupply, s.lastCFMMInvariant, s.lastCFMMTotalSupply);

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
        return lastCFMMTotalSupply == 0 ? 0 : (lpTokens * lastCFMMInvariant) / lastCFMMTotalSupply;
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
        s.LP_INVARIANT = uint128(convertLPToInvariant(s.LP_TOKEN_BALANCE, lastCFMMInvariant, lastCFMMTotalSupply));

        // Update GammaPool's interest rate index and update last block updated
        accFeeIndex = s.accFeeIndex * lastFeeIndex / 1e18;
        s.accFeeIndex = uint96(accFeeIndex);
        s.LAST_BLOCK_NUMBER = uint48(block.number);
    }

    /// @dev Update GammaPool's state variables and pay protocol fee
    /// @return accFeeIndex - liquidity invariant lpTokenBalance represents
    /// @return lastFeeIndex - interest accrued to loans in GammaPool
    /// @return lastCFMMFeeIndex - interest accrued to loans in GammaPool
    function updateIndex() internal virtual returns(uint256 accFeeIndex, uint256 lastFeeIndex, uint256 lastCFMMFeeIndex) {
        uint256 borrowedInvariant = s.BORROWED_INVARIANT;
        uint256 lastCFMMInvariant;
        uint256 lastCFMMTotalSupply;
        (lastCFMMFeeIndex, lastCFMMInvariant, lastCFMMTotalSupply) = updateCFMMIndex(borrowedInvariant);
        uint256 blockDiff = block.number - s.LAST_BLOCK_NUMBER; // Time passed in blocks
        if(blockDiff > 0) {
            lastCFMMFeeIndex = s.lastCFMMFeeIndex * lastCFMMFeeIndex / 1e18;
            s.lastCFMMFeeIndex = 1e18;
            (uint256 borrowRate,) = calcBorrowRate(s.LP_INVARIANT, borrowedInvariant, s.factory, address(this));
            lastFeeIndex = calcFeeIndex(lastCFMMFeeIndex, borrowRate, blockDiff);
            (accFeeIndex, borrowedInvariant) = updateStore(lastFeeIndex, borrowedInvariant, lastCFMMInvariant, lastCFMMTotalSupply);
            if(borrowedInvariant > 0) { // Only pay protocol fee if there are loans
                mintToDevs(lastFeeIndex, lastCFMMFeeIndex);
            }
        } else {
            s.lastCFMMFeeIndex = uint80(s.lastCFMMFeeIndex * lastCFMMFeeIndex / 1e18);
            lastFeeIndex = 1e18;
            accFeeIndex = s.accFeeIndex;
            s.LP_TOKEN_BORROWED_PLUS_INTEREST = convertInvariantToLP(borrowedInvariant, lastCFMMTotalSupply, lastCFMMInvariant);
            s.LP_INVARIANT = uint128(convertLPToInvariant(s.LP_TOKEN_BALANCE, lastCFMMInvariant, lastCFMMTotalSupply));
        }
    }

    /// @dev Mint GS LP tokens as protocol fee payment
    /// @param lastFeeIndex - interest accrued to loans in GammaPool
    /// @param lastCFMMIndex - liquidity invariant lpTokenBalance represents
    function mintToDevs(uint256 lastFeeIndex, uint256 lastCFMMIndex) internal virtual {
        (address _to, uint256 _protocolFee,,,) = IGammaPoolFactory(s.factory).getPoolFee(address(this));
        if(_to != address(0) && _protocolFee > 0) {
            uint256 gsFeeIndex = lastFeeIndex > lastCFMMIndex ? lastFeeIndex - lastCFMMIndex : 0; // _protocolFee excludes CFMM fee yield
            uint256 denominator =  lastFeeIndex - gsFeeIndex * _protocolFee / 100000; // _protocolFee is 10000 by default (10%)
            uint256 pctToPrint = lastFeeIndex * 1e18 / denominator - 1e18; // Result always is percentage as 18 decimals number or zero
            uint256 devShares = pctToPrint > 0 ? s.totalSupply * pctToPrint / 1e18 : 0;
            if(devShares > 0) {
                _mint(_to, devShares); // protocol fee is paid as dilution
            }
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