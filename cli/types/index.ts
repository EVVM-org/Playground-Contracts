export type ConfirmAnswer = {
  configureAdvancedMetadata: string;
  confirmInputs: string;
  deploy: string;
  register: string;
};

export type InputAddresses = {
  admin: `0x${string}` | null;
  goldenFisher: `0x${string}` | null;
  activator: `0x${string}` | null;
};

export interface CreatedContract {
  contractName: string;
  contractAddress: `0x${string}`;
}

export type EvvmMetadata = {
  EvvmName: string | null;
  EvvmID: number | null;
  principalTokenName: string | null;
  principalTokenSymbol: string | null;
  principalTokenAddress: `0x${string}` | null;
  totalSupply: number | null;
  eraTokens: number | null;
  reward: number | null;
};