# L1 Troubleshooting: DOS Chain (MetaDOS) - Complete Case Study

> Full documentation of DOS Chain L1 mainnet recovery: problem, debugging approach, internal engineering discussions, and successful resolution.

---

## Case Overview

**Client**: DOS Chain (MetaDOS)
**Issue Type**: L1 Block Production Stopped After Subnet-to-L1 Conversion
**Severity**: Critical - No blocks produced for 19+ days, then 50+ days total
**Date Range**: January - February 2026
**Status**: RESOLVED - Chain producing blocks again
**Participants**: Nicolas Arnedo (Solutions Engineering), Owen Wahlgren (DevRel), Yacov Manevich (AvalancheGo core), Anh Le (DOS dev team), Eun Kyu Choi (DOS)

---

## Chain Details

| Parameter | Value |
|-----------|-------|
| Chain ID | 7979 |
| Subnet ID | `nQCwF6V9y8VFjvMuPeQVWWYn6ba75518Dpf6ZMWZNb3NyTA94` |
| Blockchain ID | `22v7AG7h6qaVxd4bLvAsSsg2LZ4RCn5iVYgFn7a2Fj1LCuYwjv` |
| Last Block Before Halt | 2,273,699 (Jan 1, 2026 11:59:47 UTC) |
| AvalancheGo Version (initial) | v1.14.0 |
| Subnet-EVM Version | v0.8.0 |
| Validators | v0: `NodeID-3K3PUAqo3cKxRoQyYto1EsXtuTHoDZ2B6`, v1: `NodeID-Ma3Ztm2A48bCVjfiSmoZS5MKNzKVTRN7j`, v2: `NodeID-G8yv8mWQy8FLdFfAhJ4v294T5Z2DWDVEH`, v6: `NodeID-Mu35k31HAXFbEp1SqJr1uUrue9nwqVFe6` |

---

## Timeline of Events

