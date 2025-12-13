/**
 * Full Test Command Module
 * 
 * Executes the complete EVVM test suite using Foundry's forge test.
 * 
 * @module cli/commands/fulltest
 */

import { $ } from "bun";
import { colors } from "../constants";

/**
 * Runs the full EVVM test suite
 * 
 * Executes all unit tests for EVVM contracts with detailed output including:
 * - Test results summary
 * - Detailed test execution logs
 * - Gas usage reports
 * - Progress indicators
 * 
 * @returns {Promise<void>} Resolves when tests complete
 */
export async function fullTest() {
  console.log(
    `${colors.evvmGreen}Starting full test suite on EVVM...${colors.reset}`
  );
  await $`forge test --match-contract unitTestCorrect_EVVM --summary --detailed --gas-report -vvv --show-progress`;
}
