# Interchain Messaging (ICM)

> Build cross-chain dApps using Avalanche's native interchain messaging protocol

---

## Goals

1. Understand ICM architecture and message flow
2. Deploy TeleporterMessenger contracts
3. Send and receive cross-chain messages
4. Build cross-chain dApps with proper error handling

---

## Overview

Avalanche Interchain Messaging (ICM) enables native cross-L1 communication using:

- **Avalanche Warp Messaging (AWM)**: Low-level BLS signature-based messaging
- **Teleporter**: High-level protocol built on AWM for EVM chains
- **TeleporterMessenger**: Smart contract interface for sending/receiving messages

```
┌─────────────────┐                    ┌─────────────────┐
│   Source L1     │                    │ Destination L1  │
│                 │                    │                 │
│ ┌─────────────┐ │    AWM + Relayer   │ ┌─────────────┐ │
│ │  Your dApp  │ │ =================> │ │  Your dApp  │ │
│ └──────┬──────┘ │                    │ └──────▲──────┘ │
│        │        │                    │        │        │
│ ┌──────▼──────┐ │                    │ ┌──────┴──────┐ │
│ │ Teleporter  │ │                    │ │ Teleporter  │ │
│ │  Messenger  │ │                    │ │  Messenger  │ │
│ └─────────────┘ │                    │ └─────────────┘ │
└─────────────────┘                    └─────────────────┘
```

---

## Key Contracts

### TeleporterMessenger

Main contract for cross-chain messaging:

```solidity
interface ITeleporterMessenger {
    function sendCrossChainMessage(
        TeleporterMessageInput calldata messageInput
    ) external returns (bytes32 messageID);

    function receiveCrossChainMessage(
        uint32 messageIndex,
        address relayerRewardAddress
    ) external;

    function retryMessageExecution(
        bytes32 sourceBlockchainID,
        TeleporterMessage calldata message,
        address relayerRewardAddress
    ) external;
}
```

### TeleporterRegistry

Manages Teleporter versions:

```solidity
interface ITeleporterRegistry {
    function getLatestTeleporter() external view returns (ITeleporterMessenger);
    function getTeleporterFromVersion(uint256 version) external view returns (ITeleporterMessenger);
    function latestVersion() external view returns (uint256);
}
```

---

## Sending Cross-Chain Messages

> **IMPORTANT: Cross-Chain Contract Deployment**
>
> ICM contracts deployed on-chain are **permanent**. Before deploying cross-chain messaging contracts:
>
> **Pre-Deployment Checklist:**
> - [ ] **TEST ON FUJI FIRST** - Deploy sender AND receiver on testnet
> - [ ] **VERIFY BLOCKCHAIN IDs** - Use `info.getBlockchainID`, NOT chain ID
> - [ ] **TEST MESSAGE FLOW** - Send test messages before mainnet
> - [ ] **VERIFY TELEPORTER ADDRESSES** - Confirm TeleporterRegistry address matches
> - [ ] **TEST GAS LIMITS** - Ensure `requiredGasLimit` is sufficient
> - [ ] **RUN RELAYER** - Verify AWM relayer is operational
> - [ ] **BACKUP KEYS** - Store deployer keys securely

### Basic Message Structure

```solidity
struct TeleporterMessageInput {
    bytes32 destinationBlockchainID;
    address destinationAddress;
    TeleporterFeeInfo feeInfo;
    uint256 requiredGasLimit;
    address[] allowedRelayerAddresses;
    bytes message;
}

struct TeleporterFeeInfo {
    address feeTokenAddress;
    uint256 amount;
}
```

### Simple Message Sender

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@teleporter/ITeleporterMessenger.sol";
import "@teleporter/ITeleporterRegistry.sol";

