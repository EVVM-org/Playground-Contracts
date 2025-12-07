#!/usr/bin/env bun

// index.ts - CLI Entry Point

import { $ } from "bun";

import { parseArgs } from "util";
import { version } from "./package.json";

type ConfirmAnswer = {
  configureAdvancedMetadata: string;
  confirmInputs: string;
  deploy: string;
};

type InputAddresses = {
  admin: `0x${string}` | null;
  goldenFisher: `0x${string}` | null;
  activator: `0x${string}` | null;
};

interface CreatedContract {
  contractName: string;
  contractAddress: `0x${string}`;
}

type EvvmMetadata = {
  EvvmName: string | null;
  EvvmID: number | null;
  principalTokenName: string | null;
  principalTokenSymbol: string | null;
  principalTokenAddress: `0x${string}` | null;
  totalSupply: number | null;
  eraTokens: number | null;
  reward: number | null;
};

// Terminal colors
const colors = {
  reset: "\x1b[0m",
  bright: "\x1b[1m",
  green: "\x1b[32m",
  blue: "\x1b[34m",
  yellow: "\x1b[33m",
  red: "\x1b[31m",
  darkGray: "\x1b[90m",
  evvmGreen: "\x1b[38;2;1;240;148m",
};

// Available commands
const commands = {
  help: showHelp,
  version: showVersion,
  deploy: deployEvvm,
  fulltest: fullTest,
};

// Main function
async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    showHelp();
    return;
  }

  const { values, positionals } = parseArgs({
    args,
    options: {
      help: { type: "boolean", short: "h" },
      version: { type: "boolean", short: "v" },
      name: { type: "string", short: "n" },
      verbose: { type: "boolean" },
    },
    allowPositionals: true,
  });

  // Global flags
  if (values.help) {
    showHelp();
    return;
  }

  if (values.version) {
    showVersion();
    return;
  }

  // Execute command
  const command = positionals[0];
  const handler = commands[command as keyof typeof commands];

  if (handler) {
    await handler(positionals.slice(1), values);
  } else {
    console.error(
      `${colors.red}Error: Unknown command "${command}"${colors.reset}`
    );
    console.log(
      `Use ${colors.bright}--help${colors.reset} to see available commands\n`
    );
    process.exit(1);
  }
}

// Command: help
function showHelp() {
  console.log(`
${colors.bright}EVVM CLI Tool${colors.reset} - A command line interface tool

${colors.bright}USAGE:${colors.reset}
  evvm <command> [options]

${colors.bright}COMMANDS:${colors.reset}
  ${colors.green}help${colors.reset}              Show this help
  ${colors.green}version${colors.reset}           Show version
  ${colors.green}deploy${colors.reset}            Deploy and verify an EVVM
  ${colors.green}fulltest${colors.reset}          Run full test suite

${colors.bright}OPTIONS:${colors.reset}
  -h, --help          Show help
  -v, --version       Show version
  `);
}

