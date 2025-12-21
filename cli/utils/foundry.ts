/**
 * Foundry Integration Utilities
 *
 * Provides functions for interacting with Foundry toolchain including:
 * - Contract deployment and verification
 * - Wallet management and validation
 * - Registry contract interactions
 * - Solidity file generation
 *
 * @module cli/utils/foundry
 */

import { $ } from "bun";
import type {
  BaseInputAddresses,
  EvvmMetadata,
  CreatedContract,
  ContractFileMetadata,
  CrossChainInputs,
} from "../types";
import {
  colors,
  EthSepoliaPublicRpc,
  RegisteryEvvmAddress,
  ChainData,
} from "../constants";
import { formatNumber, showError } from "./validators";

/**
 * Generates and writes the BaseInputs.sol file with deployment configuration
 *
 * Creates a Solidity contract containing all deployment parameters including
 * admin addresses and EVVM metadata. This file is used by the deployment script.
 *
 * @param {BaseInputAddresses} addresses - Admin, golden fisher, and activator addresses
 * @param {EvvmMetadata} evvmMetadata - EVVM configuration including token economics
 * @returns {Promise<boolean>} True if file was written successfully
 */
export async function writeBaseInputsFile(
  addresses: BaseInputAddresses,
  evvmMetadata: EvvmMetadata
): Promise<boolean> {
  const inputDir = "./input";
  const inputFile = `${inputDir}/BaseInputs.sol`;

  try {
    await Bun.file(inputFile).text();
  } catch {
    await $`mkdir -p ${inputDir}`.quiet();
    await Bun.write(inputFile, "");
    console.log(`${colors.blue}Created ${inputFile}${colors.reset}`);
  }

  const inputFileContent = `// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import {EvvmStructs} from "@evvm/playground-contracts/contracts/evvm/lib/EvvmStructs.sol";

abstract contract BaseInputs {
    address admin = ${addresses.admin};
    address goldenFisher = ${addresses.goldenFisher};
    address activator = ${addresses.activator};

    EvvmStructs.EvvmMetadata inputMetadata =
        EvvmStructs.EvvmMetadata({
            EvvmName: "${evvmMetadata.EvvmName}",
            // evvmID will be set to 0, and it will be assigned when you register the evvm
            EvvmID: 0,
            principalTokenName: "${evvmMetadata.principalTokenName}",
            principalTokenSymbol: "${evvmMetadata.principalTokenSymbol}",
            principalTokenAddress: ${evvmMetadata.principalTokenAddress},
            totalSupply: ${formatNumber(evvmMetadata.totalSupply)},
            eraTokens: ${formatNumber(evvmMetadata.eraTokens)},
            reward: ${formatNumber(evvmMetadata.reward)}
        });
}
`;

  await Bun.write(inputFile, inputFileContent);
  return true;
}

/**
 * Generates and writes the CrossChainInputs.sol file with cross-chain configuration
 *
 * Creates a Solidity contract containing all cross-chain messaging parameters for
 * both host and external chain stations. Used by cross-chain deployment scripts.
 *
 * @param {CrossChainInputs} crossChainInputs - Cross-chain configuration for Hyperlane, LayerZero, and Axelar
 * @returns {Promise<boolean>} True if file was written successfully
 */
