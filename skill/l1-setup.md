# Avalanche L1 (Subnet) Setup

> Create and deploy custom Avalanche L1 blockchains

---

## Goals

1. Create custom EVM-compatible L1 blockchains
2. Configure chain parameters (gas, tokens, precompiles)
3. Deploy to local network, Fuji testnet, and mainnet
4. Manage validators and chain upgrades

---

## Deployment Options

| Method | Best For | Complexity |
|--------|----------|------------|
| **Builders Hub Console** | Production L1s, teams, visual configuration | Low |
| **Avalanche CLI** | Local development, automation, advanced users | Medium |
| **Manual Deployment** | Maximum control, custom VMs | High |

**Recommended Path**: Use Builders Hub Console for production deployments, CLI for local development.

---

## Option 1: Builders Hub Console (Recommended)

The Builders Hub Console at [build.avax.network](https://build.avax.network) provides a guided, visual interface for L1 creation.

### Why Use Console?

- **No CLI setup required** - browser-based workflow
- **Visual Genesis Builder** - configure tokenomics, permissions, fees visually
- **Integrated validator management** - add/remove validators through UI
- **Built-in ICM support** - Teleporter and relayer setup included
- **Deployment tracking** - monitor L1 status from dashboard

### Console Workflow

#### Step 1: Prerequisites
1. Install [Core Wallet](https://core.app) browser extension
2. Get testnet AVAX from [faucet.avax.network](https://faucet.avax.network)
3. Bridge AVAX from C-Chain to P-Chain (required for validator staking)

#### Step 2: Create L1 via Console
1. Go to [build.avax.network/tools/l1-launcher](https://build.avax.network/tools/l1-launcher)
2. Connect your Core Wallet
3. Click "Create New L1"
4. Configure using the Genesis Builder:
   - **Chain ID**: Unique identifier (check [chainlist.org](https://chainlist.org))
   - **Token Symbol**: Your native gas token (e.g., `MYT`)
   - **Initial Allocation**: Addresses and amounts for token distribution
   - **Fee Configuration**: Gas limits, base fee, target block rate
   - **Permissioning**: Who can deploy contracts, who can transact
   - **Precompiles**: Enable advanced features (see Precompiles section)

#### Step 3: Deploy
1. Review configuration summary
2. Sign the `CreateSubnetTx` with Core Wallet
3. Sign the `CreateChainTx` to deploy blockchain
4. Wait for confirmation (typically < 1 minute on Fuji)

#### Step 4: Add Validators
1. Navigate to your L1 in the Console dashboard
2. Click "Add Validator"
3. Enter validator NodeID (from their AvalancheGo node)
4. Set stake amount and duration
5. Sign transaction

#### Step 5: Set Up ICM (Optional)
1. Deploy Teleporter contracts via Console wizard
2. Configure relayer endpoints
3. Test cross-chain messaging

### Console vs CLI Comparison

| Feature | Console | CLI |
|---------|---------|-----|
| Visual configuration | ✅ | ❌ |
| Scriptable/automatable | ❌ | ✅ |
| Local development | ❌ | ✅ |
| Production deployment | ✅ | ✅ |
| ICM wizard | ✅ | ✅ |
| Custom VM support | Limited | ✅ |

---

## Option 2: Avalanche CLI (Development)

Use CLI for local development, CI/CD pipelines, and advanced customization.

### Prerequisites

```bash
# Install Avalanche CLI
curl -sSfL https://raw.githubusercontent.com/ava-labs/avalanche-cli/main/scripts/install.sh | sh -s

# Add to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH=~/bin:$PATH

# Verify installation
avalanche --version
```

---

## Creating an L1 with CLI

### Interactive Creation

```bash
# Start the creation wizard
avalanche blockchain create mychain

# You'll be prompted for:
# 1. VM type (Subnet-EVM is default for EVM compatibility)
# 2. Chain ID (choose unique ID, check chainlist.org)
# 3. Token symbol (for native gas token)
# 4. Gas configuration (low/medium/high throughput)
# 5. Airdrop addresses (for initial token distribution)
# 6. Precompiles (optional advanced features)
```

### Non-Interactive Creation

```bash
# Create with specific parameters
avalanche blockchain create mychain \
  --vm subnet-evm \
  --chain-id 12345 \
  --token-symbol MYT \
  --genesis-file ./genesis.json

# View created blockchain config
avalanche blockchain describe mychain
```

---

## Genesis Configuration

### Sample genesis.json

```json
{
  "config": {
    "chainId": 12345,
    "feeConfig": {
      "gasLimit": 15000000,
      "targetBlockRate": 2,
      "minBaseFee": 25000000000,
      "targetGas": 15000000,
      "baseFeeChangeDenominator": 36,
      "minBlockGasCost": 0,
      "maxBlockGasCost": 1000000,
      "blockGasCostStep": 200000
    },
    "allowFeeRecipients": false
  },
  "alloc": {
    "0x8db97C7cEcE249c2b98bDC0226Cc4C2A57BF52FC": {
      "balance": "0x295BE96E64066972000000"
    }
  },
  "timestamp": "0x0",
  "gasLimit": "0xe4e1c0",
  "difficulty": "0x0",
  "mixHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "coinbase": "0x0000000000000000000000000000000000000000",
  "number": "0x0",
  "gasUsed": "0x0",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000"
}
```

### Fee Configuration Options

| Preset | Target Block Rate | Min Base Fee | Use Case |
|--------|------------------|--------------|----------|
| Low | 2s | 25 gwei | Standard apps |
| Medium | 2s | 25 gwei | Higher throughput |
| High | 1s | 1 gwei | Maximum throughput |

---

## Deploying Your L1

### Local Deployment (Development)

```bash
# Deploy to local network (starts a local Avalanche network)
avalanche blockchain deploy mychain --local

# This will:
# 1. Start a local Avalanche network
# 2. Create the subnet on the network
# 3. Deploy your blockchain configuration
# 4. Output RPC endpoint and chain details

# Output example:
# RPC URL: http://127.0.0.1:9650/ext/bc/mychain/rpc
# Chain ID: 12345
# Funded address: 0x8db97C7cEcE249c2b98bDC0226Cc4C2A57BF52FC
```

### Fuji Testnet Deployment

```bash
# First, create a key for deployment
avalanche key create mykey

# Fund the key with Fuji AVAX from faucet
# https://faucet.avax.network/

# Deploy to Fuji
avalanche blockchain deploy mychain --fuji

# Add validators (requires staked AVAX)
avalanche blockchain addValidator mychain --fuji
```

### Mainnet Deployment

> **CRITICAL: IRREVERSIBLE WITH FINANCIAL IMPLICATIONS**
>
> Mainnet deployment uses **real AVAX** and creates permanent blockchain records.
>
> **Pre-Mainnet Checklist:**
> - [ ] **COMPLETED FUJI TESTING** - Full deployment and operation on testnet
> - [ ] **SMART CONTRACTS AUDITED** - Professional audit for any custom contracts
> - [ ] **BACKUP ALL KEYS** - Store securely offline, multiple copies
> - [ ] **VERIFY GENESIS CONFIG** - Double-check token allocations, permissions
> - [ ] **VALIDATOR COORDINATION** - All validators ready with hardware and keys
> - [ ] **FUNDS VERIFIED** - Sufficient AVAX for staking (2000+ per validator)

```bash
# 1. FIRST: Verify your configuration one more time
avalanche blockchain describe mychain

# 2. VERIFY you've tested on Fuji
# If not: avalanche blockchain deploy mychain --fuji

# 3. Deploy to mainnet (requires real AVAX for staking)
avalanche blockchain deploy mychain --mainnet

# IMPORTANT: Mainnet deployment requires:
# 1. Sufficient AVAX for validator staking (minimum 2000 AVAX per validator)
# 2. At least 5 validators for production
# 3. Proper key management and security
```

---

## Precompiles Configuration

### Available Precompiles

| Precompile | Address | Purpose |
|------------|---------|---------|
| ContractDeployerAllowList | 0x0300...0000 | Restrict who can deploy contracts |
| TransactionAllowList | 0x0300...0001 | Restrict who can submit transactions |
| NativeMinter | 0x0300...0002 | Mint native tokens programmatically |
| FeeConfigManager | 0x0300...0003 | Dynamically adjust fee parameters |
| RewardManager | 0x0300...0004 | Customize block reward distribution |
| WarpMessenger | 0x0200...0005 | Enable cross-chain messaging |

### Enabling Precompiles

```bash
# Enable during creation
avalanche blockchain create mychain --precompiles

# Or configure in genesis
```

### Contract Deployer Allow List

```json
{
  "config": {
    "contractDeployerAllowListConfig": {
      "adminAddresses": ["0x8db97C7cEcE249c2b98bDC0226Cc4C2A57BF52FC"],
      "enabledAddresses": [],
      "blockTimestamp": 0
    }
  }
}
```

### Native Minter Configuration

```json
{
  "config": {
    "contractNativeMinterConfig": {
      "adminAddresses": ["0x8db97C7cEcE249c2b98bDC0226Cc4C2A57BF52FC"],
      "enabledAddresses": [],
      "blockTimestamp": 0
    }
  }
}
```

---

## Managing Your L1

### View Blockchain Info

```bash
# List all created blockchains
avalanche blockchain list

# Get detailed info about a blockchain
avalanche blockchain describe mychain

# Check blockchain status
avalanche blockchain stats mychain
```

### Validator Management

```bash
# List current validators
avalanche blockchain validators mychain

# Add a new validator
avalanche blockchain addValidator mychain \
  --node-id NodeID-xxx \
  --stake-amount 2000 \
  --start-time "2024-01-01T00:00:00Z" \
  --stake-duration 365d

# Remove a validator
avalanche blockchain removeValidator mychain --node-id NodeID-xxx
```

### Chain Upgrades

```bash
# Prepare an upgrade
avalanche blockchain upgrade mychain

# The upgrade wizard will help you:
# 1. Select upgrade type (precompile activation, network upgrade, etc.)
# 2. Set activation timestamp
# 3. Configure new parameters

# Apply upgrade to local network
avalanche blockchain upgrade apply mychain --local

# Apply upgrade to Fuji
avalanche blockchain upgrade apply mychain --fuji
```

---

## Proof of Stake vs Proof of Authority

### Comparison

| Aspect | PoA (Proof of Authority) | PoS (Proof of Stake) |
|--------|--------------------------|----------------------|
| **Validator Selection** | Admin-controlled | Permissionless staking |
| **Decentralization** | Centralized | Decentralized |
| **Best For** | Private chains, development | Public chains, production |
| **Rewards** | Optional (custom) | Built-in reward calculator |
| **Delegation** | Not supported | Supported |

### Proof of Authority (PoA)

```bash
# Default for new L1s - simpler setup
# Validators are managed by an admin address
# Good for: Private chains, development, controlled environments

avalanche blockchain create mychain --proof-of-authority
```

### Proof of Stake (PoS)

```bash
# Validators must stake tokens
# More decentralized
# Good for: Public chains, production deployments

avalanche blockchain create mychain --proof-of-stake
```

**PoS Implementation Options**:
- `NativeTokenStakingManager` - Validators stake the L1's native gas token
- `ERC20TokenStakingManager` - Validators stake a specific ERC20 token

---

## Converting PoA to PoS

> **CRITICAL: IRREVERSIBLE OPERATION**
>
> Converting from PoA to PoS is a **one-way operation** that cannot be undone. The proxy upgrade permanently changes how validators are managed.
>
> **Before proceeding:**
> - [ ] **TEST ON FUJI FIRST** - Deploy a test L1 and perform the full upgrade
> - [ ] **BACKUP ALL KEYS** - ProxyAdmin key, validator keys, deployer keys
> - [ ] **COORDINATE WITH VALIDATORS** - They must re-register under PoS
> - [ ] **VERIFY CONTRACTS** - Audit new implementation before upgrading
> - [ ] **HAVE ROLLBACK PLAN** - While upgrade can't be reversed, have recovery procedures documented

You can convert an existing PoA L1 to PoS by upgrading the ValidatorManager proxy contract.

### Architecture Overview

When you deploy a PoA L1, contracts are deployed behind an upgradeable proxy:

```
┌─────────────────────────────────────────────────────────────┐
│                    Your L1 Blockchain                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐      ┌──────────────────────────────┐ │
│  │   ProxyAdmin     │      │  TransparentUpgradeableProxy │ │
│  │                  │      │                              │ │
│  │  Owner: You      │─────▶│  Points to: PoAValidator     │ │
│  │  (controller)    │      │            Manager           │ │
│  └──────────────────┘      └──────────────────────────────┘ │
│                                       │                      │
│                                       ▼                      │
│                            ┌──────────────────────┐         │
│                            │  PoAValidatorManager │         │
│                            │   (implementation)   │         │
│                            └──────────────────────┘         │
│                                                              │
│  After Upgrade:                       │                      │
│                                       ▼                      │
│                            ┌──────────────────────┐         │
│                            │ NativeTokenStaking   │         │
│                            │      Manager         │         │
│                            └──────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

### Pre-Upgrade Checklist

- [ ] You have the ProxyAdmin owner key (controller address from deployment)
- [ ] Decide on staking token: Native or ERC20
- [ ] Plan validator migration strategy
- [ ] Test on Fuji before mainnet
- [ ] Communicate timeline to existing validators

### Step 1: Get Your Contract Addresses

```bash
# View your L1 details
avalanche blockchain describe mychain

# Note these addresses from output:
# - Validator Manager Proxy: 0xfeedc0de...
# - Proxy Admin: 0xc0ffee...
# - Your controller address (ProxyAdmin owner)
```

Or query directly:

```bash
# Get Validator Manager address
cast call $VALIDATOR_MANAGER_PROXY "owner()" --rpc-url $L1_RPC

# Verify you control the ProxyAdmin
cast call $PROXY_ADMIN "owner()" --rpc-url $L1_RPC
```

### Step 2: Deploy New PoS Implementation

#### Option A: Native Token Staking

Validators stake your L1's native gas token.

```solidity
// script/DeployNativeTokenStaking.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {NativeTokenStakingManager} from "@icm-contracts/validator-manager/NativeTokenStakingManager.sol";
import {ValidatorManagerSettings, PoSValidatorManagerSettings} from "@icm-contracts/validator-manager/interfaces/IPoSValidatorManager.sol";
import {IRewardCalculator} from "@icm-contracts/validator-manager/interfaces/IRewardCalculator.sol";

contract DeployNativeTokenStaking is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        // Deploy the new implementation
        NativeTokenStakingManager stakingManager = new NativeTokenStakingManager();

        console.log("NativeTokenStakingManager deployed at:", address(stakingManager));

        vm.stopBroadcast();
    }
}
```

#### Option B: ERC20 Token Staking

Validators stake a specific ERC20 token.

```solidity
// script/DeployERC20TokenStaking.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {ERC20TokenStakingManager} from "@icm-contracts/validator-manager/ERC20TokenStakingManager.sol";

contract DeployERC20TokenStaking is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        ERC20TokenStakingManager stakingManager = new ERC20TokenStakingManager();

        console.log("ERC20TokenStakingManager deployed at:", address(stakingManager));

        vm.stopBroadcast();
    }
}
```

### Step 3: Upgrade the Proxy

> **POINT OF NO RETURN**: The following upgrade is irreversible. Once executed, your L1 permanently becomes PoS.
>
> **Final checks before running:**
> ```bash
> # Verify you're on the correct network
> echo $L1_RPC
>
> # Verify implementation address is correct
> echo $NEW_IMPLEMENTATION
>
> # Simulate first (no --broadcast)
> forge script script/UpgradeToPoS.s.sol --rpc-url $L1_RPC
> ```

```solidity
// script/UpgradeToPoS.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradeToPoS is Script {
    function run() external {
        // Your L1's contract addresses
        address proxyAdmin = vm.envAddress("PROXY_ADMIN");
        address validatorManagerProxy = vm.envAddress("VALIDATOR_MANAGER_PROXY");
        address newImplementation = vm.envAddress("NEW_IMPLEMENTATION");

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        // Upgrade proxy to new PoS implementation
        ProxyAdmin(proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(validatorManagerProxy),
            newImplementation,
            ""  // No initialization call - we'll do it separately
        );

        console.log("Upgraded ValidatorManager to:", newImplementation);

        vm.stopBroadcast();
    }
}
```

### Step 4: Initialize PoS Settings

```solidity
// script/InitializePoS.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {NativeTokenStakingManager} from "@icm-contracts/validator-manager/NativeTokenStakingManager.sol";
import {PoSValidatorManagerSettings} from "@icm-contracts/validator-manager/interfaces/IPoSValidatorManager.sol";
import {ValidatorManagerSettings} from "@icm-contracts/validator-manager/interfaces/IValidatorManager.sol";

contract InitializePoS is Script {
    function run() external {
        address validatorManagerProxy = vm.envAddress("VALIDATOR_MANAGER_PROXY");
        address rewardCalculator = vm.envAddress("REWARD_CALCULATOR"); // Deploy separately or use existing

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        NativeTokenStakingManager manager = NativeTokenStakingManager(validatorManagerProxy);

        // Configure PoS settings
        PoSValidatorManagerSettings memory posSettings = PoSValidatorManagerSettings({
            baseSettings: ValidatorManagerSettings({
                subnetID: bytes32(0),  // Your subnet ID
                churnPeriodSeconds: 1 hours,
                maximumChurnPercentage: 20  // Max 20% validator churn per period
            }),
            minimumStakeAmount: 100 ether,      // Minimum stake required
            maximumStakeAmount: 10000 ether,    // Maximum stake allowed
            minimumStakeDuration: 14 days,      // Minimum staking period
            minimumDelegationFeeBips: 100,      // 1% minimum delegation fee
            maximumStakeMultiplier: 4,          // Delegation multiplier
            weightToValueFactor: 1,
            rewardCalculator: IRewardCalculator(rewardCalculator)
        });

        // Initialize (only works once)
        manager.initialize(posSettings);

        console.log("PoS initialized successfully");

        vm.stopBroadcast();
    }
}
```

### Step 5: Migrate Existing Validators

Existing PoA validators need to register as PoS validators:

```solidity
// For each existing validator
function migrateValidator(
    NativeTokenStakingManager manager,
    bytes32 nodeID,
    uint64 registrationExpiry,
    bytes memory blsPublicKey
) external payable {
    // Validator stakes tokens
    manager.initializeValidatorRegistration{value: msg.value}(
        ValidatorRegistrationInput({
            nodeID: nodeID,
            blsPublicKey: blsPublicKey,
            registrationExpiry: registrationExpiry,
            remainingBalanceOwner: PChainOwner({
                threshold: 1,
                addresses: [msg.sender]
            }),
            disableOwner: PChainOwner({
                threshold: 1,
                addresses: [msg.sender]
            })
        }),
        uint64(block.timestamp + 365 days),  // Delegation end time
        1000  // Delegation fee (10%)
    );
}
```

### Run the Upgrade

> **ALWAYS TEST ON FUJI FIRST**
>
> The commands below should be run on a **Fuji test L1** before mainnet.

```bash
# ============================================
# STEP 0: TEST ON FUJI FIRST (MANDATORY)
# ============================================
# Create a test L1 on Fuji and run through the entire upgrade process
# before attempting on mainnet. This catches configuration errors safely.

# ============================================
# STEP 1: Deploy new implementation (simulation first)
# ============================================
# Simulate WITHOUT --broadcast first
forge script script/DeployNativeTokenStaking.s.sol --rpc-url $L1_RPC

# If simulation succeeds, deploy for real
forge script script/DeployNativeTokenStaking.s.sol \
    --rpc-url $L1_RPC \
    --broadcast

# ============================================
# STEP 2: Upgrade proxy (IRREVERSIBLE)
# ============================================
export NEW_IMPLEMENTATION=0x...  # From step 1
export PROXY_ADMIN=0x...         # From describe output
export VALIDATOR_MANAGER_PROXY=0x...

# SIMULATE FIRST - verify no errors
forge script script/UpgradeToPoS.s.sol --rpc-url $L1_RPC

# VERIFY addresses are correct
echo "Upgrading proxy $VALIDATOR_MANAGER_PROXY to $NEW_IMPLEMENTATION"
echo "Using ProxyAdmin: $PROXY_ADMIN"
read -p "Confirm these are correct? (yes/no): " confirm
[ "$confirm" != "yes" ] && echo "Aborted" && exit 1

# Execute upgrade (NO GOING BACK AFTER THIS)
forge script script/UpgradeToPoS.s.sol \
    --rpc-url $L1_RPC \
    --broadcast

# ============================================
# STEP 3: Initialize PoS settings
# ============================================
forge script script/InitializePoS.s.sol \
    --rpc-url $L1_RPC \
    --broadcast

# ============================================
# STEP 4: Verify upgrade succeeded
# ============================================
cast call $VALIDATOR_MANAGER_PROXY "minimumStakeAmount()" --rpc-url $L1_RPC

# Should return your configured minimum stake amount
```

### Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| `Ownable: caller is not the owner` | Wrong key for ProxyAdmin | Use controller address from deployment |
| `Already initialized` | Tried to init twice | Initialization is one-time only |
| `Invalid implementation` | Wrong contract type | Ensure deploying correct staking manager |
| Validators can't register | Settings too restrictive | Check minimum stake, duration |

### Progressive Decentralization Alternative

For gradual migration, consider [Suzaku's BalancerValidatorManager](https://www.suzaku.network/post/introducing-balancervalidatormanager):

- Run PoA and PoS simultaneously during transition
- Allocate voting weight between both systems
- Gradually shift to full PoS

```
Phase 1: 100% PoA, 0% PoS
Phase 2: 70% PoA, 30% PoS
Phase 3: 30% PoA, 70% PoS
Phase 4: 0% PoA, 100% PoS
```

---

## Interchain Communication Setup

### Enable ICM on Your L1

```bash
# When creating, enable Teleporter
avalanche blockchain create mychain --teleporter

# This will:
# 1. Deploy TeleporterMessenger contract
# 2. Deploy TeleporterRegistry contract
# 3. Configure Warp messaging

# For existing chains, deploy ICM contracts manually
# See icm-interchain-messaging.md
```

---

## Local Development Workflow

### Start Local Network

```bash
# Start network with your blockchain
avalanche network start

# Stop network
avalanche network stop

# Clean up (removes all local state)
avalanche network clean
```

### Using with Foundry/Hardhat

```bash
# Get RPC URL after deployment
avalanche blockchain describe mychain --local

# Add to foundry.toml
# [rpc_endpoints]
# mychain = "http://127.0.0.1:9650/ext/bc/mychain/rpc"

# Deploy contracts
forge script script/Deploy.s.sol --rpc-url mychain --broadcast
```

### Funded Test Accounts

When deploying locally, these accounts are pre-funded:

```
Address: 0x8db97C7cEcE249c2b98bDC0226Cc4C2A57BF52FC
Private Key: 56289e99c94b6912bfc12adc093c9b51124f0dc54ac7a766b2bc5ccf558d8027
Balance: 1,000,000 tokens
```

---

## Configuration Files

### Avalanche CLI Config

Location: `~/.avalanche-cli/config.json`

```json
{
  "network": "fuji",
  "metrics-enabled": true,
  "log-level": "info"
}
```

### Subnet Config

Location: `~/.avalanche-cli/subnets/<name>/`

```
subnets/mychain/
├── genesis.json          # Chain genesis configuration
├── sidecar.json          # Metadata about the subnet
├── chain.json            # Chain-specific config
└── subnet.json           # Subnet-level config
```

---

## Custom Virtual Machines

### Using a Custom VM

```bash
# Import a custom VM binary
avalanche blockchain create mychain --custom-vm ./path/to/vm-binary

# Or specify a VM repository
avalanche blockchain create mychain --vm-repo https://github.com/my-org/my-vm
```

### VM Requirements

Custom VMs must:
1. Implement the Avalanche VM interface
2. Support the Snowman consensus protocol
3. Be compiled for the target platform

---

## Best Practices

### Development
- Always test on local network first
- Use separate keys for dev/test/prod
- Version your genesis configurations
- Document custom precompile settings

### Testnet (Fuji)
- Test with realistic validator counts
- Verify ICM connectivity with other chains
- Test upgrade procedures before mainnet

### Mainnet
- Minimum 5 validators recommended
- Use hardware security modules (HSM) for validator keys
- Monitor validator uptime and performance
- Have upgrade and incident response plans

---

## Troubleshooting

### Common Issues

**"Subnet not found"**
```bash
# Ensure network is running
avalanche network status

# Redeploy if needed
avalanche blockchain deploy mychain --local
```

**"Insufficient funds for staking"**
```bash
# Check balance
avalanche key list

# For Fuji, use faucet: https://faucet.avax.network/
```

**"VM not compatible"**
```bash
# Ensure AvalancheGo and VM versions are compatible
avalanche blockchain upgrade vm mychain
```

### Getting Help

```bash
# CLI help
avalanche --help
avalanche blockchain --help

# Check logs
avalanche network logs
```
