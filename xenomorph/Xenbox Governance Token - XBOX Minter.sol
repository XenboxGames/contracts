// SPDX-License-Identifier: MIT

// @title Xenomorph NFT Game by OxSorcerer | Battousai Nakamoto | DarcViper for Xenbox Games
// https://twitter.com/0xSorcerers | https://github.com/Dark-Viper | https://t.me/Oxsorcerer | https://t.me/battousainakamoto | https://t.me/darcViper

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Xenbox is ERC20, Ownable, ReentrancyGuard {        
        constructor(string memory _name, string memory _symbol) 
            ERC20(_name, _symbol)
        {}
    using ABDKMath64x64 for uint256;
    using SafeMath for uint256;

    bool public paused = false;
    uint256 public CIRC_SUPPLY = 0;
    uint256 public MAX_SUPPLY = 5000000000 * 10 ** decimals();

    event mintEvent(uint256 indexed multiplier);
    function mint(uint256 _multiplier) external onlyOwner {        
        require(!paused, "Paused Contract");
        require(_multiplier > 0, "Invalid Multiplier");
        require(CIRC_SUPPLY < MAX_SUPPLY, "Max Minted");
        uint256 multiplier =  _multiplier * (1_000_000 * 10 ** decimals());
        require(CIRC_SUPPLY + multiplier < MAX_SUPPLY, "Max Exceeded");
        _mint(msg.sender, multiplier);  
        CIRC_SUPPLY += multiplier;      
        emit mintEvent(multiplier);
    }

    event burnEvent(uint256 indexed _amount);
    function Burn(uint256 _amount) public nonReentrant {                
        require(!paused, "Paused Contract");
       _burn(msg.sender, _amount);
       emit burnEvent(_amount);
    }

    event Pause();
    function pause() public onlyOwner {
        require(msg.sender == owner(), "Only Deployer.");
        require(!paused, "Contract already paused.");
        paused = true;
        emit Pause();
    }

    event Unpause();
    function unpause() public onlyOwner {
        require(msg.sender == owner(), "Only Deployer.");
        require(paused, "Contract not paused.");
        paused = false;
        emit Unpause();
    }
}