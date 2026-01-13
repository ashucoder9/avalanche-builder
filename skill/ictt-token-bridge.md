# Interchain Token Transfer (ICTT)

> Deploy trustless token bridges between Avalanche L1s

---

## Goals

1. Understand ICTT architecture (TokenHome/TokenRemote)
2. Deploy ERC-20 token bridges
3. Bridge native tokens between chains
4. Implement multi-hop transfers

---

## Overview

ICTT enables token transfers between Avalanche L1s without trusted intermediaries:

- **TokenHome**: Locks tokens on the source chain
- **TokenRemote**: Mints/burns wrapped tokens on destination chains
- **ICM**: Handles cross-chain message delivery

```
┌──────────────────────┐                    ┌──────────────────────┐
│    Source Chain      │                    │  Destination Chain   │
│                      │                    │                      │
│  ┌────────────────┐  │                    │  ┌────────────────┐  │
│  │   ERC-20       │  │                    │  │ Wrapped ERC-20 │  │
│  │   Token        │  │                    │  │    Token       │  │
│  └───────┬────────┘  │                    │  └───────▲────────┘  │
│          │           │                    │          │           │
│  ┌───────▼────────┐  │    Teleporter      │  ┌───────┴────────┐  │
│  │   TokenHome    │  │ =================> │  │  TokenRemote   │  │
│  │  (locks tokens)│  │                    │  │ (mints tokens) │  │
│  └────────────────┘  │                    │  └────────────────┘  │
└──────────────────────┘                    └──────────────────────┘
```

---

## Contract Types

### ERC-20 Bridges

| Contract | Purpose |
|----------|---------|
| `ERC20TokenHome` | Lock ERC-20 tokens on home chain |
| `ERC20TokenRemote` | Mint/burn wrapped tokens on remote chains |

### Native Token Bridges

| Contract | Purpose |
|----------|---------|
| `NativeTokenHome` | Lock native tokens (AVAX) on home chain |
| `NativeTokenRemote` | Mint wrapped native as ERC-20 on remote |
| `ERC20TokenHomeNative` | Use ERC-20 as native token on L1 |

---

## Deploying an ERC-20 Bridge

> **CRITICAL: ICTT Bridge Deployment is IRREVERSIBLE**
>
> ICTT contracts are **non-upgradeable**. Once deployed:
> - Contract behavior cannot be changed
> - Bugs require deploying entirely new bridge
> - Liquidity must be migrated manually
>
> **Pre-Deployment Checklist:**
> - [ ] **TEST ON FUJI FIRST** - Deploy full bridge (Home + Remote) on testnet
> - [ ] **VERIFY TOKEN ADDRESS** - Confirm the ERC-20 token address is correct
> - [ ] **VERIFY BLOCKCHAIN IDs** - Use blockchain ID, NOT chain ID
> - [ ] **TEST TRANSFERS BOTH WAYS** - Send tokens Home→Remote and Remote→Home on testnet
> - [ ] **VERIFY TELEPORTER ADDRESSES** - Ensure TeleporterRegistry matches the chain
> - [ ] **BACKUP DEPLOYER KEY** - Store securely, you'll need it for registration

### Step 1: Deploy TokenHome on Source Chain

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@icm-contracts/ictt/TokenHome/ERC20TokenHome.sol";

contract MyTokenHome is ERC20TokenHome {
    constructor(
        address teleporterRegistryAddress,
        address teleporterManager,
        address wrappedToken,
        uint8 tokenDecimals
    ) ERC20TokenHome(
        teleporterRegistryAddress,
        teleporterManager,
        wrappedToken,
        tokenDecimals
    ) {}
}
```

### Deployment Script

```solidity
// script/DeployTokenHome.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@icm-contracts/ictt/TokenHome/ERC20TokenHome.sol";

contract DeployTokenHome is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        address teleporterRegistry = 0x7C43605E14F391720e1b37E49C78C4b03A488d98;
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        uint8 tokenDecimals = 18;

        vm.startBroadcast(deployerKey);

        ERC20TokenHome tokenHome = new ERC20TokenHome(
            teleporterRegistry,
            msg.sender,  // teleporterManager
            tokenAddress,
            tokenDecimals
        );

        console.log("TokenHome deployed at:", address(tokenHome));

        vm.stopBroadcast();
    }
}
```

### Step 2: Deploy TokenRemote on Destination Chain

```solidity
// script/DeployTokenRemote.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@icm-contracts/ictt/TokenRemote/ERC20TokenRemote.sol";

