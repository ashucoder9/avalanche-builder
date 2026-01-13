# Smart Contract Development

> Write, deploy, and interact with Solidity smart contracts on Avalanche

---

## Goals

1. Set up a smart contract development environment
2. Write common contract patterns (tokens, NFTs, DeFi)
3. Deploy and verify contracts on Avalanche
4. Interact with deployed contracts

---

## Getting Started

### Prerequisites

```bash
# Install Foundry (recommended)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Or install Hardhat
npm install --save-dev hardhat
npx hardhat init
```

### Create a New Project

```bash
# Foundry
forge init my-avalanche-contracts
cd my-avalanche-contracts

# Install OpenZeppelin
forge install OpenZeppelin/openzeppelin-contracts

# Add remappings
echo '@openzeppelin/=lib/openzeppelin-contracts/' >> remappings.txt
```

### Project Structure

```
my-avalanche-contracts/
├── src/                  # Contract source files
│   └── MyContract.sol
├── test/                 # Test files
│   └── MyContract.t.sol
├── script/               # Deployment scripts
│   └── Deploy.s.sol
├── lib/                  # Dependencies
├── foundry.toml          # Configuration
└── remappings.txt        # Import remappings
```

---

## foundry.toml Configuration

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.24"
optimizer = true
optimizer_runs = 200

# Avalanche RPC endpoints
[rpc_endpoints]
avalanche = "https://api.avax.network/ext/bc/C/rpc"
fuji = "https://api.avax-test.network/ext/bc/C/rpc"
local = "http://127.0.0.1:9650/ext/bc/C/rpc"

# For contract verification
[etherscan]
avalanche = { key = "${SNOWTRACE_API_KEY}", url = "https://api.snowtrace.io/api" }
fuji = { key = "${SNOWTRACE_API_KEY}", url = "https://api-testnet.snowtrace.io/api" }
```

---

## Contract Patterns

### 1. ERC-20 Token

A fungible token (like USDC, WAVAX).

```solidity
// src/MyToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, ERC20Burnable, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }

    /// @notice Mint new tokens (only owner)
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
```

**Deploy:**
```bash
forge create src/MyToken.sol:MyToken \
  --rpc-url fuji \
  --private-key $PRIVATE_KEY \
  --constructor-args "My Token" "MTK" 1000000 \
  --verify
```

### 2. ERC-721 NFT

A non-fungible token collection.

```solidity
// src/MyNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721, ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;
    uint256 public mintPrice = 0.01 ether;  // 0.01 AVAX
    uint256 public maxSupply = 10000;

    constructor() ERC721("My NFT Collection", "MNFT") Ownable(msg.sender) {}

    /// @notice Mint a new NFT
    function mint(string memory uri) public payable returns (uint256) {
        require(msg.value >= mintPrice, "Insufficient payment");
        require(_nextTokenId < maxSupply, "Max supply reached");

        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);

        return tokenId;
    }

    /// @notice Batch mint multiple NFTs
    function batchMint(string[] memory uris) public payable returns (uint256[] memory) {
        require(msg.value >= mintPrice * uris.length, "Insufficient payment");
        require(_nextTokenId + uris.length <= maxSupply, "Exceeds max supply");

        uint256[] memory tokenIds = new uint256[](uris.length);

        for (uint256 i = 0; i < uris.length; i++) {
            uint256 tokenId = _nextTokenId++;
            _safeMint(msg.sender, tokenId);
            _setTokenURI(tokenId, uris[i]);
            tokenIds[i] = tokenId;
        }

        return tokenIds;
    }

    /// @notice Withdraw contract balance (only owner)
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    /// @notice Update mint price (only owner)
    function setMintPrice(uint256 newPrice) public onlyOwner {
        mintPrice = newPrice;
    }

    // Required overrides
    function tokenURI(uint256 tokenId)
        public view override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
