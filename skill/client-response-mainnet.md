# Response to Client - DOS Chain Mainnet Issue

## Direct Answers to Your 3 Questions

### ❌ Question 1: What is the correct Warp activation timestamp?

**Your current timestamp `1767225600` is WRONG - this is causing the issue!**

**Problem:**
- Your last block: timestamp ~1735776000 (Jan 1, 2026 11:59:47 UTC)
- Your Warp setting: 1767225600 (approximately Jan 31, 2026)
- **Warp is AFTER the last block = Invalid state**

**Correct timestamp to use:**
```json
{
  "precompileUpgrades": [
    {
      "warpConfig": {
        "blockTimestamp": 1735689600
      }
    }
  ]
}
```

Where `1735689600` = Jan 1, 2026 00:00:00 UTC (12 hours **before** your last block)

**Why this matters:**
- Warp activation MUST be ≤ last block timestamp
- Your node checks "should Warp be active?" when building blocks
- If activation is in the "future" relative to existing blocks, it creates database mismatch
- This prevents ValidatorManager from initializing
- Which prevents block production

---

### ⚠️ Question 2: Should you delete L1 chain data and resync?

**Try this FIRST (config fix only):**

1. **Fix Warp timestamp on ALL 3 validators** (don't restart yet):
   ```bash
   cat > ~/.avalanchego/configs/chains/22v7AG7h6qaVxd4bLvAsSsg2LZ4RCn5iVYgFn7a2Fj1LCuYwjv/upgrade.json << 'EOF'
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
   ```

2. **Sequential restart** (2 minutes between each):
   - Restart Validator 1, wait 2+ min, verify healthy
   - Restart Validator 2, wait 2+ min, verify healthy
   - Restart Validator 3, wait 2+ min, verify healthy

3. **Check if blocks start producing**:
   ```bash
   tail -f ~/.avalanchego/logs/main.log | grep "built block"
   ```

**Only delete chain data IF config fix doesn't work:**

If after 5+ minutes with correct config you still see no blocks:

```bash
# ONE VALIDATOR AT A TIME (never all at once!)

# Stop node
sudo systemctl stop avalanchego

# BACKUP staking keys (critical!)
cp -r ~/.avalanchego/staking /backup/

# Delete chain database
rm -rf ~/.avalanchego/db/*22v7AG7h6qaVxd4bLvAsSsg2LZ4RCn5iVYgFn7a2Fj1LCuYwjv*/

# Restart (will resync from network, takes 15-60 min)
sudo systemctl start avalanchego
```

**Important**: Only resync one validator at a time. Others must stay online.

---

### ✅ Question 3: Is there another way to resolve the database mismatch?

**Yes - fixing the Warp timestamp should resolve it without resync.**

**The database mismatch is caused by:**

```
Chain state:     Block 2273699 at timestamp 1735776000
Config says:     "Activate Warp at 1767225600" (future)
Node logic:      "Warp should activate at block X... but I never reached that timestamp!"
Result:          Database appears inconsistent, can't build blocks
```

**The fix:**
- Change Warp timestamp to **1735689600** (before last block)
- Node will see: "Warp should have activated at block 0" (already done)
- ValidatorManager will initialize properly
- Blocks can be produced

**No resync needed IF:**
- The chain database isn't actually corrupted
- Just the config was wrong
- Restarting with correct config should work

**Resync needed IF:**
- Config fix doesn't work after 5+ minutes
- Logs show database corruption errors
- ValidatorManager still returns `0x`

---

## Recommended Execution Plan

### Phase 1: Config Fix (Try This First)

**On ALL 3 validators:**
```bash
# 1. Fix Warp timestamp
cat > ~/.avalanchego/configs/chains/22v7AG7h6qaVxd4bLvAsSsg2LZ4RCn5iVYgFn7a2Fj1LCuYwjv/upgrade.json << 'EOF'
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

# 2. Verify ProposerVM config is correct
cat > ~/.avalanchego/configs/chains/22v7AG7h6qaVxd4bLvAsSsg2LZ4RCn5iVYgFn7a2Fj1LCuYwjv/config.json << 'EOF'
{
  "proposervm-block-delay-min": "100ms",
  "proposervm-block-delay-max": "5s",
  "proposer-min-block-delay": 0
}
EOF
```

**Then restart sequentially:**
```bash
# Validator 1: restart, wait 2 min, verify healthy
# Validator 2: restart, wait 2 min, verify healthy
# Validator 3: restart, wait 2 min, verify healthy
```

**Check results:**
```bash
# Should see blocks being built
tail -f ~/.avalanchego/logs/main.log | grep "built block"
```

### Phase 2: Resync (Only If Phase 1 Fails)

**If no blocks after 5+ minutes with correct config:**

One validator at a time:
1. Stop validator
2. Backup staking keys
3. Delete chain database
4. Restart (resyncs from network)
5. Wait until healthy
6. Move to next validator

---

## Key Points

✅ **DO:**
- Fix Warp timestamp to 1735689600 (before last block)
- Apply config to all validators before any restarts
- Restart validators one at a time
- Wait 2+ minutes between validator restarts
- Monitor logs for "built block" messages

❌ **DON'T:**
- Use Warp timestamp 1767225600 (it's in the future - wrong!)
- Restart all validators at once
- Delete databases before trying config fix
- Skip backing up staking keys

---

## Timeline Comparison

```
WRONG (current):
Last Block:     1735776000  (Jan 1, 2026 11:59:47 UTC)
Warp Setting:   1767225600  (~ Jan 31, 2026)
                     ↑
                This is AFTER last block = ERROR

CORRECT (fix):
Last Block:     1735776000  (Jan 1, 2026 11:59:47 UTC)
Warp Setting:   1735689600  (Jan 1, 2026 00:00:00 UTC)
                     ↑
                This is BEFORE last block = OK
```

---

## Need Help?

I've created a complete step-by-step guide with scripts:
- `metados-mainnet-fix.md` - Full procedure with all scripts
- `fix-mainnet-config.sh` - Automated config fix
- `coordinated-mainnet-restart.sh` - Safe restart procedure
- `verify-block-production.sh` - Verification script

These are in the `avalanche-builder/skill/` directory.

**Bottom line**: Change Warp timestamp to 1735689600, restart validators sequentially, and blocks should start producing.
