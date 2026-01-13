# Security Best Practices

> Secure your Avalanche smart contracts and dApps

---

## Goals

1. Identify and prevent common vulnerabilities
2. Implement secure coding patterns
3. Handle cross-chain security properly
4. Prepare for security audits

---

## OWASP Smart Contract Top 10

### 1. Reentrancy

**Vulnerability**: External calls can call back into your contract before state updates.

```solidity
// VULNERABLE
function withdraw() public {
    uint256 amount = balances[msg.sender];
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success);
    balances[msg.sender] = 0;  // Too late!
}

// SECURE: Checks-Effects-Interactions pattern
function withdraw() public nonReentrant {
    uint256 amount = balances[msg.sender];
    balances[msg.sender] = 0;  // Update state FIRST
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");
}
```

**Prevention**:
- Use OpenZeppelin's `ReentrancyGuard`
- Follow Checks-Effects-Interactions pattern
- Update state before external calls

### 2. Access Control

**Vulnerability**: Missing or improper access restrictions.

```solidity
// VULNERABLE: Anyone can mint
function mint(address to, uint256 amount) public {
    _mint(to, amount);
}

// SECURE: Role-based access
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SecureToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
```

**Prevention**:
- Use OpenZeppelin's `Ownable` or `AccessControl`
- Implement principle of least privilege
- Document all privileged functions

### 3. Integer Overflow/Underflow

**Vulnerability**: Arithmetic operations wrap around (pre-Solidity 0.8).

```solidity
// Solidity 0.8+ has built-in checks
uint256 a = type(uint256).max;
uint256 b = a + 1;  // REVERTS automatically

// Use unchecked only when certain it's safe
unchecked {
    uint256 c = a + 1;  // Wraps to 0
}
```

**Prevention**:
- Use Solidity 0.8+
- Be careful with `unchecked` blocks
- Validate inputs before arithmetic

### 4. Unsafe External Calls

**Vulnerability**: Not checking return values or using deprecated patterns.

```solidity
// VULNERABLE: Ignoring return value
IERC20(token).transfer(to, amount);

// VULNERABLE: Using transfer() which can fail silently
payable(to).transfer(amount);

// SECURE: Check return values
require(IERC20(token).transfer(to, amount), "Transfer failed");

// BETTER: Use SafeERC20
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
using SafeERC20 for IERC20;

IERC20(token).safeTransfer(to, amount);

// SECURE: Use call for ETH/AVAX
(bool success, ) = to.call{value: amount}("");
require(success, "Transfer failed");
```

### 5. Denial of Service (DoS)

**Vulnerability**: Attackers can make functions unusable.

```solidity
// VULNERABLE: Unbounded loop
function distributeRewards(address[] memory users) public {
    for (uint i = 0; i < users.length; i++) {
        // Can run out of gas with large array
        payable(users[i]).transfer(rewards[users[i]]);
    }
}

// SECURE: Pull pattern + pagination
mapping(address => uint256) public pendingRewards;

function claimReward() public {
    uint256 reward = pendingRewards[msg.sender];
    require(reward > 0, "No rewards");
    pendingRewards[msg.sender] = 0;
    (bool success, ) = msg.sender.call{value: reward}("");
    require(success, "Transfer failed");
}
```

**Prevention**:
- Use pull over push for payments
- Implement pagination for loops
- Set reasonable gas limits

### 6. Front-Running

**Vulnerability**: Attackers see pending transactions and act first.

```solidity
// VULNERABLE: DEX swap without slippage protection
function swap(address tokenIn, address tokenOut, uint256 amountIn) public {
    // Attacker can sandwich this transaction
}

// SECURE: Commit-reveal pattern
mapping(bytes32 => uint256) public commitments;

function commit(bytes32 hash) external {
    commitments[hash] = block.timestamp;
}

function reveal(
    uint256 value,
    bytes32 salt
) external {
    bytes32 hash = keccak256(abi.encodePacked(msg.sender, value, salt));
    require(commitments[hash] != 0, "Not committed");
    require(block.timestamp >= commitments[hash] + 1 minutes, "Too soon");
    require(block.timestamp <= commitments[hash] + 1 hours, "Expired");

    delete commitments[hash];
    // Execute action with value
}
```

### 7. Timestamp Dependence

**Vulnerability**: Miners can manipulate `block.timestamp` slightly.

```solidity
// VULNERABLE: Exact timestamp comparison
require(block.timestamp == deadline, "Wrong time");

// SECURE: Use ranges, not exact values
require(block.timestamp >= startTime, "Too early");
require(block.timestamp <= endTime, "Too late");

// Note: On Avalanche, block times are more predictable
// but still don't rely on exact timestamps
```

