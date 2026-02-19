#!/bin/bash
# Testnet Validator Management Script for DOS Chain
# Purpose: Remove or check problematic validator NodeID-Ej578hCdtGtaSQUMQFkPkoXVHHByJJzZM

set -e

# Configuration
PROBLEMATIC_VALIDATOR="NodeID-Ej578hCdtGtaSQUMQFkPkoXVHHByJJzZM"
SUBNET_ID="YOUR_SUBNET_ID"  # Update with actual subnet ID
L1_RPC="http://127.0.0.1:9650/ext/bc/YOUR_CHAIN_ID/rpc"  # Update with actual RPC
VALIDATOR_MANAGER_PROXY="0xfAcadE0000000000000000000000000000000000"  # Default address

echo "=== DOS Chain Testnet Validator Management ==="
echo "Target Validator: $PROBLEMATIC_VALIDATOR"
echo ""

# Function to convert NodeID to bytes32
node_id_to_bytes32() {
  local node_id=$1
  # Remove "NodeID-" prefix and decode from CB58 to hex
  # This is a simplified version - use proper decoding in production
  echo "0x$(echo $node_id | sed 's/NodeID-//' | base58 -d | xxd -p)"
}

# Menu
echo "What would you like to do?"
echo ""
echo "1. Check validator connectivity status"
echo "2. Check all L1 validators"
echo "3. Add a new validator (recommended)"
echo "4. Remove problematic validator (PoA only)"
echo "5. Debug validator connectivity"
echo ""
read -p "Select option (1-5): " OPTION

