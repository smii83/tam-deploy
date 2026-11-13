#!/usr/bin/env node
/**
 * Cross-platform Firebase Local Emulator runner for TAM automated tests.
 * Ensures emulator-only local env/secret files exist so Firebase CLI never
 * stalls on interactive prompts in CI or fresh developer environments.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..");
const functionsDir = path.join(root, "functions");

function ensureLocalFile(filename, content) {
  const target = path.join(functionsDir, filename);
  if (!fs.existsSync(target)) {
    fs.writeFileSync(target, content, "utf8");
  }
}

ensureLocalFile(".env.local", "APPLE_SHARED_SECRET=\n");
ensureLocalFile(".secret.local", "GEMINI_API_KEY=emulator-dummy-gemini-key\n");

const mode = process.argv[2] || "integration";
const targets = {
  integration: {
    emulators: "auth,firestore,functions,storage",
    cmd: "node node_modules/vitest/vitest.mjs run --config vitest.integration.config.ts",
  },
  e2e: {
    emulators: "auth,firestore,functions,hosting,storage",
    cmd: "node node_modules/@playwright/test/cli.js test",
  },
  perf: {
    emulators: "auth,firestore,functions,hosting,storage",
    cmd: "node tests/perf/run_k6.mjs",
  },
};

const spec = targets[mode];
if (!spec) {
  console.error(`Unknown emulator test mode: ${mode}`);
  process.exit(1);
}

const isWin = process.platform === "win32";
const bin = isWin ? "cmd.exe" : "firebase";
const firebaseArgs = [
  "--non-interactive",
  "emulators:exec",
  "--project",
  "tam-app-fd30f",
  "--only",
  spec.emulators,
  spec.cmd,
];

const res = spawnSync(
  bin,
  isWin ? ["/c", "firebase.cmd", ...firebaseArgs] : firebaseArgs,
  {
    cwd: root,
    stdio: "inherit",
  }
);

process.exit(res.status ?? 1);
