# Node Operations

> Run and manage AvalancheGo nodes for validators and RPC endpoints

---

## Goals

1. Install and configure AvalancheGo
2. Run Primary Network nodes (C-Chain, P-Chain, X-Chain)
3. Set up L1/Subnet validators
4. Monitor and maintain node health
5. **Safely upgrade nodes** (including while staking)
6. **Convert between node types** (archive, RPC, validator)
7. **Tune performance** with advanced configurations

---

## System Requirements

### Minimum Hardware

| Use Case | CPU | RAM | Storage | Network |
|----------|-----|-----|---------|---------|
| Development | 4 cores | 8 GB | 200 GB SSD | 10 Mbps |
| Testnet | 8 cores | 16 GB | 500 GB SSD | 25 Mbps |
| Mainnet Validator | 8+ cores | 32 GB | 1 TB NVMe | 100 Mbps |
| Archival Node | 16+ cores | 64 GB | 4+ TB NVMe | 100 Mbps |

### Supported OS

- Ubuntu 20.04/22.04 LTS (recommended)
- Debian 11+
- macOS (development only)

---

## Installing AvalancheGo

### Method 1: Install Script (Recommended)

```bash
# Download and run install script
wget -nd -m https://raw.githubusercontent.com/ava-labs/avalanche-docs/master/scripts/avalanchego-installer.sh
chmod 755 avalanchego-installer.sh
./avalanchego-installer.sh

# The script will:
# 1. Download the latest AvalancheGo binary
# 2. Create systemd service
# 3. Set up configuration directories
```

### Method 2: Manual Installation

```bash
# Download latest release
wget https://github.com/ava-labs/avalanchego/releases/download/v1.11.x/avalanchego-linux-amd64-v1.11.x.tar.gz

# Extract
tar -xvf avalanchego-linux-amd64-v1.11.x.tar.gz

# Move to appropriate location
sudo mv avalanchego-v1.11.x /opt/avalanche/avalanchego

# Create symlink
sudo ln -s /opt/avalanche/avalanchego/avalanchego /usr/local/bin/avalanchego
```

### Method 3: Build from Source

```bash
# Install Go 1.21+
wget https://go.dev/dl/go1.21.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# Clone repository
git clone https://github.com/ava-labs/avalanchego.git
cd avalanchego

# Build
./scripts/build.sh

# Binary is at ./build/avalanchego
```

---

## Running a Node

### Basic Startup

```bash
# Run on Mainnet
avalanchego --network-id=mainnet

# Run on Fuji Testnet
avalanchego --network-id=fuji

# Run with specific data directory
avalanchego --network-id=mainnet --db-dir=/data/avalanche
```

### Using Systemd Service

```bash
# If installed via script, service is already configured
sudo systemctl start avalanchego
sudo systemctl enable avalanchego  # Start on boot
sudo systemctl status avalanchego

# View logs
sudo journalctl -u avalanchego -f
```

### Manual Systemd Setup

Create `/etc/systemd/system/avalanchego.service`:

```ini
[Unit]
Description=AvalancheGo Node
After=network.target

[Service]
Type=simple
User=avalanche
ExecStart=/usr/local/bin/avalanchego --config-file=/etc/avalanche/config.json
Restart=always
RestartSec=5
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

---

## Configuration

### Main Config File

Create `~/.avalanchego/config.json`:

```json
{
  "network-id": "mainnet",
  "http-host": "0.0.0.0",
  "http-port": 9650,
  "staking-port": 9651,
  "db-dir": "/data/avalanche/db",
  "log-dir": "/data/avalanche/logs",
  "log-level": "info",
  "api-admin-enabled": false,
  "api-keystore-enabled": false,
  "index-enabled": false,
  "state-sync-enabled": true
}
```

### Common Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `network-id` | Network to connect to | mainnet |
| `http-host` | HTTP API bind address | 127.0.0.1 |
| `http-port` | HTTP API port | 9650 |
| `staking-port` | P2P staking port | 9651 |
| `db-dir` | Database directory | ~/.avalanchego/db |
| `state-sync-enabled` | Fast sync (recommended) | true |
| `index-enabled` | Transaction indexing | false |

### API Configuration

```json
{
  "api-admin-enabled": false,
  "api-keystore-enabled": false,
  "api-metrics-enabled": true,
  "http-allowed-origins": ["*"],
  "http-allowed-hosts": ["*"]
}
```

### Chain-Specific Configs

Create chain config in `~/.avalanchego/configs/chains/`:

**C-Chain** (`C/config.json`):
```json
{
  "state-sync-enabled": true,
  "pruning-enabled": true,
  "eth-apis": [
    "eth",
    "eth-filter",
    "net",
    "web3",
    "internal-eth",
    "internal-blockchain",
    "internal-transaction"
  ]
}
```

---

## Running L1/Subnet Nodes

### Track an Existing L1

```bash
# Add subnet tracking to config
{
  "track-subnets": "subnet-id-1,subnet-id-2"
}

# Or via command line
avalanchego --track-subnets=<subnet-id>
```

### Install Subnet VM Plugin

```bash
# Build or download the VM binary (e.g., Subnet-EVM)
git clone https://github.com/ava-labs/subnet-evm.git
cd subnet-evm
./scripts/build.sh

# Copy to plugins directory
# Plugin name must be the VMID
cp build/srEXiWaHuhNyGwPUi444Tu47ZEDwxTWrbQiuD7FmgSAQ6X7Dy \
   ~/.avalanchego/plugins/
```

### L1 Config

Create `~/.avalanchego/configs/subnets/<subnet-id>.json`:

```json
{
  "validatorOnly": false,
  "consensusParameters": {
    "k": 20,
    "alpha": 15
  }
}
```

---

## Becoming a Validator

### Requirements

- **Mainnet**: Minimum 2000 AVAX staked
- **Fuji**: Minimum 1 AVAX staked
- Node must be fully synced
- Stable network connection

### Get Node ID

```bash
curl -X POST --data '{
    "jsonrpc":"2.0",
    "id"     :1,
    "method" :"info.getNodeID"
}' -H 'content-type:application/json;' http://127.0.0.1:9650/ext/info
```

### Add Validator via Core Wallet

1. Open Core Wallet
2. Go to Stake → Validate
3. Enter Node ID
4. Set stake amount and duration
5. Confirm transaction

### Add Validator via API

```bash
curl -X POST --data '{
    "jsonrpc": "2.0",
    "method": "platform.addValidator",
    "params": {
        "nodeID":"NodeID-xxx",
        "startTime": 1640000000,
        "endTime": 1672000000,
        "stakeAmount": 2000000000000,
        "rewardAddress": "P-avax1...",
        "delegationFeeRate": 10,
        "username": "myUser",
        "password": "myPassword"
    },
    "id": 1
}' -H 'content-type:application/json;' http://127.0.0.1:9650/ext/P
```

---

## Monitoring

### Health Check

```bash
# Check node health
curl -X POST --data '{
    "jsonrpc":"2.0",
    "id"     :1,
    "method" :"health.health"
}' -H 'content-type:application/json;' http://127.0.0.1:9650/ext/health

# Check if bootstrapped
curl -X POST --data '{
    "jsonrpc":"2.0",
    "id"     :1,
    "method" :"info.isBootstrapped",
    "params": {
        "chain": "C"
    }
}' -H 'content-type:application/json;' http://127.0.0.1:9650/ext/info
```

### Prometheus Metrics

Enable metrics in config:
```json
{
  "api-metrics-enabled": true
}
```

Access at: `http://localhost:9650/ext/metrics`

### Grafana Dashboard

1. Import Avalanche dashboard from Grafana Labs
2. Configure Prometheus data source
3. Monitor:
   - Block height
   - Peer connections
   - Transaction throughput
   - Validator uptime

### Log Monitoring

```bash
# View recent logs
sudo journalctl -u avalanchego --since "1 hour ago"

# Follow logs in real-time
sudo journalctl -u avalanchego -f

# Check for errors
sudo journalctl -u avalanchego | grep -i error
```

---

## Maintenance

### Updating AvalancheGo

```bash
# Stop the node
sudo systemctl stop avalanchego

# Download new version
./avalanchego-installer.sh --reinstall

# Or manually:
wget https://github.com/ava-labs/avalanchego/releases/download/vX.X.X/avalanchego-linux-amd64-vX.X.X.tar.gz
tar -xvf avalanchego-linux-amd64-vX.X.X.tar.gz
sudo cp avalanchego-vX.X.X/avalanchego /usr/local/bin/

# Start the node
sudo systemctl start avalanchego
```

### Database Pruning

```bash
# Enable pruning for C-Chain
# In ~/.avalanchego/configs/chains/C/config.json:
{
  "pruning-enabled": true,
  "offline-pruning-enabled": true
}

# Run offline pruning (node must be stopped)
avalanchego --offline-pruning-enabled
```

### Backup

