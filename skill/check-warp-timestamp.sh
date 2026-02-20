#!/bin/bash
# Quick diagnostic: Check if Warp timestamp is correct
# Run this on any validator to verify configuration

set -e

CHAIN_ID="22v7AG7h6qaVxd4bLvAsSsg2LZ4RCn5iVYgFn7a2Fj1LCuYwjv"
CONFIG_DIR="$HOME/.avalanchego/configs/chains/$CHAIN_ID"
LAST_BLOCK_TS=1735776000  # Jan 1, 2026 11:59:47 UTC

echo "=========================================="
echo "DOS Chain - Warp Timestamp Diagnostic"
echo "=========================================="
echo ""

# Check if config files exist
if [ ! -f "$CONFIG_DIR/upgrade.json" ]; then
  echo "❌ ERROR: upgrade.json not found!"
  echo "   Expected location: $CONFIG_DIR/upgrade.json"
  exit 1
fi

if [ ! -f "$CONFIG_DIR/config.json" ]; then
  echo "⚠️  WARNING: config.json not found!"
  echo "   Expected location: $CONFIG_DIR/config.json"
fi

# Read current Warp timestamp
echo "Reading current configuration..."
echo ""

WARP_TS=$(cat "$CONFIG_DIR/upgrade.json" | jq -r '.precompileUpgrades[0].warpConfig.blockTimestamp // "NOT SET"')

echo "Chain Details:"
echo "  Chain ID: $CHAIN_ID"
echo "  Last Block Timestamp: $LAST_BLOCK_TS ($(date -u -r $LAST_BLOCK_TS '+%Y-%m-%d %H:%M:%S UTC'))"
echo ""

echo "Current Warp Configuration:"
echo "  Warp Timestamp: $WARP_TS"

if [ "$WARP_TS" = "NOT SET" ]; then
  echo "  ❌ ERROR: Warp timestamp not configured!"
  exit 1
fi

# Convert to human-readable date
WARP_DATE=$(date -u -r $WARP_TS '+%Y-%m-%d %H:%M:%S UTC' 2>/dev/null || echo "Invalid timestamp")
echo "  Warp Date: $WARP_DATE"
echo ""

# Validate timestamp
echo "Validation:"

if [ "$WARP_TS" -gt "$LAST_BLOCK_TS" ]; then
  echo "  ❌ CRITICAL ERROR: Warp timestamp is AFTER last block!"
  echo ""
  echo "  This is why blocks are not producing!"
  echo ""
  echo "  Last Block:  $LAST_BLOCK_TS ($(date -u -r $LAST_BLOCK_TS '+%Y-%m-%d %H:%M:%S UTC'))"
  echo "  Warp Set To: $WARP_TS ($WARP_DATE)"
  echo "  Difference:  $(($WARP_TS - $LAST_BLOCK_TS)) seconds in the future"
  echo ""
  echo "  ✅ Solution: Change Warp timestamp to 1735689600"
  echo "     (Jan 1, 2026 00:00:00 UTC - 12 hours before last block)"
  echo ""
  echo "  Run this command to fix:"
  echo ""
  echo "  cat > $CONFIG_DIR/upgrade.json << 'EOF'"
  echo "  {"
  echo "    \"precompileUpgrades\": ["
  echo "      {"
  echo "        \"warpConfig\": {"
  echo "          \"blockTimestamp\": 1735689600"
  echo "        }"
  echo "      }"
  echo "    ]"
  echo "  }"
  echo "  EOF"
  echo ""
  exit 1

elif [ "$WARP_TS" -eq "$LAST_BLOCK_TS" ]; then
  echo "  ⚠️  WARNING: Warp timestamp equals last block timestamp"
  echo "     This might work, but safer to set it earlier"
  echo "     Recommended: 1735689600 (12 hours before)"
  echo ""
  exit 0

else
  # Warp is before last block - good!
  DIFF=$(($LAST_BLOCK_TS - $WARP_TS))
  echo "  ✅ CORRECT: Warp timestamp is BEFORE last block"
  echo "     Difference: $DIFF seconds ($((DIFF / 3600)) hours) before last block"
  echo ""

  # Check if it's the recommended value
  if [ "$WARP_TS" -eq 1735689600 ]; then
    echo "  ✅ Using recommended timestamp (Jan 1, 2026 00:00:00 UTC)"
  else
    echo "  ℹ️  Using custom timestamp (also valid)"
  fi
