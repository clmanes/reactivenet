<p align="center">
  <img src="logo.svg" width="96" alt="ReactiveNET logo">
</p>

# ReactiveNET

**Apps written in Markdown, run in the browser — no cloud, no account.**

ReactiveNET is a platform for building micro-applications by describing them in
a Markdown document extended with *reactive directives*: forms that save rows,
lists, tables, boards, calendars and maps that display them, charts,
aggregations, Python and SQL executed in the browser, Italian open data,
and AI directives that use whatever model the user configures — a local one
included. It is aimed primarily at public administrations and schools:
data lives in the writer's browser (IndexedDB), sharing is end-to-end
encrypted, and the interface targets WCAG 2.2 level AA in seven languages.

- **Website and guide**: <https://reactivenet.ai> (Italian) · <https://reactivenet.ai/en/> (English)
- **The app**: <https://app.reactivenet.ai>
- A document is a plain text file: it versions, diffs and travels like one.

```markdown
::form{path="spese"}
::input{field="voce" label="Voce" required}
::input{field="importo" label="Importo" type="number"}
::save[Aggiungi]
::/form

::list{path="spese" deletable}
{voce} — {importo} €
::/list

Totale: :sum{path="spese" field="importo"}
```

That is a complete expense-tracking app.

## Repository layout

| Path | What it is |
| --- | --- |
| `src/` | The app: ReScript 12 → React 19 → Vite 7. `src/core/` is pure logic (no DOM, fully tested), `src/shell/` is all browser contact, `src/spectrum/` wraps the Spectrum web components. |
| `doc/` | The directive guide the MCP server serves to AI assistants. |
| `mcp/` | The MCP server: lets a model write and validate ReactiveNET apps with the app's own compiled grammar. |
| `data/` | The open-data service: DuckDB warehouse + ETL over Italian public datasets. |
| `pb/` | PocketBase schema and hooks (encrypted short links, shared spaces). |
| `site/` | The Hugo website: guide, blog, app catalogue, legal pages. |
| `legal/` | The legal documents (Italian reference text + English translation) — the site publishes a generated copy. |
| `scripts/` | Build, versioning, icons, screenshots, deployment helpers. |

## Getting started

Prerequisites: [Bun](https://bun.sh) (every script runs with `bun`; Node is not
required).

```sh
bun install
bun run pyodide:assets   # vendors the Pyodide core into public/ (13 MB, gitignored)
```

Development needs **two processes**:

```sh
bun run res:dev   # ReScript compiler in watch mode (.res → .res.mjs)
bun run dev       # Vite dev server
```

Optional local services, each same-origin behind the Vite proxy:

```sh
bun run mcp   # MCP server on :8789 — powers the in-app assistant
bun run od    # open-data service on :8788 — needs a DuckDB warehouse (see data/README.md)
bun run pb    # PocketBase on :8090 — short links and shared spaces
```

Tests (pure core, no DOM needed) and the production build:

```sh
bun run test
bun run res:build && bun run build && bun run preview
```

Note that `bun run preview` serves the real Content-Security-Policy, which the
dev server does not: anything security-related must be verified there.

## Architecture in one paragraph

The renderer turns directives into structure and `data-rn-*` attributes only;
*binders* in `src/shell/` read and write storage after each render. Everything
grammatical — scanning, attributes, validation, data-flow analysis — lives in
`src/core/` as pure, tested functions, and the MCP server imports those same
compiled modules, so an AI assistant and the app can never disagree about what
a directive means. Rendered markdown goes through DOMPurify with Trusted
Types under a strict CSP; user values reach the DOM as `textContent`, never
`innerHTML`. The full tour is in [CLAUDE.md](CLAUDE.md), which doubles as the
contributor's architecture guide.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The two rules that surprise people:
every `.res` file has a `.resi` interface, and a directive is not finished
until its documentation follows in the same piece of work — `doc/` and the
site guide, in both languages (a test enforces it).

## Security

See [SECURITY.md](SECURITY.md) for how to report a vulnerability.

## License

The source code is licensed under the **[Apache License 2.0](LICENSE)**.

The editorial content — the guide, the example apps, the blog and the site's
documentation — is licensed under **CC BY 4.0**. The names "ReactiveNET" and
"Reactive" and the logo are trademarks of Cosimo Luigi Manes and are not
covered by either licence; see the
[licences and attributions](legal/en/licences-and-attributions.md) document,
which also lists the third-party components and the open-data sources with
their attribution requirements.

Metadata for the Italian public-software catalogue is in
[`publiccode.yml`](publiccode.yml).
