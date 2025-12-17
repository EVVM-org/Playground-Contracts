/**
 * Full Test Command Module
 *
 * Executes the complete EVVM test suite using Foundry's forge test.
 *
 * @module cli/commands/fulltest
 */

import { $ } from "bun";
import { colors } from "../constants";
import { contractInterfacesGenerator } from "../utils/foundry";

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
export async function developer(_args: string[], options: any) {
  const makeInterface = options.makeInterface || false;

  if (makeInterface) await contractInterfacesGenerator();
}
