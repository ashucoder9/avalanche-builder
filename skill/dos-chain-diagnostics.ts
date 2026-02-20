/**
 * DOS Chain Diagnostic Script
 * Run this from your local machine to test chain state
 *
 * Usage:
 *   npm install viem
 *   npx tsx dos-chain-diagnostics.ts
 */

import { createPublicClient, http, parseAbi } from 'viem'

const DOS_CHAIN_CONFIG = {
  id: 7979,
  name: 'DOS Chain',
  rpcUrl: 'https://main.doschain.com/',
  subnetId: 'nQCwF6V9y8VFjvMuPeQVWWYn6ba75518Dpf6ZMWZNb3NyTA94',
  blockchainId: '22v7AG7h6qaVxd4bLvAsSsg2LZ4RCn5iVYgFn7a2Fj1LCuYwjv',
}

const client = createPublicClient({
  transport: http(DOS_CHAIN_CONFIG.rpcUrl)
})

const WARP_PRECOMPILE_ADDRESS = '0x0200000000000000000000000000000000000005'
const VALIDATOR_MANAGER_ADDRESS = '0xfAcadE0000000000000000000000000000000000'

interface DiagnosticResult {
  test: string
  status: 'PASS' | 'FAIL' | 'WARNING'
  message: string
  data?: any
}

const results: DiagnosticResult[] = []

async function runDiagnostics() {
  console.log('🔍 DOS Chain Diagnostic Report')
  console.log('═══════════════════════════════════════\n')

  await testRPCConnectivity()
  await testChainState()
  await testBlockProduction()
  await testWarpPrecompile()
  await testValidatorManager()
  await testMempool()

  printResults()
  printRecommendations()
}

async function testRPCConnectivity() {
  try {
    const chainId = await client.getChainId()
    results.push({
      test: 'RPC Connectivity',
      status: chainId === DOS_CHAIN_CONFIG.id ? 'PASS' : 'FAIL',
      message: `Connected to chain ${chainId}`,
      data: { chainId }
    })
  } catch (error: any) {
    results.push({
      test: 'RPC Connectivity',
      status: 'FAIL',
      message: `Cannot connect: ${error.message}`
    })
  }
}

async function testChainState() {
  try {
    const blockNumber = await client.getBlockNumber()
    const block = await client.getBlock({ blockNumber })

    const lastBlockTime = new Date(Number(block.timestamp) * 1000)
    const now = new Date()
    const hoursSinceLastBlock = (now.getTime() - lastBlockTime.getTime()) / (1000 * 60 * 60)

    const status = hoursSinceLastBlock > 24 ? 'FAIL' : hoursSinceLastBlock > 1 ? 'WARNING' : 'PASS'

    results.push({
      test: 'Chain State',
      status,
      message: `Last block: ${blockNumber}, ${hoursSinceLastBlock.toFixed(1)}h ago`,
      data: {
        blockNumber: blockNumber.toString(),
        timestamp: lastBlockTime.toISOString(),
        hoursSinceLastBlock: hoursSinceLastBlock.toFixed(2)
      }
    })
  } catch (error: any) {
    results.push({
      test: 'Chain State',
      status: 'FAIL',
      message: `Cannot read chain state: ${error.message}`
    })
  }
}

async function testBlockProduction() {
  try {
    const startBlock = await client.getBlockNumber()
    console.log('⏳ Testing block production (waiting 15 seconds)...')
    await new Promise(resolve => setTimeout(resolve, 15000))
    const endBlock = await client.getBlockNumber()
    const blocksProduced = Number(endBlock - startBlock)

    results.push({
      test: 'Block Production (15s)',
      status: blocksProduced > 0 ? 'PASS' : 'FAIL',
      message: `Produced ${blocksProduced} blocks in 15 seconds`,
      data: { blocksProduced, startBlock: startBlock.toString(), endBlock: endBlock.toString() }
    })
  } catch (error: any) {
    results.push({
      test: 'Block Production',
      status: 'FAIL',
      message: `Cannot test: ${error.message}`
    })
  }
}