contract DeployTokenRemote is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        address teleporterRegistry = 0x7C43605E14F391720e1b37E49C78C4b03A488d98;
        bytes32 homeBlockchainID = vm.envBytes32("HOME_BLOCKCHAIN_ID");
        address tokenHomeAddress = vm.envAddress("TOKEN_HOME_ADDRESS");

        TokenRemoteSettings memory settings = TokenRemoteSettings({
            teleporterRegistryAddress: teleporterRegistry,
            teleporterManager: msg.sender,
            tokenHomeBlockchainID: homeBlockchainID,
            tokenHomeAddress: tokenHomeAddress,
            tokenHomeDecimals: 18
        });

        vm.startBroadcast(deployerKey);

        ERC20TokenRemote tokenRemote = new ERC20TokenRemote(
            settings,
            "Wrapped MyToken",    // name
            "wMYT",               // symbol
            18                    // decimals
        );

        console.log("TokenRemote deployed at:", address(tokenRemote));

        vm.stopBroadcast();
    }
}
```

### Step 3: Register Remote with Home

```solidity
// After deploying TokenRemote, register it with TokenHome
function registerRemote(
    ERC20TokenHome tokenHome,
    bytes32 remoteBlockchainID,
    address tokenRemoteAddress
) external {
    RemoteTokenTransferrerSettings memory remoteSettings = RemoteTokenTransferrerSettings({
        blockchainID: remoteBlockchainID,
        tokenTransferrerAddress: tokenRemoteAddress
    });

    tokenHome.registerRemoteTokenTransferrer(remoteSettings);
}
```

---

## Transferring Tokens

### Send Tokens to Remote Chain

```solidity
import "@icm-contracts/ictt/interfaces/IERC20TokenTransferrer.sol";

function bridgeTokens(
    IERC20TokenTransferrer tokenHome,
    address token,
    bytes32 destinationBlockchainID,
    address destinationAddress,
    uint256 amount
) external {
    // Approve TokenHome to spend tokens
    IERC20(token).approve(address(tokenHome), amount);

    // Prepare transfer input
    SendTokensInput memory input = SendTokensInput({
        destinationBlockchainID: destinationBlockchainID,
        destinationTokenTransferrerAddress: tokenRemoteAddress,
        recipient: destinationAddress,
        primaryFeeTokenAddress: address(0),
        primaryFee: 0,
        secondaryFee: 0,
        requiredGasLimit: 250000,
        multiHopFallback: address(0)
    });

    // Send tokens
    tokenHome.send(input, amount);
}
```

### Receive Tokens (Automatic)

When tokens are sent from TokenHome, the TokenRemote contract automatically:
1. Receives the Teleporter message
2. Mints wrapped tokens to the recipient
3. Emits transfer events

### Return Tokens to Home Chain

```solidity
function returnTokens(
    IERC20TokenTransferrer tokenRemote,
    bytes32 homeBlockchainID,
    address recipient,
    uint256 amount
) external {
    // No approval needed - TokenRemote burns tokens directly

    SendTokensInput memory input = SendTokensInput({
        destinationBlockchainID: homeBlockchainID,
        destinationTokenTransferrerAddress: tokenHomeAddress,
        recipient: recipient,
        primaryFeeTokenAddress: address(0),
        primaryFee: 0,
        secondaryFee: 0,
        requiredGasLimit: 250000,
        multiHopFallback: address(0)
    });

    tokenRemote.send(input, amount);
}
```

---

## Native Token Bridging

### Bridge Native AVAX to an L1

```solidity
// Deploy NativeTokenHome on C-Chain
NativeTokenHome nativeHome = new NativeTokenHome(
    teleporterRegistry,
    msg.sender,
    address(wavax)  // Wrapped AVAX address
);

// Deploy ERC20TokenRemote on your L1
ERC20TokenRemote wrappedAvax = new ERC20TokenRemote(
    settings,
    "Wrapped AVAX",
    "WAVAX",
    18
);
```

### Use L1 Native Token on C-Chain

```solidity
// Deploy ERC20TokenHome on your L1 (for native token)
ERC20TokenHomeNative tokenHome = new ERC20TokenHomeNative(
    teleporterRegistry,
    msg.sender,
    18  // decimals of native token
);

// Deploy NativeTokenRemote on C-Chain
NativeTokenRemote tokenRemote = new NativeTokenRemote(
    settings,
    "L1 Native Token",
    "L1T",
    18,
    0,    // initialReserveImbalance
    false // multiplyOnRemote
);
```

---

## Multi-Hop Transfers

### Transfer Between Two L1s Through C-Chain

```
L1-A  →  C-Chain (Home)  →  L1-B
     lock              unlock & lock → mint