export async function writeCrossChainInputsFile(
  crossChainInputs: CrossChainInputs
): Promise<boolean> {
  const inputDir = "./input";
  const inputFile = `${inputDir}/CrossChainInputs.sol`;

  try {
    await Bun.file(inputFile).text();
  } catch {
    await $`mkdir -p ${inputDir}`.quiet();
    await Bun.write(inputFile, "");
    console.log(`${colors.blue}Created ${inputFile}${colors.reset}`);
  }

  const inputFileContent = `// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import {EvvmStructs} from "@evvm/playground-contracts/contracts/evvm/lib/EvvmStructs.sol";
import {HostChainStationStructs} from "@evvm/playground-contracts/contracts/treasuryTwoChains/lib/HostChainStationStructs.sol";
import {ExternalChainStationStructs} from "@evvm/playground-contracts/contracts/treasuryTwoChains/lib/ExternalChainStationStructs.sol";

abstract contract CrossChainInputs {
    address constant adminExternal = ${crossChainInputs.adminExternal};

    HostChainStationStructs.CrosschainConfig crosschainConfigHost =
        HostChainStationStructs.CrosschainConfig({
            hyperlane: HostChainStationStructs.HyperlaneConfig({
                externalChainStationDomainId: ${crossChainInputs.crosschainConfigHost.hyperlane.externalChainStationDomainId}, //Domain ID for External on Hyperlane
                externalChainStationAddress: bytes32(0), //External Chain Station Address on Hyperlane
                mailboxAddress: ${crossChainInputs.crosschainConfigHost.hyperlane.mailboxAddress} //Mailbox for Host on Hyperlane
            }),
            layerZero: HostChainStationStructs.LayerZeroConfig({
                externalChainStationEid: ${crossChainInputs.crosschainConfigHost.layerZero.externalChainStationEid}, //EID for External on LayerZero
                externalChainStationAddress: bytes32(0), //External Chain Station Address on LayerZero
                endpointAddress: ${crossChainInputs.crosschainConfigHost.layerZero.endpointAddress} //Endpoint for Host on LayerZero
            }),
            axelar: HostChainStationStructs.AxelarConfig({
                externalChainStationChainName: "${crossChainInputs.crosschainConfigHost.axelar.externalChainStationChainName}", //Chain Name for External on Axelar
                externalChainStationAddress: "", //External Chain Station Address on Axelar
                gasServiceAddress: ${crossChainInputs.crosschainConfigHost.axelar.gasServiceAddress}, //Gas Service for External on Axelar
                gatewayAddress: ${crossChainInputs.crosschainConfigHost.axelar.gatewayAddress} //Gateway for Host on Axelar
            })
        });

    ExternalChainStationStructs.CrosschainConfig crosschainConfigExternal =
        ExternalChainStationStructs.CrosschainConfig({
            hyperlane: ExternalChainStationStructs.HyperlaneConfig({
                hostChainStationDomainId: ${crossChainInputs.crosschainConfigExternal.hyperlane.hostChainStationDomainId}, //Domain ID for Host on Hyperlane
                hostChainStationAddress: bytes32(0), //Host Chain Station Address on Hyperlane
                mailboxAddress: ${crossChainInputs.crosschainConfigExternal.hyperlane.mailboxAddress} //Mailbox for External on Hyperlane
            }),
            layerZero: ExternalChainStationStructs.LayerZeroConfig({
                hostChainStationEid: ${crossChainInputs.crosschainConfigExternal.layerZero.hostChainStationEid}, //EID for Host on LayerZero
                hostChainStationAddress: bytes32(0), //Host Chain Station Address on LayerZero
                endpointAddress: ${crossChainInputs.crosschainConfigExternal.layerZero.endpointAddress} //Endpoint for External on LayerZero
            }),
            axelar: ExternalChainStationStructs.AxelarConfig({
                hostChainStationChainName: "${crossChainInputs.crosschainConfigExternal.axelar.hostChainStationChainName}", //Chain Name for Host on Axelar
                hostChainStationAddress: "", //Host Chain Station Address on Axelar
                gasServiceAddress: ${crossChainInputs.crosschainConfigExternal.axelar.gasServiceAddress}, //Gas Service for External on Axelar
                gatewayAddress: ${crossChainInputs.crosschainConfigExternal.axelar.gatewayAddress} //Gateway for External on Axelar
            })
        });
}
`;

  await Bun.write(inputFile, inputFileContent);
  return true;
}

/**
 * Checks if a chain ID is registered in the EVVM Registry
 *
 * Queries the EVVM Registry contract on Ethereum Sepolia to verify if the
 * target chain ID is supported for EVVM deployments.
 *
 * @param {number} chainId - The chain ID to check
 * @returns {Promise<boolean | undefined>} True if registered, false if not, undefined on error
 */