contract CrossChainSender {
    ITeleporterRegistry public immutable teleporterRegistry;
    bytes32 public destinationBlockchainID;
    address public destinationContract;

    constructor(
        address _teleporterRegistry,
        bytes32 _destinationBlockchainID,
        address _destinationContract
    ) {
        teleporterRegistry = ITeleporterRegistry(_teleporterRegistry);
        destinationBlockchainID = _destinationBlockchainID;
        destinationContract = _destinationContract;
    }

    function sendMessage(string calldata message) external {
        ITeleporterMessenger teleporter = teleporterRegistry.getLatestTeleporter();

        teleporter.sendCrossChainMessage(
            TeleporterMessageInput({
                destinationBlockchainID: destinationBlockchainID,
                destinationAddress: destinationContract,
                feeInfo: TeleporterFeeInfo({
                    feeTokenAddress: address(0),  // No fee for basic messages
                    amount: 0
                }),
                requiredGasLimit: 100000,
                allowedRelayerAddresses: new address[](0),  // Any relayer can deliver
                message: abi.encode(msg.sender, message)
            })
        );
    }
}
```

---

## Receiving Cross-Chain Messages

### Basic Message Receiver

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@teleporter/ITeleporterMessenger.sol";
import "@teleporter/ITeleporterReceiver.sol";

contract CrossChainReceiver is ITeleporterReceiver {
    ITeleporterMessenger public immutable teleporter;
    bytes32 public sourceBlockchainID;

    // Events
    event MessageReceived(
        bytes32 indexed sourceBlockchainID,
        address indexed originSenderAddress,
        string message
    );

    // Received messages
    string[] public receivedMessages;

    constructor(address _teleporter, bytes32 _sourceBlockchainID) {
        teleporter = ITeleporterMessenger(_teleporter);
        sourceBlockchainID = _sourceBlockchainID;
    }

    function receiveTeleporterMessage(
        bytes32 _sourceBlockchainID,
        address _originSenderAddress,
        bytes calldata _message
    ) external override {
        // Verify caller is the Teleporter contract
        require(msg.sender == address(teleporter), "Unauthorized");

        // Verify source chain
        require(_sourceBlockchainID == sourceBlockchainID, "Invalid source chain");

        // Decode and process message
        (address sender, string memory message) = abi.decode(_message, (address, string));

        receivedMessages.push(message);

        emit MessageReceived(_sourceBlockchainID, sender, message);
    }

    function getMessagesCount() external view returns (uint256) {
        return receivedMessages.length;
    }
}
```

---

## Using the Teleporter Registry

### Getting the Latest Teleporter

```solidity
import "@teleporter/ITeleporterRegistry.sol";

contract MyDApp {
    ITeleporterRegistry public immutable teleporterRegistry;

    constructor(address _registry) {
        teleporterRegistry = ITeleporterRegistry(_registry);
    }

    function sendMessage(bytes calldata data) external {
        // Always get the latest version
        ITeleporterMessenger teleporter = teleporterRegistry.getLatestTeleporter();

        // Use teleporter...
    }
}
```

### Handling Multiple Versions

```solidity
function receiveTeleporterMessage(
    bytes32 sourceBlockchainID,
    address originSenderAddress,
    bytes calldata message
) external {
    // Check if caller is a valid Teleporter version
    uint256 version = teleporterRegistry.latestVersion();
    bool isValidTeleporter = false;

    for (uint256 i = 1; i <= version; i++) {
        if (msg.sender == address(teleporterRegistry.getTeleporterFromVersion(i))) {
            isValidTeleporter = true;
            break;
        }
    }

    require(isValidTeleporter, "Invalid Teleporter");

    // Process message...
}
```

---

## Relayer Fee Management

### Setting Up Fees

