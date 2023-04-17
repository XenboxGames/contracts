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
        constructor(string memory _name, string memory _symbol, address _xenomorph, address _newGuard) 
            ERC20(_name, _symbol)
        {
            xenomorph = _xenomorph;
            guard = _newGuard;
        }
    using ABDKMath64x64 for uint256;
    using SafeMath for uint256;

    bool public paused = false;
    address private guard;
    address public xenomorph;
    uint256 public CIRC_SUPPLY = 0;
    uint256 public MAX_SUPPLY = 5000000000 * 10 ** decimals();
    uint256 public TotalBurns;

    modifier onlyGuard() {
        require(msg.sender == guard, "Not authorized.");
        _;
    }

    modifier onlyBurner() {
        require(msg.sender == xenomorph, "Not authorized.");
        _;
    }

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
    function Burn(uint256 _amount) external onlyBurner {                
        require(!paused, "Paused Contract");
       _burn(msg.sender, _amount);
       TotalBurns += _amount;
       emit burnEvent(_amount);
    }

    function burner(uint256 _amount) external onlyOwner {                
        require(!paused, "Paused Contract");
       _burn(msg.sender, _amount);
       TotalBurns += _amount;
       emit burnEvent(_amount);
    }

    event Pause();
    function pause() public onlyGuard {
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

    function setXenomorph (address _xenomorph) external onlyOwner {
        xenomorph = _xenomorph;
    }

    function setGuard (address _newGuard) external onlyGuard {
        guard = _newGuard;
    }
}
