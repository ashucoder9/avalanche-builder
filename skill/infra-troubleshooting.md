# Infrastructure & Node Operations Troubleshooting

> Real-world incidents from managed node infrastructure, dedicated nodes, and operational issues.

---

## Case 001: High CPU on Graph Protocol Dedicated Node (C-Chain)

**Date**: February 2026
**Severity**: Medium - Alerts firing, service degraded
**Node**: `graphnode1` (dedicated full-index C-Chain node)
**Client**: The Graph Protocol
**Status**: RESOLVED - Simple reboot

### Context

Three dedicated full-index C-Chain nodes (`graphnode1`, `graphnode2`, `graphnode3`) run as infrastructure for The Graph Protocol's indexing service. These are archival nodes with full indexing enabled, serving subgraph queries against C-Chain data.

### Symptom

- High CPU consumption alerts on `graphnode1`
- CPU spikes isolated to the `upload-profiles` container (profiling sidecar), not the main AvalancheGo process
- `graphnode2` and `graphnode3` unaffected

### Ownership Investigation

Before debugging, had to determine who owned the node:

| Team | Owns it? |
|------|----------|
| AvaCloud | No (confirmed by Yulin Dong) |
| Platform | No response, likely not |
| DevRel | Yes - The Graph Protocol relationship |

**Lesson**: Maintain a clear ownership registry for dedicated nodes. When alerts fire, the first bottleneck was figuring out who to ask.

### Root Cause (Probable)

The `upload-profiles` container is a profiling sidecar that collects and uploads performance profiles (CPU, memory, goroutine dumps) from the main node process. Likely causes:

1. **Stuck profiling loop** - The sidecar got into a tight retry loop (e.g., failed uploads to storage backend due to network blip, expired credentials, or full disk). Without proper backoff, it spins CPU endlessly.
2. **Memory/goroutine leak in sidecar** - Long-running Go profiling processes can accumulate state over time, especially under heavy indexing load.
3. **Large profile payload** - Full-index C-Chain nodes have massive state. Serializing/compressing a large heap profile could spike CPU, potentially triggered by increased indexing activity.

### Resolution

Simple pod reboot:
```bash
# Reboot the pod (managed infra)
# Node came back healthy immediately
```

CPU returned to normal after restart. The issue was in the sidecar's accumulated state, not the node itself.

### Diagnostic Steps for Similar Issues

1. **Identify which container is consuming CPU** - Is it the main AvalancheGo process or a sidecar?
   ```bash
   # If using Docker
   docker stats
   # If using Kubernetes
   kubectl top pods -n <namespace> --containers
   ```

2. **Check if the node itself is healthy**:
   ```bash
   curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"health.health"}' \
     -H 'content-type:application/json' http://127.0.0.1:9650/ext/health | jq '.result.healthy'
   ```

3. **Check sidecar container logs for errors**:
   ```bash
   # Kubernetes
   kubectl logs <pod> -c upload-profiles --tail=100
   # Docker
   docker logs <container> --tail=100
   ```

4. **If CPU is the main AvalancheGo process** (not a sidecar):
   ```bash
   # Check if it's stuck in bootstrapping
   curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.isBootstrapped","params":{"chain":"C"}}' \
     -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq

   # Check peer count
   curl -s -X POST --data '{"jsonrpc":"2.0","id":1,"method":"info.peers"}' \
     -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | jq '.result.numPeers'

   # Get goroutine dump for analysis
   kill -SIGABRT $(pgrep avalanchego)
   ```

5. **If reboot doesn't fix it**, investigate the profiling backend:
   - Check storage credentials/permissions
   - Check disk space on profile upload destination
   - Check network connectivity to profile storage

### Key Takeaway

Not all CPU alerts are the node - check sidecar containers first. For managed infra with profiling sidecars, a stuck upload loop is a common failure mode that a simple restart resolves.

---

## Patterns: Infrastructure Quick Reference

| Symptom | First Check | Likely Cause | Quick Fix |
|---------|-------------|--------------|-----------|
| High CPU on sidecar container | Container logs for retry loops | Stuck upload/export loop | Reboot pod |
| High CPU on main AvalancheGo | `isBootstrapped` + peer count | Bootstrapping or state sync | Wait, or check peers |
| Node unhealthy after reboot | Health endpoint + logs | Config mismatch or corrupt DB | Check config, consider DB resync |
| Disk space alerts | `df -h` on data volume | Chain DB growth | Prune or expand storage |
| Node falling behind | Block height vs network | Slow disk I/O or low peers | Upgrade storage, check network |
| OOM kills | Container memory limits | State growth exceeding limits | Increase memory limits |

---

**Document Version**: 1.0
**Last Updated**: February 19, 2026
