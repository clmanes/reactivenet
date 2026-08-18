// Pyodide's core, copied into public/ so it is served from this origin.
//
// The alternative is the CDN everybody uses, and it is the wrong trade for this app:
// a page that otherwise talks to nobody would start fetching a 14 MB runtime from a
// third party, and the CSP that makes `script-src 'self'` meaningful would have to be
// opened for it. Copied here, Python runs offline like everything else.
//
// Only the core: the interpreter, its stdlib and the wasm. Packages (numpy, pandas,
// matplotlib…) are megabytes each and are fetched on demand by whoever asks for them
// — see the note in CLAUDE.md about what that costs.

import { cp, mkdir, rm } from "node:fs/promises";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";

const require = createRequire(import.meta.url);
const source = dirname(require.resolve("pyodide/package.json"));
const target = join(process.cwd(), "public", "pyodide");

const files = [
  "pyodide.mjs",
  "pyodide.asm.mjs",
  "pyodide.asm.wasm",
  "python_stdlib.zip",
  "pyodide-lock.json",
];

await rm(target, { recursive: true, force: true });
await mkdir(target, { recursive: true });
for (const file of files) {
  await cp(join(source, file), join(target, file));
}
console.log("pyodide core copied into public/pyodide (" + files.length + " files)");