### 8. Signature Replay

**Vulnerability**: Signatures can be reused across transactions or chains.

```solidity
// VULNERABLE: No replay protection
function executeWithSig(
    address to,
    uint256 amount,
    bytes memory signature
) external {
    address signer = recoverSigner(to, amount, signature);
    // Signature can be replayed!
}

// SECURE: Include nonce and chain ID
mapping(address => uint256) public nonces;

function executeWithSig(
    address to,
    uint256 amount,
    uint256 nonce,
    uint256 deadline,
    bytes memory signature
) external {
    require(block.timestamp <= deadline, "Expired");
    require(nonce == nonces[signer], "Invalid nonce");

    bytes32 hash = keccak256(abi.encodePacked(
        "\x19\x01",
        DOMAIN_SEPARATOR,  // Includes chain ID
        keccak256(abi.encode(to, amount, nonce, deadline))
    ));

    address signer = ECDSA.recover(hash, signature);
    nonces[signer]++;

    // Execute
}
```

### 9. Oracle Manipulation

**Vulnerability**: Using manipulable price feeds.

```solidity
// VULNERABLE: Spot price from single DEX
function getPrice() public view returns (uint256) {
    (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
    return reserve1 * 1e18 / reserve0;  // Easily manipulated!
}

// SECURE: Use Chainlink oracles
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

AggregatorV3Interface internal priceFeed;

function getPrice() public view returns (uint256) {
    (
        uint80 roundId,
        int256 price,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) = priceFeed.latestRoundData();

    require(price > 0, "Invalid price");
    require(updatedAt >= block.timestamp - 1 hours, "Stale price");
    require(answeredInRound >= roundId, "Stale round");

    return uint256(price);
}
```

### 10. Uninitialized Storage/Proxy Issues

**Vulnerability**: Storage collisions in proxy patterns.

```solidity
// SECURE: Use OpenZeppelin's upgradeable contracts
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract MyContractV1 is Initializable {
    uint256 public value;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 _value) public initializer {
        value = _value;
    }
}
```

---

## Avalanche-Specific Security

### Cross-Chain Message Validation

```solidity
contract SecureCrossChainReceiver is ITeleporterReceiver {
    ITeleporterMessenger public immutable teleporter;
    bytes32 public immutable trustedSourceChain;
    address public immutable trustedSourceContract;

    constructor(
        address _teleporter,
        bytes32 _sourceChain,
        address _sourceContract
    ) {
        teleporter = ITeleporterMessenger(_teleporter);
        trustedSourceChain = _sourceChain;
        trustedSourceContract = _sourceContract;
    }

    function receiveTeleporterMessage(
        bytes32 sourceBlockchainID,
        address originSenderAddress,
        bytes calldata message
    ) external override {
        // CRITICAL: Verify all three conditions
        require(
            msg.sender == address(teleporter),
            "Caller must be Teleporter"
        );
        require(
            sourceBlockchainID == trustedSourceChain,
            "Invalid source chain"
        );
        require(
            originSenderAddress == trustedSourceContract,
            "Invalid source contract"
        );

        // Now safe to process
        _processMessage(message);
    }
}
```

### Warp Message Security

```solidity
// Verify Warp messages properly
import "@subnet-evm/contracts/interfaces/IWarpMessenger.sol";

function verifyWarpMessage(bytes32 messageHash) internal view returns (bool) {
    IWarpMessenger warp = IWarpMessenger(WARP_PRECOMPILE);

    (WarpMessage memory message, bool valid) = warp.getVerifiedWarpMessage(0);

    require(valid, "Invalid Warp message");
    require(
        keccak256(message.payload) == messageHash,
        "Message hash mismatch"
    );

    return true;
}
```

### L1/Subnet Trust Assumptions

When building for Avalanche L1s, consider:

1. **Validator Set Size**: Smaller validator sets = lower security guarantees
2. **Stake Requirements**: Higher stake = more economic security
3. **Cross-chain Dependencies**: Your L1's security depends on the source chain's security

```solidity
// Consider requiring minimum confirmations for high-value operations
uint256 public constant MIN_CONFIRMATIONS = 10;

function processHighValueTransfer(
    bytes32 messageId,
    uint256 blockNumber
) external {
    require(
        block.number >= blockNumber + MIN_CONFIRMATIONS,
        "Insufficient confirmations"
    );
    // Process transfer
}
```

