// SPDX-License-Identifier: MIT

// @title Xenomorph NFT Game by OxSorcerer | Battousai Nakamoto | DarcViper for Xenbox Games
// https://twitter.com/0xSorcerers | https://github.com/Dark-Viper | https://t.me/Oxsorcerer | https://t.me/battousainakamoto | https://t.me/darcViper

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Xenomorph is ERC721Enumerable, Ownable {        
        constructor(string memory _name, string memory _symbol) 
            ERC721(_name, _symbol)
        {}

    uint256 COUNTER = 0;
    uint256 public mintFee = 0.00001 ether;
    uint256 public _pid = 0;
    uint256 public requiredAmount = 2000000 ether;
    uint256 public hatchingAmount = 20000000 ether;
    uint256 private divisor = 1 ether;
    uint256 public TotalContractBurns = 0;
    uint256 BattlesTotal = 0; 
    using Strings for uint256;
    string public baseURI;
    string public baseExtension = ".json";
    string public Author = "0xSorcerer | Battousai Nakamoto | Dark-Viper";    
    address public deadAddress = 0x000000000000000000000000000000000000dEaD;
    bool public paused = false;
    using SafeERC20 for IERC20;    

    struct Player {
        string name;
        uint256 id;
        string image;        
        string metadata;
        uint256 level;
        uint256 attack;
        uint256 defence;
        uint256 fights;
        uint256 wins;
        uint256 payout;
        uint256 hatch;
        uint256 history;
    }

     struct TokenInfo {
        IERC20 paytoken;
    }

    struct Assaulter {
        uint256 attackerId;
        uint256 defenderId;
        uint256 timestamp;
    }

    struct Debilitator {
        uint256 attackerId;
        uint256 defenderId;
        uint256 timestamp;
    }

    //Arrays
    TokenInfo[] public AllowedCrypto;

    // Mapping
    mapping (uint256 => Player) public players;
    mapping (uint256 => uint256) public functionCalls;
    mapping (uint256 => uint256) private lastReset;
    mapping (uint256 => mapping (uint256 => uint256)) public fightTimestamps;
    mapping (uint256 => Assaulter[]) public assaulters;
    mapping (uint256 => Debilitator[]) public debilitators;

    event TokenMinted(uint256 indexed tokenId, string indexed _name);

    function mint(string memory _name) public payable {
        require(!paused, "The contract is currently paused");
        require(msg.value == mintFee, "The cost of minting an NFT");
        require(bytes(_name).length > 0, "The name cannot be empty");
        // Create a new player and map it
        players[COUNTER] = Player({
            name: _name,
            id: COUNTER,
            image: generateImageUrl(COUNTER),
            metadata: generateMetadataUrl(COUNTER),
            level: 0,
            attack: 100,
            defence: 100,
            fights: 0,
            wins: 0,
            payout: 0,
            hatch: 0,
            history: 0});
        // Mint a new ERC721 token for the player
        uint256 tokenId = COUNTER;
        _mint(msg.sender, tokenId);
        emit TokenMinted(tokenId, _name);
        COUNTER++;
    }

    function updateName(uint256 _tokenId, string memory _newName) public {
       require(msg.sender == ownerOf(_tokenId), "You must own the token to update its name");
       require(bytes(_newName).length > 0, "The name cannot be empty");
       require(_tokenId > 0 && _tokenId <= totalSupply(), "Xenomorph does not exist!");
        // Update the name in the players mapping
        players[_tokenId].name = string(_newName);
    }

    function updateMintFee(uint256 _mintFee) external onlyOwner() {
        mintFee = _mintFee;
    }

    function updatePayID (uint256 _payId) external onlyOwner() {
        _pid = _payId;
    }

    function updateRequiredAmount(uint256 _requiredAmount) external onlyOwner() {
        requiredAmount = _requiredAmount;
    }

    function updateHatchingAmount(uint256 _hatchingAmount) external onlyOwner() {
        hatchingAmount = _hatchingAmount;
    }

    function burn(uint256 _burnAmount, uint256 _num) internal {
        require(_burnAmount > 0 && _num > 0, "Arguments must be positive integers");
        uint256 burnAmount = (_burnAmount * _num)/100 ; 
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;               
        paytoken.transfer(deadAddress, burnAmount); 
        TotalContractBurns += burnAmount;       
    }
    
    function transferTokens(uint256 _cost) internal {
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        paytoken.transferFrom(msg.sender,address(this), _cost);
    }

    function hatchXenomorph (uint256 _tokenId) public payable {
        require(!paused, "The contract is currently paused");
        require(_tokenId > 0 && _tokenId <= totalSupply(), "Xenomorph does not exist!");
        uint256 cost;
        cost = hatchingAmount;
        //Transfer Required Tokens to Hatch Xenomorph        
        transferTokens(cost); 
        //Initiate a 10% burn from the contract       
        burn(cost, 10);
        // Hatch Xenomorph
        players[_tokenId].hatch++;
    }

    function weaponize (uint256 _tokenId) public payable {        
        require(!paused, "The contract is currently paused");
        require(players[_tokenId].hatch > 0, "You must hatch your Xenomorph to weaponize it.");
        require(msg.sender == ownerOf(_tokenId), "You must own a Xenomorph to weaponize it.");
        require(players[_tokenId].id != 0, "Xenomorph does not exist");
        uint256 cost;
        cost = requiredAmount;        
        //Transfer Required Tokens to Weaponize Xenomorph
        transferTokens(cost);  
        //Initiate a 50% burn from the contract
        burn(cost, 50);
        // Weaponize Xenomorph
        players[_tokenId].attack += 20;
    } 

    function regenerate (uint256 _tokenId) public payable {
        require(msg.sender == ownerOf(_tokenId), "You must own a Xenomorph to regenerate");
        require(players[_tokenId].id != 0, "Xenomorph does not exist");
        require(players[_tokenId].hatch > 0, "You must hatch your Xenomorph to regenerate it.");        
        uint256 cost;
        cost = requiredAmount;
        //Transfer Required Tokens to Weaponize Xenomorph
        transferTokens(cost); 
        //Initiate a 50% burn from the contract
        burn(cost, 50);
        // Regenerate Xenomorph
        players[_tokenId].defence += 20;
    } 

    event AssaultEvent(uint256 indexed attackerId, uint256 indexed defenderId, uint256 stolenPoints, uint256 indexed timestamp);
    
    function Assault(uint256 attackerId, uint256 defenderId) public payable {
        require(!paused, "The contract is currently paused");
        require(msg.sender == ownerOf(attackerId), "You must own the Xenomorph to assault your enemy!");
        require(players[attackerId].hatch > 0, "You must hatch your Xenomorph");
        require(players[attackerId].attack > 0, "You must have at least 1 attack point to assault");
        require(players[defenderId].attack > 0, "The defender must have at least 1 attack point to be assaulted");
        require(functionCalls[attackerId] < 1000, "You have reached your daily attack limit.");
        require(block.timestamp - fightTimestamps[attackerId][defenderId] >= 24 hours, "Too soon to assault this enemy again.");
        require(attackerId > 0 && attackerId <= totalSupply() && defenderId > 0 && defenderId <= totalSupply(), "Xenomorph does not exist!");
        require(attackerId != defenderId, "You cannot attack yourself");
        uint256 cost;
        cost = requiredAmount;
        //Transfer Required Tokens to Weaponize Xenomorph
        transferTokens(cost); 
         //Initiate a 10% burn from the contract
        burn(cost, 10);
        // increment the function call counter
        functionCalls[attackerId]++;
        // update the fightTimestamps record
        fightTimestamps[attackerId][defenderId] = block.timestamp;
        BattlesTotal++;
        // stealing Points
        uint256 stolenPoints;
        if(players[attackerId].attack >= (players[defenderId].defence + 300)) {
            stolenPoints = 20;
        } else if (players[attackerId].level > players[defenderId].level) {
            stolenPoints = 20;
        } else {
            stolenPoints = 10;
        }
        players[defenderId].attack -= stolenPoints;
        players[attackerId].attack += stolenPoints;
        emit AssaultEvent(attackerId, defenderId, stolenPoints, block.timestamp);
        players[attackerId].fights++;
        players[attackerId].history++;
        players[attackerId].payout += ((requiredAmount - (requiredAmount/10))/divisor);
        addAssaulter(attackerId, defenderId);
    }

    event AssaultPayoutClaimed(uint256 indexed _playerId, uint256 indexed _payreward);

    function claimAssault(uint256 _playerId) public {
        require(!paused, "The contract is currently paused");
        // Ensure that the player calling the function is the owner of the player
        require(msg.sender == ownerOf(_playerId), "You must own the Xenomorph to claim the reward");
        require(_playerId > 0 && _playerId <= totalSupply(), "Xenomorph does not exist!");
        // Check if the player is eligible for a reward
        uint256 reward = (players[_playerId].attack - 100) / 100;
        require(reward > 0, "You are not eligible for a reward");
        // Update the player
        players[_playerId].wins += reward;
        players[_playerId].attack = 100;
        //calculate payout        
        uint256 winmultiplier = 5;
        uint256 payreward = ((requiredAmount - (requiredAmount/10))/divisor) * reward * winmultiplier;
        players[_playerId].payout += payreward;
        // Emit event for payout 
        emit AssaultPayoutClaimed(_playerId, payreward);
    }

    event DebilitateEvent(uint256 indexed attackerId, uint256 indexed defenderId, uint256 stolenPoints, uint256 indexed timestamp);

    function Debilitate(uint256 attackerId, uint256 defenderId) public payable {
        require(!paused, "The contract is currently paused");
        require(msg.sender == ownerOf(attackerId), "You must own the Xenomorph to debilitate your enemy!"); 
        require(players[attackerId].hatch > 0, "You must hatch your Xenomorph");       
        require(players[attackerId].defence > 0, "You must have at least 1 defence point to debilitate");
        require(players[defenderId].defence > 0, "The defender must have at least 1 defence point to be debilitated");
        require(functionCalls[attackerId] < 1000, "You have reached your daily debilitation limit.");
        // check if the last debilitation was more than 24 hours ago
        require(block.timestamp - fightTimestamps[attackerId][defenderId] >= 24 hours, "Too soon to debilitate this enemy again.");
        require(attackerId > 0 && attackerId <= totalSupply() && defenderId > 0 && defenderId <= totalSupply(), "Xenomorph does not exist!");
        require(attackerId != defenderId, "You cannot debilitate yourself");
        uint256 cost;
        cost = requiredAmount;
        //Transfer Required Tokens to Weaponize Xenomorph
        transferTokens(cost); 
        //Burn 10% forever
        burn(cost, 10);
        // increment the function call counter
        functionCalls[attackerId]++;
        // update the fightTimestamps record
        fightTimestamps[attackerId][defenderId] = block.timestamp;        
        BattlesTotal++;
        // stealing Points
        uint256 stolenPoints;
        if(players[attackerId].defence >= (players[defenderId].attack + 300)) {
            stolenPoints = 20;            
        } else if (players[attackerId].level > players[defenderId].level) {
            stolenPoints = 20;
        } else {
            stolenPoints = 10;
        }
        players[defenderId].defence -= stolenPoints;
        players[attackerId].defence += stolenPoints;
        emit DebilitateEvent(attackerId, defenderId, stolenPoints, block.timestamp);
        players[attackerId].fights++;
        players[attackerId].history++;
        players[attackerId].payout += ((requiredAmount - (requiredAmount/10))/divisor);
        addDebilitator(attackerId, defenderId);
    }

    event DebilitatePayoutClaimed(uint256 indexed _playerId, uint256 _payreward);

    function claimDebilitate(uint256 _playerId) public {
        require(!paused, "The contract is currently paused");
        // Ensure that the player calling the function is the owner of the player
        require(msg.sender == ownerOf(_playerId), "You must own the Xenomorph to claim the reward");
        require(_playerId > 0 && _playerId <= totalSupply(), "Xenomorph does not exist");
        // Check if the player is eligible for a reward
        uint256 reward = (players[_playerId].defence - 100) / 100;
        require(reward > 0, "You are not eligible for a reward");
        // Update the player
        players[_playerId].wins += reward;
        players[_playerId].defence = 100;
        //calculate payout        
        uint256 winmultiplier = 5;
        uint256 payreward = ((requiredAmount - (requiredAmount/10))/divisor) * reward * winmultiplier;
        players[_playerId].payout += payreward;
        // Emit event for payout 
        emit DebilitatePayoutClaimed(_playerId, payreward);
    }

    event LevelUpEvent(uint256 indexed _playerId, uint256 indexed _level);

    function levelUp(uint256 _playerId) public {
        require(!paused, "The contract is currently paused");
        // Ensure that the player calling the function is the owner of the Xenomorph
        require(msg.sender == ownerOf(_playerId), "You must own the Xenomorph to claim the reward");
        require(_playerId > 0 && _playerId <= totalSupply(), "Xenomorph does not exist!");
        // Calculate the player's current level by dividing their win count by the increment
        uint256 currentLevel = players[_playerId].wins / 5;
        // Update the player's level
        players[_playerId].level = currentLevel;
        // Emit event for level up
        emit LevelUpEvent(_playerId, currentLevel);
    }
    
    function resetFunctionCalls(uint256 _playerId) public {
        require(!paused, "The contract is currently paused");
        require(msg.sender == ownerOf(_playerId), "You must own the token to reset the function calls counter.");
        // check if the last reset was more than 24 hours ago
        require(block.timestamp - lastReset[_playerId] >= 24 hours, "Too soon to reset the counter.");
        // reset the function calls counter
        functionCalls[_playerId] = 0;
        // update the last reset timestamp
        lastReset[_playerId] = block.timestamp;
    }

    function generateImageUrl(uint256 _counter) internal pure returns (string memory) {
        return string.concat("https://xenbox.xyz/xenomorph/",Strings.toString(_counter),".png");
    }

    function generateMetadataUrl(uint256 _counter) internal pure returns (string memory) {
        return string.concat("https://xenbox.xyz/xenomorph/",Strings.toString(_counter),".json");
    }
    
    function changeOwner(address newOwner) public onlyOwner {
        // Require that the caller is the current owner of the contract
        require(msg.sender == owner(), "Only the contract creator can change the owner.");
        // Update the owner to the new owner
        transferOwnership(newOwner);
    }

    function withdraw(uint256 _amount) external payable onlyOwner() {
        address payable _owner = payable(owner());
        _owner.transfer(_amount);
    }

    function withdrawERC20(uint256 _payId, uint256 _amount) external payable onlyOwner() {
        TokenInfo storage tokens = AllowedCrypto[_payId];
        IERC20 paytoken;
        paytoken = tokens.paytoken;
        paytoken.transfer(msg.sender, _amount);
    }

    address payable developmentAddress;

    function setDevelopmentAddress(address payable _developmentAddress) public onlyOwner {
        require(msg.sender == owner(), "Only the contract owner can perform this action.");
        developmentAddress = _developmentAddress;
    }

    event PayoutsClaimed(address indexed _player, uint256 indexed _amount);

    function Payouts (uint256 _playerId) public payable {
        require(!paused, "The contract is currently paused");
        require(players[_playerId].level >= 1, "You must have a level of at least 1 to claim a payout");
        require(players[_playerId].payout > 0, "Your payout is 0");
        require(players[_playerId].fights >= 5, "You must have engaged in at least 5 fights to claim a payout");
        require(msg.sender == ownerOf(_playerId), "You must own the Xenomorph to claim the reward");
        // Calculate the payout amount
        uint256 totalAmount = (players[_playerId].payout * divisor);
        uint256 fee = totalAmount / 20;
        uint256 payoutAmount = totalAmount - fee;
        TokenInfo storage tokens = AllowedCrypto[_pid];
        IERC20 paytoken;
        paytoken = tokens.paytoken; 
        //Check the contract for adequate withdrawal balance
        require(paytoken.balanceOf(address(this)) > totalAmount, "Not enough reserves, please try again later");      
        // Transfer the payout amount to the player
        require(paytoken.transfer(msg.sender, payoutAmount), "Transfer Failed");
        // Platform fee
        require(paytoken.transfer(developmentAddress, fee), "Transfer Failed");
        // Reset the payout and wins fields
        players[_playerId].payout = 0;
        players[_playerId].wins = 0;
        // Emit event for payout claim
        emit PayoutsClaimed(msg.sender, payoutAmount);
    }
    
    function addCurrency(
        IERC20 _paytoken
    ) public onlyOwner {
        AllowedCrypto.push(
            TokenInfo({
                paytoken: _paytoken
            })
        );
    }

    function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
    }

    function updateBaseURI(string memory _newLink) external onlyOwner() {
        baseURI = _newLink;
    }

    event Pause();
    function pause() public onlyOwner {
        require(msg.sender == owner(), "Only the deployer can pause the contract.");
        require(!paused, "The contract is already paused.");
        paused = true;
        emit Pause();
    }

    event Unpause();
    function unpause() public onlyOwner {
        require(msg.sender == owner(), "Only the deployer can unpause the contract.");
        require(paused, "The contract is not paused.");
        paused = false;
        emit Unpause();
    } 

    // Getters
  function getPlayers() public view returns (Player[] memory) {
        uint256 counter = 0;
        uint256 total = totalSupply();
        Player[] memory result = new Player[](total);    
        for (uint256 i = 0; i < total; i++) {
                result[counter] = players[i];
                counter++;
        }
        return result;
    }

  function getPlayerOwners(address _player) public view returns (Player[] memory) {
        Player[] memory result = new Player[](balanceOf(_player));
        uint256 counter = 0;        
        uint256 total = totalSupply();
        for (uint256 i = 0; i < total; i++) {
            if (ownerOf(i) == _player) {
                result[counter] = players[i];
                counter++;
            }
        }
        return result;
    } 
    
    function addAssaulter(uint256 attackerId, uint256 defenderId) internal {
        Assaulter memory assaulter = Assaulter({
            attackerId: attackerId,
            defenderId: defenderId,
            timestamp: fightTimestamps[attackerId][defenderId]
        });
        assaulters[attackerId].push(assaulter);
    }

    function getAssaulters(uint256 attackerId) public view returns (Assaulter[] memory) {
        uint256 total = assaulters[attackerId].length;
        Assaulter[] memory result = new Assaulter[](total);
        
        uint256 counter = 0;
        for (uint256 i = 0; i < total; i++) { 
            if (assaulters[attackerId][i].attackerId == attackerId) { 
                result[counter] = assaulters[attackerId][i];
                counter++;  
            }
        }
        return result;
    }



    function addDebilitator(uint256 attackerId, uint256 defenderId) internal {
        Debilitator memory debilitator = Debilitator({
            attackerId: attackerId,
            defenderId: defenderId,
            timestamp: fightTimestamps[attackerId][defenderId]
        });
        debilitators[attackerId].push(debilitator);
    }

    function getDebilitators(uint256 attackerId) public view returns (Debilitator[] memory) {
        uint256 counter = 0;
        uint256 total = debilitators[attackerId].length;
        Debilitator[] memory result = new Debilitator[](total);
        
        for (uint256 i = 0; i < total; i++) { 
            if (debilitators[attackerId][i].attackerId == attackerId) { 
                result[counter] = debilitators[attackerId][i];  
                counter++; 
            }
        }
        return result;
    }


    // Timer for the voting
    uint256 public votingTimer;

    // Map to store the tokenId and its timestamp
    mapping (uint256 => uint256) public tokenTimestamp;

    // Global YAY and NAY votes
    uint256 public YAYVotes;
    uint256 public NAYVotes;

    // Result of the vote
    string public VotePassed;

    // Proof of Game function
    function  ProofOfGame(bytes32 vote, uint256 tokenId) public onlyOwner {
        require(vote == bytes32("YES") || vote == bytes32("NO"), "Invalid vote. Please enter 'Yes' or 'No'.");
        require(tokenTimestamp[tokenId] == 0, "This token has already voted.");
        require(block.timestamp >= votingTimer, "Voting has not started yet or has already ended.");

        Player memory nft = players[tokenId];

        uint256 totalVotes = nft.level + nft.fights + nft.wins + nft.hatch + nft.history + (nft.attack / 100) + (nft.defence / 100);
        
        if (vote == bytes32("YES")) {
            YAYVotes += totalVotes;
        } else {
            NAYVotes += totalVotes;
        }
        
        tokenTimestamp[tokenId] = block.timestamp;
    }

    // Function to reset the voting process
    function resetVoting() public onlyOwner {
        YAYVotes = 0;
        NAYVotes = 0;
        VotePassed = "";
        uint256 total = totalSupply();
        for (uint256 i = 0; i < total; i++) {
            tokenTimestamp[i] = 0;
        }
        votingTimer = 0;
    }

    // Function to start the voting process
    function startVoting(uint256 _votingTimer) public onlyOwner {
        votingTimer = block.timestamp + _votingTimer;
        resetVoting();
    }

    // Function to end the voting process and determine the result
    function endVoting() public onlyOwner {
        require(block.timestamp >= votingTimer, "Voting has not ended yet.");
        if (YAYVotes > NAYVotes) {
        VotePassed = "PASSED";
        } else {
        VotePassed = "NOT PASSED";
        }
    }  
}