pragma solidity ^0.8.0;

import "./IGammaPool.sol";

interface IPoolViewer {

    function canLiquidate(address pool, uint256 tokenId) external view returns(bool);

    function getLatestRates(address pool) external view returns(IGammaPool.RateData memory data);

    function getLoans(address pool, uint256 start, uint256 end, bool active) external view returns(IGammaPool.LoanData[] memory _loans);

    function getLoansById(address pool, uint256[] calldata tokenIds, bool active) external view returns(IGammaPool.LoanData[] memory _loans);

    function loan(address pool, uint256 tokenId) external view returns(IGammaPool.LoanData memory loanData);

    function getLatestPoolData(address pool) external view returns(IGammaPool.PoolData memory data);

    function getPoolData(address pool) external view returns(IGammaPool.PoolData memory data);

    function getTokensMetaData(address[] memory _tokens) external view returns(string[] memory _symbols, string[] memory _names, uint8[] memory _decimals);

}
