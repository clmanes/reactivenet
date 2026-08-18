# Contributing to ReactiveNET

Thank you for considering a contribution. This file is the short version;
[CLAUDE.md](CLAUDE.md) is the long one — it documents the architecture, the
invariants and the traps, and it is worth reading before touching anything
non-trivial.

## Setup

Everything runs with [Bun](https://bun.sh); Node is not required.

```sh
bun install
bun run pyodide:assets    # vendors Pyodide into public/ (gitignored)
bun run res:dev           # terminal 1 — ReScript watch
bun run dev               # terminal 2 — Vite dev server
```

## Tests

```sh
bun run test              # compiles ReScript, runs the core tests + the guide check
bun test ./src/core/SafeUrl_test.res.mjs    # one file (the ./ prefix matters)
bun run test -t "rejects"                   # by test name
```

The core (`src/core/`) is pure — no DOM, no stubs — and every module there has
tests. If your change is expressible as a core function, put it there and test
it.

## The rules that are enforced

- **A directive is not finished without its documentation.** `doc/` (what the
  AI assistant reads) and the site guide under `site/content/{it,en}/guida/`,
  in **both** languages, in the same piece of work. `scripts/test-guide.mjs`
  makes a missing mention a red build.
- **Every `.res` file has a `.resi` interface** (test modules excepted).
- **No `localStorage`/`sessionStorage`** — all persistence goes through
  IndexedDB (`src/shell/Idb.res`).
- **The CSP has three copies** — `vite.config.js` (source of truth),
  `public/_headers`, `Caddyfile` — and `SecurityPolicy_test` keeps them in
  step. Change all three together.
- **The legal documents follow the code**: a change that touches data,
  third-party hosts or retention must update `legal/it` and `legal/en` in the
  same piece of work.
- **Compiled `.res.mjs` files are committed** on purpose — review the emitted
  JS in your diff.
- Missing translations are build errors: `Translations.key` is a variant and
  all seven languages must be written.

## Security checks

`bun run dev` installs **no CSP**. Anything touching rendering, sanitisation,
Trusted Types or the service worker must be verified under
`bun run res:build && bun run build && bun run preview`, which serves the real
policy.

## Submitting

- Open an issue first for anything larger than a fix, so the approach can be
  agreed before the work.
- Keep PRs focused; include the documentation and legal updates the rules
  above require.
- By submitting a contribution you agree that it is licensed under the
  repository's Apache License 2.0 (see LICENSE, § 5 of the licence).

## Reporting a vulnerability

Please do not open a public issue: see [SECURITY.md](SECURITY.md).
