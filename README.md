# Playground-Contracts: Experimental EVVM Implementations

![EVVM Logo](https://github.com/user-attachments/assets/08d995ee-7512-42e4-a26c-0d62d2e8e0bf)

**Playground-Contracts** is the experimental staging area for the Ethereum Virtual Virtual Machine (EVVM) and its services. This repository is used to rapidly prototype, test, and validate new contract implementations and features. Only after successful validation here do features move to testnet, and then to mainnet.

The EVVM aims to provide infraless EVM virtualization, addressing scalability and chain fragmentation challenges.

---

## Repository Workflow

1. **Prototype & Experiment:** New ideas and features are implemented and tested in Playground-Contracts.
2. **Validation:** If a feature passes all local and CI tests, it is considered for promotion.
3. **Promotion:** Validated features are migrated to testnet deployments.
4. **Production:** After testnet validation, features are merged into mainnet contracts.

---

## Prerequisites

- [Foundry](https://getfoundry.sh/) (for Solidity development and testing)
- Node.js (for package management)

## Quick Start

```bash
git clone https://github.com/EVVM-org/EVVM-Contracts
cd EVVM-Contracts
make install
```

## Installation

Install dependencies and compile contracts:
```bash
make install
```

## Local Development

Start a local Anvil chain:
```bash
make anvil
# In another terminal:
make mock  # Deploy all mock contracts
```

## Compilation

Recompile contracts:
```bash
make compile
```

## Testing

Example test scripts are in the `test` directory. For more, see the [Makefile](https://github.com/EVVM-org/EVVM-Contracts/blob/main/makefile).

### EVVM Contracts
```bash
make unitTestCorrectEvvm
make unitTestRevertEvvm
make unitTestCorrectEvvmPayMultiple
make unitTestRevertEvvmPayMultiple_syncExecution
```

### SMate Contracts
```bash
make unitTestCorrectSMate
make unitTestRevertSMate
```

### MateNameService
```bash
make unitTestCorrectMateNameService
make unitTestRevertMateNameService
```

### Fuzz Testing
```bash
make fuzzTestEvvmPayMultiple
make fuzzTestMnsOffers
make fuzzTestSMateGoldenStaking
```

## Static Analysis
```bash
make staticAnalysis  # Generates reportWake.txt
```

## Project Structure

- `src/` — Main contract sources (core, staking, MateNameService, mocks)
- `test/` — Unit and fuzz tests for all modules
- `lib/` — External libraries (OpenZeppelin, Uniswap, EVVM-solidity-library, etc.)
- `script/` — Deployment and utility scripts

## Main Dependencies
- Solidity (via Foundry)
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [Uniswap v3](https://github.com/Uniswap/v3-core)
- [Chainlink CCIP](https://github.com/smartcontractkit/ccip)
- [Axelar GMP](https://github.com/axelarnetwork/axelar-gmp-sdk-solidity)
- [LayerZero](https://github.com/LayerZero-Labs/LayerZero)
- [Hyperlane](https://github.com/hyperlane-xyz/hyperlane-monorepo)

## Contributing

1. Fork the repository
2. Create a feature branch and make changes inside the mock contracts
3. Add tests for new features
4. Submit a PR with a detailed description

> **Security Note**: Never commit real private keys. Use test credentials only.