---

## Secure Development Patterns

### Pausable Contracts

```solidity
import "@openzeppelin/contracts/security/Pausable.sol";

contract SecureContract is Pausable, Ownable {
    function criticalFunction() external whenNotPaused {
        // Only works when not paused
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
```

### Rate Limiting

```solidity
contract RateLimited {
    uint256 public constant RATE_LIMIT = 1000 ether;
    uint256 public constant RATE_PERIOD = 1 days;

    uint256 public periodStart;
    uint256 public periodAmount;

    modifier rateLimited(uint256 amount) {
        if (block.timestamp >= periodStart + RATE_PERIOD) {
            periodStart = block.timestamp;
            periodAmount = 0;
        }

        require(
            periodAmount + amount <= RATE_LIMIT,
            "Rate limit exceeded"
        );
        periodAmount += amount;
        _;
    }

    function withdraw(uint256 amount) external rateLimited(amount) {
        // Process withdrawal
    }
}
```

### Emergency Withdrawal

```solidity
contract WithEmergencyExit is Ownable {
    bool public emergencyMode;

    modifier notInEmergency() {
        require(!emergencyMode, "Emergency mode active");
        _;
    }

    function enableEmergencyMode() external onlyOwner {
        emergencyMode = true;
        emit EmergencyModeEnabled(block.timestamp);
    }

    function emergencyWithdraw() external {
        require(emergencyMode, "Not in emergency mode");
        uint256 balance = userBalances[msg.sender];
        userBalances[msg.sender] = 0;
        // Return user funds without normal checks
        payable(msg.sender).transfer(balance);
    }
}
```

---

## Security Tools

### Static Analysis

```bash
# Slither - Comprehensive analyzer
pip install slither-analyzer
slither . --print human-summary

# Common findings to address:
# - Reentrancy vulnerabilities
# - Unchecked return values
# - Dangerous strict equalities
# - Missing zero-address checks

# Mythril - Symbolic execution
pip install mythril
myth analyze contracts/MyContract.sol
```

### Foundry Security Testing

```solidity
// Fuzz testing for edge cases
function testFuzz_CannotWithdrawMoreThanBalance(
    address user,
    uint256 depositAmount,
    uint256 withdrawAmount
) public {
    vm.assume(user != address(0));
    vm.assume(depositAmount > 0 && depositAmount < type(uint128).max);

    // Setup
    vm.deal(user, depositAmount);
    vm.prank(user);
    vault.deposit{value: depositAmount}();

    // Should revert if withdrawing more than deposited
    if (withdrawAmount > depositAmount) {
        vm.expectRevert();
    }

    vm.prank(user);
    vault.withdraw(withdrawAmount);
}

// Invariant testing
function invariant_TotalSupplyMatchesBalances() public {
    uint256 totalFromBalances = 0;
    for (uint i = 0; i < actors.length; i++) {
        totalFromBalances += token.balanceOf(actors[i]);
    }
    assertEq(token.totalSupply(), totalFromBalances);
}
```

---

## Audit Checklist

### Pre-Audit Preparation

- [ ] All tests passing with >90% coverage
- [ ] No compiler warnings
- [ ] Slither findings addressed or documented
- [ ] NatSpec documentation complete
- [ ] README with architecture overview
- [ ] Known issues documented

### Code Quality

- [ ] Follows Solidity style guide
- [ ] Consistent naming conventions
- [ ] No dead code or unused imports
- [ ] Events for all state changes
- [ ] Clear error messages

### Access Control

- [ ] All privileged functions identified
- [ ] Role hierarchy documented
- [ ] Multi-sig for critical operations
- [ ] Timelocks on upgrades

### Economic Security

- [ ] No flashloan attack vectors
- [ ] Oracle manipulation resistant
- [ ] Slippage protection on swaps
- [ ] Fee extraction not exploitable

### Cross-Chain (if applicable)

- [ ] Message origin validated
- [ ] Chain ID checked
- [ ] Replay protection in place
- [ ] Failure modes handled

---

## Incident Response

### If You Discover a Vulnerability

1. **Don't panic** - Assess severity calmly
2. **Pause if possible** - Use pausable pattern
3. **Don't disclose publicly** - Coordinate privately
4. **Prepare fix** - Have patch ready before announcement
5. **Communicate** - Notify users through official channels

### Bug Bounty Programs

Consider setting up a bug bounty:
- Immunefi: https://immunefi.com
- HackerOne: https://hackerone.com
- Code4rena: https://code4rena.com