```

### 3. Simple Vault

A contract for depositing and withdrawing AVAX.

```solidity
// src/Vault.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Vault is ReentrancyGuard {
    mapping(address => uint256) public balances;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    /// @notice Deposit AVAX into the vault
    function deposit() public payable {
        require(msg.value > 0, "Must deposit something");
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Withdraw AVAX from the vault
    function withdraw(uint256 amount) public nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Withdraw all AVAX from the vault
    function withdrawAll() public nonReentrant {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");

        balances[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Get contract's total balance
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
```

### 4. Staking Contract

Stake tokens to earn rewards.

```solidity
// src/Staking.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Staking is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    uint256 public rewardRate = 100;  // Rewards per second
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public balances;

    uint256 public totalSupply;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(
        address _stakingToken,
        address _rewardToken
    ) Ownable(msg.sender) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;

        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored +
            ((block.timestamp - lastUpdateTime) * rewardRate * 1e18) / totalSupply;
    }

    function earned(address account) public view returns (uint256) {
        return (balances[account] *
            (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 +
            rewards[account];
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");

        totalSupply += amount;
        balances[msg.sender] += amount;

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        totalSupply -= amount;
        balances[msg.sender] -= amount;

        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function claimReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        rewardRate = _rewardRate;
    }
}
```

### 5. Multi-Signature Wallet

Require multiple approvals for transactions.

```solidity
// src/MultiSig.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed txId);
    event Approve(address indexed owner, uint256 indexed txId);
    event Revoke(address indexed owner, uint256 indexed txId);
    event Execute(uint256 indexed txId);

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public approved;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    modifier txExists(uint256 txId) {
        require(txId < transactions.length, "Tx does not exist");
        _;
    }

    modifier notApproved(uint256 txId) {
        require(!approved[txId][msg.sender], "Already approved");
        _;
    }

    modifier notExecuted(uint256 txId) {
        require(!transactions[txId].executed, "Already executed");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(
            _required > 0 && _required <= _owners.length,
            "Invalid required number"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Duplicate owner");

            isOwner[owner] = true;
            owners.push(owner);
        }

        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submit(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwner {
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false
        }));

        emit Submit(transactions.length - 1);
    }

    function approve(uint256 txId)
        external
        onlyOwner
        txExists(txId)
        notApproved(txId)
        notExecuted(txId)
    {
        approved[txId][msg.sender] = true;
        emit Approve(msg.sender, txId);
    }

    function getApprovalCount(uint256 txId) public view returns (uint256 count) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (approved[txId][owners[i]]) {
                count++;
            }
        }
    }

    function execute(uint256 txId)
        external
        txExists(txId)
        notExecuted(txId)
    {
        require(getApprovalCount(txId) >= required, "Not enough approvals");

        Transaction storage transaction = transactions[txId];
        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "Tx failed");

        emit Execute(txId);
    }

    function revoke(uint256 txId)
        external
        onlyOwner
        txExists(txId)
        notExecuted(txId)
    {
        require(approved[txId][msg.sender], "Not approved");
        approved[txId][msg.sender] = false;
        emit Revoke(msg.sender, txId);
    }
}
```

---

## Deployment Scripts

> **IMPORTANT: Smart contract deployments are IRREVERSIBLE**
>
> Once deployed, contracts cannot be modified (unless using upgradeable patterns).
> Bugs in deployed contracts can result in **permanent loss of funds**.
>
> **Deployment Checklist:**
> - [ ] All tests passing (`forge test`)
> - [ ] 100% test coverage on critical paths (`forge coverage`)
> - [ ] Fuzz tests for numeric operations
> - [ ] Deployed and tested on **Fuji testnet first**
> - [ ] Security audit completed (for high-value contracts)
> - [ ] Constructor arguments verified
> - [ ] Private key is for correct deployer address

### Basic Deployment

```solidity
// script/Deploy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/MyToken.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        MyToken token = new MyToken("My Token", "MTK", 1_000_000);

        console.log("Token deployed to:", address(token));
        console.log("Total supply:", token.totalSupply());

        vm.stopBroadcast();
    }
}
```

### Deploy Commands

```bash
# ============================================
# STEP 1: Deploy to local (development)
# ============================================
forge script script/Deploy.s.sol --rpc-url local --broadcast

