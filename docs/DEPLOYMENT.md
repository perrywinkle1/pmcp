# PMCP Contract Deployment Guide

## Prerequisites

1. **Wallet with ETH on Base Sepolia**
   - Get testnet ETH from [Base Sepolia Faucet](https://www.coinbase.com/faucets/base-ethereum-goerli-faucet)
   - You'll need ~0.01 ETH for deployment gas

2. **Node.js & pnpm**
   ```bash
   node --version  # 20+
   pnpm --version  # 8+
   ```

3. **Foundry** (for contract compilation)
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

## Setup

1. **Clone and install**
   ```bash
   git clone https://github.com/perrywinkle1/pmcp
   cd pmcp
   pnpm install
   ```

2. **Install OpenZeppelin contracts**
   ```bash
   cd contracts
   forge install OpenZeppelin/openzeppelin-contracts --no-commit
   ```

3. **Set environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your values:
   # PRIVATE_KEY=0x... (your wallet private key)
   # TEAM_WALLET=0x... (for 20% team allocation)
   # EARLY_USERS_WALLET=0x... (for 30% airdrops)
   # TREASURY_WALLET=0x... (for 30% treasury)
   # LIQUIDITY_WALLET=0x... (for 20% liquidity)
   ```

## Deploy

### Option 1: Using Foundry (Recommended)

```bash
cd contracts

# Compile
forge build

# Deploy PMCPToken first
forge create --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY \
  src/PMCPToken.sol:PMCPToken \
  --constructor-args $TEAM_WALLET $EARLY_USERS_WALLET $TREASURY_WALLET $LIQUIDITY_WALLET

# Note the deployed token address, then deploy PMCPRegistry
forge create --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY \
  src/PMCPRegistry.sol:PMCPRegistry \
  --constructor-args <TOKEN_ADDRESS>
```

### Option 2: Using the deployment script

```bash
# From project root
npx ts-node scripts/deploy.ts --network base-sepolia
```

## Verify Contracts

```bash
# Verify PMCPToken
forge verify-contract \
  --chain-id 84532 \
  --constructor-args $(cast abi-encode "constructor(address,address,address,address)" $TEAM_WALLET $EARLY_USERS_WALLET $TREASURY_WALLET $LIQUIDITY_WALLET) \
  <TOKEN_ADDRESS> \
  src/PMCPToken.sol:PMCPToken \
  --etherscan-api-key $BASESCAN_API_KEY

# Verify PMCPRegistry
forge verify-contract \
  --chain-id 84532 \
  --constructor-args $(cast abi-encode "constructor(address)" <TOKEN_ADDRESS>) \
  <REGISTRY_ADDRESS> \
  src/PMCPRegistry.sol:PMCPRegistry \
  --etherscan-api-key $BASESCAN_API_KEY
```

## After Deployment

1. **Update SDK config** - Add contract addresses to `packages/sdk/src/index.ts`:
   ```typescript
   const NETWORKS = {
     'base-sepolia': {
       rpc: 'https://sepolia.base.org',
       registry: '<REGISTRY_ADDRESS>',
       token: '<TOKEN_ADDRESS>',
     },
     // ...
   };
   ```

2. **Transfer tokens for testing**
   - Send some PMCP tokens to test wallets
   - Approve Registry contract to spend tokens

3. **Register a test server**
   ```typescript
   import { PMCPServer } from '@pmcp/server-sdk';
   
   const server = new PMCPServer({
     privateKey: '0x...',
     network: 'base-sepolia',
     pricePerCall: '0.01',
     tools: ['test-tool'],
     registryAddress: '<REGISTRY_ADDRESS>',
     tokenAddress: '<TOKEN_ADDRESS>',
   });
   
   await server.register('https://your-server.com');
   ```

## Contract Addresses

After deployment, update this section:

| Contract | Base Sepolia | Base Mainnet |
|----------|--------------|--------------|
| PMCPToken | TBD | TBD |
| PMCPRegistry | TBD | TBD |

## Troubleshooting

**"Insufficient funds"**
- Get more testnet ETH from the faucet

**"Contract verification failed"**
- Ensure constructor args match exactly
- Wait a few minutes after deployment before verifying

**"Nonce too low"**
- Reset your nonce or wait for pending txs to confirm