```bash
# Backup staking keys (CRITICAL)
cp ~/.avalanchego/staking/staker.crt /backup/
cp ~/.avalanchego/staking/staker.key /backup/

# Backup node configuration
cp -r ~/.avalanchego/configs /backup/
```

---

## Upgrading Validator Nodes (While Staking)

Upgrading a validator node requires careful planning to avoid downtime penalties.

### Pre-Upgrade Checklist

```bash
# 1. Check current version
curl -s -X POST --data '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"info.getNodeVersion"
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq '.result'

# 2. Check node health before upgrade
curl -s -X POST --data '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"health.health"
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/health | jq '.result.healthy'

# 3. Check if node is bootstrapped
curl -s -X POST --data '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"info.isBootstrapped",
    "params":{"chain":"P"}
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/info

# 4. Verify staking keys are backed up
ls -la ~/.avalanchego/staking/
cp ~/.avalanchego/staking/staker.* /secure-backup/

# 5. Check validator status
curl -s -X POST --data '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"platform.getCurrentValidators",
    "params":{"subnetID":"11111111111111111111111111111111LpoYY"}
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/P | jq '.result.validators[] | select(.nodeID=="YOUR_NODE_ID")'
```

### Safe Upgrade Procedure (Validator)

```bash
#!/bin/bash
# safe-upgrade.sh - Safe validator upgrade script

set -e

NEW_VERSION="v1.11.x"  # Update this
BACKUP_DIR="/backup/avalanche-$(date +%Y%m%d)"

echo "=== Starting Safe Validator Upgrade ==="

# Step 1: Create backup
echo "Creating backup..."
mkdir -p $BACKUP_DIR
cp -r ~/.avalanchego/staking $BACKUP_DIR/
cp -r ~/.avalanchego/configs $BACKUP_DIR/
cp ~/.avalanchego/config.json $BACKUP_DIR/ 2>/dev/null || true

# Step 2: Download new version (while node still running)
echo "Downloading AvalancheGo $NEW_VERSION..."
cd /tmp
wget -q https://github.com/ava-labs/avalanchego/releases/download/$NEW_VERSION/avalanchego-linux-amd64-$NEW_VERSION.tar.gz
tar -xzf avalanchego-linux-amd64-$NEW_VERSION.tar.gz

# Step 3: Stop node (minimize downtime)
echo "Stopping node..."
sudo systemctl stop avalanchego

# Step 4: Replace binary
echo "Installing new version..."
sudo cp /tmp/avalanchego-$NEW_VERSION/avalanchego /usr/local/bin/avalanchego

# Step 5: Start node immediately
echo "Starting node..."
sudo systemctl start avalanchego

# Step 6: Wait for startup
echo "Waiting for node to start..."
sleep 10

# Step 7: Verify health
echo "Checking node health..."
for i in {1..30}; do
    HEALTH=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"health.health"}' \
        -H 'content-type:application/json' http://127.0.0.1:9650/ext/health 2>/dev/null | jq -r '.result.healthy')
    if [ "$HEALTH" = "true" ]; then
        echo "Node is healthy!"
        break
    fi
    echo "Waiting for node to become healthy... ($i/30)"
    sleep 10
done

# Step 8: Verify version
echo "Verifying version..."
curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.getNodeVersion"}' \
    -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq '.result'

echo "=== Upgrade Complete ==="
```

### Rollback Procedure

```bash
# If upgrade fails, rollback immediately
sudo systemctl stop avalanchego

# Restore previous binary
sudo cp /backup/avalanchego-previous /usr/local/bin/avalanchego

# Start node
sudo systemctl start avalanchego

# Verify node is working
sleep 30
curl -s http://127.0.0.1:9650/ext/health
```

### Mandatory Network Upgrades

Some upgrades are mandatory and have deadlines. Check:

```bash
# Check if upgrade is required
curl -s -X POST --data '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"info.upgrades"
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq
```

**Always monitor**: https://github.com/ava-labs/avalanchego/releases for mandatory upgrades.

---

## Handling Missed Blocks & Database Corruption

A common issue during upgrades: the node misses blocks during the restart window, causing database corruption or sync issues. Here's how to detect, prevent, and recover.

### Symptoms of Missed Block Corruption

```bash
# Check for these warning signs:

# 1. Node stuck at a specific block height
curl -s -X POST --data '{
    "jsonrpc":"2.0","id":1,
    "method":"eth_blockNumber"
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/C/rpc | jq -r '.result'
# Run multiple times - if not incrementing, node may be stuck

# 2. Health check failing
curl -s -X POST --data '{
    "jsonrpc":"2.0","id":1,
    "method":"health.health"
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/health | jq '.result'
# Look for: "healthy": false

# 3. Errors in logs
sudo journalctl -u avalanchego --since "30 minutes ago" | grep -iE "missing|corrupt|invalid|mismatch|gap|discontin"

# 4. Bootstrap keeps restarting
sudo journalctl -u avalanchego | grep -i "restarting bootstrap\|bootstrap failed"

# 5. Block verification errors
sudo journalctl -u avalanchego | grep -iE "block .* failed verification\|parent .* not found\|unknown ancestor"
```

### Common Error Messages

| Error | Meaning | Solution |
|-------|---------|----------|
| `missing trie node` | State data corrupted | Resync C-Chain or enable state-sync |
| `parent block unknown` | Block gap in database | Resync affected chain |
| `block X failed verification` | Invalid block in DB | Resync from before block X |
| `discontinuous chain` | Missing blocks | Resync affected chain |
| `leveldb: corruption` | Database file corruption | Full database resync |
| `snapshot is not available` | State sync data missing | Disable state-sync or resync |

### Prevention: Zero-Downtime Upgrade Strategy

For validators where every block matters:

```bash
#!/bin/bash
# zero-downtime-upgrade.sh
# Strategy: Use a standby node to minimize missed blocks

set -e
NEW_VERSION="v1.11.x"

echo "=== Zero-Downtime Upgrade Strategy ==="

# OPTION 1: If you have a standby node
# 1. Upgrade standby node first
# 2. Wait for standby to sync
# 3. Switch DNS/load balancer to standby
# 4. Upgrade primary node
# 5. Switch back when primary is synced

# OPTION 2: Single node - minimize downtime
# Pre-download everything before stopping

echo "Step 1: Pre-download new version (node still running)..."
cd /tmp
wget -q https://github.com/ava-labs/avalanchego/releases/download/$NEW_VERSION/avalanchego-linux-amd64-$NEW_VERSION.tar.gz
tar -xzf avalanchego-linux-amd64-$NEW_VERSION.tar.gz
echo "Download complete."

echo "Step 2: Verify download integrity..."
# Check binary works
/tmp/avalanchego-$NEW_VERSION/avalanchego --version

echo "Step 3: Graceful shutdown (let node finish current work)..."
# Send SIGTERM for graceful shutdown
sudo systemctl stop avalanchego
# Wait for clean shutdown (check logs)
sleep 5

echo "Step 4: Quick binary swap..."
sudo cp /tmp/avalanchego-$NEW_VERSION/avalanchego /usr/local/bin/avalanchego

echo "Step 5: Immediate restart..."
sudo systemctl start avalanchego

echo "Step 6: Verify health..."
sleep 15
for i in {1..60}; do
    HEALTH=$(curl -s --max-time 5 -X POST --data '{"jsonrpc":"2.0","id":1,"method":"health.health"}' \
        -H 'content-type:application/json' http://127.0.0.1:9650/ext/health 2>/dev/null | jq -r '.result.healthy' 2>/dev/null)

    if [ "$HEALTH" = "true" ]; then
        echo "✓ Node healthy after $((i*5)) seconds"
        break
    fi

    if [ $i -eq 60 ]; then
        echo "⚠ Node not healthy after 5 minutes - check logs!"
        sudo journalctl -u avalanchego --since "5 minutes ago" | tail -50
    fi

    sleep 5
done

# Verify block height is advancing
echo "Step 7: Verify blocks advancing..."
BLOCK1=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber"}' \
    -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/C/rpc | jq -r '.result')
sleep 10
BLOCK2=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber"}' \
    -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/C/rpc | jq -r '.result')

if [ "$BLOCK1" != "$BLOCK2" ]; then
    echo "✓ Blocks advancing: $BLOCK1 → $BLOCK2"
else
    echo "⚠ Blocks not advancing - may need investigation"
fi

echo "=== Upgrade Complete ==="
```

### Recovery: Partial Chain Resync (Faster)

If only one chain is corrupted, you don't need full resync:

