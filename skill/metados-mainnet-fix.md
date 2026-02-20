# DOS Chain Mainnet - Complete Fix Procedure

## Problem Summary

**Chain**: DOS Chain (ChainID: 7979)
**Issue**: No blocks produced since Jan 1, 2026
**Root Cause**: Warp precompile activation timestamp is AFTER last block timestamp

### Timeline
- **Jan 1, 2026 11:59:47 UTC**: Last block (2273699, timestamp ~1735776000)
- **Jan 20, 2026**: Subnet converted to L1
- **Current**: Applied wrong Warp timestamp (1767225600) - this is AFTER last block!

### Why This Breaks Block Production

```
Last Block Timestamp:  1735776000 (Jan 1, 2026 11:59:47 UTC)
Warp Activation:       1767225600 (~ Jan 31, 2026) ← WRONG!
                              ↑
                    This is in the "future"
                    relative to last block
                    = Invalid state
```

When node tries to produce blocks:
1. Checks if Warp should be activated
2. Sees activation timestamp is in "future" (never reached)
3. ValidatorManager precompile not initialized
4. Cannot build blocks

---

## Solution: Fix Warp Timestamp

### Step 1: Calculate Correct Timestamp

**Rule**: Warp activation MUST be ≤ last block timestamp

**Last block timestamp**: 1735776000 (Jan 1, 2026 11:59:47 UTC)

**Recommended Warp timestamp**: 1735689600 (Jan 1, 2026 00:00:00 UTC)
- This is 12 hours BEFORE the last block
- Safe margin ensures Warp is "already activated" when node starts

**Even safer option**: Use a timestamp from weeks earlier:
- 1735084800 = Dec 25, 2025 00:00:00 UTC
- 1733875200 = Dec 11, 2025 00:00:00 UTC

### Step 2: Verify Current Configuration

Before making changes, check what's currently set:

```bash
# On each validator
CHAIN_ID="22v7AG7h6qaVxd4bLvAsSsg2LZ4RCn5iVYgFn7a2Fj1LCuYwjv"

echo "Current Warp timestamp:"
cat ~/.avalanchego/configs/chains/$CHAIN_ID/upgrade.json | \
  jq '.precompileUpgrades[0].warpConfig.blockTimestamp'

echo "Current ProposerVM config:"
cat ~/.avalanchego/configs/chains/$CHAIN_ID/config.json | \
  jq '{proposerMinBlockDelay, proposerMaxBlockDelay, proposerNumHistoricalBlocks}'
```

### Step 3: Apply Correct Configuration (All Validators)

**DO THIS ON ALL 3 VALIDATORS BEFORE RESTARTING ANY**

```bash
#!/bin/bash
# fix-mainnet-config.sh

CHAIN_ID="22v7AG7h6qaVxd4bLvAsSsg2LZ4RCn5iVYgFn7a2Fj1LCuYwjv"
CONFIG_DIR="$HOME/.avalanchego/configs/chains/$CHAIN_ID"

echo "=== Fixing DOS Chain Mainnet Configuration ==="

# Create config directory
mkdir -p "$CONFIG_DIR"

# Backup existing configs
if [ -f "$CONFIG_DIR/config.json" ]; then
  cp "$CONFIG_DIR/config.json" "$CONFIG_DIR/config.json.backup.$(date +%s)"
fi
if [ -f "$CONFIG_DIR/upgrade.json" ]; then
  cp "$CONFIG_DIR/upgrade.json" "$CONFIG_DIR/upgrade.json.backup.$(date +%s)"
fi

# Fix ProposerVM config
cat > "$CONFIG_DIR/config.json" << 'EOF'
{
  "proposervm-block-delay-min": "100ms",
  "proposervm-block-delay-max": "5s",
  "proposer-min-block-delay": 0,
  "proposer-num-historical-blocks": 512,
  "state-sync-enabled": true,
  "pruning-enabled": true
}
EOF

# Fix Warp timestamp (MUST be before last block!)
cat > "$CONFIG_DIR/upgrade.json" << 'EOF'
{
  "precompileUpgrades": [
    {
      "warpConfig": {
        "blockTimestamp": 1735689600
      }
    }
  ]
}
EOF

echo "✓ Configuration fixed"
echo ""
echo "Warp timestamp: 1735689600 (Jan 1, 2026 00:00:00 UTC)"
echo "Last block:     ~1735776000 (Jan 1, 2026 11:59:47 UTC)"
echo "✓ Warp is BEFORE last block (correct)"
echo ""
echo "⚠ DO NOT RESTART YET - apply on all 3 validators first!"
```