async function deployEvvm(args: string[], options: any) {
  let confirmAnswer: ConfirmAnswer = {
    configureAdvancedMetadata: "",
    confirmInputs: "",
    deploy: "",
  };

  let confirmationDone: boolean = false;

  let evvmMetadata: EvvmMetadata = {
    EvvmName: "EVVM",
    EvvmID: 0,
    principalTokenName: "Mate Token",
    principalTokenSymbol: "MATE",
    principalTokenAddress: "0x0000000000000000000000000000000000000001",
    totalSupply: 2033333333000000000000000000,
    eraTokens: 1016666666500000000000000000,
    reward: 5000000000000000000,
  };

  let addresses: InputAddresses = {
    admin: null,
    goldenFisher: null,
    activator: null,
  };

  // Banner
  console.log(`${colors.evvmGreen}`);
  console.log("░▒▓████████▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓██████████████▓▒░  ");
  console.log("░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ");
  console.log("░▒▓█▓▒░       ░▒▓█▓▒▒▓█▓▒░ ░▒▓█▓▒▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ");
  console.log("░▒▓██████▓▒░  ░▒▓█▓▒▒▓█▓▒░ ░▒▓█▓▒▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ");
  console.log("░▒▓█▓▒░        ░▒▓█▓▓█▓▒░   ░▒▓█▓▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ");
  console.log("░▒▓█▓▒░        ░▒▓█▓▓█▓▒░   ░▒▓█▓▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ");
  console.log("░▒▓████████▓▒░  ░▒▓██▓▒░     ░▒▓██▓▒░  ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ");
  console.log(`${colors.reset}`);

  // Verify foundry installation and setup
  if (!(await foundryIsInstalledAndSetup())) return;

  while (!confirmationDone) {
    // Collect addresses with validation
    for (const key of Object.keys(addresses) as (keyof InputAddresses)[]) {
      addresses[key] = promptAddress(
        `${colors.yellow}Please enter the address for ${key}:${colors.reset}`
      );
    }

    // Ask EvvmName (by default "EVVM")
    evvmMetadata.EvvmName = promptString(
      `${colors.yellow}EVVM Name ${colors.darkGray}[${evvmMetadata.EvvmName}]:${colors.reset}`,
      evvmMetadata.EvvmName ?? undefined
    );

    // Principal token name
    evvmMetadata.principalTokenName = promptString(
      `${colors.yellow}Principal Token Name ${colors.darkGray}[${evvmMetadata.principalTokenName}]:${colors.reset}`,
      evvmMetadata.principalTokenName ?? undefined
    );

    // Principal token symbol
    evvmMetadata.principalTokenSymbol = promptString(
      `${colors.yellow}Principal Token Symbol ${colors.darkGray}[${evvmMetadata.principalTokenSymbol}]:${colors.reset}`,
      evvmMetadata.principalTokenSymbol ?? undefined
    );

    // ask for advanced metadata confirmation
    confirmAnswer.configureAdvancedMetadata = promptYesNo(
      `${colors.yellow}Do you want to configure advanced metadata? (y/n):${colors.reset}`
    );

    if (confirmAnswer.configureAdvancedMetadata.toLowerCase() === "y") {
      // total supply
      evvmMetadata.totalSupply = promptNumber(
        `${colors.yellow}Total Supply ${colors.darkGray}[${formatNumber(
          evvmMetadata.totalSupply
        )}]:${colors.reset}`,
        evvmMetadata.totalSupply ?? undefined
      );

      // eraTokens
      evvmMetadata.eraTokens = promptNumber(
        `${colors.yellow}Era Tokens ${colors.darkGray}[${formatNumber(
          evvmMetadata.eraTokens
        )}]:${colors.reset}`,
        evvmMetadata.eraTokens ?? undefined
      );

      // reward
      evvmMetadata.reward = promptNumber(
        `${colors.yellow}Reward ${colors.darkGray}[${formatNumber(
          evvmMetadata.reward
        )}]:${colors.reset}`,
        evvmMetadata.reward ?? undefined
      );
    }

    // Confirm inputs
    console.log(
      `\n${colors.bright}=== Configuration Summary ===${colors.reset}\n`
    );

    console.log(`${colors.bright}Addresses:${colors.reset}`);
    for (const key of Object.keys(addresses) as (keyof InputAddresses)[]) {
      console.log(`  ${colors.blue}${key}:${colors.reset} ${addresses[key]}`);
    }

    console.log(`\n${colors.bright}EVVM Metadata:${colors.reset}`);
    for (const [metaKey, metaValue] of Object.entries(evvmMetadata)) {
      // Skip EvvmID
      if (metaKey === "EvvmID") continue;

      // Format large numbers without scientific notation
      let displayValue = metaValue;
      if (typeof metaValue === "number" && metaValue > 1e15) {
        displayValue = metaValue.toLocaleString("fullwide", {
          useGrouping: false,
        });
      }
      console.log(`  ${colors.blue}${metaKey}:${colors.reset} ${displayValue}`);
    }
    console.log();

    // Ask for confirmation
    confirmAnswer.confirmInputs = promptYesNo(
      `${colors.yellow}Are all inputs correct? (y/n):${colors.reset}`
    );

    if (confirmAnswer.confirmInputs.toLowerCase() === "y") {
      confirmationDone = true;
    }
  }

  if (!(await writeInputsFile(addresses, evvmMetadata))) {
    console.log(
      `${colors.red}Error: Failed to write inputs file. Deployment aborted.${colors.reset}`
    );
    return;
  }

  //console.log(`${colors.blue}Updated ${inputFile}${colors.reset}`);

  // Confirmation prompt
  confirmAnswer.deploy = promptYesNo(
    `${colors.yellow}Are you sure you want to deploy to EVVM? (y/n):${colors.reset}`
  );

  if (confirmAnswer.deploy.toLowerCase() !== "y") {
    console.log(`${colors.red}Deployment cancelled${colors.reset}`);
    return;
  }

  // Retrieve chain ID from the RPC_URL environment variable
  let rpcUrl: string | undefined | null = process.env.RPC_URL;
  if (!rpcUrl) rpcUrl = null;

  while (!rpcUrl) {
    console.log(`${colors.red}RPC URL not found in .env file.${colors.reset}`);
    rpcUrl = prompt(
      `${colors.yellow}Please enter the RPC URL for deployment:${colors.reset}`
    );
    if (!rpcUrl) {
      console.log(
        `${colors.red}RPC URL cannot be empty. Please enter a valid RPC URL.${colors.reset}`
      );
    }
  }

  const chainId = await getChainId(rpcUrl);

  console.log(
    `${colors.blue}Deploying at chain host id:${colors.reset} ${chainId}`
  );

  console.log(
    `${colors.evvmGreen}Starting deployment to EVVM...${colors.reset}`
  );
  try {
    await $`forge clean`.quiet();
    await $`forge script script/Deploy.s.sol:DeployScript --via-ir --optimize true --rpc-url ${rpcUrl} --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast -vvvv`;
    console.log(
      `${colors.green}Deployment completed successfully!${colors.reset}`
    );
  } catch (error) {
    console.error(`${colors.red}Deployment failed:${colors.reset}`, error);
    return;
  }

  // Show deployed contracts and find Evvm address

  const evvmAddress: `0x${string}` | null =
    await showDeployContractsAndFindEvvm(chainId);

  console.log();
  console.log(
    `${colors.green}Evvm deployed at address: ${evvmAddress}${colors.reset}`
  );
}

