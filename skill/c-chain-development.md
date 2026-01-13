# C-Chain dApp Development

> Build production-ready dApps on Avalanche C-Chain with modern tooling

---

## Goals

1. Set up React/Next.js frontends with proper wallet integration
2. Deploy and interact with Solidity smart contracts
3. Handle transactions with proper UX patterns
4. Use viem/wagmi for type-safe blockchain interactions

---

## Recommended Dependencies

```json
{
  "dependencies": {
    "viem": "^2.x",
    "wagmi": "^2.x",
    "@tanstack/react-query": "^5.x",
    "@avalanche-sdk/client": "^0.x",
    "@avalanche-sdk/interchain": "^0.x",
    "next": "^14.x",
    "react": "^18.x"
  },
  "devDependencies": {
    "typescript": "^5.x",
    "@types/node": "^20.x",
    "@types/react": "^18.x"
  }
}
```

> **Note**: The Avalanche SDK is modular. Install only what you need:
> - `@avalanche-sdk/client` - Core RPC, wallets, transactions
> - `@avalanche-sdk/interchain` - Cross-chain messaging (ICM/ICTT)
> - `@avalanche-sdk/chainkit` - Data APIs, metrics, webhooks

---

## BuilderKit: Ready-Made Components

Before building from scratch, check [BuilderKit](https://github.com/ava-labs/builders-hub/tree/main/content/docs/builderkit) for production-ready React components.

### What BuilderKit Provides

| Component | Use Case |
|-----------|----------|
| **ICTT Bridge UI** | Token bridging interface between chains |
| **Wallet Connection** | Connect button with multi-wallet support |
| **Transaction Status** | Progress tracking and confirmations |
| **Chain Selector** | Network switching dropdowns |
| **Token Balance** | Display balances across chains |

### Using BuilderKit

```bash
# Clone the components
git clone https://github.com/ava-labs/builders-hub.git

# Copy what you need to your project
cp -r builders-hub/content/docs/builderkit/components ./src/components/builderkit
```

> **Recommendation**: Use BuilderKit components as your starting point, then customize styling and behavior to match your dApp's design.

---

## Frontend Setup

### Provider Configuration

Create `app/providers.tsx`:

```tsx
'use client'

import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { WagmiProvider, createConfig, http } from 'wagmi'
import { avalanche, avalancheFuji } from 'wagmi/chains'
import { injected, walletConnect } from 'wagmi/connectors'

const config = createConfig({
  chains: [avalanche, avalancheFuji],
  connectors: [
    injected(),
    walletConnect({
      projectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID!,
    }),
  ],
  transports: {
    [avalanche.id]: http(),
    [avalancheFuji.id]: http(),
  },
})

const queryClient = new QueryClient()

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </WagmiProvider>
  )
}
```

### Layout Integration

In `app/layout.tsx`:

```tsx
import { Providers } from './providers'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
```

---

## Wallet Connection

### Connect Button Component

```tsx
'use client'

import { useAccount, useConnect, useDisconnect } from 'wagmi'

export function ConnectWallet() {
  const { address, isConnected } = useAccount()
  const { connect, connectors, isPending } = useConnect()
  const { disconnect } = useDisconnect()

  if (isConnected) {
    return (
      <div>
        <p>Connected: {address}</p>
        <button onClick={() => disconnect()}>Disconnect</button>
      </div>
    )
  }

  return (
    <div>
      {connectors.map((connector) => (
        <button
          key={connector.uid}
          onClick={() => connect({ connector })}
          disabled={isPending}
        >
          {connector.name}
        </button>
      ))}
    </div>
  )
}
```

### Hook Usage Patterns

```tsx
// Get account info
const { address, isConnected, chain } = useAccount()

// Get balance
const { data: balance } = useBalance({ address })

// Check chain and switch if needed
const { switchChain } = useSwitchChain()
if (chain?.id !== avalanche.id) {
  switchChain({ chainId: avalanche.id })
}

// Read contract
const { data } = useReadContract({
  address: contractAddress,
  abi: contractAbi,
  functionName: 'balanceOf',
  args: [address],
})

// Write contract
const { writeContract, isPending, isSuccess } = useWriteContract()
```

---

## Smart Contract Development

### Foundry Setup

```bash
# Initialize project
forge init my-contract

# Project structure
my-contract/
├── src/
│   └── MyContract.sol
├── test/
│   └── MyContract.t.sol
├── script/
│   └── Deploy.s.sol
└── foundry.toml
```

### foundry.toml Configuration

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.24"
optimizer = true
optimizer_runs = 200

[rpc_endpoints]
avalanche = "https://api.avax.network/ext/bc/C/rpc"
fuji = "https://api.avax-test.network/ext/bc/C/rpc"

[etherscan]
avalanche = { key = "${SNOWTRACE_API_KEY}", url = "https://api.snowtrace.io/api" }
fuji = { key = "${SNOWTRACE_API_KEY}", url = "https://api-testnet.snowtrace.io/api" }
```

### Sample Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    constructor() ERC20("MyToken", "MTK") Ownable(msg.sender) {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
```

### Deployment Script

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

        MyToken token = new MyToken();
        console.log("Token deployed to:", address(token));

        vm.stopBroadcast();
    }
}
```

### Deploy Commands

> **IMPORTANT: Deployments are IRREVERSIBLE**
>
> **Always deploy to Fuji testnet first** and test thoroughly before mainnet.

```bash
# ============================================
# STEP 1: Deploy to Fuji testnet (DO THIS FIRST)
# ============================================
# Simulate first (catches errors before spending gas)
forge script script/Deploy.s.sol --rpc-url fuji