```solidity
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

function sendMessageWithFee(
    bytes calldata message,
    address feeToken,
    uint256 feeAmount
) external {
    // Approve Teleporter to spend fee tokens
    IERC20(feeToken).approve(address(teleporter), feeAmount);

    teleporter.sendCrossChainMessage(
        TeleporterMessageInput({
            destinationBlockchainID: destChainID,
            destinationAddress: destContract,
            feeInfo: TeleporterFeeInfo({
                feeTokenAddress: feeToken,
                amount: feeAmount
            }),
            requiredGasLimit: 200000,
            allowedRelayerAddresses: new address[](0),
            message: message
        })
    );
}
```

### Specifying Allowed Relayers

```solidity
function sendWithSpecificRelayers(
    bytes calldata message,
    address[] calldata relayers
) external {
    teleporter.sendCrossChainMessage(
        TeleporterMessageInput({
            // ...
            allowedRelayerAddresses: relayers,  // Only these relayers can deliver
            message: message
        })
    );
}
```

---

## Advanced: Cross-Chain Function Calls

### Encoding Function Calls

```solidity
// Sender contract
function callRemoteFunction(uint256 value) external {
    bytes memory message = abi.encodeWithSelector(
        IRemoteContract.processValue.selector,
        value,
        msg.sender
    );

    teleporter.sendCrossChainMessage(
        TeleporterMessageInput({
            destinationBlockchainID: destChainID,
            destinationAddress: remoteContract,
            feeInfo: TeleporterFeeInfo(address(0), 0),
            requiredGasLimit: 150000,
            allowedRelayerAddresses: new address[](0),
            message: message
        })
    );
}

// Receiver contract
function receiveTeleporterMessage(
    bytes32 sourceBlockchainID,
    address originSenderAddress,
    bytes calldata message
) external {
    require(msg.sender == address(teleporter), "Unauthorized");

    // Decode function selector and call
    bytes4 selector = bytes4(message[:4]);

    if (selector == this.processValue.selector) {
        (uint256 value, address sender) = abi.decode(message[4:], (uint256, address));
        _processValue(value, sender);
    }
}
```

---

## TypeScript SDK Integration

### Installation

```bash
npm install @avalanche-sdk/interchain @avalanche-sdk/client
```

### SDK Overview

The `@avalanche-sdk/interchain` package provides type-safe ICM client for:
- Sending cross-chain messages via Teleporter
- Managing message delivery and status
- ICTT token transfers

### Sending Messages from Frontend

```typescript
import { createInterchainClient } from '@avalanche-sdk/interchain'
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'

// Create interchain client
const interchainClient = createInterchainClient({
  sourceChain: {
    chainId: 43114,
    rpcUrl: 'https://api.avax.network/ext/bc/C/rpc',
    teleporterRegistry: '0x7C43605E14F391720e1b37E49C78C4b03A488d98',
  },
  destinationChain: {
    chainId: 12345,
    rpcUrl: 'http://your-l1-rpc',
    teleporterRegistry: '0x7C43605E14F391720e1b37E49C78C4b03A488d98',
  },
})

// Send a cross-chain message
const result = await interchainClient.sendMessage({
  destinationAddress: '0x...',
  message: encodedMessage,
  gasLimit: 200000n,
})

console.log('Message ID:', result.messageId)
console.log('Transaction hash:', result.txHash)
```

### Monitoring Message Status

```typescript
// Check if message was received
const status = await interchainClient.getMessageStatus(messageId)

if (status === 'delivered') {
  console.log('Message delivered!')
} else if (status === 'pending') {
  console.log('Waiting for relayer...')
}
```

### Using with @avalanche-sdk/client

```typescript
import { createAvalancheClient } from '@avalanche-sdk/client'

// Create client with full Avalanche support
const client = createAvalancheClient({
  chain: 'mainnet', // or 'fuji'
})

// Get balance across chains
const balance = await client.getBalance({
  address: '0x...',
})

// Interact with P-Chain, X-Chain, C-Chain
const validators = await client.pchain.getValidators()
```

---

## Running a Relayer

### Local Development

```bash
# Start local signature aggregator
avalanche interchain signatureAggregator start

# The relayer automatically picks up messages between local L1s
```

