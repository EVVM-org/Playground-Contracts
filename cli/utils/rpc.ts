
import { colors } from "../constants";

export async function getRPCUrlAndChainId(
  rpcUrl: string | undefined | null
): Promise<{
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