```bash
#!/bin/bash
# partial-resync.sh - Resync only the corrupted chain

CORRUPTED_CHAIN="C"  # C, X, or P

echo "=== Partial Chain Resync: $CORRUPTED_CHAIN-Chain ==="

# 1. Stop node
sudo systemctl stop avalanchego

# 2. Backup staking keys (always!)
cp -r ~/.avalanchego/staking /tmp/staking-backup-$(date +%s)

# 3. Remove only the corrupted chain's data
case $CORRUPTED_CHAIN in
    C)
        echo "Removing C-Chain (coreth) data..."
        rm -rf ~/.avalanchego/db/coreth/
        # Also remove C-Chain state if exists
        rm -rf ~/.avalanchego/db/*/coreth/ 2>/dev/null
        ;;
    X)
        echo "Removing X-Chain (avm) data..."
        rm -rf ~/.avalanchego/db/avm/
        rm -rf ~/.avalanchego/db/*/avm/ 2>/dev/null
        ;;
    P)
        echo "Removing P-Chain (platformvm) data..."
        rm -rf ~/.avalanchego/db/platformvm/
        rm -rf ~/.avalanchego/db/*/platformvm/ 2>/dev/null
        ;;
esac

# 4. Ensure state-sync is enabled for faster recovery
cat > ~/.avalanchego/configs/chains/C/config.json << 'EOF'
{
  "state-sync-enabled": true,
  "pruning-enabled": true
}
EOF

# 5. Restart - will resync only the removed chain
echo "Starting node - will resync $CORRUPTED_CHAIN-Chain..."
sudo systemctl start avalanchego

# 6. Monitor resync progress
echo "Monitoring resync (Ctrl+C to stop monitoring)..."
while true; do
    BOOTSTRAPPED=$(curl -s -X POST --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"info.isBootstrapped\",\"params\":{\"chain\":\"$CORRUPTED_CHAIN\"}}" \
        -H 'content-type:application/json' http://127.0.0.1:9650/ext/info 2>/dev/null | jq -r '.result.isBootstrapped' 2>/dev/null)

    if [ "$BOOTSTRAPPED" = "true" ]; then
        echo "✓ $CORRUPTED_CHAIN-Chain resync complete!"
        break
    fi

    echo "$(date): $CORRUPTED_CHAIN-Chain still syncing..."
    sleep 60
done
```

### Recovery: State Sync Recovery

If state is corrupted but you want to avoid full historical sync:

```bash
# Force state sync to latest state (loses old state history but fast)

# 1. Stop node
sudo systemctl stop avalanchego

# 2. Enable state sync with specific settings
cat > ~/.avalanchego/configs/chains/C/config.json << 'EOF'
{
  "state-sync-enabled": true,
  "state-sync-skip-resume": true,
  "state-sync-min-blocks": 0,
  "pruning-enabled": true,
  "populate-missing-tries": false,
  "populate-missing-tries-parallelism": 0
}
EOF

# 3. Remove problematic state data
rm -rf ~/.avalanchego/db/coreth/state/
rm -rf ~/.avalanchego/db/coreth/trie/

# 4. Restart
sudo systemctl start avalanchego

# 5. After synced, you can revert config if needed
```

### Recovery: Full Database Reset (Last Resort)

> **DESTRUCTIVE OPERATION - DATA LOSS**
>
> This procedure **permanently deletes all blockchain data**. The node must re-sync from scratch (2-6 hours with state-sync, days without).
>
> **Before proceeding:**
> - [ ] **BACKUP STAKING KEYS** - These are NOT recoverable if lost
> - [ ] **BACKUP CONFIGS** - Save your custom configurations
> - [ ] **VERIFY BACKUPS EXIST** - Check backup directory has files
> - [ ] **CONFIRM THIS IS NECESSARY** - Try partial recovery first

```bash
#!/bin/bash
# full-reset.sh - Complete database reset

echo "=== FULL DATABASE RESET ==="
echo "⚠ WARNING: This will delete all chain data and require full resync!"
echo "Press Ctrl+C within 10 seconds to cancel..."
sleep 10

# 1. Stop node
sudo systemctl stop avalanchego

# 2. CRITICAL: Backup staking keys
BACKUP_DIR="/backup/avalanche-keys-$(date +%Y%m%d-%H%M%S)"
mkdir -p $BACKUP_DIR
cp -r ~/.avalanchego/staking $BACKUP_DIR/
cp -r ~/.avalanchego/configs $BACKUP_DIR/
echo "✓ Keys backed up to: $BACKUP_DIR"

# 3. Verify backup
if [ -f "$BACKUP_DIR/staking/staker.key" ] && [ -f "$BACKUP_DIR/staking/staker.crt" ]; then
    echo "✓ Staking keys verified"
else
    echo "✗ BACKUP FAILED - ABORTING!"
    exit 1
fi

# 4. Remove database
rm -rf ~/.avalanchego/db

# 5. Optimize config for fast resync
cat > ~/.avalanchego/configs/chains/C/config.json << 'EOF'
{
  "state-sync-enabled": true,
  "pruning-enabled": true
}
EOF

# 6. Restart
sudo systemctl start avalanchego

echo "Node restarting with fresh database..."
echo "Use 'sudo journalctl -u avalanchego -f' to monitor progress"
echo "State sync typically takes 2-6 hours"
```

### Recovery: Specific Block Height Issues

```bash
# If you know the corruption started at a specific block:

# 1. Check current block vs network
LOCAL_BLOCK=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber"}' \
    -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/C/rpc | jq -r '.result')
echo "Local block: $((LOCAL_BLOCK))"

# Compare with public RPC
NETWORK_BLOCK=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber"}' \
    -H 'content-type:application/json' https://api.avax.network/ext/bc/C/rpc | jq -r '.result')
echo "Network block: $((NETWORK_BLOCK))"

DIFF=$((NETWORK_BLOCK - LOCAL_BLOCK))
echo "Behind by: $DIFF blocks"

# If only slightly behind, node might catch up on its own
# If stuck at same block, corruption likely - use partial resync
```

### Post-Recovery Validation

```bash
#!/bin/bash
# validate-recovery.sh - Run after any recovery procedure

echo "=== Post-Recovery Validation ==="

# 1. Check all chains bootstrapped
echo "Checking bootstrap status..."
ALL_GOOD=true
for chain in X P C; do
    STATUS=$(curl -s -X POST --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"info.isBootstrapped\",\"params\":{\"chain\":\"$chain\"}}" \
        -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq -r '.result.isBootstrapped')
    if [ "$STATUS" = "true" ]; then
        echo "  ✓ $chain-Chain: bootstrapped"
    else
        echo "  ✗ $chain-Chain: NOT bootstrapped"
        ALL_GOOD=false
    fi
done

# 2. Check health
echo "Checking node health..."
HEALTH=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"health.health"}' \
    -H 'content-type:application/json' http://127.0.0.1:9650/ext/health | jq -r '.result.healthy')
if [ "$HEALTH" = "true" ]; then
    echo "  ✓ Node healthy"
else
    echo "  ✗ Node NOT healthy"
    ALL_GOOD=false
fi

# 3. Check peer connections
PEERS=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.peers"}' \
    -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq -r '.result.numPeers')
echo "  Peers connected: $PEERS"
if [ "$PEERS" -lt 10 ]; then
    echo "  ⚠ Low peer count"
fi

# 4. Check blocks advancing
echo "Checking if blocks are advancing..."
BLOCK1=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber"}' \
    -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/C/rpc | jq -r '.result')
sleep 15
BLOCK2=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber"}' \
    -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/C/rpc | jq -r '.result')

if [ "$BLOCK1" != "$BLOCK2" ]; then
    echo "  ✓ Blocks advancing: $((16#${BLOCK1:2})) → $((16#${BLOCK2:2}))"
else
    echo "  ✗ Blocks NOT advancing - node may be stuck"
    ALL_GOOD=false
fi

# 5. For validators - check validator status
echo "Checking validator status..."
NODE_ID=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.getNodeID"}' \
    -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq -r '.result.nodeID')

VALIDATOR=$(curl -s -X POST --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"platform.getCurrentValidators\",\"params\":{\"nodeIDs\":[\"$NODE_ID\"]}}" \
    -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/P | jq '.result.validators[0]')

if [ "$VALIDATOR" != "null" ] && [ -n "$VALIDATOR" ]; then
    CONNECTED=$(echo $VALIDATOR | jq -r '.connected')
    UPTIME=$(echo $VALIDATOR | jq -r '.uptime')
    echo "  ✓ Validator active"
    echo "    Connected: $CONNECTED"
    echo "    Uptime: $UPTIME"
else
    echo "  ℹ Not a validator or validator info unavailable"
fi

# Summary
echo ""
if [ "$ALL_GOOD" = true ]; then
    echo "=== ✓ Recovery validation PASSED ==="
else
    echo "=== ✗ Recovery validation FAILED - check issues above ==="
fi
```

### Preventing Future Corruption

```json
// Add to ~/.avalanchego/config.json for safer operation:
{
  // Graceful shutdown timeout (gives time to finish writes)
  "shutdown-timeout": "30s",
  "shutdown-wait": "5s",

  // Database safety
  "db-config": {
    "leveldb": {
      "sync-writes": true
    }
  }
}
```

