// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Token Incentivizer Contract
 * @dev A contract that incentivizes holding a certain token
 */
contract Incentivizer is Ownable, ReentrancyGuard {
    IERC20 public xenboxToken;
    IERC20 public payToken;
    uint256 public totalRewards;
    uint256 public totalClaimedRewards;
    uint256 public startTime;
    uint256 public rewardPerBlock;
    uint256 public numberOfParticipants = 0;
    uint256 public duration = 2 weeks;
    uint256 public TotalXenboxSent;
    uint256 public currentEra = 0;
    address private guard; 
    bool public paused = false; 

    mapping(address => uint256) public balances;
    mapping(address => uint256) public lastUpdateBlock;
    mapping(address => Claim) public claimRewards;

    Era[] public eraMap;

    struct Era {
        uint256 blockNumber;
        uint256 rewardPerBlock;
    }

    struct Claim {
        uint256 eraAtBlock;
        uint256 xenboxSent;
        uint256 rewardsOwed;
    }
    
    event RewardAddedByDev(uint256 amount);
    event RewardClaimedByUser(address indexed user, uint256 amount);
    event AddXenbox(address indexed user, uint256 amount);
    event WithdrawXenbox(address indexed user, uint256 amount);
    
    constructor(
        address _xenboxToken,
        address _payToken,
        address _newGuard
    ) {
        xenboxToken = IERC20(_xenboxToken);
        payToken = IERC20(_payToken);
        guard = _newGuard;
        startTime = block.timestamp;
    }

    modifier onlyGuard() {
        require(msg.sender == guard, "Not authorized.");
        _;
    }

    function addXenbox(uint256 _amount) external nonReentrant {
        require(!paused, "Contract is paused.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(xenboxToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed.");

        Claim storage claimData = claimRewards[msg.sender];
        uint256 currentBalance = balances[msg.sender];
        uint256 newBalance = currentBalance + _amount;
        balances[msg.sender] = newBalance;

        if (currentBalance == 0) {
            numberOfParticipants += 1;
        } else {
            uint256 rewardsAccrued = calcRewards();
            claimData.rewardsOwed = rewardsAccrued;
            claimData.eraAtBlock = block.number;
        }
        
        claimData.xenboxSent += _amount;
        TotalXenboxSent += _amount;
        updateRewardPerBlock();
        emit AddXenbox(msg.sender, _amount);
    }



    /**
    * @dev Allows the user to withdraw their xenbox tokens
    */
    function withdrawXenbox() external nonReentrant {
        require(!paused, "Contract already paused.");
        require(balances[msg.sender] > 0, "No xenbox tokens to withdraw.");

        uint256 xenboxAmount = balances[msg.sender];
        balances[msg.sender] = 0;
        TotalXenboxSent -= xenboxAmount;
        xenboxToken.transfer(msg.sender, xenboxAmount);

        if (numberOfParticipants > 0) {
            numberOfParticipants -= 1;
        }

        claim();
        updateRewardPerBlock();
        emit WithdrawXenbox(msg.sender, xenboxAmount);
    }

    /**
    * @dev Adds new rewards to the contract
    * @param _amount The amount of rewards to add
    */
    function addRewards(uint256 _amount) external onlyOwner {
        payToken.transferFrom(msg.sender, address(this), _amount);
        totalRewards += _amount;
        updateRewardPerBlock();
        emit RewardAddedByDev(_amount);
    }

    function updateRewardPerBlock() internal {
        uint256 totalPayTokens = payToken.balanceOf(address(this));
        uint256 calculatedRewardPerBlock = totalPayTokens / (TotalXenboxSent * duration);
        rewardPerBlock = calculatedRewardPerBlock;
        
        if (eraMap.length == 0 || eraMap[eraMap.length - 1].blockNumber < block.number) {
            Era memory newEra = Era({
                blockNumber: block.number,
                rewardPerBlock: rewardPerBlock
            });
            eraMap.push(newEra);
        }
    }

    function calcRewards() internal returns (uint256 rewardsAccrued) {
        Claim storage claimData = claimRewards[msg.sender];
        uint256 currentBlockNumber = block.number;
        uint256[] memory eraBlocks = new uint256[](eraMap.length);

        uint256 eraCount = 0;
        for (uint i = claimData.eraAtBlock; i < eraMap.length; i++) {
            Era storage era = eraMap[i];
            if (currentBlockNumber >= era.blockNumber) {
                eraBlocks[eraCount] = era.blockNumber;
                eraCount++;
            }
        }

        if (eraCount > 0) {
        rewardsAccrued = claimData.rewardsOwed;
            for (uint i = 0; i < eraCount; i++) {            
                uint256 startBlock = i == 0 ? claimData.eraAtBlock : eraBlocks[i - 1];
                uint256 endBlock = eraBlocks[i];
                uint256 period = endBlock - startBlock;
                uint256 eraReward = period * eraMap[i].rewardPerBlock;
                uint256 userReward = (claimData.xenboxSent * eraReward);
                rewardsAccrued += userReward;
            }
        }
        claimData.rewardsOwed = 0;
        claimData.eraAtBlock = currentBlockNumber;
        return rewardsAccrued;
    }

    function claim() public nonReentrant {  
        require(!paused, "Contract already paused.");      
        uint256 rewardsAccrued = calcRewards();
        require(payToken.transfer(msg.sender, rewardsAccrued), "Transfer failed.");
    }

    function withdrawRewards(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero.");
        require(payToken.balanceOf(address(this)) >= amount, "Insufficient balance.");
        require(payToken.transfer(msg.sender, amount), "Transfer failed.");
    }

    function setDuration(uint256 _InWeeks) external onlyOwner {
        duration = _InWeeks * 1 weeks;
    }

    function setXenboxToken(address _xenboxToken) external onlyOwner {
        xenboxToken = IERC20(_xenboxToken);
    }

    function setPayToken(address _payToken) external onlyOwner {
        payToken = IERC20(_payToken);
    }

    event Pause();
    function pause() public onlyGuard {
        require(msg.sender == owner(), "Only Deployer.");
        require(!paused, "Contract already paused.");
        paused = true;
        emit Pause();
    }

    event Unpause();
    function unpause() public onlyGuard {
        require(msg.sender == owner(), "Only Deployer.");
        require(paused, "Contract not paused.");
        paused = false;
        emit Unpause();
    }

    function setGuard (address _newGuard) external onlyGuard {
        guard = _newGuard;
    }
}
