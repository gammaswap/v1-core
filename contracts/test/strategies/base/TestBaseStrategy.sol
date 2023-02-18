// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../../../libraries/Math.sol";
import "../../../strategies/BaseStrategy.sol";
import "../../TestCFMM.sol";

contract TestBaseStrategy is BaseStrategy {

    event LoanCreated(address indexed caller, uint256 tokenId);

    using LibStorage for LibStorage.Storage;

    uint16 public _protocolId;
    uint256 public borrowRate = 1e18;
    uint256 public invariant;
    address public _factory;
    uint80 public _lastFeeIndex;
    uint80 public _lastCFMMFeeIndex;

    constructor(address factory, uint16 protocolId) {
        _factory = factory;
        _protocolId = protocolId;
    }

    function initialize(address cfmm, address[] calldata tokens, uint8[] calldata decimals) external virtual {
        s.initialize(_factory, cfmm, tokens, decimals);
    }

    function maxTotalApy() internal virtual override view returns(uint256) {
        return 1e19;
    }

    function blocksPerYear() internal virtual override pure returns(uint256) {
        return 2252571;
    }

    function getParameters() public virtual view returns(address factory, address cfmm, address[] memory tokens, uint16 protocolId) {
        factory = _factory;
        cfmm = s.cfmm;
        tokens = s.tokens;
        protocolId = _protocolId;
    }

    function setUpdateStoreFields(uint256 accFeeIndex, uint256 lastFeeIndex, uint256 lpTokenBalance, uint256 borrowedInvariant, uint256 lastCFMMTotalSupply, uint256 lastCFMMInvariant) public virtual {
        s.accFeeIndex = uint96(accFeeIndex);
        _lastFeeIndex = uint80(lastFeeIndex);
        s.LP_TOKEN_BALANCE = lpTokenBalance;
        s.BORROWED_INVARIANT = uint128(borrowedInvariant);
        s.lastCFMMTotalSupply = lastCFMMTotalSupply;
        s.lastCFMMInvariant = uint128(lastCFMMInvariant);
    }

    function getUpdateStoreFields() public virtual view returns(uint256 accFeeIndex, uint256 lastFeeIndex, uint256 lpTokenBalance, uint256 borrowedInvariant, uint256 lastCFMMTotalSupply,
        uint256 lastCFMMInvariant, uint256 lpTokenBorrowedPlusInterest, uint256 lpInvariant, uint256 lpTokenTotal, uint256 totalInvariant, uint256 lastBlockNumber) {
        accFeeIndex = s.accFeeIndex;
        lastFeeIndex = _lastFeeIndex;
        lpTokenBalance = s.LP_TOKEN_BALANCE;
        borrowedInvariant = s.BORROWED_INVARIANT;
        lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        lastCFMMInvariant = s.lastCFMMInvariant;

        lpTokenBorrowedPlusInterest = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        lpInvariant = s.LP_INVARIANT;
        lpTokenTotal = lpTokenBalance + lpTokenBorrowedPlusInterest;
        totalInvariant = lpInvariant + borrowedInvariant;
        lastBlockNumber = s.LAST_BLOCK_NUMBER;
    }

    function setLPTokenBalAndBorrowedInv(uint256 lpTokenBal, uint128 borrowedInv) public virtual {
        s.LP_TOKEN_BALANCE = lpTokenBal;
        s.BORROWED_INVARIANT = borrowedInv;
    }

    function getLPTokenBalAndBorrowedInv() public virtual view returns(uint256 lpTokenBal, uint256 borrowedInv) {
        lpTokenBal = s.LP_TOKEN_BALANCE;
        borrowedInv = s.BORROWED_INVARIANT;
    }

    function setBorrowRate(uint256 _borrowRate) public virtual {
        borrowRate = _borrowRate;
    }

    function setLastBlockNumber(uint48 lastBlockNumber) public virtual {
        s.LAST_BLOCK_NUMBER = lastBlockNumber;
    }

    function updateLastBlockNumber() public virtual {
        s.LAST_BLOCK_NUMBER = uint48(block.number);
    }

    function getLastBlockNumber() public virtual view returns(uint256) {
        return s.LAST_BLOCK_NUMBER;
    }

    function setCFMMIndex(uint80 cfmmIndex) public virtual {
        _lastCFMMFeeIndex = cfmmIndex;
    }

    function getCFMMIndex() public virtual view returns(uint256){
        return _lastCFMMFeeIndex;
    }

    function testUpdateIndex() public virtual {
        (, uint256 lastFeeIndex, uint256 lastCFMMFeeIndex) = updateIndex();
        _lastFeeIndex = uint80(lastFeeIndex);
        _lastCFMMFeeIndex = uint80(lastCFMMFeeIndex);
    }

    function getUpdateIndexFields() public virtual view returns(uint256 lastCFMMTotalSupply, uint256 lastCFMMInvariant, uint256 lastCFMMFeeIndex,
        uint256 lastFeeIndex, uint256 accFeeIndex, uint256 borrowedInvariant, uint256 lpInvariant, uint256 totalInvariant,
        uint256 lpTokenBorrowedPlusInterest, uint256 lpTokenBal, uint256 lpTokenTotal, uint256 lastBlockNumber) {
        lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        lastCFMMInvariant = s.lastCFMMInvariant;
        lastCFMMFeeIndex = _lastCFMMFeeIndex;
        lastFeeIndex = _lastFeeIndex;
        accFeeIndex = s.accFeeIndex;
        borrowedInvariant = s.BORROWED_INVARIANT;
        lpInvariant = s.LP_INVARIANT;
        totalInvariant = lpInvariant + borrowedInvariant;
        lpTokenBorrowedPlusInterest = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        lpTokenBal = s.LP_TOKEN_BALANCE;
        lpTokenTotal = lpTokenBal + lpTokenBorrowedPlusInterest;
        lastBlockNumber = s.LAST_BLOCK_NUMBER;
    }

    function testUpdateCFMMIndex() public virtual {
        (uint256 lastCFMMFeeIndex,,) = updateCFMMIndex(s.BORROWED_INVARIANT);
        _lastCFMMFeeIndex = uint80(lastCFMMFeeIndex);
    }

    function testUpdateFeeIndex() public virtual {
        _lastFeeIndex = uint80(updateFeeIndex(_lastCFMMFeeIndex, s.BORROWED_INVARIANT, block.number - s.LAST_BLOCK_NUMBER));
    }

    function testUpdateStore() public virtual {
        updateStore(_lastFeeIndex, s.BORROWED_INVARIANT, s.lastCFMMInvariant, s.lastCFMMTotalSupply);
    }

    function getLastFeeIndex() public virtual view returns(uint256){
        return _lastFeeIndex;
    }

    function getCFMMData() public virtual view returns(uint256 lastCFMMFeeIndex, uint256 lastCFMMInvariant, uint256 lastCFMMTotalSupply) {
        lastCFMMFeeIndex = _lastCFMMFeeIndex;
        lastCFMMInvariant = s.lastCFMMInvariant;
        lastCFMMTotalSupply = s.lastCFMMTotalSupply;
    }

    function testMint(address account, uint256 amount) public virtual {
        _mint(account, amount);
    }

    function testBurn(address account, uint256 amount) public virtual {
        _burn(account, amount);
    }

    function totalSupply() public virtual view returns(uint256) {
        return s.totalSupply;
    }

    function balanceOf(address account) public virtual view returns(uint256) {
        return s.balanceOf[account];
    }

    function calcBorrowRate(uint256, uint256) internal virtual override view returns(uint256) {
        return borrowRate;
    }

    function getReserves() public virtual view returns(uint128[] memory) {
        return s.CFMM_RESERVES;
    }

    function testUpdateReserves() public virtual {
        updateReserves(s.cfmm);
    }

    function updateReserves(address cfmm) internal virtual override {
        (s.CFMM_RESERVES[0], s.CFMM_RESERVES[1],) = TestCFMM(cfmm).getReserves();
    }

    function setInvariant(uint256 _invariant) public virtual {
        invariant = _invariant;
    }

    function calcInvariant(address, uint128[] memory) internal virtual override view returns(uint256) {
        return invariant;
    }

    function depositToCFMM(address, address, uint256[] memory) internal virtual override returns(uint256) { return 0; }

    function withdrawFromCFMM(address, address, uint256) internal virtual override returns(uint256[] memory amounts) { return amounts; }
}
