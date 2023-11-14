//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "./ERC20.sol";

contract FaucetERC20 is ERC20 {

    address public owner;
    bool public isFaucetOpen;
    uint256 public airdropAmount;
    uint256 public AIRDROP_BLOCK;

    uint256 public tokenAmount;
    uint256 constant public waitTime = 30 minutes;

    mapping(address => uint256) lastAccessTime;

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        owner = msg.sender;
        _mint(msg.sender, 1000000000 * (10 ** decimals()));
        isFaucetOpen = true;
        tokenAmount = 10;
    }

    function setFaucetIssueAmount(uint256 _amount) public {
        require(msg.sender == owner, "FORBIDDEN");
        tokenAmount = _amount;
    }

    function setAirdropAmount(uint256 amount) public virtual {
        require(msg.sender == owner, "FORBIDDEN");
        airdropAmount = amount;
    }

    function setAirdropBlock(uint256 blockNumber) public virtual {
        require(msg.sender == owner, "FORBIDDEN");
        require(blockNumber > block.number);
        AIRDROP_BLOCK = blockNumber;
    }

    function mint(address to, uint256 amount) public virtual {
        require(msg.sender == owner, "FORBIDDEN");
        _mint(to, amount);
    }

    function mintMany(address[] calldata to, uint256 amount) public virtual {
        require(msg.sender == owner, "FORBIDDEN");
        for(uint256 i = 0; i < to.length;) {
            _mint(to[i], amount);
            unchecked {
                ++i;
            }
        }
    }

    function airdrop(address[] calldata to) public virtual {
        require(msg.sender == owner, "FORBIDDEN");
        require(AIRDROP_BLOCK >= block.number, "AIRDROP_BLOCK");

        uint256 mTotalSupply = _totalSupply;
        uint256 mAirdropAmount = airdropAmount;
        address account;
        for(uint256 i = 0; i < to.length;) {
            account = to[i];
            if(account != address(0)) {
                uint256 bal = _balances[account];
                if(bal < mAirdropAmount) {
                    uint256 amount = mAirdropAmount - bal;
                    mTotalSupply += amount;
                unchecked {
                    // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
                    _balances[account] = bal + amount;
                }
                    emit Transfer(address(0), account, amount);
                }
            }
            unchecked {
                ++i;
            }
        }
        _totalSupply = mTotalSupply;
        AIRDROP_BLOCK = 0;
    }

    function closeFaucet() public {
        require(msg.sender == owner, "FORBIDDEN");
        isFaucetOpen = false;
    }

    function openFaucet() public {
        require(msg.sender == owner, "FORBIDDEN");
        isFaucetOpen = true;
    }

    function requestTokens() public {
        require(isFaucetOpen, "CLOSED_FAUCET");
        require(allowedToWithdraw(msg.sender), "WAIT");
        _mint(msg.sender, tokenAmount * (10 ** decimals()));
        lastAccessTime[msg.sender] = block.timestamp + waitTime;
    }

    function allowedToWithdraw(address _address) public view returns (bool) {
        if(!isFaucetOpen) {
            return false;
        }
        if(lastAccessTime[_address] == 0) {
            return true;
        } else if(block.timestamp >= lastAccessTime[_address]) {
            return true;
        }
        return false;
    }
}
