// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "abdk-libraries-solidity/ABDKMath64x64.sol";
import "https://github.com/FairCrypto/XEN-crypto/blob/master/contracts/XENCrypto.sol";

contract iBurnableExecutor is Ownable, IBurnRedeemable, IERC165 {
    constructor(address xenAddress, address _newGuard) {
        xen = xenAddress;
        guard = _newGuard;
    }
    using ABDKMath64x64 for uint256;
    
    bool public paused = false;
    uint256 public TotalBurns;
    address public xen;
    address public custodian;
    address private guard;

    modifier onlyBurner() {
        require(msg.sender == xen, "Not authorized.");
        _;
    }

    modifier onlyGuard() {
        require(msg.sender == guard, "Not authorized.");
        _;
    }

    event iBurnableEvent(uint256 indexed _amount);
    
    function iBurnable(uint256 _amount) external onlyOwner {                
        require(!paused, "Paused Contract");        
        require(_amount > 0, "Invalid");
        IBurnableToken(xen).burn(msg.sender, _amount);
        emit iBurnableEvent(_amount);
    }

    function onTokenBurned(address user, uint256 amount) external override onlyBurner {        
        TotalBurns += amount;
        custodian = user;
    }

    function setXenAddress (address _xenAddress) external onlyOwner {
        require(msg.sender == owner(), "Not Owner.");
        xen = _xenAddress;
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

    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return
            interfaceId == type(IBurnRedeemable).interfaceId;
    }
}
