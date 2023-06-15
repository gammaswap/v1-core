pragma solidity ^0.8.0;

interface ICollateralManager {
    function getCollateral(address gammaPool, uint256 tokenId) external view returns(uint256);

    function liquidateCollateral(uint256 tokenId, address to) external returns(uint256);

    function retrieveCollateral(uint256 tokenId, uint256 amount, address to) external returns(uint256);

    function retrieveCollateral(uint256 tokenId, uint256[] memory amount, address to) external returns(uint256);
}