```bash
# System-level protections:

# 1. Use UPS for power protection
# 2. Enable filesystem journaling (ext4 default)
# 3. Don't force kill the node - always use systemctl stop
# 4. Monitor disk health
sudo smartctl -H /dev/sda

# 5. Set up automatic backups of staking keys
cat > /etc/cron.daily/backup-avalanche-keys << 'EOF'
#!/bin/bash
cp -r /home/avalanche/.avalanchego/staking /backup/staking-$(date +%Y%m%d)
find /backup -name "staking-*" -mtime +30 -delete
EOF
chmod +x /etc/cron.daily/backup-avalanche-keys
```

---

## Node Type Conversions

### Converting to Archive Node

Archive nodes store complete blockchain history (no pruning).

```bash
# 1. Stop node
sudo systemctl stop avalanchego

# 2. Update C-Chain config
# ~/.avalanchego/configs/chains/C/config.json
cat > ~/.avalanchego/configs/chains/C/config.json << 'EOF'
{
  "pruning-enabled": false,
  "state-sync-enabled": false,
  "offline-pruning-enabled": false,
  "populate-missing-tries": true,
  "eth-apis": [
    "eth",
    "eth-filter",
    "net",
    "web3",
    "debug",
    "internal-eth",
    "internal-blockchain",
    "internal-transaction",
    "internal-tx-pool",
    "internal-account"
  ]
}
EOF

# 3. If previously pruned, you need to resync from scratch
# WARNING: This deletes existing data!
# rm -rf ~/.avalanchego/db/

# 4. Start node (will take days to sync full history)
sudo systemctl start avalanchego
```

**Archive Node Requirements**:
- Storage: 4+ TB NVMe (and growing)
- Time: Several days to sync from genesis
- Use case: Historical queries, block explorers, analytics

### Converting to Public RPC Node

Public RPC nodes serve API requests from external clients.

```bash
# 1. Update main config for public access
cat > ~/.avalanchego/config.json << 'EOF'
{
  "network-id": "mainnet",
  "http-host": "0.0.0.0",
  "http-port": 9650,
  "http-allowed-origins": ["*"],
  "http-allowed-hosts": ["*"],
  "api-admin-enabled": false,
  "api-keystore-enabled": false,
  "api-ipcs-enabled": false,
  "api-metrics-enabled": true,
  "index-enabled": true,
  "state-sync-enabled": true,
  "db-dir": "/data/avalanche/db",
  "log-dir": "/data/avalanche/logs"
}
EOF

# 2. Configure C-Chain for RPC
cat > ~/.avalanchego/configs/chains/C/config.json << 'EOF'
{
  "state-sync-enabled": true,
  "pruning-enabled": true,
  "eth-apis": [
    "eth",
    "eth-filter",
    "net",
    "web3",
    "txpool",
    "internal-eth",
    "internal-blockchain",
    "internal-transaction"
  ],
  "tx-lookup-limit": 2350000,
  "local-txs-enabled": false,
  "api-max-duration": "0",
  "ws-cpu-refill-rate": "0",
  "ws-cpu-max-stored": "0",
  "api-max-blocks-per-request": 0,
  "allow-unfinalized-queries": false,
  "accepted-cache-size": 32
}
EOF

# 3. Set up nginx reverse proxy (recommended)
sudo apt install nginx -y

cat > /etc/nginx/sites-available/avalanche << 'EOF'
upstream avalanche {
    server 127.0.0.1:9650;
}

server {
    listen 443 ssl http2;
    server_name rpc.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/rpc.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/rpc.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://avalanche;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;

        # Rate limiting
        limit_req zone=rpc burst=50 nodelay;
    }
}

limit_req_zone $binary_remote_addr zone=rpc:10m rate=100r/s;
EOF

sudo ln -s /etc/nginx/sites-available/avalanche /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# 4. Restart node
sudo systemctl restart avalanchego
```

### Converting Regular Node to Validator

```bash
# 1. Ensure node is fully synced
curl -s -X POST --data '{
    "jsonrpc":"2.0","id":1,
    "method":"info.isBootstrapped",
    "params":{"chain":"P"}
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/info

# 2. Get your Node ID
NODE_ID=$(curl -s -X POST --data '{
    "jsonrpc":"2.0","id":1,
    "method":"info.getNodeID"
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq -r '.result.nodeID')
echo "Your Node ID: $NODE_ID"

# 3. Verify staking keys exist
ls -la ~/.avalanchego/staking/
# Should show: staker.crt and staker.key

# 4. Use Core Wallet to stake
# - Go to core.app
# - Connect wallet with 2000+ AVAX
# - Navigate to Stake > Validate
# - Enter your Node ID
# - Set stake amount and duration (minimum 2 weeks, maximum 1 year)
# - Confirm transaction

# 5. Verify validator status (after tx confirms)
curl -s -X POST --data '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"platform.getCurrentValidators",
    "params":{"subnetID":"11111111111111111111111111111111LpoYY"}
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/P | \
    jq '.result.validators[] | select(.nodeID=="'$NODE_ID'")'
```

### Validator Migration to New Server

When migrating a validator to a new server (hardware upgrade, cloud migration, etc.), you **cannot** run two nodes with the same NodeID simultaneously. This causes connection failures and can affect validator uptime.

**Key Concept**: NodeID is derived from your staking keys (`staker.key` and `staker.crt`). If two nodes have the same staking keys, they have the same NodeID, and the network treats them as a single misbehaving node.

#### Why Same NodeID on Multiple Nodes Fails

```
Node #1 (Original)          Network                Node #2 (New)
    │                          │                        │
    │ ── NodeID-xyz ─────────▶ │ ◀── NodeID-xyz ─────── │
    │                          │                        │
    └──────── CONFLICT! ───────┴───── Connection fails ─┘

The network sees the same NodeID from two different IPs,
causing both nodes to have degraded connectivity.
```

#### Step-by-Step Migration Procedure

```bash
# ============================================
# VALIDATOR MIGRATION - ZERO DOWNTIME
# ============================================

# --- ON NEW SERVER (Node #2) ---

# 1. Install AvalancheGo (same version as Node #1)
wget -nd -m https://raw.githubusercontent.com/ava-labs/avalanche-docs/master/scripts/avalanchego-installer.sh
chmod 755 avalanchego-installer.sh
./avalanchego-installer.sh

# 2. Start node WITHOUT staking keys (generates new temporary NodeID)
#    This lets it bootstrap as a non-validator
sudo systemctl start avalanchego

# 3. Wait for full bootstrap (this is the longest step)
watch -n 30 'curl -s -X POST --data '\''{"jsonrpc":"2.0","id":1,"method":"info.isBootstrapped","params":{"chain":"C"}}'\'' \
    -H "content-type:application/json" http://127.0.0.1:9650/ext/info | jq'

# Wait until ALL chains show "isBootstrapped": true
# P-Chain, X-Chain, and C-Chain must all be synced

# 4. Verify node is healthy and synced
curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"health.health"}' \
    -H 'content-type:application/json' http://127.0.0.1:9650/ext/health | jq '.result.healthy'

# --- ON OLD SERVER (Node #1) ---

# 5. Stop the old validator
sudo systemctl stop avalanchego

# 6. Backup staking keys
BACKUP_DIR="/tmp/validator-migration-$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR
cp -r ~/.avalanchego/staking $BACKUP_DIR/
echo "Staking keys backed up to: $BACKUP_DIR"

# 7. Copy staking keys to new server
scp -r ~/.avalanchego/staking/* user@new-server:~/.avalanchego/staking/

# 8. IMPORTANT: Remove staking keys from old server to prevent accidental restart
mv ~/.avalanchego/staking ~/.avalanchego/staking.old.$(date +%s)

# --- ON NEW SERVER (Node #2) ---

# 9. Stop the new node
sudo systemctl stop avalanchego

# 10. Verify staking keys are in place
ls -la ~/.avalanchego/staking/
# Should show: staker.crt and staker.key

# 11. Set correct permissions
chmod 600 ~/.avalanchego/staking/staker.key
chmod 644 ~/.avalanchego/staking/staker.crt

# 12. Start the new validator
sudo systemctl start avalanchego

# 13. Verify NodeID matches your validator
NODE_ID=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.getNodeID"}' \
    -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq -r '.result.nodeID')
echo "Node ID: $NODE_ID"

# 14. Verify validator is connected and active
curl -s -X POST --data '{
    "jsonrpc":"2.0","id":1,
    "method":"platform.getCurrentValidators",
    "params":{"nodeIDs":["'$NODE_ID'"]}
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/P | jq '.result.validators[0]'
```

#### Quick Checklist

| Step | Action | Verify |
|------|--------|--------|
| 1 | Install AvalancheGo on new server | `avalanchego --version` |
| 2 | Start new node (no staking keys) | `info.getNodeID` shows new ID |
| 3 | Wait for bootstrap | All chains `isBootstrapped: true` |
| 4 | Stop OLD validator | `systemctl status` shows stopped |
| 5 | Copy staking keys to new server | `ls ~/.avalanchego/staking/` |
| 6 | Remove keys from old server | Prevents accidental restart |
| 7 | Start NEW validator | Check NodeID matches original |
| 8 | Verify validator active | `platform.getCurrentValidators` |

