import { $ } from "bun";
import type { ConfirmAnswer, InputAddresses, EvvmMetadata } from "../types";
import { colors } from "../constants";
import { promptString, promptNumber, promptAddress, promptYesNo, promptSecret, promptSelect } from "../utils/prompts";
import { formatNumber, showError } from "../utils/validators";
import {
  foundryIsInstalledAndSetup,
  writeInputsFile,
  checkIsChainIdSupported,
  showDeployContractsAndFindEvvm,
} from "../utils/foundry";
import { getRPCUrlAndChainId } from "../utils/rpc";

export async function deployEvvm(args: string[], options: any) {
  let isDeployingOnLocalBlockchain = false;

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

  if (!(await foundryIsInstalledAndSetup())) return;

  while (!confirmationDone) {
    for (const key of Object.keys(addresses) as (keyof InputAddresses)[]) {
      addresses[key] = promptAddress(
        `${colors.yellow}Please enter the address for ${key}:${colors.reset}`
      );
    }

    evvmMetadata.EvvmName = promptString(
      `${colors.yellow}EVVM Name ${colors.darkGray}[${evvmMetadata.EvvmName}]:${colors.reset}`,
      evvmMetadata.EvvmName ?? undefined
    );

    evvmMetadata.principalTokenName = promptString(
      `${colors.yellow}Principal Token Name ${colors.darkGray}[${evvmMetadata.principalTokenName}]:${colors.reset}`,
      evvmMetadata.principalTokenName ?? undefined
    );

    evvmMetadata.principalTokenSymbol = promptString(
      `${colors.yellow}Principal Token Symbol ${colors.darkGray}[${evvmMetadata.principalTokenSymbol}]:${colors.reset}`,
      evvmMetadata.principalTokenSymbol ?? undefined
    );

    confirmAnswer.configureAdvancedMetadata = promptYesNo(
      `${colors.yellow}Do you want to configure advanced metadata? (y/n):${colors.reset}`
    );

    if (confirmAnswer.configureAdvancedMetadata.toLowerCase() === "y") {
      evvmMetadata.totalSupply = promptNumber(
        `${colors.yellow}Total Supply ${colors.darkGray}[${formatNumber(
          evvmMetadata.totalSupply
        )}]:${colors.reset}`,
        evvmMetadata.totalSupply ?? undefined
      );

      evvmMetadata.eraTokens = promptNumber(
        `${colors.yellow}Era Tokens ${colors.darkGray}[${formatNumber(
          evvmMetadata.eraTokens
        )}]:${colors.reset}`,
        evvmMetadata.eraTokens ?? undefined
      );

      evvmMetadata.reward = promptNumber(
        `${colors.yellow}Reward ${colors.darkGray}[${formatNumber(
          evvmMetadata.reward
        )}]:${colors.reset}`,
        evvmMetadata.reward ?? undefined
      );
    }

    console.log(
      `\n${colors.bright}=== Configuration Summary ===${colors.reset}\n`
    );

    console.log(`${colors.bright}Addresses:${colors.reset}`);
    for (const key of Object.keys(addresses) as (keyof InputAddresses)[]) {
      console.log(`  ${colors.blue}${key}:${colors.reset} ${addresses[key]}`);
    }

    console.log(`\n${colors.bright}EVVM Metadata:${colors.reset}`);
    for (const [metaKey, metaValue] of Object.entries(evvmMetadata)) {
      if (metaKey === "EvvmID") continue;

      let displayValue = metaValue;
      if (typeof metaValue === "number" && metaValue > 1e15) {
        displayValue = metaValue.toLocaleString("fullwide", {
          useGrouping: false,
        });
      }
      console.log(`  ${colors.blue}${metaKey}:${colors.reset} ${displayValue}`);
    }
    console.log();

    confirmAnswer.confirmInputs = promptYesNo(
      `${colors.yellow}Are all inputs correct? (y/n):${colors.reset}`
    );

    if (confirmAnswer.confirmInputs.toLowerCase() === "y") {
      confirmationDone = true;
    }
  }

  if (!(await writeInputsFile(addresses, evvmMetadata))) {
    showError(
      "Failed to write inputs file.",
      `Please try again. If the issue persists, create an issue on GitHub:\n${colors.blue}https://github.com/EVVM-org/Playgrounnd-Contracts/issues${colors.reset}`
    );
    return;
  }

  confirmAnswer.deploy = promptYesNo(
    `${colors.yellow}Are you sure you want to deploy to EVVM? (y/n):${colors.reset}`
  );

  if (confirmAnswer.deploy.toLowerCase() !== "y") {
    console.log(`${colors.red}Deployment cancelled${colors.reset}`);
    return;
  }

  const { rpcUrl, chainId } = await getRPCUrlAndChainId(process.env.RPC_URL);

  isDeployingOnLocalBlockchain = chainId === 31337 || chainId === 1337;

  if (isDeployingOnLocalBlockchain) {
    console.log(
      `\n${colors.orange}Local blockchain detected (Chain ID: ${chainId})${colors.reset}`
    );
    console.log(
      `${colors.darkGray}Skipping host chain verification step for local development.${colors.reset}\n`
    );
  } else {
    const isSupported = await checkIsChainIdSupported(chainId);

    if (isSupported === undefined) {
      showError(
        `Chain ID ${chainId} is not supported.`,
        `Please try again or if the issue persists, make an issue on GitHub.`
      );
      return;
    }

    if (isSupported) {
      showError(
        `Host Chain ID ${chainId} is not supported.`,
        `\n${colors.yellow}Possible solutions:${colors.reset}
  ${colors.bright}• Testnet chains:${colors.reset}
    Request support by creating an issue at:
    ${colors.blue}https://github.com/EVVM-org/evvm-registry-contracts${colors.reset}
    
  ${colors.bright}• Mainnet chains:${colors.reset}
    EVVM currently does not support mainnet deployments.
    
  ${colors.bright}• Local blockchains (Anvil/Hardhat):${colors.reset}
    Use an unregistered chain ID.
    ${colors.darkGray}Example: Chain ID 31337 is registered, use 1337 instead.${colors.reset}`
      );
      return;
    }
  }

  const verification = await promptSelect(
    "Select block explorer verification:",
    [
      "Etherscan v2",
      "Blockscout",
      "Custom",
      "Skip verification (not recommended)",
    ]
  );

  let verificationflag: string = "";

  switch (verification) {
    case "Etherscan v2":
      let etherscanAPI = process.env.ETHERSCAN_API
        ? process.env.ETHERSCAN_API
        : await promptSecret("Enter your Etherscan API key");

      verificationflag = `--verify --etherscan-api-key ${etherscanAPI}`;
      break;

    case "Blockscout":
      let blockscoutHomepage = process.env.BLOCKSCOUT_HOMEPAGE
        ? process.env.BLOCKSCOUT_HOMEPAGE
        : promptString("Enter your Blockscout homepage URL");
      verificationflag = ` --verifier blockscout --verifier-url ${blockscoutHomepage}/api/`;
      break;
    case "Custom":
      verificationflag = promptString("Enter your custom verification flags:");
      break;
    case "Skip verification (not recommended)":
      verificationflag = "";
      break;
  }

  const privateKey =
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

  console.log(
    `${colors.blue}Deploying at chain host id:${colors.reset} ${chainId}`
  );

  console.log(
    `${colors.evvmGreen}Starting deployment to EVVM...${colors.reset}`
  );
  try {
    await $`forge clean`.quiet();
    await $`forge script script/Deploy.s.sol:DeployScript --via-ir --optimize true --rpc-url ${rpcUrl} --private-key ${privateKey} ${verificationflag} --broadcast -vvvv`;
    console.log(
      `${colors.green}Deployment completed successfully!${colors.reset}`
    );
  } catch (error) {
    showError(
      "Deployment process encountered an error.",
      "Please check the error message above for details."
    );
    return;
  }

  const evvmAddress: `0x${string}` | null =
    await showDeployContractsAndFindEvvm(chainId);

  console.log();
  console.log(
    `${colors.green}Evvm deployed at address: ${evvmAddress}${colors.reset}`
  );
}
