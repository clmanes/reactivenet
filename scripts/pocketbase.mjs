// PocketBase, fetched and run.
//
// The server side of short share links is one Go binary with SQLite inside. It is
// not an npm package, so this script downloads the pinned release for this platform
// into .pocketbase/ (gitignored — a 15 MB binary does not belong in a repo) and runs
// it with the schema and hooks that *are* in the repo, under pb/.
//
// The version is pinned, not "latest": the hooks are written against one JSVM API,
// and a server that silently moved under them would be a bug nobody can bisect.
//
//   bun run pb            download if missing, then serve on 127.0.0.1:8090
//   bun run pb -- update  re-download the pinned version
//
// The app reaches it as /pb/* on its own origin — the Vite proxy in dev, a host
// rewrite in production (see public/_redirects) — so the CSP stays exactly as it is.

import { existsSync, mkdirSync, rmSync } from "node:fs";
import { spawnSync, spawn } from "node:child_process";
import { join } from "node:path";

const VERSION = "0.39.10";
const HOME = join(process.cwd(), ".pocketbase");
const BINARY = join(HOME, "pocketbase");

const platform = () => {
  const os = process.platform === "darwin" ? "darwin" : "linux";
  const arch = process.arch === "arm64" ? "arm64" : "amd64";
  return `${os}_${arch}`;
};

const download = async () => {
  const name = `pocketbase_${VERSION}_${platform()}.zip`;
  const url = `https://github.com/pocketbase/pocketbase/releases/download/v${VERSION}/${name}`;
  console.log(`fetching ${url}`);
  const response = await fetch(url);
  if (!response.ok) throw new Error(`download failed: ${response.status}`);
  mkdirSync(HOME, { recursive: true });
  const archive = join(HOME, name);
  await Bun.write(archive, await response.arrayBuffer());
  const unzip = spawnSync("unzip", ["-o", archive, "pocketbase", "-d", HOME]);
  if (unzip.status !== 0) throw new Error("unzip failed — is `unzip` installed?");
  rmSync(archive);
  console.log(`pocketbase v${VERSION} ready in .pocketbase/`);
};

if (process.argv[2] === "update" || !existsSync(BINARY)) {
  rmSync(BINARY, { force: true });
  await download();
}

if (process.argv[2] === "update") process.exit(0);

// Data stays in .pocketbase/pb_data (gitignored); schema and behaviour come from
// pb/, which is the part reviewed like any other code.
const child = spawn(
  BINARY,
  [
    "serve",
    "--http=127.0.0.1:8090",
    `--dir=${join(HOME, "pb_data")}`,
    `--hooksDir=${join(process.cwd(), "pb", "pb_hooks")}`,
    `--migrationsDir=${join(process.cwd(), "pb", "pb_migrations")}`,
  ],
  { stdio: "inherit" },
);
child.on("exit", (code) => process.exit(code ?? 0));