# Deploy for real
forge script script/Deploy.s.sol --rpc-url fuji --broadcast --verify

# Test the contract on Fuji before proceeding to mainnet!

# ============================================
# STEP 2: Deploy to mainnet (ONLY after Fuji testing)
# ============================================
# WARNING: Uses real AVAX, creates permanent contract

# Simulate first
forge script script/Deploy.s.sol --rpc-url avalanche

# Deploy (NO UNDO)
forge script script/Deploy.s.sol --rpc-url avalanche --broadcast --verify

# ============================================
# Verify existing contract
# ============================================
forge verify-contract <address> src/MyToken.sol:MyToken --chain avalanche
```

---

## Hardhat Alternative

### hardhat.config.ts

```typescript
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    fuji: {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      chainId: 43113,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    avalanche: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      chainId: 43114,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: {
      avalanche: process.env.SNOWTRACE_API_KEY || "",
      avalancheFuji: process.env.SNOWTRACE_API_KEY || "",
    },
  },
};

export default config;
```

---

## Transaction UX Patterns

### Transaction State Management

```tsx
'use client'

import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther } from 'viem'

export function SendTransaction() {
  const {
    data: hash,
    writeContract,
    isPending,
    error: writeError
  } = useWriteContract()

  const {
    isLoading: isConfirming,
    isSuccess: isConfirmed,
    error: confirmError
  } = useWaitForTransactionReceipt({ hash })

  const handleSend = () => {
    writeContract({
      address: '0x...',
      abi: contractAbi,
      functionName: 'transfer',
      args: ['0x...', parseEther('10')],
    })
  }

  return (
    <div>
      <button onClick={handleSend} disabled={isPending}>
        {isPending ? 'Confirming in wallet...' : 'Send'}
      </button>

      {hash && <p>Transaction: {hash}</p>}
      {isConfirming && <p>Waiting for confirmation...</p>}
      {isConfirmed && <p>Transaction confirmed!</p>}
      {(writeError || confirmError) && (
        <p>Error: {(writeError || confirmError)?.message}</p>
      )}
    </div>
  )
}
```

### Transaction UX Checklist

- [ ] Show wallet confirmation prompt state
- [ ] Display transaction hash immediately after submission
- [ ] Show pending/confirming state with spinner
- [ ] Handle user rejection gracefully
- [ ] Display success with explorer link
- [ ] Show clear error messages on failure
- [ ] Consider optimistic updates for better UX

---

## Contract Interaction Patterns

### Reading Multiple Values

```tsx
import { useReadContracts } from 'wagmi'

function TokenInfo({ address }: { address: `0x${string}` }) {
  const { data } = useReadContracts({
    contracts: [
      {
        address,
        abi: erc20Abi,
        functionName: 'name',
      },
      {
        address,
        abi: erc20Abi,
        functionName: 'symbol',
      },
      {
        address,
        abi: erc20Abi,
        functionName: 'totalSupply',
      },
    ],
  })

  const [name, symbol, totalSupply] = data || []

  return (
    <div>
      <p>Name: {name?.result}</p>
      <p>Symbol: {symbol?.result}</p>
      <p>Supply: {totalSupply?.result?.toString()}</p>
    </div>
  )
}
```

### Event Watching

```tsx
import { useWatchContractEvent } from 'wagmi'

function TransferWatcher({ address }: { address: `0x${string}` }) {
  useWatchContractEvent({
    address,
    abi: erc20Abi,
    eventName: 'Transfer',
    onLogs(logs) {
      console.log('New transfer!', logs)
    },
  })

  return <div>Watching for transfers...</div>
}
```

---

## Gas Estimation

```typescript
import { publicClient } from './client'

// Estimate gas for a transaction
const gasEstimate = await publicClient.estimateGas({
  account: '0x...',
  to: '0x...',
  value: parseEther('1'),
})

// Get current gas price
const gasPrice = await publicClient.getGasPrice()

// Estimate total cost
const totalCost = gasEstimate * gasPrice
```

---

## Best Practices

### Type Safety

```typescript
// Define contract types
import { Abi } from 'viem'

const myContractAbi = [
  {
    name: 'transfer',
    type: 'function',
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ type: 'bool' }],
  },
] as const satisfies Abi

