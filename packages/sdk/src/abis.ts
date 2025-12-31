/**
 * Contract ABIs for PMCP
 */

export const PMCPTokenABI = [
  // ERC20 Standard
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
  "function totalSupply() view returns (uint256)",
  "function balanceOf(address owner) view returns (uint256)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function transfer(address to, uint256 amount) returns (bool)",
  "function transferFrom(address from, address to, uint256 amount) returns (bool)",
  
  // Events
  "event Transfer(address indexed from, address indexed to, uint256 value)",
  "event Approval(address indexed owner, address indexed spender, uint256 value)",
];

export const PMCPRegistryABI = [
  // Server Registration
  "function registerServer(string endpoint, string[] tools, uint256 pricePerCall, bytes fhePublicKey) returns (bytes32 serverId)",
  "function updateServer(bytes32 serverId, string endpoint, uint256 pricePerCall, bool active)",
  "function updateFHEKey(bytes32 serverId, bytes fhePublicKey)",
  
  // Calling Servers
  "function callServer(bytes32 serverId)",
  
  // Withdrawals
  "function withdraw()",
  "function pendingWithdrawals(address owner) view returns (uint256)",
  
  // View Functions
  "function getServerCount() view returns (uint256)",
  "function getServer(bytes32 serverId) view returns (address owner, string endpoint, string[] tools, uint256 pricePerCall, bytes fhePublicKey, bool active, uint256 totalCalls, uint256 totalEarnings)",
  "function getServerTools(bytes32 serverId) view returns (string[])",
  "function getActiveServers(uint256 offset, uint256 limit) view returns (bytes32[] activeIds, uint256 total)",
  "function serverIds(uint256 index) view returns (bytes32)",
  
  // Events
  "event ServerRegistered(bytes32 indexed serverId, address indexed owner, string endpoint, uint256 pricePerCall)",
  "event ServerUpdated(bytes32 indexed serverId, string endpoint, uint256 pricePerCall, bool active)",
  "event ServerCalled(bytes32 indexed serverId, address indexed caller, uint256 payment)",
  "event Withdrawal(address indexed owner, uint256 amount)",
];
