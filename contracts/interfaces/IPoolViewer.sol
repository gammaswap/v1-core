pragma solidity ^0.8.0;

interface IPoolViewer {

    function getTokensMetaData(address[] memory _tokens) external view returns(string[] memory _symbols, string[] memory _names);

}