async function fullTest() {
  console.log(
    `${colors.evvmGreen}Starting full test suite on EVVM...${colors.reset}`
  );
  await $`forge test --match-contract unitTestCorrect_EVVM --summary --detailed --gas-report -vvv --show-progress`;
}

// Command: version
function showVersion() {
  console.log(`v${version}`);
}

// Global error handling
process.on("uncaughtException", (error) => {
  console.error(`${colors.red}Fatal error:${colors.reset}`, error.message);
  process.exit(1);
});

// Execute
main().catch((error) => {
  console.error(`${colors.red}Error:${colors.reset}`, error.message);
  process.exit(1);
});

// Helpers ////////////////////////////////////////////////////////////////////////////////////
function promptString(message: string, defaultValue?: string): string {
  const input = prompt(message);

  // Si está vacío y hay valor por defecto, usar el default
  if (!input && defaultValue !== undefined) {
    return defaultValue;
  }

  // Si no hay input ni default, pedir nuevamente
  if (!input) {
    console.log(
      `${colors.red}Input cannot be empty. Please enter a value.${colors.reset}`
    );
    return promptString(message, defaultValue);
  }

  return input;
}

function promptNumber(message: string, defaultValue?: number): number {
  const input = prompt(message);

  // Si está vacío y hay valor por defecto, usar el default
  if (!input && defaultValue !== undefined) {
    return defaultValue;
  }

  // Validar que sea un número válido
  const num = Number(input);
  if (isNaN(num) || num < 0) {
    console.log(
      `${colors.red}Invalid number. Please enter a valid positive number.${colors.reset}`
    );
    return promptNumber(message, defaultValue);
  }

  return num;
}

function promptAddress(
  message: string,
  defaultValue?: `0x${string}`
): `0x${string}` {
  const input = prompt(message);

  // Si está vacío y hay valor por defecto, usar el default
  if (!input && defaultValue !== undefined) {
    return defaultValue;
  }

  // Validar que sea una dirección válida
  if (!verifyAddress(input)) {
    console.log(
      `${colors.red}Invalid address format. Please enter a valid Ethereum address.${colors.reset}`
    );
    return promptAddress(message, defaultValue);
  }

  return input as `0x${string}`;
}

