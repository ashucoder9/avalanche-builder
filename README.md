# Avalanche Developer Skill for Claude Code

A comprehensive Claude Code skill for Avalanche blockchain development. This skill enables Claude to assist with building dApps, deploying smart contracts, creating L1 blockchains, setting up cross-chain messaging, and more.

## Features

- **C-Chain dApp Development**: Build React/Next.js frontends with viem, wagmi, and Core Wallet integration
- **Smart Contract Development**: Deploy Solidity contracts using Foundry or Hardhat
- **Avalanche L1 (Subnet) Creation**: Create and configure custom EVM-compatible blockchains
- **Interchain Messaging (ICM)**: Build cross-chain dApps using Teleporter
- **Token Bridges (ICTT)**: Deploy trustless token bridges between L1s
- **Node Operations**: Run AvalancheGo nodes and validators
- **Testing & Security**: Comprehensive testing patterns and security best practices

## Installation

### Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/YOUR_USERNAME/avalanche-builder/main/install.sh | bash
```

### Manual Install

1. Clone this repository:
```bash
git clone https://github.com/YOUR_USERNAME/avalanche-builder.git
```

2. Copy the skill directory to your Claude Code skills folder:
```bash
mkdir -p ~/.claude/skills
cp -r avalanche-builder/skill ~/.claude/skills/avalanche-dev
```

3. Add the skill to your Claude Code configuration:
```json
{
  "skills": {
    "avalanche-dev": {
      "path": "~/.claude/skills/avalanche-dev"
    }
  }
}
```

## Skill Structure

```
skill/
├── SKILL.md                    # Main skill definition & entry point
├── c-chain-development.md      # C-Chain dApp & smart contract development
├── l1-setup.md                 # Avalanche L1/Subnet creation & management
├── icm-interchain-messaging.md # Cross-chain messaging with Teleporter
├── ictt-token-bridge.md        # Token bridge deployment & usage
├── core-wallet.md              # Core Wallet SDK integration
├── node-operations.md          # AvalancheGo node setup & maintenance
├── testing-security.md         # Testing patterns & security checklists
└── resources.md                # Reference links & documentation
```

## Usage

Once installed, Claude Code will automatically use this skill when you ask about Avalanche development. Example prompts:

### dApp Development
- "Create a Next.js app with Core Wallet integration"
- "Write a Solidity contract for an ERC-20 token on Avalanche"
- "Set up wagmi providers for Avalanche C-Chain"

### L1/Subnet Creation
- "Create a new Avalanche L1 with custom gas settings"
- "Deploy my blockchain to Fuji testnet"
- "Add a validator to my L1"

### Cross-Chain Development
- "Set up cross-chain messaging between my L1 and C-Chain"
- "Deploy an ICTT token bridge"
- "Send a cross-chain message using Teleporter"

### Node Operations
- "How do I run an AvalancheGo validator node?"
- "Configure my node for an L1 subnet"
- "Set up monitoring for my Avalanche node"

## Prerequisites

For development, you'll need:

- **Node.js** 18+ and npm/yarn
- **Foundry** or **Hardhat** for smart contracts
- **Avalanche CLI** for L1/subnet management

Install Avalanche CLI:
```bash
curl -sSfL https://raw.githubusercontent.com/ava-labs/avalanche-cli/main/scripts/install.sh | sh -s
```

Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Resources

- [Avalanche Builder Hub](https://build.avax.network) - Official documentation
- [Avalanche Academy](https://academy.avax.network) - Interactive courses
- [Avalanche Discord](https://discord.gg/avax) - Community support

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT License - see [LICENSE](LICENSE) for details.

---

Built with the Avalanche ecosystem in mind.