### Using AWM Relayer

```bash
# Clone the relayer
git clone https://github.com/ava-labs/awm-relayer

# Configure config.json with your chains
# See: https://github.com/ava-labs/awm-relayer#configuration

# Run the relayer
./awm-relayer --config config.json
```

---

## Deployed Contract Addresses

### Fuji Testnet

| Contract | Address |
|----------|---------|
| TeleporterMessenger | `0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf` |
| TeleporterRegistry | `0x7C43605E14F391720e1b37E49C78C4b03A488d98` |

### Mainnet

| Contract | Address |
|----------|---------|
| TeleporterMessenger | `0x253b2784c75e510dD0fF1da844684a1aC0aa5fcf` |
| TeleporterRegistry | `0x7C43605E14F391720e1b37E49C78C4b03A488d98` |

---

## Foundry Setup for ICM Development

### Installation

```bash
# Add ICM contracts
forge install ava-labs/icm-contracts

# Add remappings to foundry.toml
# [remappings]
# @teleporter/=lib/icm-contracts/contracts/teleporter/
# @icm-contracts/=lib/icm-contracts/contracts/
```

### Testing Cross-Chain Contracts

```solidity
// test/CrossChain.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/CrossChainSender.sol";
import "../src/CrossChainReceiver.sol";

contract CrossChainTest is Test {
    CrossChainSender sender;
    CrossChainReceiver receiver;

    // Mock Teleporter for testing
    address mockTeleporter;

    function setUp() public {
        mockTeleporter = makeAddr("teleporter");

        // Deploy contracts with mock
        sender = new CrossChainSender(/* ... */);
        receiver = new CrossChainReceiver(mockTeleporter, bytes32(0));
    }

    function testReceiveMessage() public {
        bytes memory message = abi.encode(address(this), "Hello");

        vm.prank(mockTeleporter);
        receiver.receiveTeleporterMessage(
            bytes32(0),
            address(sender),
            message
        );

        assertEq(receiver.getMessagesCount(), 1);
    }
}
```

---

## Best Practices

### Security
- Always verify `msg.sender` is the Teleporter contract
- Validate `sourceBlockchainID` to prevent spoofing
- Use the registry to support Teleporter upgrades
- Set appropriate `requiredGasLimit` to prevent out-of-gas

### Gas Optimization
- Batch multiple operations in single messages
- Use efficient encoding for message payloads
- Consider message size vs gas costs

### Reliability
- Implement retry logic for failed messages
- Use events for message tracking
- Monitor relayer health

### Message Design
- Keep messages as small as possible
- Use deterministic encoding (abi.encode)
- Include sender information in payload for verification

---

## Troubleshooting

### Common Issues from GitHub

#### Message Rejected Due to Validator Set Changes

**Problem**: ICM message rejected on destination chain with "insufficient signing stake".

**Cause**: If the source L1's validator set changes after a message is sent but before delivery, the destination may reject it. Example:
- L1 A has 5 validators who sign a message (100% stake)
- Before delivery, 5 more validators join L1 A
- Now the signature only represents 50% of stake
- Destination requires 67% → message rejected

**Solution**:
```solidity
// Use retrySendCrossChainMessage to re-sign with new validator set
teleporterMessenger.retrySendCrossChainMessage(
    destinationBlockchainID,
    message
);
```

#### Cross-Chain Transaction Failures (GitHub #735)

**Problem**: Unable to retry failed Teleporter message execution.

**Solution**: Use the retry mechanism:
```solidity
// Retry a failed message delivery
teleporterMessenger.retryMessageExecution(
    sourceBlockchainID,
    message,
    relayerRewardAddress
);
```

#### Message Pending Forever

**Symptoms**:
- Message sent successfully on source chain
- Never arrives on destination chain
- No errors visible