#### Generating a New NodeID

> **WARNING: Removing staking keys changes your NodeID permanently**
>
> If this node is a **validator**, removing staking keys will:
> - Create a completely new NodeID
> - **Lose all staking rewards** if current keys are not backed up
> - Require re-registering as a new validator
>
> **Only do this for non-validator nodes OR if you have backed up the keys**

If you need a fresh NodeID (e.g., for a non-validator node), simply remove or rename the staking directory:

```bash
# Stop node
sudo systemctl stop avalanchego

# FIRST: Backup existing keys if you might need them
cp -r ~/.avalanchego/staking /backup/staking-$(date +%Y%m%d)

# Option A: Remove staking keys (new ones auto-generated on start)
rm -rf ~/.avalanchego/staking/

# Option B (SAFER): Rename to preserve old keys
mv ~/.avalanchego/staking ~/.avalanchego/staking.old

# Start node - new NodeID will be generated
sudo systemctl start avalanchego

# Get new NodeID
curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.getNodeID"}' \
    -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq -r '.result.nodeID'
```

#### Troubleshooting Migration

| Issue | Cause | Solution |
|-------|-------|----------|
| Both nodes can't connect | Same NodeID running on both | Stop one node completely |
| New node won't validate | Wrong staking keys | Verify `staker.key` matches original |
| NodeID doesn't match | Copied wrong files | Check `staker.key` and `staker.crt` |
| Uptime dropping | Extended downtime during migration | Bootstrap new node BEFORE stopping old |
| "duplicate node ID" error | Both nodes running | Ensure only one node has staking keys |

#### Diagnosing Duplicate NodeID Issues

**If a user mentions ANY of these symptoms during validator migration, suspect duplicate NodeID:**

| User Reports | What's Actually Happening |
|--------------|---------------------------|
| "Connection issues on both nodes" | Same NodeID = network confused |
| "Node can't find peers" | Peers reject duplicate identity |
| "Validator shows offline" | Network can't route to conflicting IPs |
| "Copied staking keys, now nothing works" | Both nodes broadcasting same NodeID |
| "Started new node before stopping old" | Race condition with same identity |
| "Sync was fine, then connectivity broke" | Happened when keys were copied |

**Key diagnostic questions:**
1. Are you running two nodes simultaneously?
2. Did you copy staking keys from another node?
3. Did you stop the old node BEFORE starting the new one with the same keys?

If YES to #1 or #2 and NO to #3 → **Duplicate NodeID problem**

---

### Converting Archive to Pruned Node

```bash
# 1. Stop node
sudo systemctl stop avalanchego

# 2. Enable pruning in C-Chain config
cat > ~/.avalanchego/configs/chains/C/config.json << 'EOF'
{
  "pruning-enabled": true,
  "offline-pruning-enabled": true,
  "offline-pruning-bloom-filter-size": 512,
  "offline-pruning-data-directory": "/data/avalanche/offline-pruning",
  "state-sync-enabled": true
}
EOF

# 3. Run offline pruning (can take hours)
mkdir -p /data/avalanche/offline-pruning
avalanchego --offline-pruning-enabled=true \
    --data-dir=~/.avalanchego \
    --offline-pruning-data-directory=/data/avalanche/offline-pruning

# 4. Start node normally
sudo systemctl start avalanchego
```

---

## Advanced Configuration

### Performance Tuning

```json
// ~/.avalanchego/config.json - High Performance
{
  "network-id": "mainnet",
  "db-type": "leveldb",
  "db-dir": "/data/avalanche/db",

  // Network tuning
  "network-peer-list-gossip-frequency": "250ms",
  "network-peer-list-gossip-size": 50,
  "network-peer-list-staker-gossip-fraction": 2,

  // Connection limits
  "inbound-connection-throttling-cooldown": "10s",
  "inbound-connection-throttling-max-conns-per-sec": 256,
  "outbound-connection-throttling-rps": 50,

  // Consensus tuning
  "consensus-shutdown-timeout": "30s",
  "consensus-gossip-frequency": "10s",

  // Bootstrap optimization
  "bootstrap-beacon-connection-timeout": "1m",
  "bootstrap-max-time-get-ancestors": "50ms",
  "bootstrap-ancestors-max-containers-sent": 2000,
  "bootstrap-ancestors-max-containers-received": 2000,

  // API performance
  "api-max-duration": "0",

  // Logging (reduce for performance)
  "log-level": "info",
  "log-display-level": "warn"
}
```

### Memory Optimization

```json
// For memory-constrained environments (16GB RAM)
{
  "state-sync-enabled": true,
  "pruning-enabled": true,

  // Reduce caches
  "db-config": {
    "leveldb": {
      "write-buffer-size": 67108864,
      "block-cache-capacity": 134217728
    }
  }
}
```

### C-Chain Advanced Config

```json
// ~/.avalanchego/configs/chains/C/config.json
{
  // Sync settings
  "state-sync-enabled": true,
  "state-sync-min-blocks": 300000,
  "state-sync-skip-resume": false,

  // Pruning
  "pruning-enabled": true,
  "offline-pruning-enabled": false,
  "accepted-cache-size": 32,

  // Transaction pool
  "tx-pool-journal": "transactions.rlp",
  "tx-pool-rejournal": "1h",
  "tx-pool-price-limit": 25000000000,
  "tx-pool-price-bump": 10,
  "tx-pool-account-slots": 16,
  "tx-pool-global-slots": 5120,
  "tx-pool-account-queue": 64,
  "tx-pool-global-queue": 1024,

  // API settings
  "rpc-gas-cap": 50000000,
  "rpc-tx-fee-cap": 100,
  "tx-lookup-limit": 0,

  // Debug APIs (enable for debugging only)
  "eth-apis": [
    "eth", "eth-filter", "net", "web3",
    "internal-eth", "internal-blockchain", "internal-transaction"
  ],

  // Performance
  "continuous-profiler-dir": "",
  "continuous-profiler-frequency": "15m",
  "continuous-profiler-max-files": 5,

  // Metrics
  "metrics-enabled": true,
  "metrics-expensive-enabled": false
}
```

### Subnet/L1 Validator Config

```json
// ~/.avalanchego/configs/subnets/<subnet-id>.json
{
  "validatorOnly": false,
  "proposerMinBlockDelay": "0s",
  "proposerNumHistoricalBlocks": 512,

  "consensusParameters": {
    "k": 20,
    "alpha": 15,
    "betaVirtuous": 15,
    "betaRogue": 20,
    "concurrentRepolls": 4,
    "optimalProcessing": 50,
    "maxOutstandingItems": 1024,
    "maxItemProcessingTime": "2m"
  },

  "gossipConfig": {
    "acceptedFrontierValidatorSize": 0,
    "acceptedFrontierNonValidatorSize": 0,
    "acceptedFrontierPeerSize": 15,
    "onAcceptValidatorSize": 0,
    "onAcceptNonValidatorSize": 0,
    "onAcceptPeerSize": 10
  }
}
```

---

## Database Management

### Check Database Size

```bash
# Total database size
du -sh ~/.avalanchego/db/

# Per-chain breakdown
du -sh ~/.avalanchego/db/*/

# Disk usage monitoring
df -h /data/avalanche/
```

### Database Corruption Recovery

```bash
# 1. Stop the node
sudo systemctl stop avalanchego

# 2. Check for corruption
# Look for errors in logs
sudo journalctl -u avalanchego | grep -i "corrupt\|error\|panic"

# 3. Try repair (C-Chain leveldb)
# WARNING: Backup first!
cp -r ~/.avalanchego/db ~/.avalanchego/db.backup

# 4. If repair fails, resync specific chain
# Delete only the corrupted chain's data
rm -rf ~/.avalanchego/db/coreth/  # For C-Chain

# 5. Restart - will resync C-Chain
sudo systemctl start avalanchego
```

### Full Database Resync

```bash
# When to resync:
# - Database corruption
# - Converting to archive node
# - Major version upgrade requiring resync

# 1. Stop node
sudo systemctl stop avalanchego

# 2. Backup staking keys (CRITICAL!)
cp -r ~/.avalanchego/staking /secure-backup/
cp -r ~/.avalanchego/configs /secure-backup/

# 3. Remove database (keeps config and keys)
rm -rf ~/.avalanchego/db

# 4. Start node - will sync from network
sudo systemctl start avalanchego

# 5. Monitor sync progress
watch -n 60 'curl -s -X POST --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"info.isBootstrapped\",\"params\":{\"chain\":\"C\"}}" -H "content-type:application/json" http://127.0.0.1:9650/ext/info'
```

### State Sync vs Full Sync

```json
// State sync (fast, recent state only) - DEFAULT
{
  "state-sync-enabled": true
}

// Full sync (slow, complete history) - for archive nodes
{
  "state-sync-enabled": false
}
```

