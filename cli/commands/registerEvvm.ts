import { colors } from "../constants";
import { promptAddress, promptNumber, promptString } from "../utils/prompts";
import { callRegisterEvvm, callSetEvvmID, isChainIdRegistered } from "../utils/foundry";
import { showError } from "../utils/validators";

export async function registerEvvm(_args: string[], options: any) {
  console.log(
    `${colors.evvmGreen}Registering a new EVVM instance...${colors.reset}`
  );

  // Obtener valores de los flags opcionales
  let evvmAddress: `0x${string}` | undefined = options.evvmAddress;
  let hostChainId: number | undefined = options.hostChainId ? Number(options.hostChainId) : undefined;
  let hostRpcUrl: string | undefined = options.hostRpcUrl;

  // Validar o solicitar valores faltantes
  if (!evvmAddress) {
    evvmAddress = promptAddress(
      `${colors.yellow}Enter the EVVM Address:${colors.reset}`
    );
  }

  if (!hostChainId) {
    hostChainId = promptNumber(
      `${colors.yellow}Enter the Host Chain ID:${colors.reset}`
    );
  }

  if (!hostRpcUrl) {
    hostRpcUrl = promptString(
      `${colors.yellow}Enter the Host RPC URL:${colors.reset}`
    );
  }

  const isDeployingOnLocalBlockchain: boolean =
    hostChainId === 31337 || hostChainId === 1337;

  if (isDeployingOnLocalBlockchain) {
    console.log(`\n${colors.orange}Local Blockchain Detected${colors.reset}`);
    console.log(`${colors.darkGray}Skipping registry contract registration for local development${colors.reset}`);
    return;
  }

  const isSupported = await isChainIdRegistered(hostChainId);
  if (isSupported === undefined) {
    showError(
      `EVVM registration failed.`,
      `Please try again or if the issue persists, make an issue on GitHub.`
    );
    return;
  }
  if (!isSupported) {
    showError(
      `Host Chain ID ${hostChainId} is not supported.`,
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


  console.log(`${colors.blue}Setting EVVM ID directly on contract...${colors.reset}\n`);

    const evvmID: number | undefined = await callRegisterEvvm(Number(hostChainId), evvmAddress, "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");
    if (!evvmID) {
      showError(
        `EVVM registration failed.`,
        `Please try again or if the issue persists, make an issue on GitHub.`
      );
      return;
    }
    console.log(`${colors.green}EVVM ID generated: ${colors.bright}${evvmID}${colors.reset}`);
    console.log(`${colors.blue}Setting EVVM ID on contract...${colors.reset}\n`);
    
    const isSet = await callSetEvvmID(evvmAddress, evvmID, hostRpcUrl, "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");

    if (!isSet) {
      showError(
        `EVVM ID setting failed.`,
        `\n${colors.yellow}You can try manually with:${colors.reset}\n${colors.blue}cast send ${evvmAddress} \\\n  --rpc-url ${hostRpcUrl} \\\n  "setEvvmID(uint256)" ${evvmID} \\\n  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80${colors.reset}`
      );
      return;
    }

    console.log(`\n${colors.bright}═══════════════════════════════════════${colors.reset}`);
    console.log(`${colors.bright}        Registration Complete${colors.reset}`);
    console.log(`${colors.bright}═══════════════════════════════════════${colors.reset}\n`);
    console.log(`${colors.green}EVVM ID: ${colors.bright}${evvmID}${colors.reset}`);
    console.log(`${colors.green}Contract: ${colors.bright}${evvmAddress}${colors.reset}`);
    console.log(`${colors.darkGray}\nYour EVVM instance is now ready to use!${colors.reset}\n`);
}
