import { $ } from "bun";
import { colors } from "../constants";

export async function fullTest() {
  console.log(
    `${colors.evvmGreen}Starting full test suite on EVVM...${colors.reset}`
  );
  await $`forge test --match-contract unitTestCorrect_EVVM --summary --detailed --gas-report -vvv --show-progress`;
}
