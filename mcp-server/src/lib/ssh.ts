import { execFile } from "node:child_process";
import {
  existsSync,
  readFileSync,
  appendFileSync,
  mkdirSync,
} from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

interface ExecResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

export function sshExec(
  alias: string,
  command: string,
  timeoutMs = 30_000
): Promise<ExecResult> {
  return new Promise((resolve) => {
    execFile(
      "ssh",
      ["-o", "ConnectTimeout=10", alias, command],
      { timeout: timeoutMs },
      (error, stdout, stderr) => {
        resolve({
          stdout: stdout?.toString() ?? "",
          stderr: stderr?.toString() ?? "",
          exitCode: error ? (error as any).code ?? 1 : 0,
        });
      }
    );
  });
}

interface ConnectionResult {
  ok: boolean;
  hostname?: string;
  user?: string;
  error?: string;
}

export async function testConnection(alias: string): Promise<ConnectionResult> {
  // First resolve SSH config locally (no network)
  const sshConfig = await getSSHConfig(alias);

  // Then test actual connectivity
  const result = await sshExec(alias, "echo OK", 15_000);
  if (result.exitCode !== 0 || !result.stdout.includes("OK")) {
    return {
      ok: false,
      ...sshConfig,
      error: result.stderr.trim() || "Connection failed",
    };
  }
  return { ok: true, ...sshConfig };
}

export function getSSHConfig(
  alias: string
): Promise<{ hostname?: string; user?: string }> {
  return new Promise((resolve) => {
    execFile(
      "ssh",
      ["-G", alias],
      { timeout: 5_000 },
      (error, stdout) => {
        if (error) {
          resolve({});
          return;
        }
        const lines = stdout.toString().split("\n");
        let hostname: string | undefined;
        let user: string | undefined;
        for (const line of lines) {
          const [key, ...rest] = line.split(" ");
          const val = rest.join(" ");
          if (key === "hostname") hostname = val;
          if (key === "user") user = val;
        }
        resolve({ hostname, user });
      }
    );
  });
}

// --- SSH Setup helpers ---

const SSH_DIR = join(homedir(), ".ssh");
const SSH_KEY_PATH = join(SSH_DIR, "id_ed25519");
const SSH_CONFIG_PATH = join(SSH_DIR, "config");

export function sshKeyExists(): boolean {
  return existsSync(SSH_KEY_PATH);
}

export function generateSSHKey(): Promise<{ ok: boolean; error?: string }> {
  return new Promise((resolve) => {
    mkdirSync(SSH_DIR, { recursive: true, mode: 0o700 });
    execFile(
      "ssh-keygen",
      ["-t", "ed25519", "-f", SSH_KEY_PATH, "-N", ""],
      { timeout: 10_000 },
      (error) => {
        if (error) {
          resolve({ ok: false, error: error.message });
        } else {
          resolve({ ok: true });
        }
      }
    );
  });
}

export function getPublicKey(): string | null {
  const pubPath = SSH_KEY_PATH + ".pub";
  if (!existsSync(pubPath)) return null;
  return readFileSync(pubPath, "utf-8").trim();
}

export function aliasExists(alias: string): boolean {
  if (!existsSync(SSH_CONFIG_PATH)) return false;
  const content = readFileSync(SSH_CONFIG_PATH, "utf-8");
  const regex = new RegExp(`^Host\\s+${alias}\\s*$`, "m");
  return regex.test(content);
}

export function writeSSHConfig(opts: {
  alias: string;
  host: string;
  port: number;
  user: string;
}): void {
  mkdirSync(SSH_DIR, { recursive: true, mode: 0o700 });
  const entry = [
    "",
    `Host ${opts.alias}`,
    `    HostName ${opts.host}`,
    `    Port ${opts.port}`,
    `    User ${opts.user}`,
    `    IdentityFile ${SSH_KEY_PATH}`,
    `    ServerAliveInterval 60`,
    "",
  ].join("\n");
  appendFileSync(SSH_CONFIG_PATH, entry);
}

export function getSSHCopyIdCommand(opts: {
  host: string;
  port: number;
  user: string;
}): string {
  return `ssh-copy-id -p ${opts.port} ${opts.user}@${opts.host}`;
}