### Step 4: Coordinated Sequential Restart

**CRITICAL**: Never restart all validators at once. Restart one at a time with monitoring.

```bash
#!/bin/bash
# coordinated-mainnet-restart.sh

VALIDATOR_NUM=${1:-1}
CHAIN_ID="22v7AG7h6qaVxd4bLvAsSsg2LZ4RCn5iVYgFn7a2Fj1LCuYwjv"
RPC_URL="http://127.0.0.1:9650"

echo "=== Coordinated Mainnet Validator Restart ==="
echo "Validator #$VALIDATOR_NUM"
echo "Chain: DOS Chain ($CHAIN_ID)"
echo ""

# Pre-restart health check
echo "Pre-restart health check..."
HEALTH_BEFORE=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"health.health"}' \
  -H 'content-type:application/json' $RPC_URL/ext/health | jq -r '.result.healthy')
echo "Health before: $HEALTH_BEFORE"

PEERS_BEFORE=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.peers"}' \
  -H 'content-type:application/json' $RPC_URL/ext/info | jq -r '.result.numPeers')
echo "Peers before: $PEERS_BEFORE"
echo ""

# Restart based on validator number
case $VALIDATOR_NUM in
  1)
    echo "⚠ Validator 1: You are the FIRST to restart"
    echo "⚠ This is the most critical - network will lose 1/3 validators"
    read -p "Confirm restart? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
      echo "Aborted"
      exit 1
    fi

    echo "Restarting AvalancheGo..."
    sudo systemctl restart avalanchego
    ;;

  2)
    echo "⚠ Validator 2: Wait at least 2 minutes after Validator 1"
    echo "⚠ Verify Validator 1 is healthy before proceeding"
    read -p "Has Validator 1 been healthy for 2+ minutes? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
      echo "Wait for Validator 1 to stabilize first!"
      exit 1
    fi

    echo "Restarting AvalancheGo..."
    sudo systemctl restart avalanchego
    ;;

  3)
    echo "⚠ Validator 3: Wait at least 2 minutes after Validator 2"
    echo "⚠ Verify Validator 2 is healthy before proceeding"
    read -p "Has Validator 2 been healthy for 2+ minutes? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
      echo "Wait for Validator 2 to stabilize first!"
      exit 1
    fi

    echo "Restarting AvalancheGo..."
    sudo systemctl restart avalanchego
    ;;

  *)
    echo "Invalid validator number (use 1, 2, or 3)"
    exit 1
    ;;
esac

# Post-restart monitoring
echo ""
echo "Waiting 30 seconds for startup..."
sleep 30

# Monitor health
echo "Post-restart health check..."
for i in {1..12}; do
  HEALTH=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"health.health"}' \
    -H 'content-type:application/json' $RPC_URL/ext/health 2>/dev/null | jq -r '.result.healthy' 2>/dev/null)

  PEERS=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.peers"}' \
    -H 'content-type:application/json' $RPC_URL/ext/info 2>/dev/null | jq -r '.result.numPeers' 2>/dev/null)

  echo "$(date): Health=$HEALTH, Peers=$PEERS"

  if [ "$HEALTH" = "true" ] && [ "$PEERS" -ge 2 ]; then
    echo "✓ Validator $VALIDATOR_NUM is healthy!"
    break
  fi

  sleep 10
done

# Check for block building
echo ""
echo "Checking for block production..."
echo "Monitoring logs for 'built block' messages..."
sudo journalctl -u avalanchego --since "1 minute ago" | grep -i "built block" | tail -5

echo ""
echo "=== Validator $VALIDATOR_NUM Restart Complete ==="
echo ""
echo "Next steps:"
case $VALIDATOR_NUM in
  1)
    echo "1. Monitor this validator for 2 minutes"
    echo "2. Verify health stays 'true'"
    echo "3. Then restart Validator 2"
    ;;
  2)
    echo "1. Monitor this validator for 2 minutes"
    echo "2. Verify health stays 'true'"
    echo "3. Then restart Validator 3"
    ;;
  3)
    echo "1. Monitor all 3 validators"
    echo "2. Check if blocks are being produced"
    echo "3. If no blocks after 5 minutes, proceed to database resync"
    ;;
esac
```