async function testWarpPrecompile() {
  try {
    const code = await client.getBytecode({ address: WARP_PRECOMPILE_ADDRESS })

    if (!code || code === '0x') {
      results.push({
        test: 'Warp Precompile',
        status: 'FAIL',
        message: 'Warp precompile not initialized (returns 0x)',
        data: { address: WARP_PRECOMPILE_ADDRESS }
      })
      return
    }

    const abi = parseAbi(['function getBlockchainID() view returns (bytes32)'])
    try {
      const blockchainId = await client.readContract({
        address: WARP_PRECOMPILE_ADDRESS,
        abi,
        functionName: 'getBlockchainID'
      })

      results.push({
        test: 'Warp Precompile',
        status: 'PASS',
        message: 'Warp precompile operational',
        data: { blockchainId }
      })
    } catch (callError: any) {
      results.push({
        test: 'Warp Precompile',
        status: 'FAIL',
        message: `Warp call failed: ${callError.shortMessage || callError.message}`,
        data: { address: WARP_PRECOMPILE_ADDRESS }
      })
    }
  } catch (error: any) {
    results.push({
      test: 'Warp Precompile',
      status: 'FAIL',
      message: `Cannot access Warp: ${error.message}`
    })
  }
}

async function testValidatorManager() {
  try {
    const code = await client.getBytecode({ address: VALIDATOR_MANAGER_ADDRESS })

    if (!code || code === '0x') {
      results.push({
        test: 'ValidatorManager',
        status: 'FAIL',
        message: 'ValidatorManager not initialized (returns 0x)',
        data: { address: VALIDATOR_MANAGER_ADDRESS }
      })
      return
    }

    results.push({
      test: 'ValidatorManager',
      status: 'WARNING',
      message: 'Has bytecode but may need initialization',
      data: { address: VALIDATOR_MANAGER_ADDRESS }
    })
  } catch (error: any) {
    results.push({
      test: 'ValidatorManager',
      status: 'FAIL',
      message: `Cannot access: ${error.message}`
    })
  }
}

async function testMempool() {
  try {
    const pendingBlock = await client.getBlock({ blockTag: 'pending' })
    const txCount = pendingBlock.transactions.length

    results.push({
      test: 'Mempool',
      status: txCount > 0 ? 'WARNING' : 'PASS',
      message: `${txCount} transactions stuck in mempool`,
      data: { pendingTransactions: txCount }
    })
  } catch (error: any) {
    results.push({
      test: 'Mempool',
      status: 'FAIL',
      message: `Cannot read mempool: ${error.message}`
    })
  }
}

function printResults() {
  console.log('\n📊 Test Results')
  console.log('═══════════════════════════════════════\n')

  for (const result of results) {
    const icon = result.status === 'PASS' ? '✅' : result.status === 'WARNING' ? '⚠️' : '❌'
    console.log(`${icon} ${result.test}: ${result.status}`)
    console.log(`   ${result.message}`)
    if (result.data) {
      console.log(`   Data:`, JSON.stringify(result.data, null, 2))
    }
    console.log()
  }
}

function printRecommendations() {
  console.log('\n💡 Recommendations')
  console.log('═══════════════════════════════════════\n')

  const failedTests = results.filter(r => r.status === 'FAIL')

  if (failedTests.some(t => t.test === 'Block Production (15s)')) {
    console.log('🔴 CRITICAL: Chain not producing blocks')
    console.log('   → Fix ProposerVM configuration (maxBuildDelay)')
    console.log('   → Enable Warp precompile in upgrade.json')
    console.log('   → Restart all validators\n')
  }

  if (failedTests.some(t => t.test === 'Warp Precompile')) {
    console.log('🔴 CRITICAL: Warp precompile not working')
    console.log('   → Add Warp config to upgrade.json')
    console.log('   → Restart validators\n')
  }

  if (failedTests.some(t => t.test === 'ValidatorManager')) {
    console.log('⚠️  ValidatorManager needs initialization')
    console.log('   → First fix block production')
    console.log('   → Then call initializeValidatorSet()\n')
  }

  console.log('\n📋 Next Steps:')
  console.log('   1. Run validator-check.sh on all 3 validator nodes')
  console.log('   2. Apply configuration fixes')
  console.log('   3. Perform coordinated restart')
  console.log('   4. Re-run this diagnostic\n')
}

runDiagnostics().catch(console.error)
