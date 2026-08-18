# Architecture

ReScript 12 → React 19 → Vite 7. Two things drive most of the structure.

## Vite never sees ReScript source

The compiler emits `Foo.res.mjs` next to `Foo.res` (`in-source: true`), the React
plugin is restricted to `**/*.res.mjs`, and `index.html` loads `/src/Main.res.mjs`
directly. Nothing works until ReScript has compiled once, which is why development
needs two processes:

```sh
bun run res:dev   # rescript watch — compiles .res -> .res.mjs
bun run dev       # vite dev server, over the compiled output
```

`bun run build` does **not** compile ReScript. Run `res:build` first.

## Pure core, effectful shell

The split is the point, not decoration.

| Layer | Where | Rule |
| --- | --- | --- |
| Core | `src/core/` | No DOM, no IO, no React. Total, deterministic functions. Every module has a `.resi` and a `_test.res`. |
| Shell | `src/shell/` | All browser contact: storage, markdown pipeline, media queries, Trusted Types, service worker, files. |
| UI | `src/` | Components. They hold state and delegate every decision to `core/`. |
| Bindings | `src/spectrum/` | Typed wrappers over the Spectrum custom elements. |
| Generated | `src/generated/` | Written by scripts. Never edited by hand. |

The dividing question is always *does this need a browser to answer?* `Theme` decides
what a theme is; `ThemeStorage` talks to IndexedDB. `DirectiveScan` decides what a
directive is; `MarkdownRenderer` turns one into DOM. `Aggregate` decides what an
average of stored strings is; `CollectionBinder` reads them. `DateValue` decides
which strings are dates; `Clock` formats one for a reader.

That boundary is why the tests need no DOM, no jsdom and no stubs — 290 of them run
in about 40 ms.

## The pipeline

```
document
  → Frontmatter.parse          split metadata from body            core
  → marked + directive tokens  markdown and directives → HTML      shell
  → DOMPurify                  → TrustedHTML                       shell
  → innerHTML                  the only sink                       shell
  → ReactiveStore.bind         controls and views                  shell
  → CollectionBinder.bind      forms, lists, aggregations          shell
  → PageNav.bind               which page is showing               shell
  → Mermaid.run                diagrams, on real elements          shell
```

Everything after the sanitiser works on nodes it has already approved. Nothing before
it touches storage. That ordering is what keeps the markdown pipeline free of storage
and the storage free of HTML.

## One scanner, three consumers

`core/DirectiveScan` is the only definition of the syntax. The marked tokenizer, the
block editor's markdown round-trip and the editor's completions all read it, so
directive syntax cannot drift between where it is rendered and where it is written.

## One registry, four consumers

`scripts/generate-spectrum-registry.mjs` reads the Custom Elements Manifests that
ship with `@spectrum-web-components` and emits **92 components, 482 attributes**.
`core/DirectiveRegistry` adds ReactiveNET's own directives to the same list, in the
same shape, and adds the HTML globals the manifests leave out.

From that one list come: the renderer's element construction and attribute
validation, the sanitiser's allowlist, the block editor's block specs, and the
editor's completions. Adding a component is a library upgrade, not a code change:

```sh
bun run spectrum:registry   # after upgrading @spectrum-web-components
bun run spectrum:icons      # after which the icon set may have changed too
```

## The editor

Split pane, one markdown string in `App.res`, two editors of which **only one is ever
mounted** — `core/EditorMode` enforces it and the invariant is tested.

CodeMirror edits the source and is *uncontrolled*: it owns its document and
`initialValue` is read once, at mount. Feeding React state back on every keystroke
would fight its own undo history and move the caret.

BlockNote is loaded through a dynamic `import()` in `BlockEditor.res`, which is what
keeps a megabyte out of the initial load — and the main chunk under Workbox's 2 MB
precache ceiling, which is a hard build failure rather than a warning.

The preview is debounced by 250 ms and the save by 700 ms, because Mermaid lays out a
whole diagram on each run and the editor never waits on it.

## Internationalisation

Seven languages, and **a missing translation is a build error**. `Translations.key`
is a variant and each language is a `switch` over it, so adding a key fails to compile
in all seven until every one is written. There is deliberately no map of strings and
no fall back to English — a key that silently renders English is exactly the bug this
design removes.

## Theming

Two independent axes, because Spectrum's `sp-theme` `color` attribute selects a shade
of the neutral scale, not a hue:

- **Polarity** — light or dark, seeded from `prefers-color-scheme`, persisted.
- **Palette** — six hues, applied as an `rn-palette-*` class on `sp-theme` that
  overrides the app's own accent tokens.

Spectrum's own component tokens are deliberately *not* overridden: changing a
component's background without the label colour Spectrum pairs with it is how
contrast regressions get introduced. A badge and a progress bar therefore keep
Spectrum's colours whatever palette is chosen — the palette recolours the app's
surfaces around them. See [Accessibility](accessibility.md).

## Testing

```sh
bun run test                              # rescript, then bun test
bun test ./src/core/SafeUrl_test.res.mjs  # one file — the ./ is required
bun run test -t "rejects"                 # by test name
```

`bun test` cannot discover these files on its own — it looks for `.test.`/`.spec.`
names with a `.js`/`.ts` extension, and the compiler emits `Foo_test.res.mjs` — which
is why the script shells out to `find`.

## Conventions

- **A `.resi` for every `.res`.** React Fast Refresh only works when a module exports
  components exclusively, and for core modules the interface is what makes a type
  abstract. Test modules are the exception; they export nothing.
- Compiled `.res.mjs` files are committed. Reviewing the emitted JavaScript in diffs
  is the point.
- `%raw` blocks are emitted **verbatim**, so a backtick inside one — even in a
  comment — ends the ReScript string and produces a baffling syntax error.
