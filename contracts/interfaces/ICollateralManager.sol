pragma solidity >=0.8.4;

/// @title Interface for CollateralManager
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Interface used for CollateralManager. External contract that holds collateral
interface ICollateralManager {

    function payLiquidity(address gammaPool, uint256 tokenId, uint256 amount, address to) external returns(uint256);

    function getCollateral(address gammaPool, uint256 tokenId) external view returns(uint256);

    function getMaxCollateral(address gammaPool, uint256 tokenId) external view returns(uint256);

    function liquidateCollateral(uint256 tokenId, address to) external returns(uint256);

    function retrieveCollateral(uint256 tokenId, uint256 amount, address to) external returns(uint256);

    function retrieveCollateral(uint256 tokenId, uint256[] memory amount, address to) external returns(uint256);
}