fi

echo ""
echo "ProposerVM Configuration:"
if [ -f "$CONFIG_DIR/config.json" ]; then
  PROPOSER_MAX=$(cat "$CONFIG_DIR/config.json" | jq -r '.["proposervm-block-delay-max"] // "NOT SET"')
  PROPOSER_MIN=$(cat "$CONFIG_DIR/config.json" | jq -r '.["proposervm-block-delay-min"] // "NOT SET"')

  echo "  Max Block Delay: $PROPOSER_MAX"
  echo "  Min Block Delay: $PROPOSER_MIN"

  if [ "$PROPOSER_MAX" = "NOT SET" ] || [ "$PROPOSER_MAX" = "null" ]; then
    echo ""
    echo "  ⚠️  ProposerVM max delay not set (will use 60min default!)"
    echo "     This could also prevent block production"
    echo ""
    echo "  ✅ Solution: Set proposervm-block-delay-max to 5s"
  elif [ "$PROPOSER_MAX" = "5s" ]; then
    echo "  ✅ ProposerVM correctly configured"
  else
    echo "  ℹ️  Using custom ProposerVM delay: $PROPOSER_MAX"
  fi
else
  echo "  ⚠️  No config.json found - using defaults"
  echo "     Default max delay is 60 minutes (too long!)"
fi

echo ""
echo "=========================================="
echo "Quick Status Check"
echo "=========================================="

# Check if node is running
if systemctl is-active --quiet avalanchego; then
  echo "  ✅ AvalancheGo is running"
else
  echo "  ❌ AvalancheGo is NOT running"
  echo "     Start with: sudo systemctl start avalanchego"
fi

# Check node health
HEALTH=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"health.health"}' \
  -H 'content-type:application/json' http://127.0.0.1:9650/ext/health 2>/dev/null | \
  jq -r '.result.healthy' 2>/dev/null)

if [ "$HEALTH" = "true" ]; then
  echo "  ✅ Node is healthy"
elif [ -z "$HEALTH" ]; then
  echo "  ⚠️  Cannot check health (node may be starting)"
else
  echo "  ❌ Node is unhealthy"
fi

# Check current block
CURRENT_BLOCK=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber"}' \
  -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/$CHAIN_ID/rpc 2>/dev/null | \
  jq -r '.result' 2>/dev/null)

if [ -n "$CURRENT_BLOCK" ] && [ "$CURRENT_BLOCK" != "null" ]; then
  BLOCK_NUM=$((16#${CURRENT_BLOCK:2}))
  echo "  ℹ️  Current block: $BLOCK_NUM"

  if [ $BLOCK_NUM -eq 2273699 ]; then
    echo "     ⚠️  Still at last known block (no new blocks produced)"
  else
    echo "     ✅ Chain has advanced beyond last known block"
  fi
else
  echo "  ⚠️  Cannot query current block"
fi

echo ""
echo "=========================================="
echo ""

# Final summary
if [ "$WARP_TS" -gt "$LAST_BLOCK_TS" ]; then
  echo "🔴 ACTION REQUIRED:"
  echo "   1. Fix Warp timestamp (see command above)"
  echo "   2. Apply fix to ALL validators"
  echo "   3. Restart validators sequentially"
  echo "   4. Monitor for block production"
elif [ "$PROPOSER_MAX" = "NOT SET" ] || [ "$PROPOSER_MAX" = "null" ]; then
  echo "🟡 ACTION SUGGESTED:"
  echo "   Configure ProposerVM settings in config.json"
  echo "   See: metados-mainnet-fix.md"
else
  echo "🟢 CONFIGURATION LOOKS CORRECT"
  echo "   If blocks still not producing:"
  echo "   - Check logs: sudo journalctl -u avalanchego -f"
  echo "   - Verify all 3 validators have correct config"
  echo "   - Consider database resync if needed"
fi

echo ""
