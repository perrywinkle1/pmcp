// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PMCPToken
 * @dev ERC20 token for the Private MCP Network
 * 
 * Fixed supply of 100,000,000 PMCP tokens
 * Used to pay for MCP server calls
 */
contract PMCPToken is ERC20, ERC20Burnable, Ownable {
    uint256 public constant TOTAL_SUPPLY = 100_000_000 * 10**18;
    
    // Distribution addresses (set during deployment)
    address public teamWallet;
    address public earlyUsersWallet;
    address public treasuryWallet;
    address public liquidityWallet;
    
    constructor(
        address _teamWallet,
        address _earlyUsersWallet,
        address _treasuryWallet,
        address _liquidityWallet
    ) ERC20("Private MCP Token", "PMCP") Ownable(msg.sender) {
        teamWallet = _teamWallet;
        earlyUsersWallet = _earlyUsersWallet;
        treasuryWallet = _treasuryWallet;
        liquidityWallet = _liquidityWallet;
        
        // Mint entire supply according to tokenomics:
        // Team: 20% (vested 2 years - vesting handled externally)
        // Early Users: 30% (airdrops, rewards for early servers)
        // Treasury: 30% (future development)
        // Liquidity: 20% (DEX pools)
        
        _mint(_teamWallet, (TOTAL_SUPPLY * 20) / 100);      // 20M PMCP
        _mint(_earlyUsersWallet, (TOTAL_SUPPLY * 30) / 100); // 30M PMCP
        _mint(_treasuryWallet, (TOTAL_SUPPLY * 30) / 100);   // 30M PMCP
        _mint(_liquidityWallet, (TOTAL_SUPPLY * 20) / 100);  // 20M PMCP
    }
}