### Step 5: Verify Block Production

After all 3 validators have been restarted:

```bash
#!/bin/bash
# verify-block-production.sh

CHAIN_ID="22v7AG7h6qaVxd4bLvAsSsg2LZ4RCn5iVYgFn7a2Fj1LCuYwjv"
RPC_URL="http://127.0.0.1:9650/ext/bc/$CHAIN_ID/rpc"

echo "=== Verifying Block Production ==="

# Get current block
BLOCK1=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber"}' \
  -H 'content-type:application/json' $RPC_URL | jq -r '.result')
echo "Current block: $((16#${BLOCK1:2}))"

# Wait 30 seconds
echo "Waiting 30 seconds..."
sleep 30

# Get new block
BLOCK2=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber"}' \
  -H 'content-type:application/json' $RPC_URL | jq -r '.result')
echo "New block: $((16#${BLOCK2:2}))"

# Check if advancing
DIFF=$((16#${BLOCK2:2} - 16#${BLOCK1:2}))
echo ""
if [ $DIFF -gt 0 ]; then
  echo "✓ SUCCESS: Blocks are being produced!"
  echo "  Produced $DIFF blocks in 30 seconds"
  echo ""
  echo "Monitor logs for confirmation:"
  echo "  tail -f ~/.avalanchego/logs/main.log | grep 'built block'"
else
  echo "✗ FAILURE: No new blocks produced"
  echo ""
  echo "Next step: Database resync required"
  echo "See 'Database Resync Procedure' below"
fi
```

---

## If Config Fix Doesn't Work: Database Resync

### When to Resync

Only if **all 3 validators have correct config** and **still no blocks after 5+ minutes**.

### Resync Procedure (One Validator at a Time)

**NEVER resync all validators at once - chain would be completely offline!**