# ============================================
# STEP 2: Deploy to Fuji testnet (ALWAYS DO THIS FIRST)
# ============================================
# Simulate first (no --broadcast) to catch errors
forge script script/Deploy.s.sol --rpc-url fuji

# If simulation succeeds, deploy
forge script script/Deploy.s.sol --rpc-url fuji --broadcast --verify

# Test the deployed contract thoroughly on Fuji before mainnet!

# ============================================
# STEP 3: Deploy to mainnet (IRREVERSIBLE)
# ============================================
# WARNING: This uses real AVAX and creates permanent contracts

# Pre-mainnet verification:
# 1. Fuji deployment tested and working
# 2. All contract addresses and parameters verified
# 3. Private key backup exists
# 4. Sufficient AVAX for deployment gas

# Simulate first
forge script script/Deploy.s.sol --rpc-url avalanche

# Deploy for real (NO UNDO AFTER THIS)
forge script script/Deploy.s.sol --rpc-url avalanche --broadcast --verify

# ============================================
# Verify existing contract
# ============================================
forge verify-contract \
  --chain-id 43114 \
  --watch \
  <CONTRACT_ADDRESS> \
  src/MyToken.sol:MyToken \
  --constructor-args $(cast abi-encode "constructor(string,string,uint256)" "My Token" "MTK" 1000000)
```

---

## Writing Tests

### Basic Test

```solidity
// test/MyToken.t.sol
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
        token = new MyToken("Test Token", "TST", 1_000_000);
    }

    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), 1_000_000 * 10 ** 18);
        assertEq(token.balanceOf(owner), 1_000_000 * 10 ** 18);
    }

    function test_Transfer() public {
        uint256 amount = 100 * 10 ** 18;

        vm.prank(owner);
        token.transfer(user1, amount);

        assertEq(token.balanceOf(user1), amount);
        assertEq(token.balanceOf(owner), (1_000_000 * 10 ** 18) - amount);
    }

    function test_Mint_OnlyOwner() public {
        uint256 amount = 100 * 10 ** 18;

        // Owner can mint
        vm.prank(owner);
        token.mint(user1, amount);
        assertEq(token.balanceOf(user1), amount);

        // Non-owner cannot mint
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user2, amount);
    }

    function testFuzz_Transfer(uint256 amount) public {
        // Bound amount to valid range
        amount = bound(amount, 1, token.balanceOf(owner));

        vm.prank(owner);
        token.transfer(user1, amount);

        assertEq(token.balanceOf(user1), amount);
    }
}
```

### Run Tests

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test
forge test --match-test test_Transfer

# Run tests on a fork
forge test --fork-url https://api.avax.network/ext/bc/C/rpc

# Gas report
forge test --gas-report

# Coverage
forge coverage
```

---

## Interacting with Contracts

### Using Cast (CLI)

```bash
# Read a value
cast call <CONTRACT_ADDRESS> "balanceOf(address)" <WALLET_ADDRESS> --rpc-url fuji

# Send a transaction
cast send <CONTRACT_ADDRESS> "transfer(address,uint256)" <TO_ADDRESS> 1000000000000000000 \
  --rpc-url fuji \
  --private-key $PRIVATE_KEY

# Decode function data
cast 4byte-decode 0xa9059cbb...

# Encode function call
cast calldata "transfer(address,uint256)" 0x123... 1000000000000000000
```

### Using viem (TypeScript)

