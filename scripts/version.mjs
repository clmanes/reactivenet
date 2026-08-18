// The version, advanced by the build rather than by remembering to.
//
// Semantic versioning says what each part means, and only one of the three can be
// decided by a machine. MAJOR and MINOR are claims about *what changed* — this breaks
// something, this adds something — and no script knows that; they stay a deliberate
// act (`bun run release minor`). PATCH is the part that only says "this is not the
// build you had before", which is exactly what a fingerprint of the sources can
// answer, so the build answers it.
//
// The fingerprint is over what actually ships: the source, the entry point, the build
// configuration and the headers. A build that changes none of them keeps its version
// — rebuilding the same tree twice must not produce two versions, or the number stops
// meaning anything.

import { createHash } from "node:crypto";
import { readFileSync, writeFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, relative } from "node:path";

const root = process.cwd();
const packagePath = join(root, "package.json");
const stampPath = join(root, ".version-stamp.json");

// Compiled output is not an input: `Foo.res.mjs` changes exactly when `Foo.res` does,
// and counting both would be counting once too often.
const IGNORED = new Set(["node_modules", "lib", "dist", ".git", "generated"]);
const isCompiled = (name) => name.endsWith(".res.mjs") || name.endsWith(".res.mjs.map");

const walk = (directory, found = []) => {
  for (const entry of readdirSync(directory).sort()) {
    if (IGNORED.has(entry)) continue;
    const full = join(directory, entry);
    if (statSync(full).isDirectory()) walk(full, found);
    else if (!isCompiled(entry)) found.push(full);
  }
  return found;
};

const fingerprint = () => {
  const hash = createHash("sha256");
  const files = [
    ...walk(join(root, "src")),
    join(root, "index.html"),
    join(root, "vite.config.js"),
    join(root, "public", "_headers"),
  ].filter((file) => existsSync(file));
  for (const file of files) {
    hash.update(relative(root, file));
    hash.update(readFileSync(file));
  }
  return hash.digest("hex").slice(0, 16);
};

const bump = (version, level) => {
  const [major, minor, patch] = version.split(".").map((part) => Number(part) || 0);
  if (level === "major") return `${major + 1}.0.0`;
  if (level === "minor") return `${major}.${minor + 1}.0`;
  return `${major}.${minor}.${patch + 1}`;
};

const level = process.argv[2] || "auto";
const pkg = JSON.parse(readFileSync(packagePath, "utf8"));
const stamp = existsSync(stampPath) ? JSON.parse(readFileSync(stampPath, "utf8")) : {};
const current = fingerprint();

if (level === "auto" && stamp.fingerprint === current) {
  console.log(`version ${pkg.version} (sources unchanged)`);
  process.exit(0);
}

const next = bump(pkg.version, level === "auto" ? "patch" : level);
pkg.version = next;
writeFileSync(packagePath, JSON.stringify(pkg, null, 2) + "\n");
writeFileSync(
  stampPath,
  JSON.stringify({ version: next, fingerprint: current }, null, 2) + "\n",
);
console.log(`version ${next} (${level === "auto" ? "patch, sources changed" : level})`);