```bash
#!/bin/bash
# resync-validator.sh

CHAIN_ID="22v7AG7h6qaVxd4bLvAsSsg2LZ4RCn5iVYgFn7a2Fj1LCuYwjv"

echo "=== Chain Database Resync ==="
echo "⚠ WARNING: This will delete chain data and resync from network"
echo "⚠ This validator will be offline during resync (15-60 minutes)"
echo "⚠ Other validators MUST remain online!"
echo ""
read -p "Proceed with resync? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted"
  exit 1
fi

# Step 1: Stop node
echo "Stopping AvalancheGo..."
sudo systemctl stop avalanchego

# Step 2: CRITICAL - Backup staking keys
echo "Backing up staking keys..."
BACKUP_DIR="/backup/avalanche-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r ~/.avalanchego/staking "$BACKUP_DIR/"
cp -r ~/.avalanchego/configs "$BACKUP_DIR/"

if [ ! -f "$BACKUP_DIR/staking/staker.key" ]; then
  echo "✗ BACKUP FAILED - ABORTING!"
  exit 1
fi
echo "✓ Staking keys backed up to: $BACKUP_DIR"

# Step 3: Delete only the chain database (not entire db)
echo "Deleting chain database..."

# Option A: Delete just this chain (safer)
find ~/.avalanchego/db -name "*$CHAIN_ID*" -type d -exec rm -rf {} + 2>/dev/null

# Option B: If option A doesn't work, delete entire db
# rm -rf ~/.avalanchego/db

echo "✓ Chain database deleted"

# Step 4: Verify config is correct
echo "Verifying configuration..."
cat ~/.avalanchego/configs/chains/$CHAIN_ID/upgrade.json | jq '.precompileUpgrades[0].warpConfig.blockTimestamp'

# Step 5: Restart
echo "Starting AvalancheGo (will resync from network)..."
sudo systemctl start avalanchego

# Step 6: Monitor sync
echo ""
echo "=== Monitoring Resync Progress ==="
echo "This may take 15-60 minutes depending on chain size"
echo ""

for i in {1..120}; do
  BOOTSTRAPPED=$(curl -s -X POST --data '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"info.isBootstrapped",
    "params":{"chain":"'$CHAIN_ID'"}
  }' -H 'content-type:application/json' http://127.0.0.1:9650/ext/info 2>/dev/null | \
    jq -r '.result.isBootstrapped' 2>/dev/null)

  if [ "$BOOTSTRAPPED" = "true" ]; then
    echo "✓ Resync complete!"
    break
  fi

  echo "$(date): Still syncing... ($i/120 checks)"
  sleep 30
done

echo ""
echo "=== Resync Complete ==="
echo "Verify blocks are being produced on this validator"
```

---

## Summary Checklist

### Pre-Execution
- [ ] All 3 validators have access to scripts
- [ ] Backup of staking keys exists
- [ ] Verified last block timestamp: ~1735776000
- [ ] Coordinated restart schedule agreed upon

### Execution Order
1. [ ] Apply config fix to Validator 1
2. [ ] Apply config fix to Validator 2
3. [ ] Apply config fix to Validator 3
4. [ ] Restart Validator 1, wait 2+ minutes, verify healthy
5. [ ] Restart Validator 2, wait 2+ minutes, verify healthy
6. [ ] Restart Validator 3, wait 2+ minutes, verify healthy
7. [ ] Verify blocks are producing

### If Blocks Still Don't Produce
8. [ ] Resync Validator 1, wait until complete
9. [ ] Verify Validator 1 is building blocks
10. [ ] Resync Validator 2 (one at a time!)
11. [ ] Resync Validator 3 (one at a time!)

---

## Critical Timestamps Reference

```
Last Block:              1735776000  (Jan 1, 2026 11:59:47 UTC)
Correct Warp Timestamp:  1735689600  (Jan 1, 2026 00:00:00 UTC)  ✓
Wrong Warp Timestamp:    1767225600  (Future date)               ✗

Rule: Warp timestamp MUST be ≤ last block timestamp
```

---

## Diagnostic Commands

### Check Current Warp Timestamp
```bash
cat ~/.avalanchego/configs/chains/$CHAIN_ID/upgrade.json | \
  jq '.precompileUpgrades[0].warpConfig.blockTimestamp'
```

### Check Last Block Number
```bash
curl -s -X POST --data '{
  "jsonrpc":"2.0",
  "id":1,
  "method":"eth_blockNumber"
}' -H 'content-type:application/json' \
  http://127.0.0.1:9650/ext/bc/$CHAIN_ID/rpc | jq
```

### Check ProposerVM Delay in Logs
```bash
sudo journalctl -u avalanchego | grep -i "waiting until we should build"
```

### Check Validator Status
```bash
curl -s -X POST --data '{
  "jsonrpc":"2.0",
  "id":1,
  "method":"platform.getCurrentValidators",
  "params":{"subnetID":"nQCwF6V9y8VFjvMuPeQVWWYn6ba75518Dpf6ZMWZNb3NyTA94"}
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/P | \
  jq '.result.validators'
```

---

**Document Version**: 1.0
**Last Updated**: January 23, 2026
**Status**: Active - Ready for mainnet execution
