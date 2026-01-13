# Core Wallet Integration

> Integrate the official Avalanche wallet into your dApps

---

## Goals

1. Set up Core Wallet connection in React/Next.js apps
2. Handle multi-chain transactions (C-Chain, X-Chain, P-Chain)
3. Implement staking and cross-chain operations
4. Support both browser extension and mobile

---

## Overview

Core is Ava Labs' official wallet for the Avalanche ecosystem:

- **Browser Extension**: Chrome, Firefox, Brave
- **Mobile Apps**: iOS and Android
- **Features**:
  - C-Chain (EVM transactions)
  - X-Chain (asset transfers)
  - P-Chain (staking, subnet operations)
  - Cross-chain transfers
  - NFT support
  - DeFi integrations

---

## Integration Methods

| Method | Best For | Complexity |
|--------|----------|------------|
| **RainbowKit** | Production apps, best UX, multi-wallet | Low |
| **wagmi Direct** | Custom UI, specific wallet targeting | Medium |
| **Manual Provider** | Maximum control, non-React apps | High |

---

## Option 1: RainbowKit (Recommended)

RainbowKit provides a polished wallet connection UI with built-in Core Wallet support.

### Installation

```bash
npm install @rainbow-me/rainbowkit wagmi viem @tanstack/react-query
```

### Quick Setup

```tsx
// app/providers.tsx
'use client'

import '@rainbow-me/rainbowkit/styles.css'
import { getDefaultConfig, RainbowKitProvider } from '@rainbow-me/rainbowkit'
import { WagmiProvider } from 'wagmi'
import { avalanche, avalancheFuji } from 'wagmi/chains'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

// Get projectId from https://cloud.walletconnect.com (free)
const config = getDefaultConfig({
  appName: 'My Avalanche dApp',
  projectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID!,
  chains: [avalanche, avalancheFuji],
  ssr: true, // Enable for Next.js
})

const queryClient = new QueryClient()

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>
          {children}
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  )
}
```

### Connect Button Component

```tsx
// components/ConnectButton.tsx
'use client'

import { ConnectButton } from '@rainbow-me/rainbowkit'

export function WalletConnect() {
  return (
    <ConnectButton
      accountStatus="avatar"
      chainStatus="icon"
      showBalance={true}
    />
  )
}
```

### Custom Connect Button

```tsx
import { ConnectButton } from '@rainbow-me/rainbowkit'

export function CustomConnectButton() {
  return (
    <ConnectButton.Custom>
      {({
        account,
        chain,
        openAccountModal,
        openChainModal,
        openConnectModal,
        mounted,
      }) => {
        const connected = mounted && account && chain

        return (
          <div>
            {!connected ? (
              <button onClick={openConnectModal} className="connect-btn">
                Connect Wallet
              </button>
            ) : chain.unsupported ? (
              <button onClick={openChainModal} className="wrong-network-btn">
                Wrong Network
              </button>
            ) : (
              <div className="connected-info">
                <button onClick={openChainModal}>
                  {chain.name}
                </button>
                <button onClick={openAccountModal}>
                  {account.displayName}
                  {account.displayBalance && ` (${account.displayBalance})`}
                </button>
              </div>
            )}
          </div>
        )
      }}
    </ConnectButton.Custom>
  )
}
```

### Adding Custom L1 Chains to RainbowKit

```tsx
import { defineChain } from 'viem'

// Define your custom L1
const myL1 = defineChain({
  id: 12345,
  name: 'My Avalanche L1',
  nativeCurrency: {
    name: 'My Token',
    symbol: 'MYT',
    decimals: 18,
  },
  rpcUrls: {
    default: { http: ['https://my-l1-rpc.example.com'] },
  },
  blockExplorers: {
    default: { name: 'Explorer', url: 'https://my-explorer.example.com' },
  },
})

// Include in config
const config = getDefaultConfig({
  appName: 'My Avalanche dApp',
  projectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID!,
  chains: [avalanche, avalancheFuji, myL1],
  ssr: true,
})
```

### RainbowKit Theming

```tsx
import { darkTheme, lightTheme, RainbowKitProvider } from '@rainbow-me/rainbowkit'

// Avalanche-themed colors
const avalancheTheme = darkTheme({
  accentColor: '#E84142', // Avalanche red
  accentColorForeground: 'white',
  borderRadius: 'medium',
})

<RainbowKitProvider theme={avalancheTheme}>
  {children}
</RainbowKitProvider>
```

