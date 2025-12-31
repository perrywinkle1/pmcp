// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title PMCPRegistry
 * @dev Registry and payment contract for Private MCP Network
 * 
 * Core functions:
 * - Server operators register their MCP servers
 * - Users pay tokens to call servers
 * - Server operators withdraw their earnings
 */
contract PMCPRegistry is ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // ============ Structs ============
    
    struct MCPServer {
        address owner;              // Who gets paid
        string endpoint;            // Where to send requests
        string[] tools;             // What tools are available
        uint256 pricePerCall;       // Cost in PMCP tokens (wei)
        bytes fhePublicKey;         // Server's FHE public key
        bool active;                // Is it accepting calls?
        uint256 totalCalls;         // Stats: total calls received
        uint256 totalEarnings;      // Stats: total tokens earned
    }
    
    // ============ State Variables ============
    
    IERC20 public immutable pmcpToken;
    
    // serverId => MCPServer
    mapping(bytes32 => MCPServer) public servers;
    
    // All registered server IDs
    bytes32[] public serverIds;
    
    // owner => pending withdrawal balance
    mapping(address => uint256) public pendingWithdrawals;
    
    // Counter for generating unique server IDs
    uint256 private serverNonce;
    
    // ============ Events ============
    
    event ServerRegistered(
        bytes32 indexed serverId,
        address indexed owner,
        string endpoint,
        uint256 pricePerCall
    );
    
    event ServerUpdated(
        bytes32 indexed serverId,
        string endpoint,
        uint256 pricePerCall,
        bool active
    );
    
    event ServerCalled(
        bytes32 indexed serverId,
        address indexed caller,
        uint256 payment
    );
    
    event Withdrawal(
        address indexed owner,
        uint256 amount
    );
    
    // ============ Constructor ============
    
    constructor(address _pmcpToken) {
        pmcpToken = IERC20(_pmcpToken);
    }
    
    // ============ Server Registration ============
    
    /**
     * @dev Register a new MCP server
     * @param endpoint URL where the server accepts requests
     * @param tools Array of tool names available on this server
     * @param pricePerCall Cost in PMCP tokens per call
     * @param fhePublicKey Server's FHE public key for encryption
     * @return serverId Unique identifier for this server
     */
    function registerServer(
        string calldata endpoint,
        string[] calldata tools,
        uint256 pricePerCall,
        bytes calldata fhePublicKey
    ) external returns (bytes32 serverId) {
        require(bytes(endpoint).length > 0, "Endpoint required");
        require(tools.length > 0, "At least one tool required");
        require(fhePublicKey.length > 0, "FHE public key required");
        
        // Generate unique server ID
        serverId = keccak256(abi.encodePacked(
            msg.sender,
            endpoint,
            block.timestamp,
            serverNonce++
        ));
        
        // Create server entry
        servers[serverId] = MCPServer({
            owner: msg.sender,
            endpoint: endpoint,
            tools: tools,
            pricePerCall: pricePerCall,
            fhePublicKey: fhePublicKey,
            active: true,
            totalCalls: 0,
            totalEarnings: 0
        });
        
        serverIds.push(serverId);
        
        emit ServerRegistered(serverId, msg.sender, endpoint, pricePerCall);
    }
    
    /**
     * @dev Update server configuration (owner only)
     */
    function updateServer(
        bytes32 serverId,
        string calldata endpoint,
        uint256 pricePerCall,
        bool active
    ) external {
        MCPServer storage server = servers[serverId];
        require(server.owner == msg.sender, "Not server owner");
        
        server.endpoint = endpoint;
        server.pricePerCall = pricePerCall;
        server.active = active;
        
        emit ServerUpdated(serverId, endpoint, pricePerCall, active);
    }
    
    /**
     * @dev Update server's FHE public key (owner only)
     */
    function updateFHEKey(bytes32 serverId, bytes calldata fhePublicKey) external {
        MCPServer storage server = servers[serverId];
        require(server.owner == msg.sender, "Not server owner");
        require(fhePublicKey.length > 0, "FHE public key required");
        
        server.fhePublicKey = fhePublicKey;
    }
    
    // ============ Calling Servers ============
    
    /**
     * @dev Pay to call a server
     * @param serverId The server to call
     * 
     * Caller must have approved this contract to spend PMCP tokens
     * Payment is held in contract until server owner withdraws
     */
    function callServer(bytes32 serverId) external nonReentrant {
        MCPServer storage server = servers[serverId];
        require(server.owner != address(0), "Server not found");
        require(server.active, "Server not active");
        
        uint256 payment = server.pricePerCall;
        
        // Transfer payment from caller to contract
        pmcpToken.safeTransferFrom(msg.sender, address(this), payment);
        
        // Credit to server owner
        pendingWithdrawals[server.owner] += payment;
        
        // Update stats
        server.totalCalls++;
        server.totalEarnings += payment;
        
        emit ServerCalled(serverId, msg.sender, payment);
    }
    
    // ============ Withdrawals ============
    
    /**
     * @dev Server operators withdraw their earnings
     */
    function withdraw() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        
        pendingWithdrawals[msg.sender] = 0;
        pmcpToken.safeTransfer(msg.sender, amount);
        
        emit Withdrawal(msg.sender, amount);
    }
    
    // ============ View Functions ============
    
    /**
     * @dev Get total number of registered servers
     */
    function getServerCount() external view returns (uint256) {
        return serverIds.length;
    }
    
    /**
     * @dev Get server details
     */
    function getServer(bytes32 serverId) external view returns (
        address owner,
        string memory endpoint,
        string[] memory tools,
        uint256 pricePerCall,
        bytes memory fhePublicKey,
        bool active,
        uint256 totalCalls,
        uint256 totalEarnings
    ) {
        MCPServer storage server = servers[serverId];
        return (
            server.owner,
            server.endpoint,
            server.tools,
            server.pricePerCall,
            server.fhePublicKey,
            server.active,
            server.totalCalls,
            server.totalEarnings
        );
    }
    
    /**
     * @dev Get server's tools
     */
    function getServerTools(bytes32 serverId) external view returns (string[] memory) {
        return servers[serverId].tools;
    }
    
    /**
     * @dev Get all active servers (paginated)
     */
    function getActiveServers(uint256 offset, uint256 limit) 
        external 
        view 
        returns (bytes32[] memory activeIds, uint256 total) 
    {
        // Count active servers
        uint256 activeCount = 0;
        for (uint256 i = 0; i < serverIds.length; i++) {
            if (servers[serverIds[i]].active) {
                activeCount++;
            }
        }
        
        // Calculate pagination
        if (offset >= activeCount) {
            return (new bytes32[](0), activeCount);
        }
        
        uint256 resultSize = limit;
        if (offset + limit > activeCount) {
            resultSize = activeCount - offset;
        }
        
        activeIds = new bytes32[](resultSize);
        uint256 currentIndex = 0;
        uint256 resultIndex = 0;
        
        for (uint256 i = 0; i < serverIds.length && resultIndex < resultSize; i++) {
            if (servers[serverIds[i]].active) {
                if (currentIndex >= offset) {
                    activeIds[resultIndex] = serverIds[i];
                    resultIndex++;
                }
                currentIndex++;
            }
        }
        
        return (activeIds, activeCount);
    }
}
