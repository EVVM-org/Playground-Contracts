/**
 * EVVM Deployment Command
 *
 * Comprehensive deployment wizard for EVVM ecosystem contracts.
 * Handles configuration, validation, deployment, verification, and registration.
 *
 * @module cli/commands/deploy
 */

import { $ } from "bun";
import type {
  ConfirmAnswer,
  BaseInputAddresses,
  EvvmMetadata,
  CrossChainInputs,
} from "../types";
import { ChainData, colors } from "../constants";
import {
  promptString,
  promptNumber,
  promptAddress,
  promptYesNo,
} from "../utils/prompts";
import { formatNumber, showError } from "../utils/validators";
import {
  writeBaseInputsFile,
  isChainIdRegistered,
  showDeployContractsAndFindEvvm,
  verifyFoundryInstalledAndAccountSetup,
  writeCrossChainInputsFile,
  showDeployTreasuryExternalChainStation,
  showDeployContractsAndFindEvvmWithTreasuryHostChainStation,
} from "../utils/foundry";
import { getRPCUrlAndChainId } from "../utils/rpc";
import { registerEvvm } from "./registerEvvm";
import { explorerVerification } from "../utils/explorerVerification";
import { checkCrossChainSupport } from "../utils/crossChain";

/**
 * Deploys a complete EVVM instance with interactive configuration for
 * cross-chain treasury support.
 *
 * Deployment process:
 * 1. Validates prerequisites (Foundry, wallet)
 * 2. Collects deployment configuration (addresses, metadata)
 * 3. Validates target chain support
 * 4. Configures block explorer verification
 * 5. Deploys all EVVM contracts
 * 6. Optionally registers EVVM in registry
 *
 * @param {string[]} args - Command arguments (unused)
 * @param {any} options - Command options including skipInputConfig, walletName
 * @returns {Promise<void>}
 */