---

## Option 2: Direct wagmi Integration

For custom UIs or when you need more control.

### Installation

```bash
npm install wagmi viem @tanstack/react-query
```

### Provider Setup

```tsx
// app/providers.tsx
'use client'

import { WagmiProvider, createConfig, http } from 'wagmi'
import { avalanche, avalancheFuji } from 'wagmi/chains'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { injected } from 'wagmi/connectors'

// Core Wallet is detected as an injected provider
const config = createConfig({
  chains: [avalanche, avalancheFuji],
  connectors: [
    injected({
      target: 'core', // Specifically target Core Wallet
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

### Connect Button

```tsx
'use client'

import { useAccount, useConnect, useDisconnect, useBalance } from 'wagmi'
import { formatEther } from 'viem'

export function CoreWalletConnect() {
  const { address, isConnected, chain } = useAccount()
  const { connect, connectors, isPending, error } = useConnect()
  const { disconnect } = useDisconnect()
  const { data: balance } = useBalance({ address })

  // Find Core Wallet connector
  const coreConnector = connectors.find(c => c.name === 'Core')

  if (isConnected) {
    return (
      <div className="wallet-info">
        <p>Connected to {chain?.name}</p>
        <p>Address: {address}</p>
        <p>Balance: {balance ? formatEther(balance.value) : '0'} AVAX</p>
        <button onClick={() => disconnect()}>
          Disconnect
        </button>
      </div>
    )
  }

  return (
    <div>
      {coreConnector ? (
        <button
          onClick={() => connect({ connector: coreConnector })}
          disabled={isPending}
        >
          {isPending ? 'Connecting...' : 'Connect Core Wallet'}
        </button>
      ) : (
        <a
          href="https://core.app/"
          target="_blank"
          rel="noopener noreferrer"
        >
          Install Core Wallet
        </a>
      )}
      {error && <p className="error">{error.message}</p>}
    </div>
  )
}
```

---

## Detecting Core Wallet

### Check if Installed

```typescript
function isCoreWalletInstalled(): boolean {
  if (typeof window === 'undefined') return false

  // Core injects itself as window.avalanche
  return !!(window as any).avalanche?.isAvalanche
}
```

### Provider Detection

```typescript
function getCoreProvider() {
  if (typeof window === 'undefined') return null

  // Core Wallet provider
  const avalanche = (window as any).avalanche
  if (avalanche?.isAvalanche) {
    return avalanche
  }

  // Core also appears as standard EIP-1193 provider
  const ethereum = (window as any).ethereum
  if (ethereum?.isCore) {
    return ethereum
  }

  return null
}
```

---

## Multi-Connector Support

### Support Multiple Wallets

```tsx
'use client'

import { useConnect, useAccount, useDisconnect } from 'wagmi'

export function WalletSelector() {
  const { connectors, connect, isPending } = useConnect()
  const { isConnected, connector: activeConnector } = useAccount()
  const { disconnect } = useDisconnect()

  if (isConnected) {
    return (
      <div>
        <p>Connected with {activeConnector?.name}</p>
        <button onClick={() => disconnect()}>Disconnect</button>
      </div>
    )
  }

  return (
    <div className="wallet-options">
      {connectors.map((connector) => (
        <button
          key={connector.uid}
          onClick={() => connect({ connector })}
          disabled={isPending}
        >
          <img
            src={getWalletIcon(connector.name)}
            alt={connector.name}
            width={24}
            height={24}
          />
          {connector.name}
        </button>
      ))}
    </div>
  )
}

function getWalletIcon(name: string): string {
  const icons: Record<string, string> = {
    'Core': '/icons/core-wallet.svg',
    'MetaMask': '/icons/metamask.svg',
    'WalletConnect': '/icons/walletconnect.svg',
  }
  return icons[name] || '/icons/wallet-default.svg'
}
```

---

## Adding Custom L1 Networks

### Programmatic Network Addition

```typescript
import { useAccount } from 'wagmi'

