import { colors } from "../constants";

export function showHelp() {
  console.log(`
${colors.bright}EVVM CLI Tool${colors.reset} - A command line interface tool

${colors.bright}USAGE:${colors.reset}
  evvm <command> [options]

${colors.bright}COMMANDS:${colors.reset}
  ${colors.green}help${colors.reset}              Show this help
  ${colors.green}version${colors.reset}           Show version
  ${colors.green}deploy${colors.reset}            Deploy and verify an EVVM
  ${colors.green}fulltest${colors.reset}          Run full test suite

${colors.bright}OPTIONS:${colors.reset}
  -h, --help          Show help
  -v, --version       Show version
  `);
}
