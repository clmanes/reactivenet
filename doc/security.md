# Security

The threat model is **DOM XSS**. The feature is literally "turn text someone typed
into HTML", so rendered markdown is attacker-controlled by definition, and so is
every value stored in a collection.

The defences are layered so that no single one is load-bearing.

## Unsafe URLs are unrepresentable

`SafeUrl.t` is abstract in its interface file, so `parse` is the only way to build
one and rendering code takes a `t`, never a string.

The parser strips ASCII control characters **before** reading the scheme, because
browsers ignore them mid-scheme: `java\tscript:` navigates exactly like
`javascript:`. That case is covered by a test, and is the reason the normalisation
exists at all.

## Rendered markdown is sanitised, and the type says so

`Sanitizer.trustedHtml` is abstract. The only way to obtain one is `toTrustedHtml`,
which runs DOMPurify with `RETURN_TRUSTED_TYPE`, and `setInnerHtml` accepts nothing
else. Reaching `innerHTML` without passing through the sanitiser is not expressible.

The preview then re-checks every rendered link against `SafeUrl` and adds
`rel="noopener noreferrer"`. DOMPurify already drops `javascript:`; this holds user
markdown to the *same* allowlist as the rest of the app.

## A stored value is text, never markup

The list binder clones the row template and substitutes into **text nodes**. A row
containing `<script>` is a row that displays those characters. There is a test for
exactly that.

`:::form` renders a `<div>`, not a `<form>`: nothing here submits anywhere, and the
sanitiser forbids form elements on purpose. Emitting one would mean relaxing that for
no gain.

## An expression cannot execute anything

`:calc` is evaluated by a hand-written recursive-descent parser over `+ - * /`,
parentheses, numbers and `#keys`. It must stay that small — the point of not reaching
for `eval` is that a document cannot execute anything, and an expression is
re-evaluated on every keystroke of every control it mentions.

## CSP with Trusted Types

Defined once in `vite.config.js` and emitted three ways: a `<meta>` tag in the built
HTML, real headers from `vite preview`, and `public/_headers` for static hosts.

`script-src` stays strict — no `unsafe-inline`, no `unsafe-eval`.

`style-src` accepts `unsafe-inline`, and cannot be configured out of it: KaTeX sizes
glyphs with style attributes, Mermaid ships a `<style>` inside its SVG, and CodeMirror
injects its theme at runtime. An inline *style* cannot execute script, so the exposure
is CSS injection, not XSS.

`frame-ancestors` is ignored in a `<meta>` CSP, so the meta variant filters it out and
relies on `X-Frame-Options` plus the header form.

### Four things that break silently if changed without knowing why

- **`sp-theme` assigns the literal `"<slot></slot>"` to `innerHTML`, and Mermaid
  builds its SVG the same way.** Under `require-trusted-types-for 'script'` these
  throw. `shell/TrustedTypes.res` installs a `default` policy with two tiers: an
  exact-match allowlist for constant strings, then DOMPurify for everything else. It
  is deliberately not a pass-through.
- **Mermaid runs with `htmlLabels: false`.** Its default puts node labels in a
  `<foreignObject>`, whose content the sanitiser strips: the diagram draws correctly
  and every box comes out empty.
- **DOMPurify creates its own `dompurify` Trusted Types policy**, which the CSP names.
  Wrapping it in a second policy of ours is worse than redundant: DOMPurify assigns
  the *unsanitised* payload to innerHTML while parsing, so a missing policy makes
  `sanitize()` throw and the preview render nothing at all.
- **The service worker is registered by hand**, with `injectRegister: false`. The
  plugin's injected script is a classic `<script>` that runs during parsing — before
  the module graph, and therefore before the Trusted Types policy exists.

## The CSP is build-only

Vite's dev server needs inline scripts and eval for HMR, so `bun run dev` gets the
other security headers but no CSP. **Policy regressions only surface under
`bun run preview`**, and several of the bugs above appeared only there.

If Spectrum renders unstyled, suspect the CSP before suspecting Spectrum, and check
the console for `[security] default Trusted Types policy not installed`.

`vite preview` reads `vite.config.js` once at startup: after editing the policy,
restart it, or the running server keeps serving the old header while the freshly
built `<meta>` carries the new one. Both are enforced, and the intersection wins.

## What is not a threat here

There is no server, no account and no request: an app cannot exfiltrate anything
because it cannot reach anything. An imported document is inert markup until it is
rendered, and rendering it goes through everything above.

What an imported app *can* do is occupy an id. That is why an import never overwrites
— see [Storage](storage.md).
