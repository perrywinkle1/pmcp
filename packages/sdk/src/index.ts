/**
 * @pmcp/sdk - Client SDK for Private MCP Network
 * 
 * Enables AI agents and applications to:
 * - Discover MCP servers from the on-chain registry
 * - Encrypt queries using FHE
 * - Pay for and execute calls
 * - Decrypt results
 */

import { ethers } from 'ethers';
import { FHEClient } from './fhe';
import { PMCPRegistryABI, PMCPTokenABI } from './abis';

export interface PMCPConfig {
  privateKey: string;
  network: 'base' | 'base-sepolia' | 'localhost';
  registryAddress?: string;
  tokenAddress?: string;
}

export interface MCPServer {
  id: string;
  owner: string;
  endpoint: string;
  tools: string[];
  pricePerCall: bigint;
  fhePublicKey: Uint8Array;
  active: boolean;
  totalCalls: bigint;
  totalEarnings: bigint;
}

export interface CallResult<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  txHash?: string;
}

// Network configurations
const NETWORKS: Record<string, { rpc: string; registry: string; token: string }> = {
  'base': {
    rpc: 'https://mainnet.base.org',
    registry: '', // To be deployed
    token: '',    // To be deployed
  },
  'base-sepolia': {
    rpc: 'https://sepolia.base.org',
    registry: '', // To be deployed
    token: '',    // To be deployed
  },
  'localhost': {
    rpc: 'http://127.0.0.1:8545',
    registry: '',
    token: '',
  },
};

export class PMCP {
  private provider: ethers.JsonRpcProvider;
  private signer: ethers.Wallet;
  private registry: ethers.Contract;
  private token: ethers.Contract;
  private fhe: FHEClient;
  private network: string;

  constructor(config: PMCPConfig) {
    const networkConfig = NETWORKS[config.network];
    if (!networkConfig) {
      throw new Error(`Unknown network: ${config.network}`);
    }

    this.network = config.network;
    this.provider = new ethers.JsonRpcProvider(networkConfig.rpc);
    this.signer = new ethers.Wallet(config.privateKey, this.provider);

    const registryAddress = config.registryAddress || networkConfig.registry;
    const tokenAddress = config.tokenAddress || networkConfig.token;

    if (!registryAddress || !tokenAddress) {
      throw new Error(`Registry and token addresses required for ${config.network}`);
    }

    this.registry = new ethers.Contract(registryAddress, PMCPRegistryABI, this.signer);
    this.token = new ethers.Contract(tokenAddress, PMCPTokenABI, this.signer);
    this.fhe = new FHEClient();
  }

  /**
   * Search for MCP servers by tool name
   */
  async search(params: { tool?: string; limit?: number }): Promise<MCPServer[]> {
    const limit = params.limit || 20;
    const [serverIds, total] = await this.registry.getActiveServers(0, limit);
    
    const servers: MCPServer[] = [];
    
    for (const serverId of serverIds) {
      const server = await this.getServer(serverId);
      if (server) {
        // Filter by tool if specified
        if (params.tool) {
          if (server.tools.some(t => t.toLowerCase().includes(params.tool!.toLowerCase()))) {
            servers.push(server);
          }
        } else {
          servers.push(server);
        }
      }
    }
    
    return servers;
  }

  /**
   * Get server details by ID
   */
  async getServer(serverId: string): Promise<MCPServer | null> {
    try {
      const data = await this.registry.getServer(serverId);
      if (data.owner === ethers.ZeroAddress) {
        return null;
      }
      
      return {
        id: serverId,
        owner: data.owner,
        endpoint: data.endpoint,
        tools: data.tools,
        pricePerCall: data.pricePerCall,
        fhePublicKey: ethers.getBytes(data.fhePublicKey),
        active: data.active,
        totalCalls: data.totalCalls,
        totalEarnings: data.totalEarnings,
      };
    } catch {
      return null;
    }
  }

  /**
   * Call an MCP server with encrypted query
   * Handles: FHE encryption, payment, and decryption
   */
  async call<T = unknown>(
    serverId: string,
    tool: string,
    params: Record<string, unknown>
  ): Promise<CallResult<T>> {
    try {
      // 1. Get server details
      const server = await this.getServer(serverId);
      if (!server) {
        return { success: false, error: 'Server not found' };
      }
      if (!server.active) {
        return { success: false, error: 'Server is not active' };
      }

      // 2. Check token allowance and approve if needed
      const allowance = await this.token.allowance(
        this.signer.address,
        await this.registry.getAddress()
      );
      
      if (allowance < server.pricePerCall) {
        const approveTx = await this.token.approve(
          await this.registry.getAddress(),
          ethers.MaxUint256 // Approve max for convenience
        );
        await approveTx.wait();
      }

      // 3. Encrypt the query using server's FHE public key
      const query = { tool, params };
      const encryptedQuery = await this.fhe.encrypt(
        JSON.stringify(query),
        server.fhePublicKey
      );

      // 4. Pay on-chain
      const tx = await this.registry.callServer(serverId);
      const receipt = await tx.wait();

      // 5. Send encrypted query to server
      const response = await fetch(server.endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-PMCP-TX': receipt.hash,
          'X-PMCP-Caller': this.signer.address,
        },
        body: JSON.stringify({
          encryptedQuery: Buffer.from(encryptedQuery).toString('base64'),
          serverId,
          tool,
        }),
      });

      if (!response.ok) {
        return { 
          success: false, 
          error: `Server error: ${response.status}`,
          txHash: receipt.hash,
        };
      }

      const serverResponse = await response.json();

      // 6. Decrypt the response
      const decryptedData = await this.fhe.decrypt(
        Buffer.from(serverResponse.encryptedResult, 'base64')
      );

      return {
        success: true,
        data: JSON.parse(decryptedData) as T,
        txHash: receipt.hash,
      };
    } catch (error) {
      return {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      };
    }
  }

  /**
   * Get PMCP token balance
   */
  async getBalance(): Promise<bigint> {
    return this.token.balanceOf(this.signer.address);
  }

  /**
   * Get current wallet address
   */
  getAddress(): string {
    return this.signer.address;
  }
}

// Re-export types and utilities
export { FHEClient } from './fhe';
export * from './abis';