export async function isChainIdRegistered(
  chainId: number
): Promise<boolean | undefined> {
  const ethRpcUrl =
    process.env.EVVM_REGISTRATION_RPC_URL?.trim() || EthSepoliaPublicRpc;
  try {
    const result =
      await $`cast call ${RegisteryEvvmAddress} --rpc-url ${ethRpcUrl} "isChainIdRegistered(uint256)(bool)" ${chainId}`.quiet();
    const isSupported = result.stdout.toString().trim() === "true";
    return isSupported;
  } catch (error) {
    console.error(
      `${colors.red}Error checking chain ID support:${colors.reset}`,
      error
    );
    return undefined;
  }
}

/**
 * Registers an EVVM instance in the EVVM Registry contract
 *
 * Calls the registry contract to register the EVVM instance and receive a unique
 * EVVM ID. This ID is used to identify the EVVM instance across the ecosystem.
 *
 * @param {number} hostChainId - Chain ID where the EVVM is deployed
 * @param {`0x${string}`} evvmAddress - Address of the deployed EVVM contract
 * @param {string} walletName - Foundry wallet name to use for the transaction
 * @param {string} ethRpcUrl - Ethereum Sepolia RPC URL for registry interaction
 * @returns {Promise<number | undefined>} The assigned EVVM ID, or undefined on error
 */
export async function callRegisterEvvm(
  hostChainId: number,
  evvmAddress: `0x${string}`,
  walletName: string = "defaultKey",
  ethRpcUrl: string = EthSepoliaPublicRpc
): Promise<number | undefined> {
  try {
    const result =
      await $`cast call ${RegisteryEvvmAddress} --rpc-url ${ethRpcUrl} "registerEvvm(uint256,address)(uint256)" ${hostChainId} ${evvmAddress} --account ${walletName}`.quiet();
    await $`cast send ${RegisteryEvvmAddress} --rpc-url ${ethRpcUrl} "registerEvvm(uint256,address)(uint256)" ${hostChainId} ${evvmAddress} --account  ${walletName}`;

    const evvmID = result.stdout.toString().trim();
    return Number(evvmID);
  } catch (error) {
    return undefined;
  }
}

/**
 * Sets the EVVM ID on the deployed EVVM contract
 *
 * After receiving an EVVM ID from the registry, this function updates the
 * EVVM contract with its assigned ID. Required to complete EVVM initialization.
 *
 * @param {`0x${string}`} evvmAddress - Address of the EVVM contract
 * @param {number} evvmID - The EVVM ID assigned by the registry
 * @param {string} hostChainRpcUrl - RPC URL for the chain where EVVM is deployed
 * @param {string} walletName - Foundry wallet name to use for the transaction
 * @returns {Promise<boolean>} True if successfully set, false on error
 */
export async function callSetEvvmID(
  evvmAddress: `0x${string}`,
  evvmID: number,
  hostChainRpcUrl: string,
  walletName: string = "defaultKey"
): Promise<boolean> {
  try {
    await $`cast send ${evvmAddress} --rpc-url ${hostChainRpcUrl} "setEvvmID(uint256)" ${evvmID} --account ${walletName} `;
    console.log(
      `${colors.evvmGreen}EVVM ID set successfully on the EVVM contract.${colors.reset}`
    );
    return true;
  } catch (error) {
    return false;
  }
}


/**
 * Sets the host chain station address on the external chain station contract
 *
 * @param {`0x${string}`} treasuryExternalChainAddress - Address of the External Chain Station contract
 * @param {`0x${string}`} treasuryHostChainStationAddress - Address of the Host Chain Station
 * @param {string} externalChainRpcUrl - RPC URL for the external chain
 * @param {string} walletName - Foundry wallet name to use for the transaction
 * @returns {Promise<boolean>} True if successfully set, false on error
 */
