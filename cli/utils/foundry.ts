import { $ } from "bun";
import type { InputAddresses, EvvmMetadata, CreatedContract } from "../types";
import { colors } from "../constants";
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

export async function getRPCUrlAndChainId(rpcUrl: string | undefined | null): Promise<{
  rpcUrl: string;
  chainId: number;
}> {
  if (!rpcUrl) rpcUrl = null;

  while (!rpcUrl) {
    console.log(
      `${colors.orange}RPC URL not found in .env file.${colors.reset}`
    );
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

  return { rpcUrl, chainId };
}

export async function getChainId(rpcUrl: string): Promise<number> {
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

export async function checkIsChainIdSupported(
  chainId: number
): Promise<boolean | undefined> {
  try {
    const result =
      await $`cast call 0x389dC8fb09211bbDA841D59f4a51160dA2377832 --rpc-url https://sepolia.drpc.org "isChainIdRegistered(uint256)(bool)" ${chainId}`.quiet();
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

export async function foundryIsInstalledAndSetup(): Promise<boolean> {
  try {
    await $`foundryup --version`.quiet();
  } catch (error) {
    showError(
      "Foundry is not installed.",
      "Please install Foundry to proceed with deployment."
    );
    return false;
  }

  let walletList = await $`cast wallet list`.quiet();
  if (!walletList.stdout.includes("defaultKey (Local)")) {
    showError(
      "Wallet 'defaultKey (Local)' is not available.",
      "Please create a wallet named 'defaultKey' using 'cast wallet new defaultKey'."
    );
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

  console.log(
    `${colors.bright}▣▣▣▣▣▣▣▣▣▣▣▣▣▣▣▣▣▣▣▣▣▣ Deployed Contracts ▣▣▣▣▣▣▣▣▣▣▣▣▣▣▣▣▣▣▣▣▣▣${colors.reset}`
  );
  createdContracts.forEach((contract: CreatedContract) => {
    console.log(
      `  ${colors.blue}${contract.contractName}:${colors.reset} ${contract.contractAddress}`
    );
  });

  return (
    createdContracts.find(
      (contract: CreatedContract) => contract.contractName === "Evvm"
    )?.contractAddress ?? null
  );
}