```typescript
import { createPublicClient, createWalletClient, http, parseAbi } from 'viem'
import { avalancheFuji } from 'viem/chains'
import { privateKeyToAccount } from 'viem/accounts'

// ABI (can also import from JSON)
const abi = parseAbi([
  'function balanceOf(address) view returns (uint256)',
  'function transfer(address to, uint256 amount) returns (bool)',
  'event Transfer(address indexed from, address indexed to, uint256 value)',
])

// Create clients
const publicClient = createPublicClient({
  chain: avalancheFuji,
  transport: http(),
})

const account = privateKeyToAccount(process.env.PRIVATE_KEY as `0x${string}`)
const walletClient = createWalletClient({
  account,
  chain: avalancheFuji,
  transport: http(),
})

// Read contract
const balance = await publicClient.readContract({
  address: '0x...',
  abi,
  functionName: 'balanceOf',
  args: ['0x...'],
})

// Write contract
const hash = await walletClient.writeContract({
  address: '0x...',
  abi,
  functionName: 'transfer',
  args: ['0x...', 1000000000000000000n],
})

// Wait for confirmation
const receipt = await publicClient.waitForTransactionReceipt({ hash })
console.log('Transfer confirmed:', receipt.status)
```

---

## Common Errors & Solutions

### "Insufficient funds"
```bash
# Check balance
cast balance $WALLET_ADDRESS --rpc-url fuji

# Get testnet AVAX from faucet
# https://faucet.avax.network/
```

### "Execution reverted"
```bash
# Simulate transaction to see error
cast call <CONTRACT> "function(args)" --rpc-url fuji

# Or use trace
cast run <TX_HASH> --rpc-url fuji
```

### "Contract not verified"
```bash
# Manual verification
forge verify-contract \
  --chain 43113 \
  <ADDRESS> \
  src/MyContract.sol:MyContract \
  --constructor-args $(cast abi-encode "constructor(uint256)" 100)
```

---

## Security: Attack Vectors & Protection

Understanding common vulnerabilities is critical for writing secure contracts. These patterns have caused billions in losses.

### Top 10 Smart Contract Vulnerabilities

#### 1. Reentrancy Attacks

**How it works**: Attacker's contract recursively calls back into your contract before state updates complete.

**Real Impact**: The DAO hack ($60M), Rari Capital ($80M), Penpie ($30M in 2024)

```solidity
// VULNERABLE - State updated AFTER external call
function withdraw(uint256 amount) external {
    require(balances[msg.sender] >= amount);
    (bool success, ) = msg.sender.call{value: amount}("");  // Attacker can re-enter here
    require(success);
    balances[msg.sender] -= amount;  // Too late!
}

// SECURE - Checks-Effects-Interactions pattern
function withdraw(uint256 amount) external nonReentrant {
    require(balances[msg.sender] >= amount, "Insufficient balance");
    balances[msg.sender] -= amount;  // Effect BEFORE interaction
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");
}
```

**Protection**:
```solidity
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SecureContract is ReentrancyGuard {
    function sensitiveFunction() external nonReentrant {
        // Protected from reentrancy
    }
}
```

#### 2. Access Control Failures

**How it works**: Critical functions lack permission checks, allowing anyone to call them.

**Real Impact**: Radiant Capital ($53M in 2024), countless smaller hacks

```solidity
// VULNERABLE - No access control
function mint(address to, uint256 amount) external {
    _mint(to, amount);  // Anyone can mint!
}

// SECURE - Role-based access
import "@openzeppelin/contracts/access/AccessControl.sol";

contract SecureToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
```

**OpenZeppelin Access Patterns**:
```solidity
// Simple ownership
import "@openzeppelin/contracts/access/Ownable.sol";

// Two-step ownership transfer (safer)
import "@openzeppelin/contracts/access/Ownable2Step.sol";

// Role-based (multiple roles)
import "@openzeppelin/contracts/access/AccessControl.sol";
```

#### 3. Integer Overflow/Underflow

**How it works**: Arithmetic exceeds data type limits, wrapping around unexpectedly.

**Protection**: Solidity 0.8+ has built-in overflow checks. For older versions, use SafeMath.

```solidity
// Solidity 0.8+ - automatic protection
uint256 result = a + b;  // Reverts on overflow

// If you need unchecked math (gas optimization)
unchecked {
    uint256 result = a + b;  // No overflow check - use carefully!
}
```

#### 4. Front-Running / MEV

**How it works**: Attackers see your pending transaction and submit their own with higher gas to execute first.

