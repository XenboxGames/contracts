// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Incentivizer Contract
 */
contract Harvester is Ownable, ReentrancyGuard {
    IERC20 public xenboxToken;
    IERC20 public payToken;
    uint256 public totalRewards = 1;
    uint256 public totalClaimedRewards;
    uint256 public startTime;
    uint256 public rewardPerStamp;
    uint256 public numberOfParticipants = 0;
    uint256 public Duration = 1209600;
    uint256 public timeLock = 24 hours;
    uint256 public TotalXenboxSent = 1;
    uint256 private divisor = 100 ether;
    address private guard; 
    bool public paused = false; 

    mapping(address => uint256) public balances;
    mapping(address => Claim) public claimRewards;
    mapping(address => uint256) public entryMap;
    mapping(address => uint256) public UserClaims;

    address[] public participants;

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

    modifier onlyAfterTimelock() {             
        require(entryMap[msg.sender] + timeLock < block.timestamp, "Timelocked.");
        _;
    }

    modifier onlyClaimant() {             
        require(UserClaims[msg.sender] + timeLock < block.timestamp, "Timelocked.");
        _;
    }

    function addXenbox(uint256 _amount) public nonReentrant {
        require(!paused, "Contract is paused.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(xenboxToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed.");

        Claim storage claimData = claimRewards[msg.sender];
        uint256 currentBalance = balances[msg.sender];
        uint256 newBalance = currentBalance + _amount;
        balances[msg.sender] = newBalance;
        entryMap[msg.sender] = block.timestamp; // record the user's entry timestamp

        if (currentBalance == 0) {
            numberOfParticipants += 1;
            participants.push(msg.sender);
        } else {
            updateAllClaims();
        }
    
        claimData.eraAtBlock = block.timestamp;
        claimData.xenboxSent += _amount;
        TotalXenboxSent += _amount;
        updateRewardPerStamp();
        emit AddXenbox(msg.sender, _amount);
    }

    /**
    * @dev Allows the user to withdraw their xenbox tokens
    */
    function withdrawXenbox() public nonReentrant onlyAfterTimelock {
        require(!paused, "Contract already paused.");
        require(balances[msg.sender] > 0, "No xenbox tokens to withdraw.");
        uint256 xenboxAmount = balances[msg.sender];
        require(xenboxToken.transfer(msg.sender, xenboxAmount), "Failed Transfer");  
        
        updateAllClaims();     
         //Delete all allocations of xenbox
        balances[msg.sender] = 0;
        TotalXenboxSent -= xenboxAmount;
        Claim storage claimData = claimRewards[msg.sender];
        claimData.xenboxSent = 0;

        updateRewardPerStamp();

        if (numberOfParticipants > 0) {
            numberOfParticipants -= 1;
            entryMap[msg.sender] = 0; // reset the user's entry timestamp
        }
        
        emit WithdrawXenbox(msg.sender, xenboxAmount);
    }

    /**
    * @dev Adds new rewards to the contract
    * @param _amount The amount of rewards to add
    */
    function addRewards(uint256 _amount) external onlyOwner {
        payToken.transferFrom(msg.sender, address(this), _amount);
        totalRewards += _amount;
        updateRewardPerStamp();
        emit RewardAddedByDev(_amount);
    }

    function updateAllClaims() internal {
    uint256 numOfParticipants = participants.length;
        for (uint i = 0; i < numOfParticipants; i++) {
            address participant = participants[i];
            Claim storage claimData = claimRewards[participant];
            uint256 currentTime = block.timestamp;
            uint256 period = block.timestamp - claimData.eraAtBlock;
            uint256 rewardsAccrued = claimData.rewardsOwed + (rewardPerStamp * period * claimData.xenboxSent);
            claimData.rewardsOwed = rewardsAccrued;
            claimData.eraAtBlock = currentTime;
        }
    }

    function updateRewardPerStamp() internal {
        rewardPerStamp = (totalRewards * divisor) / (TotalXenboxSent * Duration);
    }

    function claim() public nonReentrant onlyClaimant {  
        require(!paused, "Contract already paused."); 
        updateAllClaims(); 
        require(claimRewards[msg.sender].rewardsOwed > 0, "No rewards.");
        Claim storage claimData = claimRewards[msg.sender];
        uint256 rewards = claimData.rewardsOwed / divisor;
        require(payToken.transfer(msg.sender, rewards), "Transfer failed.");        
        claimData.rewardsOwed = 0;
        totalClaimedRewards += rewards;
        totalRewards -= rewards;
        updateRewardPerStamp(); 
        UserClaims[msg.sender] = block.timestamp; // record the user's claim timestamp       
        emit RewardClaimedByUser(msg.sender, rewards);
    }

    function withdraw(uint256 _binary, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero.");
        if (_binary > 1) {
            require(payToken.balanceOf(address(this)) >= amount, "Insufficient balance.");
            require(payToken.transfer(msg.sender, amount), "Transfer failed.");
        totalRewards -= amount;
        updateRewardPerStamp();
    }

    function setDuration(uint256 _seconds) external onlyOwner {        
        updateAllClaims();
        Duration = _seconds;
        updateRewardPerStamp();
    }

    function setTimeLock(uint256 _seconds) external onlyOwner {
        timeLock = _seconds;
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
