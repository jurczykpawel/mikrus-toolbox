import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

let cachedRoot: string | null = null;

export function resolveRepoRoot(): string {
  if (cachedRoot) return cachedRoot;

  // 1. Check MIKRUS_TOOLBOX_PATH env var
  const envPath = process.env.MIKRUS_TOOLBOX_PATH;
  if (envPath && existsSync(join(envPath, "local", "deploy.sh"))) {
    cachedRoot = resolve(envPath);
    return cachedRoot;
  }

  // 2. Walk up from __dirname (mcp-server/dist/lib/) looking for local/deploy.sh
  let dir = __dirname;
  for (let i = 0; i < 10; i++) {
    if (existsSync(join(dir, "local", "deploy.sh"))) {
      cachedRoot = dir;
      return cachedRoot;
    }
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }

  throw new Error(
    "Cannot find mikrus-toolbox repo root. Set MIKRUS_TOOLBOX_PATH env var."
  );
}

export function getDeployShPath(): string {
  return join(resolveRepoRoot(), "local", "deploy.sh");
}

export function getAppsDir(): string {
  return join(resolveRepoRoot(), "apps");
}
