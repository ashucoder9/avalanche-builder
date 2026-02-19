# Avalanche Developer Skill

> **Playbook**: Jan 2026 · Avalanche ecosystem best practices
> **Focus**: C-Chain dApps, L1 creation, ICM, ICTT bridges, Core Wallet, node operations

---

## Purpose & Scope

This skill applies when the task involves:

| Layer | Examples |
|-------|----------|
| **C-Chain dApp UI** | React/Next.js frontends, wallet connections, transaction flows |
| **Smart Contracts** | Solidity development, Hardhat/Foundry tooling, contract deployment |
| **Avalanche L1s** | Subnet creation, custom VMs, validator management, chain configuration |
| **Interchain Messaging (ICM)** | Cross-chain communication, Teleporter contracts, message relaying |
| **Token Bridges (ICTT)** | TokenHome/TokenRemote deployment, ERC-20 bridging, multi-hop transfers |
| **Node Operations** | AvalancheGo setup, validator staking, network upgrades |
| **Wallet Integration** | Core Wallet SDK, MetaMask, WalletConnect configuration |

---

## Default Stack Decisions

| Concern | Default | Rationale |
|---------|---------|-----------|
| **Client Library** | `viem` + `@avalanche-sdk/client` | Type-safe, modern, full Avalanche support |
| **Frontend Framework** | Next.js 14+ with App Router | SSR support, React Server Components |
| **Wallet Connection** | `wagmi` + Core Wallet | Best UX for Avalanche ecosystem |
| **Smart Contract Dev** | Foundry (preferred) or Hardhat | Fast compilation, better testing |
| **L1/Subnet Management** | Avalanche CLI | Official tooling, streamlined workflow |
| **Cross-chain** | `@avalanche-sdk/interchain` | Native ICM/ICTT support |

---

## Network Configuration

### C-Chain Networks

```typescript
// Mainnet
const avalancheMainnet = {
  id: 43114,
  name: 'Avalanche',
  rpcUrl: 'https://api.avax.network/ext/bc/C/rpc',
  blockExplorer: 'https://snowtrace.io',
  nativeCurrency: { name: 'AVAX', symbol: 'AVAX', decimals: 18 }
}

// Fuji Testnet
const avalancheFuji = {
  id: 43113,
  name: 'Avalanche Fuji',
  rpcUrl: 'https://api.avax-test.network/ext/bc/C/rpc',
  blockExplorer: 'https://testnet.snowtrace.io',
  nativeCurrency: { name: 'AVAX', symbol: 'AVAX', decimals: 18 }
}
```

### Primary Network Chains

| Chain | Purpose | Consensus |
|-------|---------|-----------|
| **C-Chain** | Smart contracts (EVM) | Snowman |
| **P-Chain** | Platform operations, staking, L1 management | Snowman |
| **X-Chain** | Asset transfers (UTXO model) | Avalanche |

---

## Operating Procedure

When approaching an Avalanche development task:

### 1. Classify the Layer
- **Smart Contracts**: Write Solidity, deploy contracts → see `smart-contracts.md`
- **Frontend/dApp**: Use viem, wagmi, Core Wallet → see `c-chain-development.md`
- **L1/Subnet**: Use Avalanche CLI → see `l1-setup.md`
- **Cross-chain messaging**: Use ICM contracts → see `icm-interchain-messaging.md`
- **Token bridging**: Use ICTT → see `ictt-token-bridge.md`
- **Node setup**: Use AvalancheGo → see `node-operations.md`
- **Security review**: Audit prep, vulnerabilities → see `security.md`

### 2. Select Building Blocks
```
dApp Frontend       → viem + wagmi + Core Wallet
Smart Contracts     → Foundry + OpenZeppelin
L1 Creation         → avalanche blockchain create
Cross-chain Calls   → TeleporterMessenger
Token Bridges       → TokenHome + TokenRemote
Node Operations     → AvalancheGo + avalanche-cli
```

### 3. Implement with Correctness
- Use TypeScript for type safety
- Follow Avalanche contract patterns from `icm-contracts`
- Test on Fuji before mainnet deployment
- Verify contracts on Snowtrace

### 4. Add Tests
- Unit tests with Foundry's `forge test`
- Integration tests on local Avalanche network
- E2E tests for cross-chain flows

---

## Quick Start Commands

### Project Initialization

```bash
# Install Avalanche CLI
curl -sSfL https://raw.githubusercontent.com/ava-labs/avalanche-cli/main/scripts/install.sh | sh -s

# Create a new L1 blockchain
avalanche blockchain create myblockchain

# Deploy to local network
avalanche blockchain deploy myblockchain --local

# Initialize Foundry project for C-Chain
forge init my-avalanche-dapp
cd my-avalanche-dapp

# Add OpenZeppelin contracts
forge install OpenZeppelin/openzeppelin-contracts

# Add ICM contracts for cross-chain
forge install ava-labs/icm-contracts
```