// Use with wagmi hooks for full type inference
const { writeContract } = useWriteContract()
writeContract({
  abi: myContractAbi,
  address: '0x...',
  functionName: 'transfer', // autocomplete works!
  args: ['0x...', 100n], // type-checked
})
```

### Error Handling

```typescript
try {
  const hash = await walletClient.writeContract({
    address: '0x...',
    abi: contractAbi,
    functionName: 'transfer',
    args: ['0x...', parseEther('10')],
  })
} catch (error) {
  if (error.name === 'UserRejectedRequestError') {
    // User rejected in wallet
  } else if (error.name === 'ContractFunctionExecutionError') {
    // Contract reverted - check error.cause for details
  } else if (error.name === 'InsufficientFundsError') {
    // Not enough AVAX for gas
  }
}
```

### Chain Switching

```tsx
import { useSwitchChain, useChainId } from 'wagmi'
import { avalanche } from 'wagmi/chains'

function ChainSwitcher() {
  const chainId = useChainId()
  const { switchChain, isPending } = useSwitchChain()

  if (chainId !== avalanche.id) {
    return (
      <button
        onClick={() => switchChain({ chainId: avalanche.id })}
        disabled={isPending}
      >
        Switch to Avalanche
      </button>
    )
  }

  return <p>Connected to Avalanche</p>
}
```

---

## Data Fetching Patterns

### Using React Query with viem

```tsx
import { useQuery } from '@tanstack/react-query'
import { publicClient } from './client'

function useTokenBalance(address: `0x${string}`, tokenAddress: `0x${string}`) {
  return useQuery({
    queryKey: ['tokenBalance', address, tokenAddress],
    queryFn: () => publicClient.readContract({
      address: tokenAddress,
      abi: erc20Abi,
      functionName: 'balanceOf',
      args: [address],
    }),
    refetchInterval: 10000, // Refetch every 10s
  })
}
```

### Caching Contract Data

```typescript
// Create a client with caching
import { createPublicClient, http } from 'viem'
import { avalanche } from 'viem/chains'

const publicClient = createPublicClient({
  chain: avalanche,
  transport: http(),
  batch: {
    multicall: true, // Enable multicall batching
  },
})
```

---

## Useful Contract ABIs

### ERC-20 Minimal ABI

```typescript
export const erc20Abi = [
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'owner', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'transfer',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'to', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'approve',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'allowance',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
    ],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'Transfer',
    type: 'event',
    inputs: [
      { name: 'from', type: 'address', indexed: true },
      { name: 'to', type: 'address', indexed: true },
      { name: 'amount', type: 'uint256', indexed: false },
    ],
  },
] as const
```

---

## Avalanche SDK Usage

The `@avalanche-sdk/client` provides Avalanche-specific functionality beyond standard EVM operations.

### Installation

```bash
npm install @avalanche-sdk/client @avalanche-sdk/chainkit
```

### Creating an Avalanche Client

```typescript
import { createAvalancheClient } from '@avalanche-sdk/client'

// Create client for mainnet
const client = createAvalancheClient({
  network: 'mainnet', // or 'fuji'
})

// Or with custom RPC
const customClient = createAvalancheClient({
  rpcUrl: 'https://api.avax.network/ext/bc/C/rpc',
})
```

### Multi-Chain Operations

```typescript
// Get balances across all chains
const balances = await client.getBalances({
  address: '0x...',
})

console.log('C-Chain:', balances.cchain)
console.log('P-Chain:', balances.pchain)
console.log('X-Chain:', balances.xchain)

// P-Chain operations
const validators = await client.pchain.getCurrentValidators()
const stakingInfo = await client.pchain.getStake({ addresses: ['P-avax1...'] })

// X-Chain operations
const utxos = await client.xchain.getUTXOs({ addresses: ['X-avax1...'] })
```

### Using ChainKit for Data APIs

```typescript
import { createChainKitClient } from '@avalanche-sdk/chainkit'

const chainkit = createChainKitClient({
  apiKey: process.env.GLACIER_API_KEY, // Optional for higher rate limits
})

// Get ERC-20 balances for an address
const tokenBalances = await chainkit.evm.getERC20Balances({
  chainId: 43114,
  address: '0x...',
})

// Get NFTs owned by address
const nfts = await chainkit.evm.getNFTs({
  chainId: 43114,
  address: '0x...',
})

// Get transaction history
const txHistory = await chainkit.evm.getTransactions({
  chainId: 43114,
  address: '0x...',
  pageSize: 25,
})

// Get chain metrics
const metrics = await chainkit.metrics.getChainMetrics({
  chainId: 43114,
})
```

### Combining with viem

```typescript
import { createPublicClient, http } from 'viem'
import { avalanche } from 'viem/chains'
import { createAvalancheClient } from '@avalanche-sdk/client'

// Use viem for standard EVM operations
const viemClient = createPublicClient({
  chain: avalanche,
  transport: http(),
})

// Use Avalanche SDK for Avalanche-specific operations
const avaxClient = createAvalancheClient({ network: 'mainnet' })

// Read contract with viem
const balance = await viemClient.readContract({
  address: '0x...',
  abi: erc20Abi,
  functionName: 'balanceOf',
  args: ['0x...'],
})

// Get P-Chain staking info with Avalanche SDK
const staking = await avaxClient.pchain.getStake({
  addresses: ['P-avax1...'],
})
```
