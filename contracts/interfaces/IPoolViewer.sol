// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import "./IGammaPool.sol";

/// @title Interface for Viewer Contract for GammaPool
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev Viewer makes complex view function calls from GammaPool's storage data (e.g. updated loan and pool debt)
interface IPoolViewer {

    /// @dev Check if can liquidate loan identified by `tokenId`
    /// @param pool - address of pool loans belong to
    /// @param tokenId - unique id of loan, used to look up loan in GammaPool
    /// @return canLiquidate - true if loan can be liquidated, false otherwise
    function canLiquidate(address pool, uint256 tokenId) external view returns(bool);

    /// @dev Get latest rate information from GammaPool
    /// @param pool - address of pool to request latest rates for
    /// @return data - RateData struct containing latest rate information
    function getLatestRates(address pool) external view returns(IGammaPool.RateData memory data);

    /// @dev Get list of loans and their corresponding tokenIds created in GammaPool. Capped at s.tokenIds.length.
    /// @param pool - address of pool loans belong to
    /// @param start - index from where to start getting tokenIds from array
    /// @param end - end index of array wishing to get tokenIds. If end > s.tokenIds.length, end is s.tokenIds.length
    /// @param active - if true, return loans that have an outstanding liquidity debt
    /// @return _loans - list of loans created in GammaPool
    function getLoans(address pool, uint256 start, uint256 end, bool active) external view returns(IGammaPool.LoanData[] memory _loans);

    /// @dev Get list of loans mapped to tokenIds in array `tokenIds`
    /// @param pool - address of pool loans belong to
    /// @param tokenIds - list of loan tokenIds
    /// @param active - if true, return loans that have an outstanding liquidity debt
    /// @return _loans - list of loans created in GammaPool
    function getLoansById(address pool, uint256[] calldata tokenIds, bool active) external view returns(IGammaPool.LoanData[] memory _loans);

    /// @dev Get loan with its most updated information
    /// @param pool - address of pool loan belongs to
    /// @param tokenId - unique id of loan, used to look up loan in GammaPool
    /// @return loanData - loan data struct (same as Loan + tokenId)
    function loan(address pool, uint256 tokenId) external view returns(IGammaPool.LoanData memory loanData);

    /// @dev Returns pool storage data updated to their latest values
    /// @notice Difference with getPoolData() is this struct is what PoolData would return if an update of the GammaPool were to occur at the current block
    /// @param pool - address of pool to get pool data for
    /// @return data - struct containing all relevant global state variables and descriptive information of GammaPool. Used to avoid making multiple calls
    function getLatestPoolData(address pool) external view returns(IGammaPool.PoolData memory data);

    /// @dev Returns same information as getLatestPoolData plus symbol and name of tokens of pool
    /// @param pool - address of pool to get pool data for
    /// @return data - struct containing all relevant global state variables and descriptive information of GammaPool. Used to avoid making multiple calls
    function getLatestPoolDataWithMetaData(address pool) external view returns(IGammaPool.PoolData memory data);

    /// @dev Calculate origination fee that will be charged if borrowing liquidity amount
    /// @param pool - address of GammaPool to calculate origination fee for
    /// @param liquidity - liquidity to borrow
    /// @return origFee - calculated origination fee, without any discounts
    function calcDynamicOriginationFee(address pool, uint256 liquidity) external view returns(uint256 origFee);

    /// @dev Return pool storage data
    /// @param pool - address of pool to get pool data for
    /// @return data - struct containing all relevant global state variables and descriptive information of GammaPool. Used to avoid making multiple calls
    function getPoolData(address pool) external view returns(IGammaPool.PoolData memory data);

    /// @dev Get CFMM tokens meta data
    /// @param _tokens - array of token address of ERC20 tokens of CFMM
    /// @return _symbols - array of symbols of ERC20 tokens of CFMM
    /// @return _names - array of names of ERC20 tokens of CFMM
    /// @return _decimals - array of decimals of ERC20 tokens of CFMM
    function getTokensMetaData(address[] memory _tokens) external view returns(string[] memory _symbols, string[] memory _names, uint8[] memory _decimals);

}
