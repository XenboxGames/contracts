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
    function getPlayerOwners(address _user) external returns (uint256[] memory);
}

/**
 * @title Proof of Play Miner contract
 */
contract ProofOfPlay is Ownable, ReentrancyGuard {
    IERC20 public xenboxToken;
    uint256 public totalRewards = 1;
    uint256 public totalClaimedRewards;
    uint256 public multiplier = 10;
    uint256 public bonus = 1;
    uint256 public timeLock = 24 hours;
    uint256 private divisor = 100 ether;
    address private guard; 
    address public xenomorph;
    bool public paused = false; 

    address[] public Participants;
    // Declare the ActiveMiners array
    uint256 public activeMinersLength;

    mapping(uint256 => IXenomorphic.Player) public ActiveMiners;
    mapping(address => uint256[]) public AllOwners;
    mapping(uint256 => Miner) public Collectors;

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

    function getOwnerData() public nonReentrant {
        uint256[] memory tokenIds = IXenomorphic(xenomorph).getPlayerOwners(msg.sender);
        AllOwners[msg.sender] = tokenIds;
    }

    function mineXenbox(uint256 _tokenId) public nonReentrant {
        require(!paused, "Paused Contract");
        getMinerData();
        getOwnerData();
        // Check if the _tokenId is present in the AllOwners[msg.sender] mapping
        bool verified = false;
        uint256[] memory ownedTokenIds = AllOwners[msg.sender];
        for (uint256 i = 0; i < ownedTokenIds.length; i++) {
            if (ownedTokenIds[i] == _tokenId) {
                verified = true;
                break;
            }
        }
        require(verified, "Not Owner!");
        require(_tokenId > 0 && _tokenId <= activeMinersLength, "Not Found!");         
        require(ActiveMiners[_tokenId].hatch > 1, "Hatchup Required");
        require(ActiveMiners[_tokenId].level > 0, "Levelup Required");

        uint256 hatch = ActiveMiners[_tokenId].hatch * 10 * bonus;
        uint256 level = (ActiveMiners[_tokenId].level - Collectors[_tokenId].level) * bonus;
        uint256 fights = (ActiveMiners[_tokenId].fights - Collectors[_tokenId].fights) * bonus;
        uint256 wins = (ActiveMiners[_tokenId].wins - Collectors[_tokenId].wins) * bonus;
        uint256 history = (ActiveMiners[_tokenId].history - Collectors[_tokenId].history) * bonus;
        uint256 rewards = hatch * multiplier + (level + fights + wins + history);
        
        //Check the contract for adequate withdrawal balance
        require(xenboxToken.balanceOf(address(this)) > rewards, "Not Enough Reserves");      
        // Transfer the rewards amount to the miner
        require(xenboxToken.transfer(msg.sender, rewards), "Failed Transfer.");

        getCollectors(_tokenId);
        
        emit RewardClaimedByMiner(msg.sender, rewards);
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


    function setMultiplier (uint256 _multiples) external onlyOwner() {
        multiplier = _multiples;
    }

    function setBonus (uint256 _multiples) external onlyOwner() {
        bonus = _multiples;
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