case $OPTION in
  1)
    echo ""
    echo "=== Checking Validator Connectivity ==="
    echo ""

    # Check if node appears in peer list
    echo "Checking peer connections..."
    curl -s -X POST --data '{
      "jsonrpc":"2.0",
      "id":1,
      "method":"info.peers"
    }' -H 'content-type:application/json' http://127.0.0.1:9650/ext/info | \
      jq ".result.peers[] | select(.nodeID==\"$PROBLEMATIC_VALIDATOR\")"

    # Check L1 validator status
    echo ""
    echo "Checking L1 validator status..."
    curl -s -X POST --data "{
      \"jsonrpc\":\"2.0\",
      \"id\":1,
      \"method\":\"platform.getCurrentValidators\",
      \"params\":{\"subnetID\":\"$SUBNET_ID\"}
    }" -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/P | \
      jq ".result.validators[] | select(.nodeID==\"$PROBLEMATIC_VALIDATOR\")"
    ;;

  2)
    echo ""
    echo "=== All L1 Validators ==="
    echo ""

    curl -s -X POST --data "{
      \"jsonrpc\":\"2.0\",
      \"id\":1,
      \"method\":\"platform.getCurrentValidators\",
      \"params\":{\"subnetID\":\"$SUBNET_ID\"}
    }" -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/P | \
      jq '.result.validators[] | {nodeID, connected, weight, startTime, endTime}'
    ;;

  3)
    echo ""
    echo "=== Add New Validator (RECOMMENDED) ==="
    echo ""
    echo "To add a validator, you need:"
    echo "  1. New validator's NodeID"
    echo "  2. BLS Public Key and Signature"
    echo "  3. Sufficient AVAX for staking"
    echo ""
    echo "Steps:"
    echo ""
    echo "1. Get validator's NodeID from their node:"
    echo "   curl -X POST --data '{"
    echo "     \"jsonrpc\":\"2.0\","
    echo "     \"id\":1,"
    echo "     \"method\":\"info.getNodeID\""
    echo "   }' -H 'content-type:application/json' http://VALIDATOR_IP:9650/ext/info"
    echo ""
    echo "2. Add validator to subnet via P-Chain:"
    echo "   curl -X POST --data '{"
    echo "     \"jsonrpc\":\"2.0\","
    echo "     \"method\":\"platform.addPermissionlessValidator\","
    echo "     \"params\":{"
    echo "       \"subnetID\":\"$SUBNET_ID\","
    echo "       \"nodeID\":\"NodeID-NEW_VALIDATOR\","
    echo "       \"startTime\":$(date -u +%s),"
    echo "       \"endTime\":$(($(date -u +%s) + 31536000)),"
    echo "       \"weight\":20"
    echo "     },"
    echo "     \"id\":1"
    echo "   }' -H 'content-type:application/json' http://127.0.0.1:9650/ext/bc/P"
    echo ""
    echo "3. Or use Core Wallet:"
    echo "   - Go to Stake > Validate"
    echo "   - Select your L1 subnet"
    echo "   - Enter validator details"
    echo "   - Confirm transaction"
    ;;

  4)
    echo ""
    echo "=== Remove Validator (PoA Only) ==="
    echo ""
    echo "⚠ WARNING: This only works for Proof of Authority L1s!"
    echo "⚠ You will be left with only 1 validator (no redundancy)"
    echo "⚠ Recommended: Add a 3rd validator first"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM

    if [ "$CONFIRM" != "yes" ]; then
      echo "Aborted."
      exit 0
    fi

    echo ""
    echo "To remove validator, use one of these methods:"
    echo ""
    echo "METHOD 1: Using cast (Foundry)"
    echo "  Prerequisites: Install Foundry (foundryup)"
    echo ""
    echo "  # Convert NodeID to bytes32"
    echo "  NODE_ID_BYTES32=\$(node_id_to_bytes32 $PROBLEMATIC_VALIDATOR)"
    echo ""
    echo "  # Remove validator"
    echo "  cast send $VALIDATOR_MANAGER_PROXY \\"
    echo "    \"removeValidator(bytes32)\" \\"
    echo "    \$NODE_ID_BYTES32 \\"
    echo "    --rpc-url $L1_RPC \\"
    echo "    --private-key \$OWNER_PRIVATE_KEY"
    echo ""
    echo "METHOD 2: Using ethers.js script"
    echo "  See: https://docs.avax.network/subnets/upgrade/poa-to-pos#remove-validator"
    echo ""
    echo "METHOD 3: Via ValidatorManager contract directly"
    echo "  Contract: $VALIDATOR_MANAGER_PROXY"
    echo "  Function: removeValidator(bytes32 nodeID)"
    echo "  Parameter: NodeID as bytes32"
    ;;

  5)
    echo ""
    echo "=== Debug Validator Connectivity ==="
    echo ""
    echo "Common connectivity issues and fixes:"
    echo ""
    echo "1. FIREWALL BLOCKING PORT 9651"
    echo "   On validator node:"
    echo "   $ sudo ufw status"
    echo "   $ sudo ufw allow 9651/tcp"
    echo "   $ sudo systemctl restart avalanchego"
    echo ""
    echo "2. PORT NOT FORWARDED (NAT/Router)"
    echo "   - Log into router admin panel"
    echo "   - Forward external port 9651 -> validator internal IP:9651"
    echo "   - Test: nc -zv VALIDATOR_PUBLIC_IP 9651"
    echo ""
    echo "3. WRONG PUBLIC IP CONFIGURED"
    echo "   Add to ~/.avalanchego/config.json:"
    echo "   {"
    echo "     \"public-ip\": \"YOUR_PUBLIC_IP\","
    echo "     \"dynamic-public-ip\": \"ifconfigco\""
    echo "   }"
    echo ""
    echo "4. NODE NOT RUNNING"
    echo "   $ sudo systemctl status avalanchego"
    echo "   $ sudo systemctl start avalanchego"
    echo ""
    echo "5. WRONG NETWORK"
    echo "   Ensure node is on Fuji testnet:"
    echo "   $ curl -s localhost:9650/ext/info -X POST \\"
    echo "       -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"info.getNetworkName\"}' \\"
    echo "       -H 'content-type:application/json' | jq"
    echo "   Should return: \"networkName\": \"fuji\""
    echo ""
    echo "6. STAKING KEYS MISSING"
    echo "   $ ls -la ~/.avalanchego/staking/"
    echo "   Should show: staker.crt and staker.key"
    echo ""
    echo "To check from working node:"
    echo "  curl -s localhost:9650/ext/info -X POST \\"
    echo "    -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"info.peers\"}' \\"
    echo "    -H 'content-type:application/json' | \\"
    echo "    jq '.result.peers[] | select(.nodeID==\"$PROBLEMATIC_VALIDATOR\")'"
    ;;

  *)
    echo "Invalid option"
    exit 1
    ;;
esac

echo ""
echo "=== Script Complete ==="