async function addCustomNetwork(chainConfig: {
  chainId: number
  chainName: string
  rpcUrls: string[]
  nativeCurrency: {
    name: string
    symbol: string
    decimals: number
  }
  blockExplorerUrls?: string[]
}) {
  const provider = getCoreProvider()
  if (!provider) throw new Error('Core Wallet not found')

  try {
    await provider.request({
      method: 'wallet_addEthereumChain',
      params: [{
        chainId: `0x${chainConfig.chainId.toString(16)}`,
        chainName: chainConfig.chainName,
        rpcUrls: chainConfig.rpcUrls,
        nativeCurrency: chainConfig.nativeCurrency,
        blockExplorerUrls: chainConfig.blockExplorerUrls,
      }],
    })
  } catch (error: any) {
    if (error.code === 4001) {
      throw new Error('User rejected network addition')
    }
    throw error
  }
}

// Usage
await addCustomNetwork({
  chainId: 12345,
  chainName: 'My Avalanche L1',
  rpcUrls: ['https://my-l1-rpc.example.com'],
  nativeCurrency: {
    name: 'My Token',
    symbol: 'MYT',
    decimals: 18,
  },
  blockExplorerUrls: ['https://my-explorer.example.com'],
})
```

### Switch Network with wagmi

```tsx
import { useSwitchChain, useChainId } from 'wagmi'

function NetworkSwitcher() {
  const chainId = useChainId()
  const { chains, switchChain, isPending } = useSwitchChain()

  return (
    <div className="network-switcher">
      <select
        value={chainId}
        onChange={(e) => switchChain({ chainId: Number(e.target.value) })}
        disabled={isPending}
      >
        {chains.map((chain) => (
          <option key={chain.id} value={chain.id}>
            {chain.name}
          </option>
        ))}
      </select>
    </div>
  )
}
```

---

## Signing Messages

### Personal Sign

```tsx
import { useSignMessage } from 'wagmi'

function SignMessageButton() {
  const { signMessage, isPending, data: signature } = useSignMessage()

  const handleSign = () => {
    signMessage({
      message: 'Welcome to My dApp! Please sign to verify your wallet.',
    })
  }

  return (
    <div>
      <button onClick={handleSign} disabled={isPending}>
        {isPending ? 'Signing...' : 'Sign Message'}
      </button>
      {signature && <p>Signature: {signature}</p>}
    </div>
  )
}
```

### Typed Data Signing (EIP-712)

```tsx
import { useSignTypedData } from 'wagmi'

function SignTypedDataButton() {
  const { signTypedData, isPending } = useSignTypedData()

  const handleSign = () => {
    signTypedData({
      domain: {
        name: 'My dApp',
        version: '1',
        chainId: 43114,
        verifyingContract: '0x...',
      },
      types: {
        Permit: [
          { name: 'owner', type: 'address' },
          { name: 'spender', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'nonce', type: 'uint256' },
          { name: 'deadline', type: 'uint256' },
        ],
      },
      primaryType: 'Permit',
      message: {
        owner: '0x...',
        spender: '0x...',
        value: 1000000n,
        nonce: 0n,
        deadline: BigInt(Math.floor(Date.now() / 1000) + 3600),
      },
    })
  }

  return (
    <button onClick={handleSign} disabled={isPending}>
      Sign Permit
    </button>
  )
}
```

---

## Transaction Handling

### Send Transaction with Status

```tsx
'use client'

import { useSendTransaction, useWaitForTransactionReceipt } from 'wagmi'
import { parseEther } from 'viem'

function SendAvax() {
  const {
    data: hash,
    sendTransaction,
    isPending: isSending,
    error: sendError,
  } = useSendTransaction()

  const {
    isLoading: isConfirming,
    isSuccess: isConfirmed,
  } = useWaitForTransactionReceipt({ hash })

  const handleSend = () => {
    sendTransaction({
      to: '0x...',
      value: parseEther('0.1'),
    })
  }

  return (
    <div>
      <button onClick={handleSend} disabled={isSending}>
        {isSending ? 'Confirm in wallet...' : 'Send 0.1 AVAX'}
      </button>

      {hash && (
        <div>
          <p>Transaction: {hash}</p>
          {isConfirming && <p>Waiting for confirmation...</p>}
          {isConfirmed && <p>Transaction confirmed!</p>}
        </div>
      )}

      {sendError && <p className="error">{sendError.message}</p>}
    </div>
  )
}
```

### Contract Interaction

```tsx
import { useWriteContract, useWaitForTransactionReceipt } from 'wagmi'

