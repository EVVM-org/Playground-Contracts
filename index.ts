#!/usr/bin/env bun

// index.ts - CLI Entry Point

import { $ } from "bun";

import { parseArgs } from "util";
import { version } from "./package.json";

type ConfirmAnswer = {
  configureAdvancedMetadata: string | null;
  confirmInputs: string | null;
  deploy: string | null;
};

type InputAddresses = {
  admin: `0x${string}` | null;
  goldenFisher: `0x${string}` | null;
  activator: `0x${string}` | null;
};

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
  greet: greetCommand,
  example: exampleCommand,
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
  ${colors.green}greet${colors.reset}             Greet user
  ${colors.green}example${colors.reset}           Example command
  ${colors.green}deploy${colors.reset}            Deploy to EVVM
  ${colors.green}fulltest${colors.reset}          Run full test suite

${colors.bright}OPTIONS:${colors.reset}
  -h, --help          Show help
  -v, --version       Show version
  -n, --name <name>   Specify a name
  --verbose           Verbose mode

${colors.bright}EXAMPLES:${colors.reset}
  evvm greet --name John
  evvm example --verbose
  evvm deploy
  evvm fulltest
  `);
}

async function deployEvvm(args: string[], options: any) {
  let confirmAnswer: ConfirmAnswer = {
    configureAdvancedMetadata: null,
    confirmInputs: null,
    deploy: null,
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

  // we verify if foundry is installed
  try {
    await $`foundryup --version`.quiet();
  } catch (error) {
    console.log(
      `${colors.red}Error: Foundry is not installed. Please install Foundry to proceed with deployment.${colors.reset}`
    );
    return;
  }

  // Verify defaultKey wallet exists
  const walletList = await $`cast wallet list`.quiet();
  if (!walletList.stdout.includes("defaultKey (Local)")) {
    console.log(
      `${colors.red}Error: Wallet 'defaultKey (Local)' is not available. Deployment aborted.${colors.reset}`
    );
    return;
  }

  while (!confirmationDone) {
    for (const key of Object.keys(addresses) as (keyof InputAddresses)[]) {
      let input: string | null = null;
      while (!input) {
        input = prompt(
          `${colors.yellow}Please enter the address for ${key}:${colors.reset}`
        );
        if (input && /^0x[a-fA-F0-9]{40}$/.test(input)) {
          addresses[key] = input as `0x${string}`;
        } else {
          console.log(
            `${colors.red}Invalid address format. Please enter a valid Ethereum address.${colors.reset}`
          );
          input = null;
        }
      }
    }

    // Ask EvvmName (by default "EVVM")

    let evvmNameInput = prompt(
      `${colors.yellow}EVVM Name ${colors.darkGray}[${evvmMetadata.EvvmName}]:${colors.reset}`
    );
    if (evvmNameInput) {
      evvmMetadata.EvvmName = evvmNameInput;
    }

    // ask for principal token details

    // principal token name

    let principalTokenNameInput = prompt(
      `${colors.yellow}Principal Token Name ${colors.darkGray}[${evvmMetadata.principalTokenName}]:${colors.reset}`
    );
    if (principalTokenNameInput) {
      evvmMetadata.principalTokenName = principalTokenNameInput;
    }

    // principal token symbol
    let principalTokenSymbolInput = prompt(
      `${colors.yellow}Principal Token Symbol ${colors.darkGray}[${evvmMetadata.principalTokenSymbol}]:${colors.reset}`
    );
    if (principalTokenSymbolInput) {
      evvmMetadata.principalTokenSymbol = principalTokenSymbolInput;
    }

    // ask for advanced metadata confirmation
    while (
      confirmAnswer.configureAdvancedMetadata === null ||
      (confirmAnswer.configureAdvancedMetadata.toLowerCase() !== "y" &&
        confirmAnswer.configureAdvancedMetadata.toLowerCase() !== "n")
    ) {
      confirmAnswer.configureAdvancedMetadata = prompt(
        `${colors.yellow}Do you want to configure advanced metadata? (y/n):${colors.reset}`
      );
    }

    if (confirmAnswer.configureAdvancedMetadata.toLowerCase() === "y") {
      // total supply
      let totalSupplyInput = prompt(
        `${colors.yellow}Total Supply ${colors.darkGray}[${evvmMetadata.totalSupply}]:${colors.reset}`
      );

      // eraTokens
      let eraTokensInput = prompt(
        `${colors.yellow}Era Tokens ${colors.darkGray}[${evvmMetadata.eraTokens}]:${colors.reset}`
      );

      // reward
      let rewardInput = prompt(
        `${colors.yellow}Reward ${colors.darkGray}[${evvmMetadata.reward}]:${colors.reset}`
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
    while (
      confirmAnswer.confirmInputs === null ||
      (confirmAnswer.confirmInputs.toLowerCase() !== "y" &&
        confirmAnswer.confirmInputs.toLowerCase() !== "n")
    ) {
      confirmAnswer.confirmInputs = prompt(
        `${colors.yellow}Are all inputs correct? (y/n):${colors.reset}`
      );
    }

    if (confirmAnswer.confirmInputs.toLowerCase() === "y") {
      confirmationDone = true;
    }
  }

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

  // Reescribe input/Inputs.sol with new data

  // Format large numbers without scientific notation

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

  //console.log(`${colors.blue}Updated ${inputFile}${colors.reset}`);

  // Confirmation prompt
  while (
    confirmAnswer.deploy === null ||
    (confirmAnswer.deploy.toLowerCase() !== "y" &&
      confirmAnswer.deploy.toLowerCase() !== "n")
  ) {
    confirmAnswer.deploy = prompt(
      `${colors.yellow}Are you sure you want to deploy to EVVM? (y/n):${colors.reset}`
    );
  }

  if (confirmAnswer.deploy.toLowerCase() !== "y") {
    console.log(`${colors.red}Deployment cancelled${colors.reset}`);
    return;
  }

  // Retrieve chain ID from the RPC URL
  const rpcUrl = "http://0.0.0.0:8545";
  const chainId = await getChainId(rpcUrl);

  console.log(`${colors.blue}Deploying at chain host id:${colors.reset} ${chainId}`);

  console.log(
    `${colors.evvmGreen}Starting deployment to EVVM...${colors.reset}`
  );
  try {
    await $`forge clean`.quiet();
    await $`forge script script/Deploy.s.sol:DeployScript --via-ir --optimize true --rpc-url http://0.0.0.0:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast -vvvv`;
    console.log(
      `${colors.green}Deployment completed successfully!${colors.reset}`
    );
  } catch (error) {
    console.error(`${colors.red}Deployment failed:${colors.reset}`, error);
  }
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

// Command: greet
async function greetCommand(args: string[], options: any) {
  const name = options.name || "user";
  console.log(`${colors.green}Hello, ${name}!${colors.reset}`);

  if (options.verbose) {
    console.log(
      `${colors.blue}[Verbose]${colors.reset} Executing greet command`
    );
  }
}

// Command: example
async function exampleCommand(args: string[], options: any) {
  console.log(`${colors.yellow}Executing example command...${colors.reset}`);

  // Simulate async operation
  await Bun.sleep(1000);

  console.log(`${colors.green}✓${colors.reset} Operation completed!`);

  if (options.verbose) {
    console.log(`${colors.blue}[Verbose]${colors.reset} Args:`, args);
    console.log(`${colors.blue}[Verbose]${colors.reset} Options:`, options);
  }
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

// Helpers
const formatNumber = (num: number | null) => {
  if (num === null) return "0";
  if (num > 1e15) {
    return num.toLocaleString("fullwide", { useGrouping: false });
  }
  return num.toString();
};

async function getChainId(rpcUrl: string): Promise<number> {
  //curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' [YOUR_RPC_URL]

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