| Method | Time | Storage | Historical Data |
|--------|------|---------|-----------------|
| State Sync | ~4 hours | ~400 GB | Recent only |
| Full Sync | ~3-7 days | ~1-4 TB | Complete |

---

## Staking Lifecycle Management

### Check Current Stake Status

```bash
# Get your node's validation info
NODE_ID=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.getNodeID"}' \
    -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq -r '.result.nodeID')

curl -s -X POST --data '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"platform.getCurrentValidators",
    "params":{"subnetID":"11111111111111111111111111111111LpoYY","nodeIDs":["'$NODE_ID'"]}
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/P | jq '.result.validators[0]'
```

### Check Pending Validator (After Staking TX)

```bash
curl -s -X POST --data '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"platform.getPendingValidators",
    "params":{"subnetID":"11111111111111111111111111111111LpoYY"}
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/P | jq
```

### Check Validator Uptime

```bash
curl -s -X POST --data '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"info.uptime"
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq
```

### Extending Validation Period

You cannot extend an existing validation period. Instead:
1. Wait for current period to end
2. Restake with new end time
3. Or add a new validation period that starts when current one ends

### Adding More Stake (Delegation)

```bash
# You can add delegators to your validator
# Max delegation: 5x your validator stake
# Use Core Wallet: Stake > Delegate
```

### Unstaking / End of Validation

```bash
# Stake is automatically returned when:
# 1. Validation period ends
# 2. Validator is removed from subnet

# Check when your validation ends
curl -s -X POST --data '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"platform.getCurrentValidators",
    "params":{"nodeIDs":["YOUR_NODE_ID"]}
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/P | \
    jq '.result.validators[0].endTime'

# Convert timestamp to human readable
date -d @TIMESTAMP
```

---

## Networking

### Firewall Configuration

```bash
# Allow P2P traffic
sudo ufw allow 9651/tcp

# Allow API access (restrict in production!)
sudo ufw allow 9650/tcp

# Enable firewall
sudo ufw enable
```

### Port Forwarding

| Port | Protocol | Purpose |
|------|----------|---------|
| 9651 | TCP | P2P/Staking |
| 9650 | TCP | HTTP API |

> **Important:** AvalancheGo uses **TCP only** - there is no UDP component. If you see UDP not listening on port 9651, that's expected behavior, not a problem. Only TCP connectivity matters for peer communication.

### NAT Configuration

If behind NAT, configure port forwarding on your router:
- Forward external port 9651 → internal:9651

Add to config:
```json
{
  "public-ip": "YOUR_PUBLIC_IP",
  "dynamic-public-ip": "ifconfigco"
}
```

---

## Troubleshooting

### Node Not Syncing

```bash
# Check peer connections
curl -s -X POST --data '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"info.peers"
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq '.result.numPeers'

# If no/few peers:
# 1. Check firewall
sudo ufw status
sudo ufw allow 9651/tcp

# 2. Check port forwarding (if behind NAT)
curl -s https://ifconfig.me  # Get public IP
# Ensure router forwards port 9651 to your machine

# 3. Add bootstrap nodes manually
avalanchego --bootstrap-ips="..." --bootstrap-ids="..."

# 4. Check if banned
curl -s -X POST --data '{
    "jsonrpc":"2.0","id":1,
    "method":"info.peers"
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq '.result.peers[].ip'
```

### Stuck Bootstrapping

```bash
# Check bootstrap progress
curl -s -X POST --data '{
    "jsonrpc":"2.0","id":1,
    "method":"info.isBootstrapped",
    "params":{"chain":"X"}
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/info

# Check each chain
for chain in X P C; do
    echo -n "$chain-Chain: "
    curl -s -X POST --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"info.isBootstrapped\",\"params\":{\"chain\":\"$chain\"}}" \
        -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq -r '.result.isBootstrapped'
done

# If stuck, check logs for errors
sudo journalctl -u avalanchego --since "10 minutes ago" | grep -i error

# Try enabling state sync (faster)
# Add to config: "state-sync-enabled": true
```

### High Memory Usage

```bash
# Check current memory
free -h
ps aux | grep avalanchego

# Optimize for lower memory:
# 1. Enable state sync
{
  "state-sync-enabled": true
}

# 2. Reduce caches in db-config
# 3. Disable unnecessary APIs
{
  "index-enabled": false,
  "api-keystore-enabled": false
}

# 4. Check for memory leaks
sudo journalctl -u avalanchego | grep -i "out of memory\|oom"
```

### High Disk Usage

```bash
# Check what's using space
du -sh ~/.avalanchego/db/*

# Enable pruning (C-Chain)
# ~/.avalanchego/configs/chains/C/config.json
{
  "pruning-enabled": true
}

# Run offline pruning to reclaim space
sudo systemctl stop avalanchego
avalanchego --offline-pruning-enabled=true
sudo systemctl start avalanchego
```

### Validator Uptime Issues

```bash
# Check uptime
curl -s -X POST --data '{
    "jsonrpc":"2.0","id":1,
    "method":"info.uptime"
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq

# Check if validator is connected
curl -s -X POST --data '{
    "jsonrpc":"2.0","id":1,
    "method":"platform.getCurrentValidators",
    "params":{"nodeIDs":["YOUR_NODE_ID"]}
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/P | jq '.result.validators[0].connected'

# Common causes of low uptime:
# 1. Network issues - check peer count
# 2. Node crashes - check logs
# 3. Slow block processing - upgrade hardware
# 4. Firewall blocking p2p - open port 9651
```

### Validator Not Responding / Offline

```bash
# Check validator status
curl -s -X POST --data '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"platform.getCurrentValidators",
    "params":{"subnetID":"11111111111111111111111111111111LpoYY"}
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/P | \
    jq '.result.validators[] | select(.nodeID=="YOUR_NODE_ID")'

# Verify staking keys exist and have correct permissions
ls -la ~/.avalanchego/staking/
# Should show: staker.crt and staker.key

# Verify keys match your node ID
openssl x509 -in ~/.avalanchego/staking/staker.crt -text -noout | grep -A1 "Subject:"

# If keys are missing/wrong, restore from backup
cp /backup/staker.* ~/.avalanchego/staking/
sudo systemctl restart avalanchego
```

### Connection Refused

```bash
# Check if node is running
sudo systemctl status avalanchego

# Check if process is listening
ss -tlnp | grep 9650

# Check if API is bound correctly
grep "http-host" ~/.avalanchego/config.json
# Should be "0.0.0.0" for external access

# Check firewall
sudo ufw status
sudo ufw allow 9650/tcp  # Only if needed externally

# Check for binding conflicts
sudo lsof -i :9650
```

### Node Keeps Crashing

```bash
# Check recent crashes
sudo journalctl -u avalanchego --since "1 hour ago" | grep -i "panic\|fatal\|crash"

# Check system resources
dmesg | grep -i "out of memory"
df -h  # Check disk space

# Common fixes:
# 1. Increase swap
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 2. Increase file descriptor limit
# Add to /etc/security/limits.conf:
# avalanche soft nofile 65535
# avalanche hard nofile 65535

# 3. Check for corrupted database
# May need to resync
```

### Subnet/L1 Not Syncing

```bash
# Check if subnet is being tracked
grep "track-subnets" ~/.avalanchego/config.json

# Verify VM plugin is installed
ls -la ~/.avalanchego/plugins/

# Check subnet bootstrap status
curl -s -X POST --data '{
    "jsonrpc":"2.0","id":1,
    "method":"info.isBootstrapped",
    "params":{"chain":"SUBNET_CHAIN_ID"}
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/info

# Check for VM errors
sudo journalctl -u avalanchego | grep -i "vm\|subnet" | tail -50
```

### API Rate Limiting / Slow Responses

```bash
# For RPC nodes serving many requests:

# 1. Remove API limits
{
  "api-max-duration": "0",
  "http-read-timeout": "30s",
  "http-write-timeout": "30s"
}

# 2. Optimize C-Chain
{
  "ws-cpu-refill-rate": "0",
  "ws-cpu-max-stored": "0",
  "api-max-blocks-per-request": 0
}

# 3. Use nginx for rate limiting instead
# 4. Add caching layer (Redis)
# 5. Scale horizontally with multiple nodes
```

### Recovering from Wrong Network

```bash
# If accidentally synced to wrong network:

# 1. Stop node
sudo systemctl stop avalanchego

# 2. Remove database
rm -rf ~/.avalanchego/db

# 3. Fix config
# Ensure "network-id": "mainnet" or "fuji"

# 4. Restart
sudo systemctl start avalanchego
```

---

## NAT, IPv6 & Connectivity Issues

NAT and networking issues are among the most common problems reported on GitHub.

### NAT Traversal Failures (GitHub Issue #335, #461)

**Symptoms:**
- Node visible for 1-2 days then goes offline
- High CPU usage (all cores maxed)
- Log shows: `NAT traversal has failed`
- Validator uptime drops

