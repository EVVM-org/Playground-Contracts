# EVVM contracts

![](https://github.com/user-attachments/assets/08d995ee-7512-42e4-a26c-0d62d2e8e0bf)


The Ethereum Virtual Virtual Machine ⚙️ Infraless EVM Virtualization solving Scalability and Chain Fragmentation 🔧


## Prerequisites

- [Foundry](https://getfoundry.sh/)
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

Start local Anvil chain:
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

There is some example testing scripts in the `test` directory. If you want to check more tests, please check the [Makefile](https://github.com/EVVM-org/EVVM-Contracts/blob/main/makefile) file.

### EVVM Contracts
```bash
# All tests
make unitTestCorrectEvvm
make unitTestRevertEvvm

# Individual tests
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
# EVVM
make fuzzTestEvvmPayMultiple

# MNS
make fuzzTestMnsOffers

# SMate
make fuzzTestSMateGoldenStaking
```

## Static Analysis
```bash
make staticAnalysis  # Generates reportWake.txt
```

## Contributing

1. Fork repository
2. Create feature branch and make changes inside the mock contracts
3. Add tests for new features
4. Submit PR with detailed description

> **Security Note**: Never commit real private keys. Use test credentials only.

---

*This is a temporary README - Final documentation pending project completion*