export async function callSetHostChainAddress(
  treasuryExternalChainAddress: `0x${string}`,
  treasuryHostChainStationAddress: `0x${string}`,
  externalChainRpcUrl: string,
  walletName: string = "defaultKey"
): Promise<boolean> {
  try {
    await $`cast send ${treasuryExternalChainAddress} --rpc-url ${externalChainRpcUrl} "_setHostChainAddress(address,string)" ${treasuryHostChainStationAddress} "${treasuryHostChainStationAddress}" --account ${walletName}`;
    console.log(
      `${colors.evvmGreen}Host chain address set successfully on External Chain Station.${colors.reset}`
    );
    return true;
  } catch (error) {
    return false;
  }
}

/**
 * Sets the host chain station address on the external chain station contract
 *
 * @param {`0x${string}`} treasuryHostChainStationAddress - Address of the Host Chain Station
 * @param {`0x${string}`} treasuryExternalChainAddress - Address of the External Chain Station contract
 * @param {string} hostChainRpcUrl - RPC URL for the host chain
 * @param {string} walletName - Foundry wallet name to use for the transaction
 * @returns {Promise<boolean>} True if successfully set, false on error
 */
export async function callSetExternalChainAddress(
  treasuryHostChainStationAddress: `0x${string}`,
  treasuryExternalChainAddress: `0x${string}`,
  hostChainRpcUrl: string,
  walletName: string = "defaultKey"
): Promise<boolean> {
  try {
    await $`cast send ${treasuryHostChainStationAddress} --rpc-url ${hostChainRpcUrl} "_setExternalChainAddress(address,string)" ${treasuryExternalChainAddress} "${treasuryExternalChainAddress}" --account ${walletName}`;
    console.log(
      `${colors.evvmGreen}Host chain address set successfully on Host Chain Station.${colors.reset}`
    );
    return true;
  } catch (error) {
    return false;
  }
}

/**
 * Verifies Foundry installation and wallet setup
 *
 * Performs prerequisite checks before deployment:
 * 1. Verifies Foundry toolchain is installed
 * 2. Verifies the specified wallet exists in Foundry keystore
 *
 * @param {string} walletName - Name of the wallet to verify
 * @returns {Promise<boolean>} True if all prerequisites are met, false otherwise
 */
export async function verifyFoundryInstalledAndAccountSetup(
  walletName: string = "defaultKey"
): Promise<boolean> {
  if (!(await foundryIsInstalled())) {
    showError(
      "Foundry is not installed.",
      "Please install Foundry to proceed with deployment."
    );
    return false;
  }

  if (!(await walletIsSetup(walletName))) {
    showError(
      `Wallet '${walletName}' is not available.`,
      `Please import your wallet using:\n   ${colors.evvmGreen}cast wallet import ${walletName} --interactive${colors.reset}\n\n   You'll be prompted to enter your private key securely.`
    );
    return false;
  }
  return true;
}

/**
 * Checks if Foundry toolchain is installed
 *
 * @returns {Promise<boolean>} True if Foundry is installed and accessible
 */
export async function foundryIsInstalled(): Promise<boolean> {
  try {
    await $`foundryup --version`.quiet();
  } catch (error) {
    return false;
  }
  return true;
}

/**
 * Checks if a wallet exists in Foundry's keystore
 *
 * @param {string} walletName - Name of the wallet to check
 * @returns {Promise<boolean>} True if wallet exists in keystore
 */
export async function walletIsSetup(
  walletName: string = "defaultKey"
): Promise<boolean> {
  let walletList = await $`cast wallet list`.quiet();
  if (!walletList.stdout.includes(`${walletName} (Local)`)) {
    return false;
  }
  return true;
}

/**
 * Displays deployed contracts and extracts EVVM contract address
 *
 * Reads the Foundry broadcast file to:
 * 1. Extract all deployed contract addresses
 * 2. Display them in a formatted list
 * 3. Locate and return the EVVM contract address
 *
 * @param {number} chainId - Chain ID where contracts were deployed
 * @returns {Promise<`0x${string}` | null>} EVVM contract address, or null if not found
 */