```bash
# Check if NAT is the issue
sudo journalctl -u avalanchego | grep -i "NAT"

# Solutions:

# Option 1: Set public IP explicitly (recommended)
# Add to ~/.avalanchego/config.json:
{
  "public-ip": "YOUR_PUBLIC_IP"
}

# Option 2: Use dynamic IP resolution
{
  "dynamic-public-ip": "ifconfigco"
}
# Other options: "opendns", "ifconfigme"

# Option 3: Disable NAT traversal entirely (if you have direct public IP)
{
  "nat-traversal-enabled": false,
  "public-ip": "YOUR_PUBLIC_IP"
}
```

### IPv6 Issues (GitHub Issue #3078)

**Problem:** Node prefers IPv6 and gets marked offline when IPv6 connectivity is poor.

```bash
# Check if using IPv6
curl -s localhost:9650/ext/info -X POST -H 'content-type:application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"info.getNodeIP"}' | jq

# Force IPv4 only - add to config:
{
  "public-ip": "YOUR_IPV4_ADDRESS"
}

# Or disable IPv6 at system level (if not needed)
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
```

### Port 9651 Connectivity Issues (GitHub Issue #442)

**Problem:** After enabling port forwarding, node fails to start.

```bash
# Verify port is open externally
# Visit: https://ismyportopen.com/ and check port 9651

# Common causes:
# 1. Another AvalancheGo instance using the port
sudo lsof -i :9651
# Kill any duplicate processes

# 2. Firewall blocking after forward
sudo ufw status
sudo ufw allow 9651/tcp

# 3. Router hairpin NAT not supported
# Solution: Use public IP in config instead of relying on NAT

# 4. ISP blocking port 9651
# Solution: Use a VPS or different network
```

### Checking Connectivity

```bash
#!/bin/bash
# check-connectivity.sh

echo "=== Avalanche Node Connectivity Check ==="

# 1. Get public IP
PUBLIC_IP=$(curl -s https://ifconfig.me)
echo "Public IP: $PUBLIC_IP"

# 2. Check port 9651 externally
echo -n "Port 9651 (P2P): "
nc -zv -w5 $PUBLIC_IP 9651 2>&1 | grep -q "succeeded" && echo "OPEN" || echo "CLOSED"

# 3. Check configured IP matches
CONFIGURED_IP=$(curl -s localhost:9650/ext/info -X POST -H 'content-type:application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"info.getNodeIP"}' 2>/dev/null | jq -r '.result.ip' | cut -d: -f1)
echo "Configured IP: $CONFIGURED_IP"

if [ "$PUBLIC_IP" != "$CONFIGURED_IP" ]; then
    echo "⚠ WARNING: Public IP doesn't match configured IP!"
    echo "  Add to config: \"public-ip\": \"$PUBLIC_IP\""
fi

# 4. Check peer count
PEERS=$(curl -s localhost:9650/ext/info -X POST -H 'content-type:application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"info.peers"}' 2>/dev/null | jq '.result.numPeers')
echo "Connected peers: $PEERS"

if [ "$PEERS" -lt 10 ]; then
    echo "⚠ Low peer count - may indicate connectivity issues"
fi
```

---

## Bootstrap Issues

Bootstrap problems are frequently reported (GitHub Issues #995, #1023, #947, #804).

### Bootstrap Takes Too Long

**Normal bootstrap times:**
| Method | Approximate Time |
|--------|-----------------|
| State Sync | 2-6 hours |
| Full Sync | 3-7 days |

```bash
# Check bootstrap progress
curl -s localhost:9650/ext/info -X POST -H 'content-type:application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"info.isBootstrapped","params":{"chain":"C"}}' | jq

# Monitor ETA in logs
sudo journalctl -u avalanchego | grep -i "ETA\|bootstrap"
```

**Speed up bootstrap:**
```json
// ~/.avalanchego/config.json
{
  "state-sync-enabled": true,
  "bootstrap-beacon-connection-timeout": "1m",
  "bootstrap-max-time-get-ancestors": "50ms",
  "bootstrap-ancestors-max-containers-sent": 2000,
  "bootstrap-ancestors-max-containers-received": 2000
}
```

### Bootstrap Never Finishes (GitHub Issue #1023)

**Symptoms:**
- C-Chain ETA keeps increasing
- Been bootstrapping for weeks
- Log shows constantly increasing job count

```bash
# Check if ETA is increasing
watch -n 60 'sudo journalctl -u avalanchego --since "1 minute ago" | grep -i "ETA"'

# If ETA keeps increasing, try:

# 1. Enable state sync (if not already)
# Add to C-Chain config:
{
  "state-sync-enabled": true,
  "state-sync-min-blocks": 0
}

# 2. Increase resources
# Ensure at least 16GB RAM and fast SSD

# 3. Nuclear option - fresh start with state sync
sudo systemctl stop avalanchego
rm -rf ~/.avalanchego/db
# Ensure state-sync-enabled: true
sudo systemctl start avalanchego
```

### Bootstrap Fails After Completion (GitHub Issue #804)

**Problem:** Node bootstraps successfully, but fails on restart with "Failed to connect to bootstrap nodes"

```bash
# Check for stale connections
sudo journalctl -u avalanchego | grep -i "failed to connect"

# Common causes:
# 1. Stale NodeID in database
# 2. Clock skew
# 3. Network config changed

# Fix: Verify clock sync
timedatectl status
sudo systemctl restart systemd-timesyncd

# If persists, check for duplicate node instances
ps aux | grep avalanchego
# Kill any extras

# Last resort: Remove network state but keep chain data
rm -rf ~/.avalanchego/db/network/
sudo systemctl restart avalanchego
```

### "API call rejected - chain not done bootstrapping" (GitHub Issue #507)

```bash
# This is normal during bootstrap - wait for completion
# Check progress:
for chain in X P C; do
    echo -n "$chain: "
    curl -s localhost:9650/ext/info -X POST -H 'content-type:application/json' \
        -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"info.isBootstrapped\",\"params\":{\"chain\":\"$chain\"}}" | jq -r '.result.isBootstrapped'
done
```

---

## Memory Issues (GitHub Issues #717, #240)

### Out of Memory / OOM Killed

**Minimum requirements:**
- Mainnet: 16GB RAM (32GB recommended)
- With state sync: 8GB minimum
- Archive node: 64GB+ recommended

```bash
# Check if OOM killed
dmesg | grep -i "out of memory"
sudo journalctl -k | grep -i "oom"

# Check current memory usage
free -h
ps aux --sort=-%mem | head -5

# Solutions:

# 1. Add swap space
sudo fallocate -l 16G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 2. Enable state sync to reduce memory
{
  "state-sync-enabled": true
}

# 3. Limit memory caches
# C-Chain config:
{
  "state-sync-enabled": true,
  "pruning-enabled": true,
  "accepted-cache-size": 16
}

# 4. Use systemd memory limits
sudo systemctl edit avalanchego
# Add:
[Service]
MemoryMax=28G
MemoryHigh=24G
```

### Memory Leak Detection

```bash
# Monitor memory over time
while true; do
    MEM=$(ps -o rss= -p $(pgrep avalanchego) | awk '{print $1/1024}')
    echo "$(date): ${MEM}MB"
    sleep 300
done >> /tmp/avalanche-memory.log &

# If memory constantly grows without plateau, report bug with:
# - AvalancheGo version
# - Config
# - Memory graph
```

---

## CPU Issues (GitHub Issues #258, #335, #874)

### High CPU Usage

**Normal CPU behavior:**
- During bootstrap: High (all cores busy)
- After bootstrap: 1-10% average
- During network upgrades: Spikes expected

```bash
# Check CPU usage
top -p $(pgrep avalanchego)

# Common causes:

# 1. NAT traversal failing (Issue #335)
sudo journalctl -u avalanchego | grep -i "NAT"
# Fix: Set public-ip explicitly

# 2. Query timeout cycle (Issue #874)
sudo journalctl -u avalanchego | grep -i "timeout\|deadline"
# Fix: Check network connectivity and peer count

# 3. Slow disk causing backlog
iostat -x 1 5
# If disk util > 90%, upgrade to NVMe SSD

# 4. Too many API requests
# Enable rate limiting or reduce API exposure
```

### CPU Optimization

```json
// ~/.avalanchego/config.json
{
  // Reduce logging overhead
  "log-level": "info",
  "log-display-level": "warn",

  // Optimize network
  "network-peer-list-gossip-frequency": "500ms",

  // Reduce API overhead if not serving external requests
  "api-admin-enabled": false,
  "api-keystore-enabled": false,
  "index-enabled": false
}
```

---

## Validator Uptime Issues (GitHub Issues #461, #464)

### Understanding Uptime

- Minimum for rewards: **80%** (changed from 60% in v1.5.3)
- Calculated by other validators observing your node
- Affected by: connectivity, restarts, crashes

```bash
# Check your uptime
curl -s localhost:9650/ext/info -X POST -H 'content-type:application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"info.uptime"}' | jq

# Check network's view of your uptime
NODE_ID=$(curl -s localhost:9650/ext/info -X POST -H 'content-type:application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"info.getNodeID"}' | jq -r '.result.nodeID')

curl -s localhost:9650/ext/bc/P -X POST -H 'content-type:application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"platform.getCurrentValidators\",\"params\":{\"nodeIDs\":[\"$NODE_ID\"]}}" | jq '.result.validators[0].uptime'
```

### Uptime Drops Unexpectedly

```bash
# Common causes and fixes:

# 1. NAT issues (most common)
# Add to config:
{
  "public-ip": "YOUR_PUBLIC_IP"
}

# 2. Clock drift
sudo systemctl status systemd-timesyncd
timedatectl set-ntp true

# 3. Network instability
# Monitor connectivity:
ping -c 100 8.8.8.8 | grep -E "loss|avg"

# 4. Benched by other validators
sudo journalctl -u avalanchego | grep -i "bench"

# 5. Resource exhaustion during spikes
# Add monitoring and alerts
```

### Uptime Reporting Bug (GitHub Issue #464)

**Issue:** `getCurrentValidators` sometimes returns incorrect uptime values.

```bash
# Workaround: Query multiple times and average
for i in {1..5}; do
    curl -s localhost:9650/ext/bc/P -X POST -H 'content-type:application/json' \
        -d '{"jsonrpc":"2.0","id":1,"method":"platform.getCurrentValidators","params":{"nodeIDs":["YOUR_NODE_ID"]}}' | \
        jq '.result.validators[0].uptime'
    sleep 2
done
```

---

## Docker Deployment (GitHub Issue #452)

### Basic Docker Setup

```bash
# Pull official image
docker pull avaplatform/avalanchego:latest

# Run with persistent storage (CRITICAL!)
docker run -d \
    --name avalanchego \
    -p 9650:9650 \
    -p 9651:9651 \
    -v /data/avalanche:/root/.avalanchego \
    avaplatform/avalanchego:latest \
    /avalanchego/build/avalanchego

# ⚠ WARNING: Without -v, staking keys are lost on container restart!
```

### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  avalanchego:
    image: avaplatform/avalanchego:latest
    container_name: avalanchego
    restart: unless-stopped
    ports:
      - "9650:9650"
      - "9651:9651"
    volumes:
      - avalanche-data:/root/.avalanchego
      - ./config:/root/.avalanchego/configs:ro
    environment:
      - AVAGO_PUBLIC_IP=${PUBLIC_IP}
    command: >
      /avalanchego/build/avalanchego
      --public-ip=${PUBLIC_IP}
      --http-host=0.0.0.0
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9650/ext/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  avalanche-data:
```

### Docker with Custom Config

```bash
# Create config directory
mkdir -p ./avalanche-config/chains/C

# Main config
cat > ./avalanche-config/config.json << 'EOF'
{
  "http-host": "0.0.0.0",
  "public-ip": "YOUR_PUBLIC_IP",
  "network-id": "mainnet"
}
EOF

# C-Chain config
cat > ./avalanche-config/chains/C/config.json << 'EOF'
{
  "state-sync-enabled": true,
  "pruning-enabled": true
}
EOF

# Run with config mount
docker run -d \
    --name avalanchego \
    -p 9650:9650 \
    -p 9651:9651 \
    -v /data/avalanche:/root/.avalanchego \
    -v $(pwd)/avalanche-config:/config:ro \
    avaplatform/avalanchego:latest \
    /avalanchego/build/avalanchego --config-file=/config/config.json
```

### Docker Networking for IPv6

```bash
# Enable IPv6 in Docker daemon
sudo tee /etc/docker/daemon.json << 'EOF'
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00::/80"
}
EOF

