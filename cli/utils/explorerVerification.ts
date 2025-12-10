import { promptSecret, promptSelect, promptString } from "./prompts";

export async function explorerVerification(): Promise<string | undefined> {
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
  return verificationflag;
}
