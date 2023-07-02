// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

/// @title Interface for LoanObserver
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Interface used for LoanObserver. External contract that can hold collateral for loan or implement after loan update hook
/// @notice GammaSwap team will create LoanObservers that will either work as Collateral Managers or hooks to update code
interface ILoanObserver {

    struct LoanObserved {
        /// @dev Loan counter, used to generate unique tokenId which indentifies the loan in the GammaPool
        uint256 id;

        // 1x256 bits
        /// @dev Index of GammaPool interest rate at time loan is created/updated, max 7.9% trillion
        uint96 rateIndex; // 96 bits

        // 1x256 bits
        /// @dev Initial loan debt in liquidity invariant units. Only increase when more liquidity is borrowed, decreases when liquidity is paid
        uint128 initLiquidity; // 128 bits
        /// @dev Loan debt in liquidity invariant units, increases with every update according to how many blocks have passed
        uint128 liquidity; // 128 bits

        /// @dev Initial loan debt in terms of LP tokens at time liquidity was borrowed, updates along with initLiquidity
        uint256 lpTokens;
        /// @dev Reserve tokens held as collateral for the liquidity debt, indices match GammaPool's tokens[] array indices
        uint128[] tokensHeld; // array of 128 bit numbers

        /// @dev price at which loan was opened
        uint256 px;
    }

    /// @dev Unique identifier of observer
    function refId() external view returns(uint16);

    /// @dev Observer type (2 = does not track collateral and onLoanUpdate returns zero, 3 = tracks collateral and onLoanUpdate returns collateral held outside of GammaPool)
    function refType() external view returns(uint16);

    /// @dev Validate observer can work with GammaPool
    /// @param gammaPool - address of GammaPool observer contract will observe
    /// @return validated - true if observer can work with `gammaPool`, false otherwise
    function validate(address gammaPool) external view returns(bool);

    /// @notice Used to identify requests from GammaPool
    /// @dev Factory contract of GammaPool observer will receive updates from
    function factory() external view returns(address);

    /// @notice Should require authentication that msg.sender is GammaPool of tokenId and GammaPool is registered
    /// @dev Update observer when a loan update occurs
    /// @dev If an observer does not hold collateral for loan it should return 0
    /// @param cfmm - address of the CFMM GammaPool is for
    /// @param protocolId - protocol id of the implementation contract for this GammaPool
    /// @param tokenId - unique identifier of loan in GammaPool
    /// @param data - data passed by gammaPool (e.g. LoanObserved)
    /// @return collateral - loan collateral held outside of GammaPool (Only significant when the loan tracks collateral)
    function onLoanUpdate(address cfmm, uint16 protocolId, uint256 tokenId, bytes memory data) external returns(uint256 collateral);
}
