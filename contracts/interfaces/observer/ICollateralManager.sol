// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "./ILoanObserver.sol";

/// @title Interface for CollateralManager
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Interface used for CollateralManager. External contract that can hold collateral for loan and liquidate debt with its collateral
/// @notice GammaSwap team will create CollateralManagers that may have hooks available for other developers to extend functionality of GammaPool
interface ICollateralManager is ILoanObserver {

    /// @dev Get collateral of loan identified by tokenId
    /// @param gammaPool - address of pool loan identified by tokenId belongs to
    /// @param tokenId - unique identifier of loan in GammaPool
    /// @return collateral - loan collateral held outside of GammaPool for loan identified by `tokenId`
    function getCollateral(address gammaPool, uint256 tokenId) external view returns(uint256 collateral);

    /// @notice Should require authentication that msg.sender is GammaPool of tokenId and GammaPool is registered
    /// @dev Liquidate loan debt of loan identified by tokenId
    /// @param cfmm - address of the CFMM GammaPool is for
    /// @param protocolId - protocol id of the implementation contract for this GammaPool
    /// @param tokenId - unique identifier of loan in GammaPool
    /// @param amount - liquidity amount to liquidate
    /// @param to - address of liquidator
    /// @return collateral - loan collateral held outside of GammaPool (Only significant when the loan tracks collateral)
    function liquidateCollateral(address cfmm, uint16 protocolId, uint256 tokenId, uint256 amount, address to) external returns(uint256 collateral);
}
