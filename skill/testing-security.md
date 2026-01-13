# Testing & Security

> Test Avalanche dApps and smart contracts with confidence

---

## Goals

1. Write comprehensive unit and integration tests
2. Test cross-chain functionality locally
3. Identify and prevent common security vulnerabilities
4. Follow security best practices for production

---

## Smart Contract Testing

### Foundry Testing

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test
forge test --match-test testTransfer

# Run with gas reporting
forge test --gas-report

# Run with coverage
forge coverage
```

### Basic Test Structure

```solidity
// test/MyContract.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken public token;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        vm.prank(owner);
        token = new MyToken();
    }

    function testInitialBalance() public view {
        assertEq(token.balanceOf(owner), 1000000 * 10 ** 18);
    }

    function testTransfer() public {
        uint256 amount = 100 * 10 ** 18;

        vm.prank(owner);
        token.transfer(user1, amount);

        assertEq(token.balanceOf(user1), amount);
    }

    function testTransferInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert();
        token.transfer(user2, 100);
    }

    function testFuzzTransfer(uint256 amount) public {
        // Bound amount to valid range
        amount = bound(amount, 0, token.balanceOf(owner));

        vm.prank(owner);
        token.transfer(user1, amount);

        assertEq(token.balanceOf(user1), amount);
    }
}
```

### Testing with Fork

```solidity
contract ForkTest is Test {
    uint256 avalancheFork;

    function setUp() public {
        // Fork Avalanche mainnet
        avalancheFork = vm.createFork("https://api.avax.network/ext/bc/C/rpc");
        vm.selectFork(avalancheFork);
    }

    function testOnFork() public {
        // Test against real Avalanche state
        address wavax = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
        IERC20 token = IERC20(wavax);

        assertGt(token.totalSupply(), 0);
    }
}
```

---

## Cross-Chain Testing

### Local Multi-Chain Setup

```bash
# Start local Avalanche network with multiple L1s
avalanche network start

# Deploy blockchain A
avalanche blockchain deploy chainA --local

# Deploy blockchain B
avalanche blockchain deploy chainB --local

# Both chains will have Teleporter deployed automatically
```

### Testing ICM Contracts

```solidity
contract CrossChainTest is Test {
    // Mock Teleporter for unit tests
    address mockTeleporter;

    CrossChainSender sender;
    CrossChainReceiver receiver;

    bytes32 sourceChainID = bytes32(uint256(1));
    bytes32 destChainID = bytes32(uint256(2));

    function setUp() public {
        mockTeleporter = makeAddr("teleporter");

        sender = new CrossChainSender(
            address(mockTeleporter),
            destChainID,
            address(0)  // Set receiver later
        );

        receiver = new CrossChainReceiver(
            mockTeleporter,
            sourceChainID
        );
    }

    function testReceiveMessage() public {
        bytes memory payload = abi.encode(
            address(this),
            "Hello from source chain"
        );

        // Simulate Teleporter calling receiver
        vm.prank(mockTeleporter);
        receiver.receiveTeleporterMessage(
            sourceChainID,
            address(sender),
            payload
        );

        assertEq(receiver.getMessagesCount(), 1);
    }

    function testUnauthorizedReceiver() public {
        bytes memory payload = abi.encode(address(this), "test");

        // Non-Teleporter address should fail
        vm.prank(address(0xdead));
        vm.expectRevert("Unauthorized");
        receiver.receiveTeleporterMessage(
            sourceChainID,
            address(sender),
            payload
        );
    }

    function testWrongSourceChain() public {
        bytes memory payload = abi.encode(address(this), "test");

        vm.prank(mockTeleporter);
        vm.expectRevert("Invalid source chain");
        receiver.receiveTeleporterMessage(
            bytes32(uint256(999)),  // Wrong chain
            address(sender),
            payload
        );
    }
}
```

### Integration Testing with Local Network

```typescript
// test/integration/crossChain.test.ts
import { describe, it, expect, beforeAll } from 'vitest'
import { createPublicClient, createWalletClient, http } from 'viem'

