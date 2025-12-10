import { colors } from "../constants";

export function promptString(message: string, defaultValue?: string): string {
  const input = prompt(message);

  if (!input && defaultValue !== undefined) {
    return defaultValue;
  }

  if (!input) {
    console.log(
      `${colors.red}Input cannot be empty. Please enter a value.${colors.reset}`
    );
    return promptString(message, defaultValue);
  }

  return input;
}

export function promptNumber(message: string, defaultValue?: number): number {
  const input = prompt(message);

  if (!input && defaultValue !== undefined) {
    return defaultValue;
  }

  const num = Number(input);
  if (isNaN(num) || num < 0) {
    console.log(
      `${colors.red}Invalid number. Please enter a valid positive number.${colors.reset}`
    );
    return promptNumber(message, defaultValue);
  }

  return num;
}

export function promptAddress(
  message: string,
  defaultValue?: `0x${string}`
): `0x${string}` {
  const input = prompt(message);

  if (!input && defaultValue !== undefined) {
    return defaultValue;
  }

  if (!verifyAddress(input)) {
    console.log(
      `${colors.red}Invalid address format. Please enter a valid Ethereum address.${colors.reset}`
    );
    return promptAddress(message, defaultValue);
  }

  return input as `0x${string}`;
}

export function promptYesNo(message: string, defaultValue?: string): string {
  const input = prompt(message);

  if (!input && defaultValue !== undefined) {
    return defaultValue;
  }

  if (input?.toLowerCase() !== "y" && input?.toLowerCase() !== "n") {
    console.log(`${colors.red}Please enter 'y' or 'n'${colors.reset}`);
    return promptYesNo(message, defaultValue);
  }

  return input.toLowerCase();
}

export function promptSecret(message: string): Promise<string> {
  process.stdout.write(`${colors.yellow}${message}: ${colors.reset}`);

  let secret = "";

  if (process.stdin.isTTY) {
    process.stdin.setRawMode(true);
  }
  process.stdin.resume();
  process.stdin.setEncoding("utf8");

  return new Promise<string>((resolve) => {
    const onKeyPress = (key: string) => {
      if (key === "\u0003") {
        if (process.stdin.isTTY) {
          process.stdin.setRawMode(false);
        }
        process.stdin.pause();
        process.exit();
      }

      if (key === "\r" || key === "\n") {
        process.stdin.removeListener("data", onKeyPress);
        if (process.stdin.isTTY) {
          process.stdin.setRawMode(false);
        }
        process.stdin.pause();
        console.log();
        resolve(secret);
      }

      if (key === "\x7f" || key === "\b") {
        if (secret.length > 0) {
          secret = secret.slice(0, -1);
          process.stdout.write("\b \b");
        }
      }
      else if (key.length === 1 && key !== "\r" && key !== "\n") {
        secret += key;
        process.stdout.write("*");
      }
    };

    process.stdin.on("data", onKeyPress);
  });
}

export async function promptSelect(
  message: string,
  options: string[]
): Promise<string> {
  console.log(`\n${colors.yellow}${message}${colors.reset}`);

  let selectedIndex = 0;
  let isFirstRender = true;

  const renderOptions = () => {
    if (!isFirstRender) {
      process.stdout.write(`\x1b[${options.length}A`);
    }
    isFirstRender = false;

    options.forEach((option, index) => {
      process.stdout.write("\x1b[2K");
      if (index === selectedIndex) {
        console.log(`${colors.evvmGreen}🭬 ${option}${colors.reset}`);
      } else {
        console.log(`  ${option}`);
      }
    });
  };

  renderOptions();

  if (process.stdin.isTTY) {
    process.stdin.setRawMode(true);
  }
  process.stdin.resume();
  process.stdin.setEncoding("utf8");

  return new Promise<string>((resolve) => {
    const onKeyPress = (key: string) => {
      if (key === "\u0003") {
        if (process.stdin.isTTY) {
          process.stdin.setRawMode(false);
        }
        process.stdin.pause();
        process.exit();
      }

      if (key === "\x1b[A") {
        selectedIndex =
          selectedIndex > 0 ? selectedIndex - 1 : options.length - 1;
        renderOptions();
      }

      if (key === "\x1b[B") {
        selectedIndex =
          selectedIndex < options.length - 1 ? selectedIndex + 1 : 0;
        renderOptions();
      }

      if (key === "\r" || key === "\n") {
        process.stdin.removeListener("data", onKeyPress);
        if (process.stdin.isTTY) {
          process.stdin.setRawMode(false);
        }
        process.stdin.pause();

        const selected = options[selectedIndex];
        if (selected) {
          console.log();
          resolve(selected);
        }
      }
    };

    process.stdin.on("data", onKeyPress);
  });
}

function verifyAddress(address: string | null): boolean {
  if (!address) return false;
  return /^0x[a-fA-F0-9]{40}$/.test(address);
}