export async function showDeployContractsAndFindEvvm(
  chainId: number
): Promise<`0x${string}` | null> {
  const broadcastFile = `./broadcast/Deploy.s.sol/${chainId}/run-latest.json`;
  const broadcastContent = await Bun.file(broadcastFile).text();
  const broadcastJson = JSON.parse(broadcastContent);

  const createdContracts = broadcastJson.transactions
    .filter((tx: any) => tx.transactionType === "CREATE")
    .map(
      (tx: any) =>
        ({
          contractName: tx.contractName,
          contractAddress: tx.contractAddress,
        } as CreatedContract)
    );

  console.log(
    `\n${colors.bright}═══════════════════════════════════════${colors.reset}`
  );
  console.log(`${colors.bright}          Deployed Contracts${colors.reset}`);
  console.log(
    `${colors.bright}═══════════════════════════════════════${colors.reset}\n`
  );

  const chainData = ChainData[chainId];
  const explorerUrl = chainData?.ExplorerToAddress;

  createdContracts.forEach((contract: CreatedContract) => {
    console.log(
      `  ${colors.green}✓${colors.reset} ${colors.blue}${contract.contractName}${colors.reset}\n    ${colors.darkGray}→${colors.reset} ${contract.contractAddress}`
    );
    if (explorerUrl) {
      console.log(
        `    ${colors.darkGray}→${colors.reset} ${explorerUrl}${contract.contractAddress}`
      );
    }
  });
  console.log();

  return (
    createdContracts.find(
      (contract: CreatedContract) => contract.contractName === "Evvm"
    )?.contractAddress ?? null
  );
}

export async function showDeployContractsAndFindEvvmWithTreasuryHostChainStation(
  chainIdHost: number
): Promise<{
  evvmAddress: `0x${string}` | null;
  treasuryHostChainStationAddress: `0x${string}` | null;
}> {
  const broadcastFile = `./broadcast/Deploy.s.sol/${chainIdHost}/run-latest.json`;
  const broadcastContent = await Bun.file(broadcastFile).text();
  const broadcastJson = JSON.parse(broadcastContent);

  const createdContracts = broadcastJson.transactions
    .filter((tx: any) => tx.transactionType === "CREATE")
    .map(
      (tx: any) =>
        ({
          contractName: tx.contractName,
          contractAddress: tx.contractAddress,
        } as CreatedContract)
    );

  console.log(
    `\n${colors.bright}═══════════════════════════════════════${colors.reset}`
  );
  console.log(`${colors.bright}          Deployed Contracts${colors.reset}`);
  console.log(
    `${colors.bright}═══════════════════════════════════════${colors.reset}\n`
  );

  const chainData = ChainData[chainIdHost];
  const explorerUrl = chainData?.ExplorerToAddress;

  createdContracts.forEach((contract: CreatedContract) => {
    console.log(
      `  ${colors.green}✓${colors.reset} ${colors.blue}${contract.contractName}${colors.reset}\n    ${colors.darkGray}→${colors.reset} ${contract.contractAddress}`
    );
    if (explorerUrl) {
      console.log(
        `    ${colors.darkGray}→${colors.reset} ${explorerUrl}${contract.contractAddress}`
      );
    }
  });
  console.log();

  const evvmAddress =
    createdContracts.find(
      (contract: CreatedContract) => contract.contractName === "Evvm"
    )?.contractAddress ?? null;

  const treasuryHostChainStationAddress =
    createdContracts.find(
      (contract: CreatedContract) =>
        contract.contractName === "TreasuryHostChainStation"
    )?.contractAddress ?? null;

  return { evvmAddress, treasuryHostChainStationAddress };
}


