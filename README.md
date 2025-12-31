# Private MCP Network (PMCP)

> Pay tokens, get private MCP access. Server never sees your data.

A token-gated marketplace where people buy and sell access to private MCP servers, with queries encrypted via FHE so server operators never see user data.

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   Client    │──FHE───▶│  MCP Server │──FHE───▶│   Result    │
│  (AI Agent) │  Query  │  (Executes  │ Response│  (Decrypted │
│             │◀────────│  on cipher) │◀────────│  by client) │
└─────────────┘         └─────────────┘         └─────────────┘
                               │
                               ▼
                        ┌─────────────┐
                        │  On-chain   │
                        │  Registry & │
                        │  Payments   │
                        └─────────────┘
```

## Why This Exists

**Problem**: You want an AI agent to use tools that access sensitive data (your CRM, financial APIs, medical records, proprietary databases). But:
- You don't trust the MCP server operator to see your queries
- Server operators don't trust users to not abuse their APIs
- There's no way to pay for MCP access without setting up billing relationships

**Solution**: 
- FHE encrypts queries so servers compute on ciphertext (they never see your data)
- Token payments handle monetization without accounts or invoices
- On-chain registry makes servers discoverable

## Quick Start

### For Users (AI Agents / Applications)

```typescript
import { PMCP } from '@pmcp/sdk';

const client = new PMCP({ 
  privateKey: '0x...',
  network: 'base' 
});

// Find a server
const servers = await client.search({ tool: 'stock-price' });

// Call it (handles FHE + payment automatically)
const result = await client.call(servers[0].id, 'stock-price', {
  symbol: 'AAPL'
});

console.log(result); // { price: 150.23, ... }
```

### For Server Operators

```typescript
import { PMCPServer } from '@pmcp/server-sdk';

const server = new PMCPServer({
  privateKey: '0x...',
  pricePerCall: 0.01, // PMCP tokens
  tools: ['stock-price', 'company-info']
});

// Register on-chain
await server.register('https://my-server.com');

// Handle calls (input is FHE ciphertext)
server.onCall('stock-price', async (encryptedInput, ctx) => {
  // Your tool logic operates on ciphertext
  // FHE magic happens here - you never see the actual data
  return encryptedResult;
});

server.start();
```

## Project Structure

```
pmcp/
├── contracts/              # Solidity smart contracts
│   ├── PMCPToken.sol       # ERC20 payment token
│   └── PMCPRegistry.sol    # Server registry + payments
├── packages/
│   ├── sdk/                # @pmcp/sdk - Client library
│   └── server-sdk/         # @pmcp/server-sdk - Server library
├── apps/
│   └── demo-server/        # Example FHE-enabled MCP server
├── scripts/
│   ├── deploy.ts           # Deployment script
│   └── verify.sh           # Contract verification
└── docs/                   # Documentation
```

## Token (PMCP)

**One purpose**: Pay for MCP server calls.

- **Total Supply**: 100,000,000 PMCP (fixed)
- **Chain**: Base
- **Standard**: ERC-20

### Distribution
| Allocation | Percentage | Purpose |
|------------|------------|---------|
| Team | 20% | 2-year vest |
| Early Users | 30% | Airdrops, server rewards |
| Treasury | 30% | Future development |
| Liquidity | 20% | DEX pools |

## Smart Contracts

### PMCPToken
Standard ERC-20 token with fixed supply. No mint function after deployment.

### PMCPRegistry
- `registerServer()` - Register an MCP server with tools and pricing
- `callServer()` - Pay to access a server (tokens held in escrow)
- `withdraw()` - Server operators claim earnings

## FHE (Fully Homomorphic Encryption)

PMCP uses FHE to enable computation on encrypted data:

1. Client encrypts query with server's public key
2. Server receives ciphertext (cannot decrypt)
3. Server executes tool on ciphertext using FHE operations
4. Server returns encrypted result
5. Client decrypts result with their private key

**Server never sees**: query content OR result.

### Supported Operations
- Arithmetic (+, -, *, /)
- Comparisons (<, >, ==)
- Conditionals (if/else on encrypted conditions)
- Lookups (oblivious table access)

### Limitations
- Latency: FHE is slower than plaintext computation
- Complex logic: Heavy branching is expensive
- Data size: Large datasets are computationally intensive

## Development

### Prerequisites
- Node.js 20+
- pnpm 8+
- Foundry (for contracts)

### Setup

```bash
# Clone repo
git clone https://github.com/perrywinkle1/pmcp
cd pmcp

# Install dependencies
pnpm install

# Build packages
pnpm build

# Run tests
pnpm test
```

### Deploy Contracts

```bash
# Set environment variables
export PRIVATE_KEY=0x...
export TEAM_WALLET=0x...
export EARLY_USERS_WALLET=0x...
export TREASURY_WALLET=0x...
export LIQUIDITY_WALLET=0x...

# Deploy to Base Sepolia testnet
npx ts-node scripts/deploy.ts --network base-sepolia
```

### Run Demo Server

```bash
cd apps/demo-server
PRIVATE_KEY=0x... REGISTER=true pnpm dev
```

## Architecture Decisions

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| Chain | Base | Low fees, EVM compatible, Coinbase ecosystem |
| FHE | TFHE/Concrete | Best practical performance for FHE |
| Payments | Simple per-call | No complexity, no staking |
| Governance | None (v1) | Ship simple first |
| Disputes | Punt to v2 | Complexity to add later if needed |

## Roadmap

### Phase 1: MVP (Current)
- [x] Registry contract
- [x] Token contract
- [x] Client SDK
- [x] Server SDK
- [x] Demo server
- [ ] Testnet deployment
- [ ] Basic frontend

### Phase 2: Launch
- [ ] Mainnet deployment
- [ ] Token launch
- [ ] Multiple server implementations
- [ ] SDK improvements

### Phase 3: Growth
- [ ] Server reputation
- [ ] Dispute resolution
- [ ] Additional chains

## License

MIT

## Links

- Website: TBD
- Twitter: TBD
- Discord: TBD
- Docs: TBD