```solidity
// VULNERABLE - Predictable swap
function swap(uint256 amountIn, uint256 minAmountOut) external {
    // MEV bot sees this, front-runs with same swap
}

// SECURE - Commit-reveal pattern
mapping(bytes32 => uint256) public commitments;

function commit(bytes32 hash) external {
    commitments[hash] = block.number;
}

function reveal(uint256 amount, bytes32 secret) external {
    bytes32 hash = keccak256(abi.encodePacked(msg.sender, amount, secret));
    require(commitments[hash] > 0, "No commitment");
    require(block.number > commitments[hash] + 1, "Too early");
    // Execute swap
}
```

**Protection**:
- Use commit-reveal for sensitive operations
- Set reasonable slippage limits (0.1-5%)
- Consider private mempools (Flashbots)

#### 5. Oracle Manipulation

**How it works**: Attacker manipulates price feeds to exploit collateral calculations.

**Real Impact**: Inverse Finance ($15.6M), Mango Markets ($114M)

```solidity
// VULNERABLE - Spot price from DEX
function getPrice() public view returns (uint256) {
    return dex.getReserves();  // Can be manipulated in single tx
}

// SECURE - Use Chainlink oracle
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

AggregatorV3Interface internal priceFeed;

function getPrice() public view returns (uint256) {
    (, int256 price, , uint256 updatedAt, ) = priceFeed.latestRoundData();
    require(block.timestamp - updatedAt < 1 hours, "Stale price");
    require(price > 0, "Invalid price");
    return uint256(price);
}
```

#### 6. Denial of Service (DoS)

**How it works**: Attacker makes contract unusable by consuming all gas or causing failures.

```solidity
// VULNERABLE - Unbounded loop
function distributeRewards(address[] memory recipients) external {
    for (uint i = 0; i < recipients.length; i++) {
        payable(recipients[i]).transfer(rewards[recipients[i]]);  // Can fail and block all
    }
}

// SECURE - Pull pattern
mapping(address => uint256) public pendingRewards;

function claimReward() external {
    uint256 reward = pendingRewards[msg.sender];
    require(reward > 0, "No reward");
    pendingRewards[msg.sender] = 0;
    (bool success, ) = msg.sender.call{value: reward}("");
    require(success, "Transfer failed");
}
```

#### 7. Unsafe External Calls

**How it works**: Unchecked calls to arbitrary addresses enable malicious code execution.

```solidity
// VULNERABLE - Arbitrary call target
function execute(address target, bytes calldata data) external {
    target.call(data);  // Attacker can call anything
}

// SECURE - Whitelist targets
mapping(address => bool) public allowedTargets;

function execute(address target, bytes calldata data) external onlyOwner {
    require(allowedTargets[target], "Target not allowed");
    (bool success, ) = target.call(data);
    require(success, "Call failed");
}
```

#### 8. Flashloan Attacks

**How it works**: Uncollateralized loans enable governance attacks or price manipulation in single transaction.

**Real Impact**: Beanstalk ($181M)

```solidity
// Protection for governance
import "@openzeppelin/contracts/governance/utils/Votes.sol";

// Require tokens to be held for minimum time before voting
function _getVotes(address account) internal view returns (uint256) {
    // Snapshot-based voting prevents flashloan attacks
    return getPastVotes(account, block.number - 1);
}
```

#### 9. Signature Replay

**How it works**: Valid signature is reused on different chain or after intended use.

```solidity
// SECURE - Include chain ID and nonce
function executeWithSignature(
    address to,
    uint256 amount,
    uint256 nonce,
    uint256 deadline,
    bytes memory signature
) external {
    require(block.timestamp <= deadline, "Expired");
    require(!usedNonces[nonce], "Nonce used");

    bytes32 hash = keccak256(abi.encodePacked(
        "\x19\x01",
        DOMAIN_SEPARATOR,  // Includes chain ID
        keccak256(abi.encode(to, amount, nonce, deadline))
    ));

    address signer = ECDSA.recover(hash, signature);
    require(signer == authorizedSigner, "Invalid signature");

    usedNonces[nonce] = true;
    // Execute
}
```