sudo systemctl restart docker
```

### Upgrading Docker Node

```bash
# Pull new version
docker pull avaplatform/avalanchego:v1.11.x

# Stop current container
docker stop avalanchego

# Remove container (data persisted in volume)
docker rm avalanchego

# Start with new version
docker run -d \
    --name avalanchego \
    -p 9650:9650 \
    -p 9651:9651 \
    -v /data/avalanche:/root/.avalanchego \
    avaplatform/avalanchego:v1.11.x \
    /avalanchego/build/avalanchego

# Verify
docker logs -f avalanchego
```

---

## Common Error Reference

Quick reference for error messages from GitHub issues and official docs:

| Error Message | Cause | Solution |
|--------------|-------|----------|
| `NAT traversal has failed` | Can't determine public IP | Set `public-ip` in config |
| `Failed to connect to bootstrap nodes` | Network/firewall issue | Check port 9651, verify no duplicate nodes |
| `API call rejected - chain not done bootstrapping` | Normal during sync | Wait for bootstrap to complete |
| `FATAL: consensus engine shutting down` | Critical error | Check logs, may need resync |
| `leveldb: corruption` | Database corrupted | Resync affected chain |
| `missing trie node` | State corruption | Enable state-sync, resync C-Chain |
| `context deadline exceeded` | Timeout / slow network | Check connectivity, disk I/O |
| `OOM killed` | Out of memory | Add swap, increase RAM, enable state-sync |
| `duplicate node ID` | Another node using same keys | Stop duplicate instance |
| `clock skew` | System time wrong | Enable NTP sync |
| `incompatible version` | Old node version | Upgrade AvalancheGo |
| `parent block unknown` | Block gap in DB | Resync affected chain |
| `could not query snowman vm` | Subnet VM issue | Check VM plugin installed correctly |

---

## Security Best Practices

### Staking Key Protection

1. **Never share** staker.key
2. Store backup in secure, offline location
3. Use hardware security modules (HSM) for production
4. Rotate keys if compromised

### API Security

```json
{
  "api-admin-enabled": false,
  "api-keystore-enabled": false,
  "http-allowed-hosts": ["localhost", "your-monitoring-server"]
}
```

### Network Hardening

1. Use dedicated validator machine
2. Disable unnecessary services
3. Keep system updated
4. Use fail2ban for SSH protection
5. Monitor for unusual activity

---

## Quick Reference Commands

### Node Status

```bash
# Node version
curl -s localhost:9650/ext/info -X POST -H 'content-type:application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"info.getNodeVersion"}' | jq '.result'

# Node ID
curl -s localhost:9650/ext/info -X POST -H 'content-type:application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"info.getNodeID"}' | jq -r '.result.nodeID'

# Node health
curl -s localhost:9650/ext/health -X POST -H 'content-type:application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"health.health"}' | jq '.result.healthy'

# Peer count
curl -s localhost:9650/ext/info -X POST -H 'content-type:application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"info.peers"}' | jq '.result.numPeers'

# Bootstrap status (all chains)
for c in X P C; do echo -n "$c: "; curl -s localhost:9650/ext/info -X POST \
    -H 'content-type:application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"info.isBootstrapped\",\"params\":{\"chain\":\"$c\"}}" \
    | jq -r '.result.isBootstrapped'; done

# Uptime
curl -s localhost:9650/ext/info -X POST -H 'content-type:application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"info.uptime"}' | jq '.result'
```

### Validator Commands

```bash
# Current validators
curl -s localhost:9650/ext/bc/P -X POST -H 'content-type:application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"platform.getCurrentValidators","params":{"subnetID":"11111111111111111111111111111111LpoYY"}}' \
    | jq '.result.validators | length'

# My validator info
curl -s localhost:9650/ext/bc/P -X POST -H 'content-type:application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"platform.getCurrentValidators","params":{"nodeIDs":["NODE_ID"]}}' \
    | jq '.result.validators[0]'

# Pending validators
curl -s localhost:9650/ext/bc/P -X POST -H 'content-type:application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"platform.getPendingValidators","params":{}}' | jq
```

### Service Management

```bash
# Start/stop/restart
sudo systemctl start avalanchego
sudo systemctl stop avalanchego
sudo systemctl restart avalanchego

# Status
sudo systemctl status avalanchego

# Logs
sudo journalctl -u avalanchego -f              # Follow logs
sudo journalctl -u avalanchego --since "1h"    # Last hour
sudo journalctl -u avalanchego | grep -i error # Errors only

# Enable on boot
sudo systemctl enable avalanchego
```

### Disk & Resources

```bash
# Database size
du -sh ~/.avalanchego/db/

# Disk usage
df -h

# Memory usage
free -h

# Process info
ps aux | grep avalanchego
```

### Config File Locations

```
~/.avalanchego/
├── config.json                          # Main config
├── staking/
│   ├── staker.crt                       # Node certificate
│   └── staker.key                       # Node private key (BACKUP!)
├── configs/
│   ├── chains/
│   │   ├── C/config.json                # C-Chain config
│   │   ├── X/config.json                # X-Chain config
│   │   └── <chainID>/config.json        # Subnet chain config
│   └── subnets/
│       └── <subnetID>.json              # Subnet config
├── db/                                   # Database (can be large)
├── logs/                                 # Log files
└── plugins/                              # VM plugins
```