describe('Cross-chain Integration', () => {
  let chainAClient: ReturnType<typeof createPublicClient>
  let chainBClient: ReturnType<typeof createPublicClient>

  beforeAll(async () => {
    // Connect to local chains (after avalanche network start)
    chainAClient = createPublicClient({
      transport: http('http://localhost:9650/ext/bc/chainA/rpc'),
    })
    chainBClient = createPublicClient({
      transport: http('http://localhost:9650/ext/bc/chainB/rpc'),
    })
  })

  it('should send message from A to B', async () => {
    // Deploy contracts, send message, verify receipt
  })
})
```

---

## Hardhat Testing

### Test Configuration

```typescript
// hardhat.config.ts
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    hardhat: {
      forking: {
        url: "https://api.avax.network/ext/bc/C/rpc",
        blockNumber: 40000000,
      },
    },
  },
};

export default config;
```

### Hardhat Test Example

```typescript
import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("MyToken", function () {
  async function deployFixture() {
    const [owner, user1, user2] = await ethers.getSigners();

    const MyToken = await ethers.getContractFactory("MyToken");
    const token = await MyToken.deploy();

    return { token, owner, user1, user2 };
  }

  it("Should transfer tokens correctly", async function () {
    const { token, owner, user1 } = await loadFixture(deployFixture);

    const amount = ethers.parseEther("100");
    await token.transfer(user1.address, amount);

    expect(await token.balanceOf(user1.address)).to.equal(amount);
  });
});
```

---

## Security Checklist

### Access Control

```solidity
// Bad: No access control
function mint(address to, uint256 amount) public {
    _mint(to, amount);
}

// Good: Proper access control
function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
}