export async function showDeployTreasuryExternalChainStation(
  chainIdExternal: number
): Promise<`0x${string}` | null> {
  const broadcastFile = `./broadcast/Deploy.s.sol/${chainIdExternal}/run-latest.json`;
  const broadcastContent = await Bun.file(broadcastFile).text();
  const broadcastJson = JSON.parse(broadcastContent);

  const createdContracts = broadcastJson.transactions
    .filter((tx: any) => tx.transactionType === "CREATE")
    .map(
      (tx: any) =>
        ({
          contractName: tx.contractName,
          contractAddress: tx.contractAddress,
        } as CreatedContract)
    );

  console.log(
    `\n${colors.bright}═══════════════════════════════════════${colors.reset}`
  );
  console.log(`${colors.bright}          Deployed Contracts${colors.reset}`);
  console.log(
    `${colors.bright}═══════════════════════════════════════${colors.reset}\n`
  );

  const chainData = ChainData[chainIdExternal];
  const explorerUrl = chainData?.ExplorerToAddress;

  createdContracts.forEach((contract: CreatedContract) => {
    console.log(
      `  ${colors.green}✓${colors.reset} ${colors.blue}${contract.contractName}${colors.reset}\n    ${colors.darkGray}→${colors.reset} ${contract.contractAddress}`
    );
    if (explorerUrl) {
      console.log(
        `    ${colors.darkGray}→${colors.reset} ${explorerUrl}${contract.contractAddress}`
      );
    }
  });
  console.log();

  return (
    createdContracts.find(
      (contract: CreatedContract) =>
        contract.contractName === "TreasuryExternalChainStation"
    )?.contractAddress ?? null
  );
}


/**
 * Generates Solidity interfaces for EVVM contracts
 *
 * Uses Foundry's `cast interface` command to create interface files for
 * all core EVVM contracts. Interfaces are saved in the `src/interfaces` directory.
 *
 * @returns {Promise<void>} Resolves when interfaces are generated
 */
export async function contractInterfacesGenerator() {
  let contracts: ContractFileMetadata[] = [
    {
      contractName: "Evvm",
      folderName: "evvm",
    },
    {
      contractName: "NameService",
      folderName: "nameService",
    },
    {
      contractName: "P2PSwap",
      folderName: "p2pSwap",
    },
    {
      contractName: "Staking",
      folderName: "staking",
    },
    {
      contractName: "Estimator",
      folderName: "staking",
    },
    {
      contractName: "Treasury",
      folderName: "treasury",
    },
    {
      contractName: "TreasuryExternalChainStation",
      folderName: "treasuryTwoChains",
    },
    {
      contractName: "TreasuryHostChainStation",
      folderName: "treasuryTwoChains",
    },
  ];

  console.log(
    `\n${colors.bright}╔═══════════════════════════════════════════════════════════╗${colors.reset}`
  );
  console.log(
    `${colors.bright}║          Generating Contract Interfaces                   ║${colors.reset}`
  );
  console.log(
    `${colors.bright}╚═══════════════════════════════════════════════════════════╝${colors.reset}\n`
  );

  const fs = require("fs");
  const path = "./src/interfaces";
  if (!fs.existsSync(path)) {
    console.log(
      `${colors.yellow}⚠  Interfaces folder not found. Creating...${colors.reset}\n`
    );
    fs.mkdirSync(path);
  }

  for (const contract of contracts) {
    console.log(
      `${colors.blue}▸ Processing ${contract.contractName}...${colors.reset}`
    );

    let evvmInterface =
      await $`cast interface src/contracts/${contract.folderName}/${contract.contractName}.sol`.quiet();
    let interfacePath = `./src/interfaces/I${contract.contractName}.sol`;

    // Process and clean the interface content
    let content = evvmInterface.stdout
      .toString()
      .replace(
        /^\/\/ SPDX-License-Identifier:.*$/m,
        "// SPDX-License-Identifier: EVVM-NONCOMMERCIAL-1.0\n// Full license terms available at: https://www.evvm.info/docs/EVVMNoncommercialLicense"
      )
      .replace("pragma solidity ^0.8.4;", "pragma solidity ^0.8.0;")
      .replace(
        `interface ${contract.contractName} {`,
        `interface I${contract.contractName} {`
      );

    fs.writeFileSync(interfacePath, content);

    console.log(
      `  ${colors.green}✓ I${contract.contractName}.sol${colors.reset} ${colors.darkGray}→ ${interfacePath}${colors.reset}\n`
    );
  }

  console.log(
    `${colors.green}✓${colors.reset}${colors.bright} Successfully generated ${contracts.length} interfaces${colors.reset}`
  );
}