```

```solidity
function multiHopTransfer(
    IERC20TokenTransferrer tokenRemoteA,
    bytes32 cChainID,
    bytes32 l1bChainID,
    address recipient,
    uint256 amount
) external {
    SendTokensInput memory input = SendTokensInput({
        destinationBlockchainID: l1bChainID,  // Final destination
        destinationTokenTransferrerAddress: tokenRemoteBAddress,
        recipient: recipient,
        primaryFeeTokenAddress: address(0),
        primaryFee: 0,
        secondaryFee: 0,
        requiredGasLimit: 350000,  // Higher for multi-hop
        multiHopFallback: msg.sender  // Receive on C-Chain if L1-B fails
    });

    tokenRemoteA.send(input, amount);
}
```

---

## TypeScript SDK Usage

### Installation

```bash
npm install @avalanche-sdk/interchain @avalanche-sdk/client viem
```

### SDK Overview

The `@avalanche-sdk/interchain` package provides ICTT functionality:
- Deploy TokenHome and TokenRemote contracts
- Transfer tokens between chains
- Monitor transfer status

### Deploy ICTT Bridge

```typescript
import { createICTTClient } from '@avalanche-sdk/interchain'
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { avalanche } from 'viem/chains'

const account = privateKeyToAccount(process.env.PRIVATE_KEY as `0x${string}`)

const walletClient = createWalletClient({
  account,
  chain: avalanche,
  transport: http(),
})

// Create ICTT client
const icttClient = createICTTClient({
  sourceChain: {
    chainId: 43114,
    rpcUrl: 'https://api.avax.network/ext/bc/C/rpc',
    teleporterRegistry: '0x7C43605E14F391720e1b37E49C78C4b03A488d98',
  },
  walletClient,
})

// Deploy TokenHome on source chain
const { address: tokenHomeAddress, txHash } = await icttClient.deployERC20TokenHome({
  tokenAddress: '0x...',  // ERC-20 token to bridge
})

console.log('TokenHome deployed:', tokenHomeAddress)

// Deploy TokenRemote on destination chain
const { address: tokenRemoteAddress } = await icttClient.deployERC20TokenRemote({
  tokenHomeBlockchainID: sourceBlockchainID,
  tokenHomeAddress,
  name: 'Wrapped Token',
  symbol: 'wTKN',
  decimals: 18,
})

console.log('TokenRemote deployed:', tokenRemoteAddress)

// Register remote with home
await icttClient.registerRemote({
  tokenHomeAddress,
  remoteBlockchainID,
  tokenRemoteAddress,
})
```

### Transfer Tokens

```typescript
import { parseEther } from 'viem'

// Bridge tokens to L1
const result = await icttClient.sendTokens({
  tokenHomeAddress: '0x...',
  destinationBlockchainID: '...',
  destinationAddress: '0x...',
  amount: parseEther('100'),
})

console.log('Transfer initiated:', result.txHash)
console.log('Message ID:', result.messageId)

// Monitor transfer status
const status = await icttClient.getTransferStatus(result.messageId)

switch (status) {
  case 'pending':
    console.log('Waiting for relayer...')
    break
  case 'delivered':
    console.log('Tokens bridged successfully!')
    break
  case 'failed':
    console.log('Transfer failed')
    break
}
```

---

## Using Avalanche CLI

### Quick Bridge Deployment

```bash
# Deploy ICTT between C-Chain and your L1
avalanche interchain tokenTransferrer deploy

# Follow the wizard to:
# 1. Select source chain
# 2. Select destination chain
# 3. Choose token to bridge
# 4. Deploy contracts
```

### Register with Core Bridge

Bridges deployed through AvaCloud automatically integrate with Core Bridge UI.

---

## Frontend: BuilderKit Components

For building bridge UIs, use [BuilderKit](https://github.com/ava-labs/builders-hub/tree/main/content/docs/builderkit) - ready-made React components for ICTT bridges.

### Available Components

BuilderKit provides production-ready components for:
- **Bridge Interface** - Token selection, amount input, chain selectors
- **Transfer Status** - Progress tracking, transaction confirmations
- **Token Balances** - Display balances across chains
- **Network Switcher** - Chain selection dropdowns

### Quick Start

```bash
# Clone BuilderKit components
git clone https://github.com/ava-labs/builders-hub.git
cd builders-hub/content/docs/builderkit