### Frontend Setup

```bash
# Create Next.js app with Avalanche template
npx create-next-app@latest my-avax-dapp --typescript

# Install dependencies
npm install viem wagmi @tanstack/react-query
npm install @avalanche-sdk/client      # Avalanche SDK for RPC/wallets
npm install @avalanche-sdk/interchain  # For cross-chain features (ICM/ICTT)
npm install @avalanche-sdk/chainkit    # For data/metrics APIs (optional)
```

---

## Deliverables Expectations

When completing tasks, provide:

1. **File diffs** with clear before/after
2. **Build/test commands** that verify the implementation
3. **Risk notes** for:
   - Transaction signing flows
   - Gas/fee considerations
   - Cross-chain timing and finality
   - Validator requirements for L1s

---

## Progressive Disclosure

Load specialized modules based on task requirements:

| Module | Load When |
|--------|-----------|
| [`smart-contracts.md`](./smart-contracts.md) | Writing Solidity contracts, ERC-20, NFTs, DeFi patterns |
| [`c-chain-development.md`](./c-chain-development.md) | Building dApps, frontend integration, wallet connection |
| [`l1-setup.md`](./l1-setup.md) | Creating/configuring Avalanche L1s (subnets) |
| [`icm-interchain-messaging.md`](./icm-interchain-messaging.md) | Cross-chain communication, Teleporter |
| [`ictt-token-bridge.md`](./ictt-token-bridge.md) | Token bridging, ICTT deployment |
| [`core-wallet.md`](./core-wallet.md) | Core Wallet SDK integration |
| [`node-operations.md`](./node-operations.md) | Running nodes, validator setup |
| [`testing-security.md`](./testing-security.md) | Testing patterns, Foundry tests |
| [`security.md`](./security.md) | Security vulnerabilities, audit preparation |
| [`resources.md`](./resources.md) | Reference documentation links |
| [`l1-troubleshooting-metados.md`](./l1-troubleshooting-metados.md) | L1 stuck after subnet-to-L1 conversion, validator issues, warp timestamp, ProposerVM |
| [`metados-mainnet-fix.md`](./metados-mainnet-fix.md) | Step-by-step mainnet config fix scripts (warp + proposerVM + restart) |

---

## Key Ecosystem Contracts

### ICM Contracts (Cross-chain)
```
TeleporterMessenger    - Core cross-chain messaging
TeleporterRegistry     - Version management for Teleporter
WarpMessenger          - Low-level Avalanche Warp Messaging
```

### ICTT Contracts (Token Transfer)
```
TokenHome              - Lock tokens on source chain
TokenRemote            - Mint/burn on destination chain
ERC20TokenHome         - ERC-20 specific home contract
ERC20TokenRemote       - ERC-20 specific remote contract
NativeTokenHome        - Native token bridging
NativeTokenRemote      - Native token on remote chain
```

### Common Precompiles (C-Chain & L1s)
```
0x0200000000000000000000000000000000000005  - Warp Precompile
0x0300000000000000000000000000000000000000  - Contract Deployer Allow List
0x0300000000000000000000000000000000000001  - Transaction Allow List
0x0300000000000000000000000000000000000002  - Native Minter
0x0300000000000000000000000000000000000003  - Fee Config Manager
```

---

## Common Patterns

### Connecting to Avalanche with viem

```typescript
import { createPublicClient, createWalletClient, http } from 'viem'
import { avalanche, avalancheFuji } from 'viem/chains'

const publicClient = createPublicClient({
  chain: avalanche,
  transport: http()
})

const walletClient = createWalletClient({
  chain: avalanche,
  transport: http()
})
```

### Reading Contract State

```typescript
const balance = await publicClient.readContract({
  address: '0x...',
  abi: erc20Abi,
  functionName: 'balanceOf',
  args: ['0x...']
})
```

### Sending Transactions

```typescript
import { parseEther } from 'viem'

const hash = await walletClient.sendTransaction({
  account,
  to: '0x...',
  value: parseEther('1')
})

const receipt = await publicClient.waitForTransactionReceipt({ hash })
```

---

## Environment Variables

```bash
# .env.local
NEXT_PUBLIC_AVALANCHE_RPC_URL=https://api.avax.network/ext/bc/C/rpc
NEXT_PUBLIC_FUJI_RPC_URL=https://api.avax-test.network/ext/bc/C/rpc
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_project_id
PRIVATE_KEY=your_private_key  # Never commit this!
SNOWTRACE_API_KEY=your_snowtrace_api_key
```