| Date | Event |
|------|-------|
| Jan 1, 2026 | Last block produced (2,273,699). Old subnet validators expired. |
| Jan 1 - Jan 20 | **19 days with NO active validators** (critical gap) |
| Jan 20, 2026 | Subnet converted to L1 via `ConvertSubnetToL1Tx`. 3 L1 validators registered (v0, v1, v2). |
| Jan 21, 2026 | Client reports issue. Initial debugging begins. |
| Jan 23, 2026 | First round of config fix scripts sent to client (ProposerVM + Warp timestamp). |
| Jan 29, 2026 | Owen escalates to Yacov Manevich (AvalancheGo core engineer). |
| Jan 30, 2026 | Yacov requests debug logs. Identifies old subnet validator (v6) is not tracking the L1. |
| Jan 31, 2026 | Yacov requests Grafana monitoring setup on all validators. |
| Feb 3, 2026 | Grafana URLs shared. Yacov confirms 100% connected stake on v6 but no new blocks. Requests `kill -SIGABRT` stack trace. |
| Feb 3, 2026 | Yacov joins call with DOS team. Starts working on AvalancheGo fix (PR #4955). |
| Feb 13, 2026 | v6 Validator Registration Guide (off-chain BLS signing) prepared. |
| Feb 17, 2026 | **Chain producing blocks again.** Client followed updated instructions: upgrade AvalancheGo, re-add old subnet validator via P-Chain, fix warp timestamp. |

---

## Phase 1: Initial Client Report (Jan 21)

### Symptoms Reported by Client

1. **ProposerVM waiting 60 minutes** instead of configured 5 minutes:
   ```
   proposervm/vm.go:459 Waiting until we should build a block {"duration": "59m59.997249322s"}
   ```

2. **Validators appeared correctly registered** on the P-Chain:
   - 3 L1 validators showing `isActive: true`, `isL1Validator: true`, `isConnected: true`
   - Both `validators.getCurrentValidators` and `platform.getCurrentValidators` returned correct data

3. **Transactions accepted but never mined**:
   - Entered mempool, pending nonce increased, but never included in blocks

4. **ValidatorManager precompile not initialized**:
   - Query to `0xfAcadE0000000000000000000000000000000000` returned `0x`
   - Chicken-and-egg: `initializeValidatorSet` needs a transaction in a block, but no blocks are being produced

### Initial Questions Asked

1. Why is ProposerVM waiting ~60 minutes when `maxBuildDelay` is only 5 minutes?
2. Is there a way to force/kickstart block production after a 20-day gap?
3. Does the 19-day gap with no active validators corrupt the chain state or consensus?
4. Is there a special procedure when converting a subnet that has already stopped producing blocks?

---

## Phase 2: Initial Fix Attempt (Jan 23)

### Root Causes Identified (Initial Assessment)

1. **Missing ProposerVM configuration** - Defaulting to 60-minute delay instead of configured 5 minutes
2. **Warp timestamp misconfiguration** - Activation timestamp `1767225600` (Jan 31, 2026) was AFTER last block timestamp `1735776000` (Jan 1, 2026)
3. **19-day validator gap** - Between old subnet validators expiring and L1 conversion

### Why Warp Timestamp Matters

```
Last Block Timestamp:  1735776000 (Jan 1, 2026 11:59:47 UTC)
Warp Activation:       1767225600 (~ Jan 31, 2026)  <-- WRONG! In "future" relative to last block

When node tries to produce blocks:
1. Checks if Warp should be activated
2. Sees activation timestamp is in "future" (never reached by any block)
3. ValidatorManager precompile cannot initialize
4. Cannot build blocks
```

**Rule**: Warp activation timestamp MUST be <= last block timestamp.

### Scripts Provided to Client

Three remediation scripts were created:
- `fix-proposer-config.sh` - Set `proposervm-block-delay-max: 5s` (was using 60-min default)
- `fix-warp-config.sh` - Set warp timestamp to `1735689600` (Jan 1, 2026 00:00:00 UTC, 12 hours before last block)
- `coordinated-restart.sh` - Sequential restart with 2-minute gaps

**Result**: Client attempted but did not execute correctly. Chain remained stuck.

---

## Phase 3: Internal Engineering Escalation (Jan 29 - Feb 3)

### Escalation to AvalancheGo Core Team

Owen Wahlgren escalated to Yacov Manevich with the core insight about why this is fundamentally hard:

> "If all validators of an L1 at P-chain height h are offline, and the latest block of the L1 references that height h, and more nodes exist in the network but aren't validators, and we want to add them as validators in P-chain height h' in order to resurrect the L1 because all of its validators are offline, that won't work because the nodes in the L1 won't agree to build a new block because they don't see themselves in the scheduling of the validator set of h."

**Key technical detail**: The ProposerVM will only allow blocks produced by validators at P-chain height h (the height referenced by the last block). New validators added at a later P-chain height h' won't be recognized for block building purposes.

However, Snowman consensus always uses the latest P-chain height, creating an asymmetry between consensus and block production.

### Debugging Steps Requested by Yacov

**Step 1: Verify L1 is being tracked**

Yacov noticed initial logs only showed P-Chain, X-Chain, and C-Chain activity with no L1 chain messages. Asked to verify the node was actually tracking the subnet.

The chains being dropped were mainnet C-Chain (`2q9e4r6Mu3U68nU1fYjgbR6JvwrRx36CohpAX5UQxse55x1Q5`) and X-Chain (`2oYMBNV4eNHyqk2fjjV5nVQLDbtmNJzq5s3qs3Lo6ftnC6FByM`) - NOT the L1 chain. Confirmed the node was indeed tracking the L1.

**Step 2: Request debug-level logs**

```bash
# Enable debug logging on the validator
# Check logs specifically for the L1 chain ID
grep "22v7AG7h6qaVxd4bLvAsSsg2LZ4RCn5iVYgFn7a2Fj1LCuYwjv" logs
```

Confirmed the L1 was being tracked. Key log observed:
```
snowman/engine.go:1136 dropping vote {"reason": "ancestor isn't cached"}
```
Yacov confirmed this was benign and not the root cause.

**Step 3: Install Grafana monitoring**

Requested installation of the [Avalanche monitoring stack](https://github.com/ava-labs/avalanche-monitoring) on all validators.

Grafana URLs provided:
- v0 (`NodeID-3K3PUAqo3cKxRoQyYto1EsXtuTHoDZ2B6`): `http://20.195.41.144:3000`
- v1 (`NodeID-Ma3Ztm2A48bCVjfiSmoZS5MKNzKVTRN7j`): `http://20.6.81.3:3000`
- v2 (`NodeID-G8yv8mWQy8FLdFfAhJ4v294T5Z2DWDVEH`): `http://20.212.250.135:3000`
- v6 (`NodeID-Mu35k31HAXFbEp1SqJr1uUrue9nwqVFe6`): `http://20.198.217.108:3000`

**Findings from Grafana**: v6 showed 100% connected stake, P-chain was advancing, but no new L1 blocks. Also noted low disk space on v6 (unrelated but flagged).

**Step 4: Request stack trace via SIGABRT**

```bash
# Get PID of avalanchego process
PID=$(pgrep avalanchego)
# Send SIGABRT to get full goroutine dump
kill -SIGABRT $PID
# Then send the logs
```

Purpose: Understand what the node was blocked on at the goroutine level.

**Step 5: Yacov created a fix PR**

After joining a call with the DOS team, Yacov created an e2e test reproducing the scenario and a fix:
- PR: https://github.com/ava-labs/avalanchego/pull/4955
- Reproduced the exact scenario in an automated test
- Fix was pending review at time of resolution

---

## Phase 4: Successful Resolution (Feb 17)

### What Actually Fixed It

The chain started producing blocks after the client correctly executed the following combination:

1. **Updated AvalancheGo to latest version** (from v1.14.0 to latest)
2. **Re-added the old subnet validator (v6) to the P-Chain** - The old subnet validator `NodeID-Mu35k31HAXFbEp1SqJr1uUrue9nwqVFe6` was added back via a P-Chain transaction directly
3. **Manually created and signed a Warp message** - They manually made + signed a warp message to bypass the chicken-and-egg problem
4. **Fixed the Warp timestamp configuration** on all validators to use `1735689600` (before last block)

### Why This Worked

The core issue was that without enough validator weight from the P-Chain's perspective, the ProposerVM would not schedule any of the registered validators to build blocks. By:
- Adding v6 back (restoring the original validator that had credentials matching what the chain state expected)
- Ensuring the Warp precompile was activated at a timestamp before the last block
- Running the latest AvalancheGo which had various L1 conversion improvements

...the validators could finally agree on block production scheduling and resume building blocks.

---

## Phase 5: Ongoing - v6 Validator Registration Guide (For Future Reference)

After the initial fix, a comprehensive guide was prepared for registering v6 properly via the ValidatorManager, in case it was needed. This documents the **off-chain BLS signing** approach, which is the only way to register a new validator when the L1 cannot produce blocks.

### Why Normal Registration Doesn't Work When Chain Is Stuck

```
Normal Flow (requires block production):
ValidatorManager.initializeValidatorRegistration()
  -> Warp message emitted on-chain
  -> Aggregator collects BLS signatures via P2P
  -> RegisterL1ValidatorTx on P-Chain

Since the chain can't produce blocks, Step 1 can't execute.
The initializeValidatorRegistration() transaction gets accepted into mempool but never mined.
```

### The Off-Chain BLS Signing Bypass

```
Off-Chain Flow (no block production needed):
1. Construct RegisterL1ValidatorMessage manually
2. Sign with BLS private keys from existing validators (v0, v1, v2)
3. Aggregate signatures off-chain
4. Submit RegisterL1ValidatorTx on P-Chain

The P-Chain only checks that the Warp message has valid BLS signatures
from >=67% of the L1's validator weight. It does NOT verify the message
originated from an on-chain transaction.
```

### Pre-Check: Determine Which Path to Take

```bash
curl -s -X POST --data '{
  "jsonrpc":"2.0","id":1,
  "method":"platform.getCurrentValidators",
  "params":{"subnetID":"nQCwF6V9y8VFjvMuPeQVWWYn6ba75518Dpf6ZMWZNb3NyTA94"}
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/P | \
  jq '.result.validators[] | {nodeID, weight, balance}'
```

| Result | Meaning | Action |
|--------|---------|--------|
| Validator listed, `balance: 0` | Ran out of AVAX, was disabled | **Scenario A** - Simple balance top-up |
| Validator NOT listed at all | Never registered post-conversion | **Scenario B** - Off-chain BLS signing & registration |
| Validator listed, `balance > 0` | Active; issue is elsewhere | Investigate further |

### Scenario A: Balance Top-Up (Simple Fix)

If a validator is registered but has `balance: 0`, use `IncreaseL1ValidatorBalanceTx` (P-Chain only, no L1 block production required):

```bash
# Install avalanche-cli
curl -sSfL https://raw.githubusercontent.com/ava-labs/avalanche-cli/main/scripts/install.sh | sh -s

# Fund validator with 10 AVAX (~7.5 months of runway at ~1.33 AVAX/month)
avalanche validator increaseBalance \
  --node-id NodeID-Mu35k31HAXFbEp1SqJr1uUrue9nwqVFe6 \
  --balance 10 \
  --mainnet

# Check ALL validators - if any have balance: 0, fund them too
avalanche validator increaseBalance \
  --node-id NodeID-3K3PUAqo3cKxRoQyYto1EsXtuTHoDZ2B6 \
  --balance 10 --mainnet

avalanche validator increaseBalance \
  --node-id NodeID-Ma3Ztm2A48bCVjfiSmoZS5MKNzKVTRN7j \
  --balance 10 --mainnet

avalanche validator increaseBalance \
  --node-id NodeID-G8yv8mWQy8FLdFfAhJ4v294T5Z2DWDVEH \
  --balance 10 --mainnet
```

**Important**: ALL validators need positive balances to participate in consensus.

### Scenario B: Off-Chain BLS Registration (Advanced)

Only needed if the validator is NOT in the P-Chain validator set at all.

**Prerequisites**:
- Go 1.22+
- Target validator's BLS public key & proof of possession (from `info.getNodeID`)
- `signer.key` files from existing validators (`~/.avalanchego/staking/signer.key`)
- P-Chain funded key (at least 11 AVAX: 10 deposit + 1 fees)
- ValidatorManager proxy address on the L1

**Step 1: Gather target validator's BLS credentials**
```bash
# Run on the target validator's machine
curl -s -X POST --data '{
  "jsonrpc":"2.0","id":1,
  "method":"info.getNodeID"
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq '.result'
# Output includes nodeID, nodePOP.publicKey (48 bytes), nodePOP.proofOfPossession (96 bytes)
```

**Step 2: Get canonical validator ordering**
```bash
curl -s -X POST --data '{
  "jsonrpc":"2.0","id":1,
  "method":"platform.getCurrentValidators",
  "params":{"subnetID":"YOUR_SUBNET_ID"}
}' -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/P | \
  jq '.result.validators[] | {nodeID, weight}'
```

**Step 3: Copy signer.key files securely**
```bash
# From each existing validator machine
scp user@v0-host:~/.avalanchego/staking/signer.key ./keys/v0-signer.key
scp user@v1-host:~/.avalanchego/staking/signer.key ./keys/v1-signer.key
scp user@v2-host:~/.avalanchego/staking/signer.key ./keys/v2-signer.key
```

> **Security**: `signer.key` files are BLS private keys - critical secrets equivalent to validator identity. Transfer only via SSH/SCP. Delete all copies from the working machine after registration is complete.

**Step 4: Run the Go registration tool**

A complete Go script is available in the `MetaDOS-v6-Validator-Registration-Guide.pdf` that:
1. Constructs a `RegisterL1ValidatorMessage` with the target validator's details
2. Wraps it in an `AddressedCall` payload with the ValidatorManager address as source
3. Creates an `UnsignedMessage` with the L1's blockchain ID and network ID
4. Signs with BLS private keys from existing validators
5. Aggregates BLS signatures into a `BitSetSignature` with correct signer indices
6. Submits `RegisterL1ValidatorTx` on the P-Chain

Key notes:
- Registration message has a **24-hour expiry** - must submit within that window
- Validators must be sorted by NodeID bytes for **canonical P-Chain ordering**
- All validators in the P-Chain set (even disabled ones) must be included in the ordering

---

## Post-Registration: Warp Timestamp Fix (Required After Any Validator Change)

After any validator is registered/reactivated on the P-Chain, block production still won't resume until the Warp timestamp is correct on ALL validators.

### The Fix (Apply to ALL Validators)

```bash
CHAIN_ID="22v7AG7h6qaVxd4bLvAsSsg2LZ4RCn5iVYgFn7a2Fj1LCuYwjv"
CONFIG_DIR="$HOME/.avalanchego/configs/chains/$CHAIN_ID"
mkdir -p "$CONFIG_DIR"

# Backup existing configs
cp "$CONFIG_DIR/config.json" "$CONFIG_DIR/config.json.backup" 2>/dev/null
cp "$CONFIG_DIR/upgrade.json" "$CONFIG_DIR/upgrade.json.backup" 2>/dev/null

# Fix 1: Warp timestamp (MUST be before last block timestamp)
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

# Fix 2: ProposerVM config
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
```

### Sequential Restart (CRITICAL: Never restart all at once)

```bash
# For each validator, one at a time with 2-minute gaps:
sudo systemctl restart avalanchego

# Wait 30 seconds, verify health
sleep 30
curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"health.health"}' \
  -H 'content-type:application/json' http://127.0.0.1:9650/ext/health | jq '.result.healthy'

# Verify peer count (should be >= 2)
curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.peers"}' \
  -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq '.result.numPeers'

# Wait until healthy=true and peers>=2, then move to next validator
```

### Verify Block Production

```bash
CHAIN_ID="22v7AG7h6qaVxd4bLvAsSsg2LZ4RCn5iVYgFn7a2Fj1LCuYwjv"

BLOCK=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber"}' \
  -H 'content-type:application/json' \
  http://127.0.0.1:9650/ext/bc/$CHAIN_ID/rpc | jq -r '.result')
echo "Current block: $((16#${BLOCK:2}))"

sleep 30

BLOCK2=$(curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber"}' \
  -H 'content-type:application/json' \
  http://127.0.0.1:9650/ext/bc/$CHAIN_ID/rpc | jq -r '.result')
echo "Block after 30s: $((16#${BLOCK2:2}))"
# Block number should have increased
```

### If Blocks Still Don't Produce After 5 Minutes

Database resync may be needed. Do **one validator at a time**:

```bash
CHAIN_ID="22v7AG7h6qaVxd4bLvAsSsg2LZ4RCn5iVYgFn7a2Fj1LCuYwjv"

# 1. Stop
sudo systemctl stop avalanchego

# 2. BACKUP staking keys (CRITICAL)
cp -r ~/.avalanchego/staking /tmp/staking-backup-$(date +%s)

# 3. Delete only the L1 chain database
find ~/.avalanchego/db -name "*$CHAIN_ID*" -type d -exec rm -rf {} + 2>/dev/null

# 4. Restart (will resync from other validators, 15-60 min)
sudo systemctl start avalanchego

# 5. Monitor sync
watch -n 10 'curl -s -X POST --data "{\"jsonrpc\":\"2.0\",\"id\":1, \
  \"method\":\"info.isBootstrapped\",\"params\":{\"chain\":\"'$CHAIN_ID'\"}}" \
  -H "content-type:application/json" http://127.0.0.1:9650/ext/info | jq'
```

---

## Key Debugging Questions & Diagnostic Commands

### Debugging Checklist (Use This For Similar Issues)

1. **Is the node tracking the L1/subnet?**
   - Check logs for the blockchain ID - if you only see P-Chain/C-Chain/X-Chain messages, the node may not be tracking your L1
   - Look for `"received message for unknown chain"` errors

2. **Are validators connected and recognized?**
   ```bash
   curl -s -X POST --data '{
     "jsonrpc":"2.0","id":1,
     "method":"platform.getCurrentValidators",
     "params":{"subnetID":"YOUR_SUBNET_ID"}
   }' -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/P | \
     jq '.result.validators[] | {nodeID, weight, balance, connected}'
   ```

3. **Do all validators have positive AVAX balance?**
   - Validators with `balance: 0` are disabled and can't participate in consensus
   - ALL validators need positive balances

4. **Is the Warp timestamp before the last block?**
   ```bash
   cat ~/.avalanchego/configs/chains/$CHAIN_ID/upgrade.json | jq
   ```

5. **What is ProposerVM doing?**
   ```bash
   sudo journalctl -u avalanchego | grep -i "proposervm\|waiting until we should build"
   ```

6. **Is the ValidatorManager initialized?**
   ```bash
   cast call 0xfAcadE0000000000000000000000000000000000 "totalWeight()(uint256)" --rpc-url $L1_RPC
   # Returns 0x = not initialized
   ```

7. **Install Grafana monitoring for deeper visibility**:
   - https://github.com/ava-labs/avalanche-monitoring
   - Check connected stake %, peer counts, block production metrics

8. **For goroutine-level debugging**:
   ```bash
   kill -SIGABRT $(pgrep avalanchego)
   # Then check logs for full goroutine dump
   ```

---

## Generalized Lessons & Patterns

### Pattern: L1 Stuck After Subnet-to-L1 Conversion

**Root cause tree**:
```
L1 not producing blocks after conversion
├── Validator weight issue
│   ├── Not enough validators registered (need >=67% weight for consensus)
│   ├── Validator(s) ran out of AVAX balance (balance: 0 = disabled)
│   └── Validator gap between old subnet expiry and L1 conversion
├── Configuration issue
│   ├── Warp timestamp AFTER last block timestamp (must be BEFORE)
│   └── ProposerVM using default 60-min delay (needs explicit config)
├── ProposerVM scheduling issue
│   ├── ProposerVM only allows blocks from validators at P-chain height of last block
│   └── New validators at later P-chain height won't be recognized for building
└── Chicken-and-egg problem
    ├── initializeValidatorSet needs a block
    ├── Blocks need validators
    └── Bypass: off-chain BLS signing to register validators without L1 blocks
```

### Prevention Best Practices

1. **Never let old validators expire before L1 conversion** - Ensure continuous validator coverage
2. **Pre-configure Warp timestamp** - Must be BEFORE or AT the last block timestamp
3. **Keep validator AVAX balances funded** - ~1.33 AVAX/month per validator, fund with buffer
4. **Have at least 4-5 validators for production** - Provides redundancy
5. **Test the full conversion flow on Fuji testnet first**
6. **Monitor validator balances** - Set up alerts before they hit zero

### Common L1 Block Production Issues Quick Reference

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Waiting 60 minutes to build block` | Missing ProposerVM config | Add `proposervm-block-delay-max: 5s` to chain config |
| `ValidatorManager returns 0x` | Not initialized, chain stuck | Register validators, fix warp timestamp |
| `No blocks after L1 conversion` | Validator gap or config issue | Ensure validator coverage + correct warp timestamp |
| `Warp precompile not working` | Timestamp after last block | Move timestamp to before last block |
| `Validator has balance: 0` | Ran out of AVAX | `IncreaseL1ValidatorBalanceTx` on P-Chain |
| `Transactions stuck in mempool` | No block production | Fix underlying block production issue first |
| `ancestor isn't cached` in logs | Normal during sync | Benign - not the root cause |
| `received message for unknown chain` | Node not tracking subnet | Verify subnet tracking config |

---

## Critical Timestamps Reference (DOS Chain Specific)

```
Last Block:              1735776000  (Jan 1, 2026 11:59:47 UTC)
Correct Warp Timestamp:  1735689600  (Jan 1, 2026 00:00:00 UTC)  CORRECT
Wrong Warp Timestamp:    1767225600  (Jan 31, 2026)               WRONG

Rule: Warp timestamp MUST be <= last block timestamp
```

---

## Related Resources

- **AvalancheGo PR #4955**: E2e test reproducing this scenario (by Yacov Manevich)
- **Avalanche Monitoring**: https://github.com/ava-labs/avalanche-monitoring
- **v6 Registration Guide**: `MetaDOS-v6-Validator-Registration-Guide.pdf`
- **Fix scripts**: `metados-mainnet-fix.md`, `check-warp-timestamp.sh`

---

**Document Version**: 2.0
**Last Updated**: February 19, 2026
**Status**: RESOLVED - Documented for future reference
