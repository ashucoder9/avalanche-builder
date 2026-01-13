# Resources

> Essential links and documentation for Avalanche development

---

## Official Documentation

### Core Documentation

| Resource | URL | Description |
|----------|-----|-------------|
| Avalanche Builder Hub | https://build.avax.network | Primary developer documentation |
| Avalanche Docs | https://docs.avax.network | General documentation |
| Avalanche Academy | https://academy.avax.network | Interactive courses |
| AvaCloud Docs | https://developers.avacloud.io | Managed infrastructure docs |

### API References

| Resource | URL |
|----------|-----|
| C-Chain API | https://docs.avax.network/reference/avalanchego/c-chain/api |
| P-Chain API | https://docs.avax.network/reference/avalanchego/p-chain/api |
| X-Chain API | https://docs.avax.network/reference/avalanchego/x-chain/api |
| Admin API | https://docs.avax.network/reference/avalanchego/admin-api |

---

## GitHub Repositories

### Core Infrastructure

| Repository | Description |
|------------|-------------|
| [avalanchego](https://github.com/ava-labs/avalanchego) | Main node implementation |
| [subnet-evm](https://github.com/ava-labs/subnet-evm) | EVM implementation for subnets |
| [avalanche-cli](https://github.com/ava-labs/avalanche-cli) | CLI tool for L1/subnet management |
| [avalanchejs](https://github.com/ava-labs/avalanchejs) | JavaScript/TypeScript SDK |

### Cross-Chain

| Repository | Description |
|------------|-------------|
| [icm-contracts](https://github.com/ava-labs/icm-contracts) | Teleporter and ICM smart contracts |
| [avalanche-interchain-token-transfer](https://github.com/ava-labs/avalanche-interchain-token-transfer) | ICTT bridge contracts |
| [awm-relayer](https://github.com/ava-labs/awm-relayer) | Avalanche Warp Message relayer |

### SDKs & Tools

| Repository | Description |
|------------|-------------|
| [avalanche-sdk-typescript](https://github.com/ava-labs/avalanche-sdk-typescript) | **Modern modular SDK** (recommended) |
| [avalanchejs](https://github.com/ava-labs/avalanchejs) | Legacy JavaScript/TypeScript SDK |
| [avalanche-wallet-sdk](https://github.com/ava-labs/avalanche-wallet-sdk) | Wallet SDK for TypeScript |
| [avacloud-sdk-typescript](https://github.com/ava-labs/avacloud-sdk-typescript) | Glacier/AvaCloud API SDK |
| [avalanche-smart-contract-quickstart](https://github.com/ava-labs/avalanche-smart-contract-quickstart) | Smart contract starter template |
| [hypersdk](https://github.com/ava-labs/hypersdk) | High-performance VM framework |

---

## NPM Packages

### Avalanche SDK (Recommended)

The modern modular SDK for Avalanche development:

```bash
# Core client - RPC, wallets, transactions, P/X/C chain support
npm install @avalanche-sdk/client

# Interchain - ICM messaging and ICTT token transfers
npm install @avalanche-sdk/interchain

# ChainKit - Data APIs, metrics, webhooks (Glacier)
npm install @avalanche-sdk/chainkit
```

> **Note**: Requires Node.js 20+ and TypeScript 5.0+
> GitHub: https://github.com/ava-labs/avalanche-sdk-typescript

### Legacy Packages (Still Supported)

```bash
# AvalancheJS - older but stable
npm install @avalabs/avalanchejs

# Wallet SDK
npm install @avalabs/avalanche-wallet-sdk

# AvaCloud SDK - Glacier API integration
npm install @avalabs/avacloud-sdk
```

### Recommended Dependencies

```bash
# EVM Interaction (works great with Avalanche SDK)
npm install viem wagmi @tanstack/react-query

# Smart Contract Development
npm install @openzeppelin/contracts

# Testing
npm install -D vitest @nomicfoundation/hardhat-toolbox
```

---

## Block Explorers

| Network | Explorer | URL |
|---------|----------|-----|
| C-Chain Mainnet | Snowtrace | https://snowtrace.io |
| C-Chain Fuji | Snowtrace Testnet | https://testnet.snowtrace.io |
| Subnets | Subnet Explorer | https://subnets.avax.network |

---

## RPC Endpoints

### Public RPC (Rate Limited)

| Network | URL |
|---------|-----|
| C-Chain Mainnet | `https://api.avax.network/ext/bc/C/rpc` |
| C-Chain Fuji | `https://api.avax-test.network/ext/bc/C/rpc` |
| P-Chain Mainnet | `https://api.avax.network/ext/bc/P` |
| X-Chain Mainnet | `https://api.avax.network/ext/bc/X` |

### WebSocket Endpoints

| Network | URL |
|---------|-----|
| C-Chain Mainnet | `wss://api.avax.network/ext/bc/C/ws` |
| C-Chain Fuji | `wss://api.avax-test.network/ext/bc/C/ws` |

### Third-Party RPC Providers

| Provider | URL |
|----------|-----|
| Infura | https://infura.io |
| Alchemy | https://alchemy.com |
| QuickNode | https://quicknode.com |
| Chainstack | https://chainstack.com |
| DRPC | https://drpc.org |

---

## Faucets

| Network | Faucet URL |
|---------|------------|
| Fuji Testnet | https://faucet.avax.network |
| Fuji AVAX (Chainlink) | https://faucets.chain.link/fuji |

---

## Contract Addresses

### Mainnet

| Contract | Address |
|----------|---------|
| WAVAX | `0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7` |
| TeleporterMessenger | `0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf` |
| TeleporterRegistry | `0x7C43605E14F391720e1b37E49C78C4b03A488d98` |

### Fuji Testnet

| Contract | Address |
|----------|---------|
| WAVAX | `0xd00ae08403B9bbb9124bB305C09058E32C39A48c` |
| TeleporterMessenger | `0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf` |
| TeleporterRegistry | `0x7C43605E14F391720e1b37E49C78C4b03A488d98` |

---

## Network Information

### Chain IDs

| Network | Chain ID (Decimal) | Chain ID (Hex) |
|---------|-------------------|----------------|
| C-Chain Mainnet | 43114 | 0xA86A |
| C-Chain Fuji | 43113 | 0xA869 |

### Blockchain IDs

| Chain | Blockchain ID |
|-------|---------------|
| C-Chain Mainnet | `2q9e4r6Mu3U68nU1fYjgbR6JvwrRx36CohpAX5UQxse55x1Q5` |
| C-Chain Fuji | `yH8D7ThNJkxmtkuv2jgBa4P1Rn3Qpr4pPr7QYNfcdoS6k6HWp` |

---

## Development Tools

### Smart Contract Development

| Tool | Purpose | URL |
|------|---------|-----|
| Foundry | Fast Solidity toolkit | https://getfoundry.sh |
| Hardhat | Ethereum dev environment | https://hardhat.org |
| Remix | Browser-based IDE | https://remix.ethereum.org |
| OpenZeppelin | Security contracts | https://openzeppelin.com/contracts |

### Frontend Development

| Tool | Purpose | URL |
|------|---------|-----|
| viem | TypeScript Ethereum client | https://viem.sh |
| wagmi | React hooks for Ethereum | https://wagmi.sh |
| RainbowKit | Wallet connection UI | https://rainbowkit.com |

### Testing & Security

| Tool | Purpose | URL |
|------|---------|-----|
| Slither | Static analyzer | https://github.com/crytic/slither |
| Mythril | Security analysis | https://github.com/ConsenSys/mythril |
| Echidna | Fuzzing tool | https://github.com/crytic/echidna |

---

## Learning Resources

### Courses

| Course | URL |
|--------|-----|
| Avalanche Fundamentals | https://academy.avax.network/course/avalanche-fundamentals |
| Interchain Messaging | https://academy.avax.network/course/interchain-messaging |
| Interchain Token Transfer | https://academy.avax.network/course/interchain-token-transfer |
| Customizing the EVM | https://academy.avax.network/course/customizing-evm |

### Tutorials

| Topic | URL |
|-------|-----|
| Deploy Smart Contract | https://build.avax.network/docs/dapps/smart-contracts/deploy-a-smart-contract |
| Create an L1 | https://build.avax.network/docs/tooling/avalanche-cli/create-deploy-subnet |
| Set Up ICM | https://build.avax.network/docs/cross-chain/avalanche-warp-messaging/deep-dive |

---

## Community

### Official Channels

| Channel | URL |
|---------|-----|
| Discord | https://discord.gg/avax |
| Twitter | https://twitter.com/avaborateams |
| Telegram | https://t.me/avalancheavax |
| Forum | https://forum.avax.network |

### Developer Support

| Resource | URL |
|----------|-----|
| Stack Overflow | https://stackoverflow.com/questions/tagged/avalanche |
| GitHub Discussions | https://github.com/ava-labs/avalanchego/discussions |

---

## Grants & Ecosystem

| Program | URL |
|---------|-----|
| Retro9000 | https://www.avax.network/retro9000 |
| Avalanche Foundation | https://www.avalanchefoundation.org |
| Codebase | https://codebase.avax.network |

---

## Useful Commands Reference

### Avalanche CLI

```bash
# L1/Blockchain Management
avalanche blockchain create <name>
avalanche blockchain deploy <name> --local|--fuji|--mainnet
avalanche blockchain describe <name>
avalanche blockchain list

# Network Management
avalanche network start
avalanche network stop
avalanche network status
avalanche network clean

# Key Management
avalanche key create <name>
avalanche key list
avalanche key export <name>

# Interchain
avalanche interchain tokenTransferrer deploy
avalanche interchain signatureAggregator start
```

### Foundry

```bash
# Project Setup
forge init <name>
forge install <dependency>

# Build & Test
forge build
forge test
forge test -vvv
forge coverage

# Deployment
forge script script/Deploy.s.sol --rpc-url <url> --broadcast
forge verify-contract <address> <contract> --chain <chain>

# Utilities
cast call <address> <sig> --rpc-url <url>
cast send <address> <sig> --private-key <key>
cast abi-encode <sig> <args>
```

### AvalancheGo

```bash
# Node Operations
avalanchego --network-id=mainnet
avalanchego --network-id=fuji
avalanchego --config-file=/path/to/config.json

# Health Checks
curl -X POST -H 'content-type:application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"health.health"}' \
  http://localhost:9650/ext/health
```