export async function deployEvvm(args: string[], options: any) {
  const skipInputConfig = options.skipInputConfig || false;
  const walletName = options.walletName || "defaultKey";

  let confirmAnswer: ConfirmAnswer = {
    configureAdvancedMetadata: "",
    confirmInputs: "",
    deploy: "",
    register: "",
    useCustomEthRpc: "",
  };

  let confirmationBasicDone: boolean = false;
  let confirmationCrossChainDone: boolean = false;

  let verificationflagExternal: string | undefined = "";
  let verificationflagHost: string | undefined = "";

  let externalChainId: number = 0;
  let hostChainId: number = 0;
  let externalRpcUrl: string = "";
  let hostRpcUrl: string = "";

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

  let crossChainInputs: CrossChainInputs = {
    adminExternal: "0x0000000000000000000000000000000000000000",
    crosschainConfigHost: {
      hyperlane: {
        externalChainStationDomainId: 0,
        mailboxAddress: "0x0000000000000000000000000000000000000000",
      },
      layerZero: {
        externalChainStationEid: 0,
        endpointAddress: "0x0000000000000000000000000000000000000000",
      },
      axelar: {
        externalChainStationChainName: "",
        gatewayAddress: "0x0000000000000000000000000000000000000000",
        gasServiceAddress: "0x0000000000000000000000000000000000000000",
      },
    },
    crosschainConfigExternal: {
      hyperlane: {
        hostChainStationDomainId: 0,
        mailboxAddress: "0x0000000000000000000000000000000000000000",
      },
      layerZero: {
        hostChainStationEid: 0,
        endpointAddress: "0x0000000000000000000000000000000000000000",
      },
      axelar: {
        hostChainStationChainName: "",
        gatewayAddress: "0x0000000000000000000000000000000000000000",
        gasServiceAddress: "0x0000000000000000000000000000000000000000",
      },
    },
  };

  let addresses: BaseInputAddresses = {
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

  if (!(await verifyFoundryInstalledAndAccountSetup(walletName))) {
    return;
  }

  if (skipInputConfig) {
    console.log(
      `\n${colors.bright}Using Existing Configuration:${colors.reset}`
    );
    console.log(
      `  ${colors.green}✓${colors.reset} Base inputs ${colors.darkGray}→ ./input/BaseInputs.sol${colors.reset}`
    );
    console.log(
      `  ${colors.green}✓${colors.reset} Cross-chain inputs ${colors.darkGray}→ ./input/CrossChainInputs.sol${colors.reset}\n`
    );
  } else {
    console.log(
      `\n${colors.bright}EVVM basic metadata configuration${colors.reset}\n`
    );
    while (!confirmationBasicDone) {
      for (const key of Object.keys(
        addresses
      ) as (keyof BaseInputAddresses)[]) {
        addresses[key] = promptAddress(
          `${colors.yellow}Enter the ${key} address:${colors.reset}`
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

      console.log();
      confirmAnswer.configureAdvancedMetadata = promptYesNo(
        `${colors.yellow}Configure advanced metadata (totalSupply, eraTokens, reward)? (y/n):${colors.reset}`
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
        `\n${colors.bright}═══════════════════════════════════════${colors.reset}`
      );
      console.log(
        `${colors.bright}          Basic Configuration Summary${colors.reset}`
      );
      console.log(
        `${colors.bright}═══════════════════════════════════════${colors.reset}\n`
      );

      console.log(`${colors.bright}Addresses:${colors.reset}`);
      for (const key of Object.keys(
        addresses
      ) as (keyof BaseInputAddresses)[]) {
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
        console.log(
          `  ${colors.blue}${metaKey}:${colors.reset} ${displayValue}`
        );
      }
      console.log();

      confirmAnswer.confirmInputs = promptYesNo(
        `${colors.yellow}Confirm configuration? (y/n):${colors.reset}`
      );

      if (confirmAnswer.confirmInputs.toLowerCase() === "y") {
        confirmationBasicDone = true;
      }
    }

    if (!(await writeBaseInputsFile(addresses, evvmMetadata))) {
      showError(
        "Failed to write inputs file.",
        `Please try again. If the issue persists, create an issue on GitHub:\n${colors.blue}https://github.com/EVVM-org/Playgrounnd-Contracts/issues${colors.reset}`
      );
      return;
    }

    console.log(
      `\n${colors.green}✓${colors.reset} Input configuration saved to ${colors.darkGray}./input/BaseInputs.sol${colors.reset}`
    );
  }

  while (!confirmationCrossChainDone) {
    console.log(
      `\n${colors.bright}EVVM cross-chain metadata configuration${colors.reset}\n`
    );

    console.log(`Checking External Chain configuration:`);

    let { rpcUrl: externalRpcUrl, chainId: externalChainId } =
      await getRPCUrlAndChainId(process.env.EXTERNAL_RPC_URL);

    let externalChainData = await checkCrossChainSupport(externalChainId);

    if (!externalChainData) return;

    console.log(`\nChecking Host Chain configuration:`);

    let { rpcUrl: hostRpcUrl, chainId: hostChainId } =
      await getRPCUrlAndChainId(process.env.HOST_RPC_URL);

    let hostChainData = await checkCrossChainSupport(hostChainId);

    if (!hostChainData) return;

    let addressAdminExternal = promptAddress(
      `${colors.yellow}Enter the external admin address:${colors.reset}`
    );

    crossChainInputs = {
      adminExternal: addressAdminExternal,
      crosschainConfigHost: {
        hyperlane: {
          externalChainStationDomainId: externalChainData.Hyperlane.DomainId,
          mailboxAddress: externalChainData.Hyperlane
            .MailboxAddress as `0x${string}`,
        },
        layerZero: {
          externalChainStationEid: externalChainData.LayerZero.EId,
          endpointAddress: externalChainData.LayerZero
            .EndpointAddress as `0x${string}`,
        },
        axelar: {
          externalChainStationChainName: externalChainData.Axelar.ChainName,
          gatewayAddress: externalChainData.Axelar.Gateway as `0x${string}`,
          gasServiceAddress: externalChainData.Axelar
            .GasService as `0x${string}`,
        },
      },
      crosschainConfigExternal: {
        hyperlane: {
          hostChainStationDomainId: hostChainData.Hyperlane.DomainId,
          mailboxAddress: hostChainData.Hyperlane
            .MailboxAddress as `0x${string}`,
        },
        layerZero: {
          hostChainStationEid: hostChainData.LayerZero.EId,
          endpointAddress: hostChainData.LayerZero
            .EndpointAddress as `0x${string}`,
        },
        axelar: {
          hostChainStationChainName: hostChainData.Axelar.ChainName,
          gatewayAddress: hostChainData.Axelar.Gateway as `0x${string}`,
          gasServiceAddress: hostChainData.Axelar.GasService as `0x${string}`,
        },
      },
    };

    console.log(
      `\n${colors.bright}═══════════════════════════════════════${colors.reset}`
    );
    console.log(
      `${colors.bright}      Cross-Chain Configuration Summary${colors.reset}`
    );
    console.log(
      `${colors.bright}═══════════════════════════════════════${colors.reset}\n`
    );

    console.log(`${colors.bright}External Admin:${colors.reset}`);
    console.log(
      `  ${colors.blue}${crossChainInputs.adminExternal}${colors.reset}`
    );

    console.log(
      `\n${colors.bright}Host Chain Station (${hostChainData.Chain}):${colors.reset}`
    );
    console.log(
      `  ${colors.darkGray}→${colors.reset} Hyperlane External Domain ID: ${colors.blue}${crossChainInputs.crosschainConfigHost.hyperlane.externalChainStationDomainId}${colors.reset}`
    );
    console.log(
      `  ${colors.darkGray}→${colors.reset} Hyperlane Mailbox: ${colors.blue}${crossChainInputs.crosschainConfigHost.hyperlane.mailboxAddress}${colors.reset}`
    );
    console.log(
      `  ${colors.darkGray}→${colors.reset} LayerZero External EId: ${colors.blue}${crossChainInputs.crosschainConfigHost.layerZero.externalChainStationEid}${colors.reset}`
    );
    console.log(
      `  ${colors.darkGray}→${colors.reset} LayerZero Endpoint: ${colors.blue}${crossChainInputs.crosschainConfigHost.layerZero.endpointAddress}${colors.reset}`
    );
    console.log(
      `  ${colors.darkGray}→${colors.reset} Axelar External Chain: ${colors.blue}${crossChainInputs.crosschainConfigHost.axelar.externalChainStationChainName}${colors.reset}`
    );
    console.log(
      `  ${colors.darkGray}→${colors.reset} Axelar Gateway: ${colors.blue}${crossChainInputs.crosschainConfigHost.axelar.gatewayAddress}${colors.reset}`
    );
    console.log(
      `  ${colors.darkGray}→${colors.reset} Axelar Gas Service: ${colors.blue}${crossChainInputs.crosschainConfigHost.axelar.gasServiceAddress}${colors.reset}`
    );

    console.log(
      `\n${colors.bright}External Chain Station (${externalChainData.Chain}):${colors.reset}`
    );
    console.log(
      `  ${colors.darkGray}→${colors.reset} Hyperlane Host Domain ID: ${colors.blue}${crossChainInputs.crosschainConfigExternal.hyperlane.hostChainStationDomainId}${colors.reset}`
    );
    console.log(
      `  ${colors.darkGray}→${colors.reset} Hyperlane Mailbox: ${colors.blue}${crossChainInputs.crosschainConfigExternal.hyperlane.mailboxAddress}${colors.reset}`
    );
    console.log(
      `  ${colors.darkGray}→${colors.reset} LayerZero Host EId: ${colors.blue}${crossChainInputs.crosschainConfigExternal.layerZero.hostChainStationEid}${colors.reset}`
    );
    console.log(
      `  ${colors.darkGray}→${colors.reset} LayerZero Endpoint: ${colors.blue}${crossChainInputs.crosschainConfigExternal.layerZero.endpointAddress}${colors.reset}`
    );
    console.log(
      `  ${colors.darkGray}→${colors.reset} Axelar Host Chain: ${colors.blue}${crossChainInputs.crosschainConfigExternal.axelar.hostChainStationChainName}${colors.reset}`
    );
    console.log(
      `  ${colors.darkGray}→${colors.reset} Axelar Gateway: ${colors.blue}${crossChainInputs.crosschainConfigExternal.axelar.gatewayAddress}${colors.reset}`
    );
    console.log(
      `  ${colors.darkGray}→${colors.reset} Axelar Gas Service: ${colors.blue}${crossChainInputs.crosschainConfigExternal.axelar.gasServiceAddress}${colors.reset}`
    );
    console.log();

    confirmAnswer.confirmInputs = promptYesNo(
      `${colors.yellow}Confirm cross-chain configuration? (y/n):${colors.reset}`
    );

    if (confirmAnswer.confirmInputs.toLowerCase() !== "y") {
      console.log(`\n${colors.red}✗ Configuration cancelled${colors.reset}`);
      return;
    }
  }

  if (!(await writeCrossChainInputsFile(crossChainInputs))) {
    showError(
      "Failed to write cross-chain inputs file.",
      `Please try again. If the issue persists, create an issue on GitHub:\n${colors.blue}https://github.com/EVVM-org/Playgrounnd-Contracts/issues${colors.reset}`
    );
    return;
  }

  console.log(
    `${colors.green}✓${colors.reset} Cross-chain input configuration saved to ${colors.darkGray}./input/CrossChainInputs.sol${colors.reset}\n`
  );

  console.log(`\n${colors.bright}Ready to Deploy${colors.reset}\n`);
  confirmAnswer.deploy = promptYesNo(
    `${colors.yellow}Proceed with deployment? (y/n):${colors.reset}`
  );

  if (confirmAnswer.deploy.toLowerCase() !== "y") {
    console.log(`\n${colors.red}✗ Deployment cancelled${colors.reset}`);
    return;
  }

  console.log(
    `\n${colors.bright}Block Explorer Verification Setup for Host Chain${colors.reset}\n`
  );
  verificationflagHost = await explorerVerification();
  if (verificationflagHost === undefined) {
    showError(
      `Explorer verification setup failed.`,
      `Please try again or if the issue persists, make an issue on GitHub.`
    );
    return;
  }

  console.log(
    `\n${colors.bright}Block Explorer Verification Setup for External Chain${colors.reset}\n`
  );
  verificationflagExternal = await explorerVerification();
  if (verificationflagExternal === undefined) {
    showError(
      `Explorer verification setup failed.`,
      `Please try again or if the issue persists, make an issue on GitHub.`
    );
    return;
  }

  console.log(
    `\n${colors.bright}═══════════════════════════════════════${colors.reset}`
  );
  console.log(`${colors.bright}             Deployment${colors.reset}`);
  console.log(
    `${colors.bright}═══════════════════════════════════════${colors.reset}\n`
  );

  const chainDataExternal = ChainData[externalChainId];

  if (chainDataExternal)
    console.log(
      `${colors.blue} Deploying on ${chainDataExternal.Chain}  (${colors.darkGray}${externalChainId})${colors.reset}`
    );
  else
    console.log(
      `${colors.blue} Deploying on Chain ID:${colors.reset} ${externalChainId}`
    );

  try {
    await $`forge clean`.quiet();

    // Split verification flags into array to avoid treating them as a single argument
    const verificationExternalArgs = verificationflagExternal
      ? verificationflagExternal.split(" ")
      : [];
    const commandExternal = [
      "forge",
      "script",
      "script/DeployCrossChainExternal.s.sol:DeployCrossChainExternalScript",
      "--via-ir",
      "--optimize",
      "true",
      "--rpc-url",
      externalRpcUrl,
      "--account",
      "defaultKey",
      ...verificationExternalArgs,
      "--broadcast",
      "-vvvv",
    ];
    await $`${commandExternal}`;
    console.log(
      `\n${colors.green}✓ Deployment on external chain completed successfully!${colors.reset}`
    );
  } catch (error) {
    showError(
      "Deployment process encountered an error.",
      "Please check the error message above for details."
    );
    return;
  }
  const treasuryExternalStationAddress =
    await showDeployTreasuryExternalChainStation(externalChainId);

  const chainDataHost = ChainData[hostChainId];
  if (chainDataHost)
    console.log(
      `\n${colors.blue} Deploying on ${chainDataHost.Chain}  (${colors.darkGray}${hostChainId})${colors.reset}`
    );
  else
    console.log(
      `\n${colors.blue} Deploying on Chain ID:${colors.reset} ${hostChainId}`
    );

  try {
    await $`forge clean`.quiet();

    // Split verification flags into array to avoid treating them as a single argument
    const verificationHostArgs = verificationflagHost
      ? verificationflagHost.split(" ")
      : [];
    const commandHost = [
      "forge",
      "script",
      "script/DeployCrossChainHost.s.sol:DeployCrossChainHostScript",
      "--via-ir",
      "--optimize",
      "true",
      "--rpc-url",
      hostRpcUrl,
      "--account",
      "defaultKey",
      ...verificationHostArgs,
      "--broadcast",
      "-vvvv",
    ];
    await $`${commandHost}`;
    console.log(
      `\n${colors.green}✓ Deployment on host chain completed successfully!${colors.reset}`
    );
  } catch (error) {
    showError(
      "Deployment process encountered an error.",
      "Please check the error message above for details."
    );
    return;
  }

  const { evvmAddress, treasuryHostChainStationAddress } =
    await showDeployContractsAndFindEvvmWithTreasuryHostChainStation(
      hostChainId
    );
}