# Copy components to your project
cp -r components/ your-project/src/components/builderkit/
```

### Example: Bridge Component

```tsx
// Use BuilderKit's bridge component as starting point
import { BridgeInterface } from '@/components/builderkit/bridge'

export function TokenBridge() {
  return (
    <BridgeInterface
      sourceChain={sourceChainConfig}
      destinationChain={destChainConfig}
      tokenHomeAddress={tokenHome}
      tokenRemoteAddress={tokenRemote}
      onTransferComplete={(txHash) => console.log('Bridged:', txHash)}
    />
  )
}
```

Using BuilderKit saves significant development time compared to building bridge UIs from scratch.

---

## Security Considerations

### Collateralization

TokenHome always maintains 1:1 collateral for all minted remote tokens:

```
TokenHome locked: 1000 tokens
TokenRemote-A minted: 400 tokens
TokenRemote-B minted: 600 tokens
Total remote: 1000 tokens (matches locked)
```

### Trust Model

ICTT does NOT rely on:
- Multisigs
- Central operators
- Third-party bridges

Instead, security comes from:
- Avalanche Warp Messaging (validator signatures)
- Source chain validator set

### Contract Immutability

ICTT contracts are **non-upgradeable**:
- Behavior cannot change after deployment
- Deploy new bridge for upgrades
- Migrate liquidity if needed

---

## Best Practices

### Deployment Safety

> **Mainnet Deployment Order:**
> 1. Deploy and test **complete bridge on Fuji** first
> 2. Transfer tokens both directions on Fuji
> 3. Wait 24+ hours, verify no issues
> 4. **Only then** deploy to mainnet

**Deployment Checklist:**
- [ ] Fuji TokenHome deployed and verified
- [ ] Fuji TokenRemote deployed and verified
- [ ] Remote registered with Home on Fuji
- [ ] Test transfer Home → Remote successful
- [ ] Test transfer Remote → Home successful
- [ ] Multi-hop tested (if applicable)
- [ ] All contract addresses documented
- [ ] Deployer keys backed up securely

### Deployment
1. Test on Fuji before mainnet
2. Verify all contracts on block explorer
3. Document blockchain IDs and addresses
4. Set appropriate gas limits

### Operations
1. Monitor bridge balances
2. Track successful/failed transfers
3. Handle multi-hop fallbacks
4. Keep relayers running

### Fee Management
1. Set reasonable relayer fees
2. Consider gas costs on both chains
3. Allow fee tokens for gasless UX

---

## Contract Addresses

### Fuji Testnet

Use TeleporterRegistry at `0x7C43605E14F391720e1b37E49C78C4b03A488d98`

### Mainnet

Use TeleporterRegistry at `0x7C43605E14F391720e1b37E49C78C4b03A488d98`

---

## Troubleshooting

### Common Issues from GitHub

#### Transfer Pending Forever

**Symptoms**: Tokens locked on home chain but never minted on remote.

**Diagnostic Steps**:
```bash
# 1. Check relayer status
curl http://localhost:8080/health

# 2. Verify destination chain synced
curl -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.isBootstrapped","params":{"chain":"C"}}' \
    -H 'content-type:application/json' http://DEST_RPC:9650/ext/info

# 3. Check Teleporter message status
# Look for SendCrossChainMessage event on source chain
```

**Solutions**:
| Cause | Solution |
|-------|----------|
| Relayer not running | Start AWM relayer |
| Destination not synced | Wait for bootstrap |
| Gas limit too low | Increase `requiredGasLimit` |
| Wrong blockchain ID | Verify IDs match deployed contracts |

#### Message Rejected - Validator Set Changes (GitHub #735)

**Problem**: ICM message rejected due to insufficient signing stake after validator set changed.

**Cause**: Source chain's validator set changed between message send and delivery. Destination chain requires 67% stake signature but message was signed by old validator set.

**Solution**:
```solidity
// Re-send the message to get new validator signatures
tokenHome.retrySendCrossChainMessage(
    destinationBlockchainID,
    originalMessage
);
```

#### Fee Token Bypass (GitHub #706)

**Problem**: Users could bypass fee mechanisms using low-value tokens.

**Status**: Fixed in January 2025.

**Prevention**: Always use the latest ICTT contract versions which include this fix.

#### Gas Limit Conflicts with Legacy Tokens (GitHub #722)

**Problem**: `NativeTokenHome` incompatible with some legacy wrapped token contracts.

**Symptoms**: Transfers fail with out-of-gas even with high gas limits.

**Solution**:
- Use latest contract versions (fixed February 2025)
- If using legacy tokens, test thoroughly on testnet first

#### Insufficient Collateral

**Problem**: Transfer fails with "insufficient collateral" error.

**Cause**: TokenHome doesn't have enough locked tokens to cover the transfer.

**Check Collateral**:
```solidity
// Check locked balance on TokenHome
uint256 locked = tokenHome.totalLocked();
uint256 totalRemote = tokenHome.totalRemoteMinted();

