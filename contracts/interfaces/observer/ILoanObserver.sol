// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

/// @title Interface for LoanObserver
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Interface used for CollateralManager. External contract that holds collateral
interface ILoanObserver {

    function refId() external view returns(uint16);

    function validate(address gammaPool) external view returns(bool);

    function getCollateral(address gammaPool, uint256 tokenId) external view returns(uint256);

    function getMaxCollateral(address gammaPool, uint256 tokenId) external view returns(uint256);

    function payLiquidity(address gammaPool, uint256 tokenId, uint256 amount, address to) external returns(uint256);

    function liquidateCollateral(uint256 tokenId, address to) external returns(uint256);

    function retrieveCollateral(uint256 tokenId, uint256 amount, address to) external returns(uint256);

    function retrieveCollateral(uint256 tokenId, uint256[] memory amount, address to) external returns(uint256);
}
