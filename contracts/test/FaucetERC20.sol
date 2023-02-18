// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FaucetERC20 is ERC20 {

    address public owner;

    uint256 constant public tokenAmount = 10*(10**18);
    uint256 constant public waitTime = 30 minutes;

    mapping(address => uint256) lastAccessTime;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        owner = msg.sender;
        _mint(msg.sender, 1000000000 * (1e18));
    }

    function mint(address to, uint256 amount) public virtual {
        require(msg.sender == owner, "FORBIDDEN");
        _mint(to, amount);
    }

    function requestTokens() public {
        require(allowedToWithdraw(msg.sender), "WAIT");
        _mint(msg.sender, tokenAmount);
        lastAccessTime[msg.sender] = block.timestamp + waitTime;
    }

    function allowedToWithdraw(address _address) public view returns (bool) {
        if(lastAccessTime[_address] == 0) {
            return true;
        } else if(block.timestamp >= lastAccessTime[_address]) {
            return true;
        }
        return false;
    }
}