function MintNFT({ contractAddress, abi }: Props) {
  const { writeContract, data: hash, isPending, error } = useWriteContract()
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash })

  const handleMint = () => {
    writeContract({
      address: contractAddress,
      abi,
      functionName: 'mint',
      args: [1], // mint 1 NFT
      value: parseEther('0.05'), // mint price
    })
  }

  return (
    <div>
      <button onClick={handleMint} disabled={isPending || isConfirming}>
        {isPending && 'Confirm in wallet...'}
        {isConfirming && 'Minting...'}
        {!isPending && !isConfirming && 'Mint NFT'}
      </button>
      {isSuccess && <p>Successfully minted!</p>}
      {error && <p className="error">{error.message}</p>}
    </div>
  )
}
```

---

## X-Chain and P-Chain Operations

Core Wallet supports X-Chain and P-Chain through its provider:

### Cross-Chain Transfer (C to X)

```typescript
// Note: These operations require the Core-specific provider API
// Standard EIP-1193 doesn't support X/P-Chain

async function transferCtoX(amount: string) {
  const coreProvider = getCoreProvider()
  if (!coreProvider) throw new Error('Core Wallet required')

  // Use Core's cross-chain API
  const result = await coreProvider.request({
    method: 'avalanche_sendTransaction',
    params: [{
      type: 'export',
      from: 'C',
      to: 'X',
      amount: amount,
    }],
  })

  return result
}
```

### P-Chain Staking

```typescript
async function delegateStake(
  nodeId: string,
  amount: string,
  startTime: number,
  endTime: number
) {
  const coreProvider = getCoreProvider()
  if (!coreProvider) throw new Error('Core Wallet required')

  const result = await coreProvider.request({
    method: 'avalanche_sendTransaction',
    params: [{
      type: 'addDelegator',
      nodeID: nodeId,
      amount: amount,
      startTime: startTime,
      endTime: endTime,
    }],
  })

  return result
}
```

---

## WalletConnect Support

### Add WalletConnect for Mobile

```tsx
import { walletConnect } from 'wagmi/connectors'

const config = createConfig({
  chains: [avalanche, avalancheFuji],
  connectors: [
    injected({ target: 'core' }),
    walletConnect({
      projectId: process.env.NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID!,
      metadata: {
        name: 'My Avalanche dApp',
        description: 'A dApp built on Avalanche',
        url: 'https://mydapp.com',
        icons: ['https://mydapp.com/icon.png'],
      },
    }),
  ],
  transports: {
    [avalanche.id]: http(),
    [avalancheFuji.id]: http(),
  },
})
```

---

## Error Handling

### Common Errors

```typescript
function handleWalletError(error: any) {
  switch (error.code) {
    case 4001:
      return 'Transaction rejected by user'
    case 4100:
      return 'Unauthorized - please connect wallet'
    case 4200:
      return 'Unsupported method'
    case 4900:
      return 'Disconnected from chain'
    case 4901:
      return 'Chain not connected'
    case -32002:
      return 'Request already pending - check wallet'
    case -32603:
      return 'Internal error - try again'
    default:
      return error.message || 'Unknown error'
  }
}
```

### React Error Boundary

```tsx
'use client'

import { Component, ReactNode } from 'react'

interface Props {
  children: ReactNode
  fallback: ReactNode
}

interface State {
  hasError: boolean
}

export class WalletErrorBoundary extends Component<Props, State> {
  state = { hasError: false }

  static getDerivedStateFromError() {
    return { hasError: true }
  }

  componentDidCatch(error: Error) {
    console.error('Wallet error:', error)
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback
    }
    return this.props.children
  }
}
```

---

## Best Practices

### UX Guidelines

1. **Always show connection status** - Users should know if connected
2. **Display current network** - Prevent wrong-network transactions
3. **Show loading states** - Wallet confirmations take time
4. **Provide clear error messages** - Don't show raw error codes
5. **Add "Install Core" link** - Help users who don't have it

### Security

1. **Never store private keys** - Let the wallet handle them
2. **Validate addresses** - Check before sending transactions
3. **Use EIP-712 for permits** - Better UX for approvals
4. **Show transaction details** - Users should know what they're signing

### Performance

1. **Cache balance queries** - Don't spam the RPC
2. **Use React Query** - Built-in caching and refetching
3. **Batch contract reads** - Use multicall when possible
