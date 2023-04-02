// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";

interface IXenomorphic {
    struct Player {
        string name;
        uint256 id;
        uint256 level;
        uint256 attack;
        uint256 defence;
        uint256 fights;
        uint256 wins;
        uint256 payout;
        uint256 hatch;
        uint256 history;
    }

    function getPlayers() external view returns (Player[] memory);
    function getPlayerOwners(address _user) external returns (Player[] memory);
}

/**
 * @title Proof of Play Miner contract
 */
contract ProofOfPlay is Ownable, ReentrancyGuard {
    IERC20 public xenboxToken;
    uint256 public totalClaimedRewards;
    uint256 public multiplier = 10;
    uint256 public timeLock = 24 hours;
    uint256 private divisor = 1 ether;
    address private guard; 
    address public xenomorph;
    bool public paused = false; 
    uint256 public hatchbonus = 5;
    uint256 public levelbonus = 4;
    uint256 public winsbonus = 3;
    uint256 public fightsbonus = 2;
    uint256 public historybonus = 1;
        

    // Declare the ActiveMiners array
    uint256 public activeMinersLength;

    mapping(uint256 => IXenomorphic.Player) public ActiveMiners;
    mapping(uint256 => Miner) public Collectors;
    mapping(uint256 => uint256) public MinerClaims;


    struct Miner {
        string name;
        uint256 id;
        uint256 level;
        uint256 attack;
        uint256 defence;
        uint256 fights;
        uint256 wins;
        uint256 payout;
        uint256 hatch;
        uint256 history;
    }

    event RewardClaimedByMiner (address indexed user, uint256 amount);
    
    constructor(
        address _xenboxToken,
        address _xenomorph,
        address _newGuard
    ) {
        xenboxToken = IERC20(_xenboxToken);
        xenomorph = _xenomorph;
        guard = _newGuard;
    }

    using ABDKMath64x64 for uint256;  

    modifier onlyGuard() {
        require(msg.sender == guard, "Not authorized.");
        _;
    }

    function getMinerData() public nonReentrant {
        IXenomorphic.Player[] memory players = IXenomorphic(xenomorph).getPlayers();
        activeMinersLength = players.length;

        for (uint256 i = 0; i < players.length; i++) {
            ActiveMiners[i] = players[i];
        }
    }

    function getActiveMiner(uint256 index) public view returns (IXenomorphic.Player memory) {
        require(index < activeMinersLength, "Index out of range.");
        return ActiveMiners[index];
    }

    function getOwnerData(uint256 _tokenId) internal returns (bool) {        
    // Get the Player structs owned by the msg.sender
    IXenomorphic.Player[] memory owners = IXenomorphic(xenomorph).getPlayerOwners(msg.sender);


    // Iterate through the stored Player structs and compare the _tokenId with the id of each Player struct
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i].id == _tokenId) {
                return true;
            }
        }
        return false;
    }

    function mineXenbox(uint256 _tokenId) public nonReentrant {
        //Require Contract isn't paused
        require(!paused, "Paused Contract");
        //Require Token Ownership    
        require(getOwnerData(_tokenId), "Not Owner!");
        //Require Miner hasn't claimed within 24hrs
        require(MinerClaims[_tokenId] + timeLock < block.timestamp, "Timelocked.");


    // if statement may work here 
     if (ActiveMiners[_tokenId].hatch > 1) {
            //Reorg ActiveMiners array
        IXenomorphic.Player[] memory players = IXenomorphic(xenomorph).getPlayers();
                activeMinersLength = players.length;

                for (uint256 i = 0; i < players.length; i++) {
                    ActiveMiners[i] = players[i];
                }

        //Calculate Rewards
        uint256 hatchfactor = ActiveMiners[_tokenId].hatch * hatchbonus;
        uint256 hatch = ActiveMiners[_tokenId].hatch * multiplier;
        uint256 level = ((ActiveMiners[_tokenId].level - Collectors[_tokenId].level) * levelbonus) + hatchfactor;
        uint256 fights = ((ActiveMiners[_tokenId].fights - Collectors[_tokenId].fights) * fightsbonus) + hatchfactor;
        uint256 wins = ((ActiveMiners[_tokenId].wins - Collectors[_tokenId].wins) * winsbonus) + hatchfactor;
        uint256 history = ((ActiveMiners[_tokenId].history - Collectors[_tokenId].history) * historybonus) + hatchfactor;
        uint256 rewards = (hatch + level + fights + wins + history) * divisor;

        // Check the contract for adequate withdrawal balance
        require(xenboxToken.balanceOf(address(this)) > rewards, "Not Enough Reserves");      
        // Transfer the rewards amount to the miner
        require(xenboxToken.transfer(msg.sender, rewards), "Failed Transfer.");
        //Register claim
        getCollectors(_tokenId);
        //Register claim timestamp
        MinerClaims[_tokenId] = block.timestamp; // record the miner's claim timestamp
        //TotalClaimedRewards
        totalClaimedRewards += rewards;       
        //emit event
        emit RewardClaimedByMiner(msg.sender, rewards);
     } else {
        require(ActiveMiners[_tokenId].attack > 10, "Hatchup Required");
     }
 
    }

    function getCollectors(uint256 _tokenId) internal {
        // Read the miner data from the ActiveMiners mapping
        IXenomorphic.Player memory activeMiner = ActiveMiners[_tokenId];

        // Transfer the miner data to the Collectors mapping
        Collectors[_tokenId] = Miner(
            activeMiner.name,
            activeMiner.id,
            activeMiner.level,
            activeMiner.attack,
            activeMiner.defence,
            activeMiner.fights,
            activeMiner.wins,
            activeMiner.payout,
            activeMiner.hatch,
            activeMiner.history
        );
    }

    function setTimeLock(uint256 _seconds) external onlyOwner {
        timeLock = _seconds;
    }

    function setMultiplier (uint256 _multiples) external onlyOwner() {
        multiplier = _multiples;
    }

    function setBonuses (uint256 _hatch, uint256 _level, uint256 _wins, uint256 _fights, uint256 _history) external onlyOwner() {
        hatchbonus = _hatch;
        levelbonus = _level;
        winsbonus = _wins;
        fightsbonus = _fights;
        historybonus = _history;
    }

    function setGuard (address _newGuard) external onlyGuard {
        guard = _newGuard;
    }

    event Pause();
    function pause() public onlyGuard {
        require(!paused, "Contract already paused.");
        paused = true;
        emit Pause();
    }

    event Unpause();
    function unpause() public onlyGuard {
        require(paused, "Contract not paused.");
        paused = false;
        emit Unpause();
    } 
}