**Diagnostic Steps**:
```bash
# 1. Check relayer is running
curl http://localhost:8080/health  # AWM relayer health endpoint

# 2. Verify destination chain is synced
curl -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.isBootstrapped","params":{"chain":"C"}}' \
    -H 'content-type:application/json' http://DEST_NODE:9650/ext/info

# 3. Check Teleporter contract addresses match
# Source and destination must use compatible TeleporterMessenger versions

# 4. Verify blockchain IDs are correct
# Common mistake: using chain ID instead of blockchain ID
```

**Common Causes**:
| Issue | Solution |
|-------|----------|
| Relayer not running | Start AWM relayer with correct config |
| Wrong blockchain ID | Use `info.getBlockchainID` to get correct ID |
| Teleporter version mismatch | Deploy same version on both chains |
| Insufficient relayer funds | Fund relayer address on destination chain |
| Destination chain not synced | Wait for bootstrap to complete |

#### Gas Limit Too Low

**Problem**: Message delivered but execution fails with out-of-gas.

**Solution**: Increase `requiredGasLimit` in message input:
```solidity
TeleporterMessageInput({
    // ...
    requiredGasLimit: 500000,  // Increase from default
    // ...
})
```

**Estimating Gas**:
```solidity
// Test locally to estimate gas needed
uint256 gasUsed = gasleft();
// ... execute your logic ...
gasUsed = gasUsed - gasleft();
// Add 20% buffer: requiredGasLimit = gasUsed * 120 / 100
```

#### Version Compatibility Issues

**Important**: TeleporterMessenger contracts are **non-upgradeable**. Compatibility only exists between same versions.

```bash
# Check deployed Teleporter version
cast call $TELEPORTER_ADDRESS "getMinTeleporterVersion()(uint256)" --rpc-url $RPC_URL
```

| Version Mismatch | Result |
|------------------|--------|
| Same major version | Usually compatible |
| Different major version | Messages will fail |
| Mixed versions on chains | Unpredictable behavior |

#### Debugging Message Flow

```typescript
// Track message through the system
import { createPublicClient, http, parseAbiItem } from 'viem'

const client = createPublicClient({
  transport: http(RPC_URL)
})

// 1. Find SendCrossChainMessage event on source
const sendLogs = await client.getLogs({
  address: TELEPORTER_ADDRESS,
  event: parseAbiItem('event SendCrossChainMessage(bytes32 indexed messageID, bytes32 indexed destinationBlockchainID, TeleporterMessage message)'),
  fromBlock: txBlockNumber,
  toBlock: txBlockNumber
})

// 2. Check ReceiveCrossChainMessage on destination
const receiveLogs = await destClient.getLogs({
  address: TELEPORTER_ADDRESS,
  event: parseAbiItem('event ReceiveCrossChainMessage(bytes32 indexed messageID, bytes32 indexed sourceBlockchainID, address indexed deliverer, address rewardRedeemer, TeleporterMessage message)'),
  fromBlock: 'earliest',
  toBlock: 'latest'
})

// 3. If not received, check MessageExecutionFailed
const failedLogs = await destClient.getLogs({
  address: TELEPORTER_ADDRESS,
  event: parseAbiItem('event MessageExecutionFailed(bytes32 indexed messageID, bytes32 indexed sourceBlockchainID, TeleporterMessage message)'),
})
```

### Error Reference

| Error | Cause | Solution |
|-------|-------|----------|
| `Unauthorized` | Caller is not Teleporter contract | Verify `msg.sender == teleporter` |
| `Invalid source chain` | Wrong `sourceBlockchainID` | Check blockchain ID, not chain ID |
| `Message already received` | Duplicate delivery attempt | Message was already processed |
| `Insufficient gas` | `requiredGasLimit` too low | Increase gas limit |
| `Invalid Teleporter` | Using wrong Teleporter version | Check registry for correct address |
| `Relayer not allowed` | Restricted relayer list | Add relayer to `allowedRelayerAddresses` or use empty array |
