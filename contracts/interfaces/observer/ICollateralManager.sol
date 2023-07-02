// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "./ILoanObserver.sol";

interface ICollateralManager is ILoanObserver {

    function getCollateral(address gammaPool, uint256 tokenId) external view returns(uint256);

    function liquidateCollateral(address gammaPool, uint256 tokenId, uint256 amount, address to) external returns(uint256);
}
