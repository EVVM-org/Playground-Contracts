export function verifyAddress(address: string | null): boolean {
  if (!address) return false;
  return /^0x[a-fA-F0-9]{40}$/.test(address);
}

export function formatNumber(num: number | null): string {
  if (num === null) return "0";
  if (num > 1e15) {
    return num.toLocaleString("fullwide", { useGrouping: false });
  }
  return num.toString();
}

export function showError(message: string, extraMessage: string = "") {
  const colors = {
    red: "\x1b[31m",
    reset: "\x1b[0m",
  };
  console.error(
    `${colors.red}🯀  Error: ${message}${colors.reset}\n${extraMessage}\n${colors.red}Deployment aborted.${colors.reset}`
  );
}