// locked should always >= totalRemote
```

**Solutions**:
- Ensure tokens are approved and transferred to TokenHome
- Check no accounting mismatch from failed transfers

#### Registration Failed

**Problem**: `registerRemoteTokenTransferrer` fails.

**Checklist**:
```solidity
// 1. TokenRemote must be deployed BEFORE registration
require(tokenRemote.code.length > 0, "Remote not deployed");

// 2. Caller must have manager role
require(tokenHome.teleporterManager() == msg.sender, "Not manager");

// 3. Blockchain ID must be correct (not chain ID!)
// Use info.getBlockchainID RPC call, not the numeric chain ID

// 4. Cannot register same remote twice
```

#### sendAndCall Failures

**Problem**: Token transfer succeeds but contract call on destination fails.

**Behavior**: Tokens are sent to `multiHopFallback` address instead of executing the call.

**Solution**: Always set a valid `multiHopFallback` address:
```solidity
SendTokensInput({
    // ...
    multiHopFallback: msg.sender,  // Tokens go here if call fails
    // ...
})
```

**Debug the failing call**:
```solidity
// Test the recipient contract separately
// Common issues:
// 1. Insufficient gas for recipient logic
// 2. Recipient contract reverts
// 3. Wrong function selector in payload
```

#### Multi-Hop Transfer Fails

**Problem**: Transfer between two L1s through C-Chain fails.

**Path**: L1-A → C-Chain (Home) → L1-B

**Common Issues**:
| Issue | Solution |
|-------|----------|
| Wrong destination ID | Use L1-B's blockchain ID, not C-Chain's |
| Insufficient gas | Multi-hop needs ~350k+ gas |
| Fallback not set | Set `multiHopFallback` for recovery |
| Middle hop fails | Check C-Chain relayer is running |

### Error Reference

| Error | Cause | Solution |
|-------|-------|----------|
| `Insufficient collateral` | TokenHome lacks locked tokens | Check approvals and balances |
| `Remote not registered` | TokenRemote not registered with Home | Call `registerRemoteTokenTransferrer` |
| `Invalid blockchain ID` | Wrong ID format | Use blockchain ID, not chain ID |
| `Transfer already processed` | Duplicate relay attempt | Message already delivered |
| `Unauthorized caller` | Not Teleporter or not manager | Check permissions |
| `Amount exceeds locked` | Trying to unlock more than locked | Check `totalLocked()` |

### Debugging Token Transfers

```typescript
import { parseAbiItem, createPublicClient, http } from 'viem'

// Track token transfer through the system
async function debugTransfer(txHash: string) {
  const client = createPublicClient({ transport: http(SOURCE_RPC) })

  // 1. Get the transaction receipt
  const receipt = await client.getTransactionReceipt({ hash: txHash })

  // 2. Find TokensLocked event on TokenHome
  const lockedLogs = await client.getLogs({
    address: TOKEN_HOME_ADDRESS,
    event: parseAbiItem('event TokensLocked(bytes32 indexed teleporterMessageID, address indexed sender, uint256 amount)'),
    fromBlock: receipt.blockNumber,
    toBlock: receipt.blockNumber
  })

  console.log('Tokens locked:', lockedLogs)

  // 3. Check Teleporter message on destination
  const destClient = createPublicClient({ transport: http(DEST_RPC) })

  // 4. Look for TokensMinted on TokenRemote
  const mintedLogs = await destClient.getLogs({
    address: TOKEN_REMOTE_ADDRESS,
    event: parseAbiItem('event TokensMinted(bytes32 indexed teleporterMessageID, address indexed recipient, uint256 amount)'),
    fromBlock: 'earliest',
    toBlock: 'latest'
  })

  console.log('Tokens minted:', mintedLogs)
}
```

### Contract Immutability Note

ICTT contracts are **non-upgradeable**:
- Behavior cannot change after deployment
- To fix issues, deploy new bridge contracts
- Migrate liquidity from old to new contracts if needed
- Always test thoroughly on Fuji before mainnet