#### 10. Improper Input Validation

**How it works**: Contract accepts malicious or unexpected inputs.

```solidity
// SECURE - Validate all inputs
function transfer(address to, uint256 amount) external {
    require(to != address(0), "Invalid recipient");
    require(to != address(this), "Cannot send to contract");
    require(amount > 0, "Amount must be positive");
    require(amount <= balances[msg.sender], "Insufficient balance");

    balances[msg.sender] -= amount;
    balances[to] += amount;
}
```

---

## OpenZeppelin Security Utilities

### Essential Imports

```solidity
// Reentrancy protection
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Emergency stop
import "@openzeppelin/contracts/utils/Pausable.sol";

// Access control
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// Safe token handling
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Cryptographic utilities
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
```

### ReentrancyGuard

```solidity
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SecureVault is ReentrancyGuard {
    // Add nonReentrant to all state-changing external functions
    function withdraw(uint256 amount) external nonReentrant {
        // Safe from reentrancy
    }

    function deposit() external payable nonReentrant {
        // Also protect deposits
    }
}
```

### Pausable (Emergency Stop)

```solidity
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PausableToken is ERC20, Pausable, Ownable {
    function transfer(address to, uint256 amount)
        public
        override
        whenNotPaused  // Blocks transfers when paused
        returns (bool)
    {
        return super.transfer(to, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
```

### SafeERC20

```solidity
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenHandler {
    using SafeERC20 for IERC20;

    function handleToken(IERC20 token, address to, uint256 amount) external {
        // These revert on failure (unlike raw transfer which may return false)
        token.safeTransfer(to, amount);
        token.safeTransferFrom(msg.sender, address(this), amount);
        token.safeApprove(spender, amount);
        token.safeIncreaseAllowance(spender, amount);
    }
}
```

---

## Security Audit Checklist

Before deploying to mainnet:

### Code Quality
- [ ] Solidity 0.8.24+ with optimizer enabled
- [ ] All compiler warnings resolved
- [ ] No floating pragma (`^0.8.0` → `0.8.24`)
- [ ] Dependencies pinned to specific versions

### Access Control
- [ ] All sensitive functions have access modifiers
- [ ] Owner/admin functions use `Ownable2Step` (two-step transfer)
- [ ] No hardcoded addresses (use constructor params)
- [ ] Emergency pause mechanism implemented

### Reentrancy
- [ ] `ReentrancyGuard` on all external state-changing functions
- [ ] Checks-Effects-Interactions pattern followed
- [ ] No callbacks to untrusted contracts

### Input Validation
- [ ] Zero address checks on all address parameters
- [ ] Amount validation (> 0, <= balance)
- [ ] Array length limits to prevent DoS
- [ ] Deadline checks on time-sensitive operations

### External Calls
- [ ] Return values checked on all external calls
- [ ] `SafeERC20` used for token transfers
- [ ] Untrusted contracts clearly marked
- [ ] No `delegatecall` to untrusted addresses

### Testing
- [ ] >95% line coverage
- [ ] Fuzz tests for numeric operations
- [ ] Invariant tests for critical properties
- [ ] Fork tests against mainnet state

### Pre-Deployment
- [ ] Deploy to Fuji testnet first
- [ ] Manual testing of all functions
- [ ] Gas optimization review
- [ ] Professional audit for high-value contracts

---

## Best Practices Checklist

- [ ] Use Solidity 0.8.24+
- [ ] Import from OpenZeppelin when possible
- [ ] Add NatSpec documentation
- [ ] Emit events for state changes
- [ ] Use `immutable` for constructor-set values
- [ ] Use `constant` for compile-time values
- [ ] Check for zero addresses in constructors
- [ ] Use SafeERC20 for token transfers
- [ ] Add ReentrancyGuard to external functions
- [ ] Test with >90% coverage before deployment
- [ ] Verify contracts on Snowtrace
