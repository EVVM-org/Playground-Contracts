import { $ } from "bun";
import type { InputAddresses, EvvmMetadata, CreatedContract } from "../types";
import {
  colors,
  EthSepoliaPublicRpc,
  RegisteryEvvmAddress,
} from "../constants";
import { formatNumber, showError } from "./validators";

export async function writeInputsFile(
  addresses: InputAddresses,
  evvmMetadata: EvvmMetadata
): Promise<boolean> {
  const inputDir = "./input";
  const inputFile = `${inputDir}/Inputs.sol`;

  try {
    await Bun.file(inputFile).text();
  } catch {
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

export async function isChainIdRegistered(
  chainId: number
): Promise<boolean | undefined> {
  try {
    const result =
      await $`cast call ${RegisteryEvvmAddress} --rpc-url ${EthSepoliaPublicRpc} "isChainIdRegistered(uint256)(bool)" ${chainId}`.quiet();
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

export async function foundryIsInstalled(): Promise<boolean> {
  try {
    await $`foundryup --version`.quiet();
  } catch (error) {
    return false;
  }
  return true;
}

export async function walletIsSetup(walletName: string = "defaultKey"): Promise<boolean> {
  let walletList = await $`cast wallet list`.quiet();
  if (!walletList.stdout.includes(`${walletName} (Local)`)) {
    return false;
  }
  return true;
}

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

  console.log(`\n${colors.bright}═══════════════════════════════════════${colors.reset}`);
  console.log(`${colors.bright}          Deployed Contracts${colors.reset}`);
  console.log(`${colors.bright}═══════════════════════════════════════${colors.reset}\n`);
  
  createdContracts.forEach((contract: CreatedContract) => {
    console.log(
      `  ${colors.green}✓${colors.reset} ${colors.blue}${contract.contractName}${colors.reset}\n    ${colors.darkGray}→${colors.reset} ${contract.contractAddress}`
    );
  });
  console.log();

  return (
    createdContracts.find(
      (contract: CreatedContract) => contract.contractName === "Evvm"
    )?.contractAddress ?? null
  );
}