function promptYesNo(message: string, defaultValue?: string): string {
  const input = prompt(message);

  // Si está vacío y hay valor por defecto, usar el default
  if (!input && defaultValue !== undefined) {
    return defaultValue;
  }

  // Validar que sea 'y' o 'n'
  if (input?.toLowerCase() !== "y" && input?.toLowerCase() !== "n") {
    console.log(`${colors.red}Please enter 'y' or 'n'${colors.reset}`);
    return promptYesNo(message, defaultValue);
  }

  return input.toLowerCase();
}

function verifyAddress(address: string | null): boolean {
  if (!address) return false;
  return /^0x[a-fA-F0-9]{40}$/.test(address);
}

const formatNumber = (num: number | null) => {
  if (num === null) return "0";
  if (num > 1e15) {
    return num.toLocaleString("fullwide", { useGrouping: false });
  }
  return num.toString();
};

async function writeInputsFile(
  addresses: InputAddresses,
  evvmMetadata: EvvmMetadata
): Promise<boolean> {
  // Verify if input/Inputs.sol exists, if not create it
  const inputDir = "./input";
  const inputFile = `${inputDir}/Inputs.sol`;

  try {
    await Bun.file(inputFile).text();
  } catch {
    // File doesn't exist, create directory and file
    await $`mkdir -p ${inputDir}`.quiet();
    await Bun.write(inputFile, "");
    console.log(`${colors.blue}Created ${inputFile}${colors.reset}`);
  }

  const inputFileContent = `// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import {EvvmStructs} from "@EVVM/playground/contracts/evvm/lib/EvvmStructs.sol";

abstract contract Inputs {
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

async function getChainId(rpcUrl: string): Promise<number> {
  const response = await fetch(rpcUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      jsonrpc: "2.0",
      method: "eth_chainId",
      params: [],
      id: 1,
    }),
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch chain ID: ${response.statusText}`);
  }
  const data = (await response.json()) as { result: string };
  return parseInt(data.result, 16);
}

async function foundryIsInstalledAndSetup(): Promise<boolean> {
  try {
    await $`foundryup --version`.quiet();
  } catch (error) {
    console.log(
      `${colors.red}Error: Foundry is not installed. Please install Foundry to proceed with deployment.${colors.reset}`
    );
    return false;
  }

  // Verify defaultKey wallet exists
  let walletList = await $`cast wallet list`.quiet();
  if (!walletList.stdout.includes("defaultKey (Local)")) {
    console.log(
      `${colors.red}Error: Wallet 'defaultKey (Local)' is not available. Deployment aborted.${colors.reset}`
    );
    return false;
  }
  return true;
}

async function showDeployContractsAndFindEvvm(
  chainId: number
): Promise<`0x${string}` | null> {
  // open ./broadcast/Deploy.s.sol/$CHAIN_ID/run-latest.json
  const broadcastFile = `./broadcast/Deploy.s.sol/${chainId}/run-latest.json`;
  //parse the file to json
  const broadcastContent = await Bun.file(broadcastFile).text();
  const broadcastJson = JSON.parse(broadcastContent);
  /*
  from the "transactions": [] array if the transactionType is "CREATE"
  we need to extract the contractName and contractAddress using map
  from CreatedContract interface
  */
  const createdContracts = broadcastJson.transactions
    .filter((tx: any) => tx.transactionType === "CREATE")
    .map(
      (tx: any) =>
        ({
          contractName: tx.contractName,
          contractAddress: tx.contractAddress,
        } as CreatedContract)
    );

  console.log(`${colors.bright}=== Deployed Contracts ===${colors.reset}`);
  createdContracts.forEach((contract: CreatedContract) => {
    console.log(
      `  ${colors.blue}${contract.contractName}:${colors.reset} ${contract.contractAddress}`
    );
  });

  // search for Evvm contract address and return it
  return (
    createdContracts.find(
      (contract: CreatedContract) => contract.contractName === "Evvm"
    )?.contractAddress ?? null
  );
}