// Better: Role-based access
function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
    _mint(to, amount);
}
```

### Reentrancy Protection

```solidity
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Vault is ReentrancyGuard {
    mapping(address => uint256) public balances;

    // Bad: Vulnerable to reentrancy
    function withdrawBad() public {
        uint256 amount = balances[msg.sender];
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        balances[msg.sender] = 0;  // State change after external call
    }

    // Good: Protected with nonReentrant + CEI pattern
    function withdraw() public nonReentrant {
        uint256 amount = balances[msg.sender];
        balances[msg.sender] = 0;  // State change before external call
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}
```

### Integer Overflow (Pre-0.8.0)

```solidity
// Solidity 0.8+ has built-in overflow checks
// For older versions, use SafeMath

// Checked math (automatic in 0.8+)
uint256 result = a + b;  // Reverts on overflow

// Unchecked (when you're sure it's safe)
unchecked {
    uint256 result = a + b;  // No overflow check
}
```

### Signature Replay

```solidity
// Bad: No nonce tracking
function executeWithSignature(
    address target,
    bytes calldata data,
    bytes calldata signature
) external {
    // Signature can be replayed!
}

// Good: Track nonces
mapping(address => uint256) public nonces;

function executeWithSignature(
    address target,
    bytes calldata data,
    uint256 nonce,
    bytes calldata signature
) external {
    require(nonce == nonces[signer], "Invalid nonce");
    nonces[signer]++;
    // Execute...
}
```

### Front-Running Protection

```solidity
// Consider commit-reveal patterns for sensitive operations
mapping(bytes32 => uint256) public commits;

function commit(bytes32 hash) external {
    commits[hash] = block.timestamp;
}

function reveal(uint256 value, bytes32 salt) external {
    bytes32 hash = keccak256(abi.encodePacked(msg.sender, value, salt));
    require(commits[hash] != 0, "Not committed");
    require(block.timestamp > commits[hash] + 1 hours, "Too soon");

    // Execute with revealed value
    delete commits[hash];
}
```

---

## Cross-Chain Security

### Teleporter Security

```solidity
contract SecureCrossChainReceiver is ITeleporterReceiver {
    ITeleporterMessenger public immutable teleporter;
    bytes32 public immutable allowedSourceChain;
    address public immutable allowedSourceContract;

    function receiveTeleporterMessage(
        bytes32 sourceBlockchainID,
        address originSenderAddress,
        bytes calldata message
    ) external override {
        // CRITICAL: Verify caller is Teleporter
        require(msg.sender == address(teleporter), "Only Teleporter");

        // Verify source chain
        require(sourceBlockchainID == allowedSourceChain, "Invalid chain");

        // Verify source contract (optional but recommended)
        require(originSenderAddress == allowedSourceContract, "Invalid sender");

        // Now safe to process message
        _processMessage(message);
    }
}
```

### Message Validation

```solidity
function _processMessage(bytes calldata message) internal {
    // Decode and validate message format
    if (message.length < 4) {
        revert("Message too short");
    }

    bytes4 selector = bytes4(message[:4]);

    // Only allow expected function selectors
    if (selector != this.handleTransfer.selector &&
        selector != this.handleMint.selector) {
        revert("Unknown message type");
    }

    // Decode with proper error handling
    try this._decodeAndExecute(message) {
        // Success
    } catch Error(string memory reason) {
        emit MessageFailed(reason);
    }
}
```

---

## Common Vulnerabilities

### 1. Unsafe External Calls

```solidity
// Bad: Unchecked return value
IERC20(token).transfer(to, amount);

// Good: Check return value
require(IERC20(token).transfer(to, amount), "Transfer failed");

// Better: Use SafeERC20
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
using SafeERC20 for IERC20;
IERC20(token).safeTransfer(to, amount);
```

### 2. Denial of Service

```solidity
// Bad: Loop over unbounded array
function distribute(address[] memory recipients) external {
    for (uint i = 0; i < recipients.length; i++) {
        // Could run out of gas
        payable(recipients[i]).transfer(amount);
    }
}

// Good: Paginated or pull-based
function distribute(uint256 start, uint256 end) external {
    require(end <= recipients.length, "Out of bounds");
    require(end - start <= 100, "Batch too large");

    for (uint i = start; i < end; i++) {
        // Process limited batch
    }
}
```

### 3. Price Oracle Manipulation

```solidity
// Bad: Spot price from single source
uint256 price = uniswapPair.getReserves();

// Good: TWAP or multiple oracles
uint256 price = chainlinkOracle.latestRoundData();
require(block.timestamp - updateTime < 1 hours, "Stale price");
```

---

## Testing Tools

### Static Analysis

```bash
# Slither - Security analyzer
pip install slither-analyzer
slither .

# Mythril - Symbolic execution
pip install mythril
myth analyze contracts/MyContract.sol
```

### Fuzzing

```solidity
// Foundry fuzz testing
function testFuzz_Transfer(
    address to,
    uint256 amount
) public {
    vm.assume(to != address(0));
    vm.assume(amount <= token.balanceOf(owner));

    vm.prank(owner);
    token.transfer(to, amount);

    assertEq(token.balanceOf(to), amount);
}

// Invariant testing
function invariant_TotalSupplyConstant() public view {
    assertEq(token.totalSupply(), INITIAL_SUPPLY);
}
```

### Gas Optimization

```bash
# Run gas snapshot
forge snapshot

# Compare gas usage
forge snapshot --diff
```

---

## Audit Preparation

### Pre-Audit Checklist

1. **Documentation**
   - [ ] System architecture documented
   - [ ] All functions documented with NatSpec
   - [ ] Known limitations listed

2. **Testing**
   - [ ] Unit test coverage > 90%
   - [ ] Integration tests passing
   - [ ] Fuzz tests for critical functions

3. **Static Analysis**
   - [ ] Slither findings addressed
   - [ ] No compiler warnings

4. **Code Quality**
   - [ ] Follows Solidity style guide
   - [ ] No unused code
   - [ ] Clear variable naming

### Post-Audit

1. Address all critical and high findings
2. Document accepted risks
3. Re-run all tests
4. Consider bug bounty program
