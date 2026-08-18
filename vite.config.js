import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { VitePWA } from "vite-plugin-pwa";
import { readFileSync } from "node:fs";


// --- Security policy -------------------------------------------------------
//
// Kept in one place and emitted three ways: as a <meta> tag baked into the built
// index.html (so the policy survives being served by a host you do not control), as
// real response headers from `vite preview`, and as public/_headers for static hosts.
// The meta tag is the fallback, not the goal — a real header is stronger because it
// applies before any markup is parsed.
//
// script-src stays strict: no 'unsafe-inline', no 'unsafe-eval'. That is the
// directive that decides whether injected markup can execute, and nothing in the app
// needs either.
//
// style-src had to give up 'unsafe-inline' when the markdown editor landed. Three
// dependencies require it and none can be configured out of it: KaTeX sizes every
// glyph with a style attribute, Mermaid ships a <style> block inside the SVG it
// generates, and CodeMirror injects its theme as a <style> element at runtime. An
// inline *style* cannot execute script; the exposure is CSS injection (think
// overlaying or hiding UI), which is why this is an acceptable trade and script-src
// is not.
//
// 'wasm-unsafe-eval' is what `::python` costs. A WebAssembly module is compiled by
// code the policy has to allow explicitly, and CPython is a WebAssembly module; the
// token exists precisely so that wasm can be permitted *without* opening `eval` and
// `new Function` to injected script, which is the thing script-src is for. Pyodide's
// core is served from this origin (see scripts/copy-pyodide.mjs), so nothing is
// fetched from anybody to run plain Python.
//
// jsdelivr in connect-src is for Pyodide packages, and only documents that ask for
// `packages` ever reach it: numpy and matplotlib are megabytes each and are not
// vendored. A deployment that wants none of it can drop the origin and copy the
// wheels into public/pyodide instead.
//
// The two `https:` grants are what the outward-looking directives cost, and both
// are bounded by what the grant can express. img-src https: is the map tiles
// (::map, any tile provider a document names) — an image can render, not run.
// connect-src https: is ::api-query and ::geocode reading public JSON APIs; a
// document could always exfiltrate through any <img> URL once img-src is open, so
// the marginal exposure is reads, and the directives only ever GET. Script, style,
// wasm and the Trusted Types wall are exactly as strict as before.
//
// api.pirsch.io in script-src is the analytics script, which index.html loads
// straight from Pirsch. It is the only third-party origin script-src grants, and
// granting it is a deliberate widening of the one directive that decides whether
// injected markup can execute: from here on, that decision is also Pirsch's. It
// buys the snippet Pirsch publishes, working unmodified. The alternative is still
// there and still wired — the /pa proxy below, in public/_redirects and in the
// Caddyfile — and rebuilding the snippet as src="/pa/pa.js" plus the three
// data-*-endpoint attributes takes this token back out. The counts themselves need
// nothing extra: connect-src already grants https:.
//
// The two loopback grants in connect-src are the assistant talking to a model
// running on the same machine — Ollama on 11434, or anything else listening there.
// They are the one place this policy allows plain http, and they are bounded to the
// host a browser will not carry a request off the machine for; every other spelling
// of a local address (a LAN address, a hostname resolving to one) is refused in the
// settings form, by core/AiSettings, so it fails where it was typed rather than as a
// console error nobody is looking at. The alternative was proxying the daemon
// through this app's own origin, which works only where the app is served by
// something that can proxy — which is not the static hosts it is built for.
// Note that CSP's host grammar cannot express an IPv6 literal, so `http://[::1]`
// cannot be granted here and is refused there for the same reason.
const CSP_DIRECTIVES = [
  "default-src 'self'",
  "script-src 'self' 'wasm-unsafe-eval' https://api.pirsch.io",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: https:",
  "font-src 'self'",
  "connect-src 'self' https: http://localhost:* http://127.0.0.1:*",
  "manifest-src 'self'",
  "worker-src 'self' blob:",
  "base-uri 'none'",
  "object-src 'none'",
  "form-action 'none'",
  "frame-ancestors 'none'",
  // Blocks every innerHTML-shaped sink unless the value came from a named policy.
  // Three exist: "lit-html" (Spectrum's rendering), "dompurify" (DOMPurify's own,
  // which stamps sanitised markdown — see shell/Sanitizer.res), and "default" (an
  // exact-match allowlist catching everything else, see shell/TrustedTypes.res).
  "require-trusted-types-for 'script'",
  "trusted-types lit-html default dompurify",
  "upgrade-insecure-requests",
];

// frame-ancestors (and report-*) are ignored when delivered via <meta>; emitting them
// there only produces console noise. The meta variant drops them and leans on
// X-Frame-Options plus the header form.
const META_IGNORED = ["frame-ancestors"];

const cspHeaderValue = CSP_DIRECTIVES.join("; ");
const cspMetaValue = CSP_DIRECTIVES.filter(
  (directive) => !META_IGNORED.some((name) => directive.startsWith(name)),
).join("; ");

// No <meta> equivalent exists for these; they must come from the server.
const SECURITY_HEADERS = {
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
  "Referrer-Policy": "no-referrer",
  "Cross-Origin-Opener-Policy": "same-origin",
  "Cross-Origin-Resource-Policy": "same-origin",
  "Permissions-Policy":
    "accelerometer=(), autoplay=(), camera=(), display-capture=(), encrypted-media=(), fullscreen=(self), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), midi=(), payment=(), usb=(), xr-spatial-tracking=()",
};

// Build only. The dev server needs inline scripts and eval for HMR, so enforcing the
// production CSP there would break the app in a way that teaches nothing;
// `bun run preview` is where the real policy gets exercised.
const contentSecurityPolicy = () => ({
  name: "reactivenet:csp",
  apply: "build",
  transformIndexHtml: {
    order: "post",
    handler: (html) => ({
      html,
      tags: [
        {
          tag: "meta",
          attrs: { "http-equiv": "Content-Security-Policy", content: cspMetaValue },
          injectTo: "head-prepend",
        },
      ],
    }),
  },
});

// The version, as a module built here rather than imported from package.json.
//
// `shell/BuildInfo` used to do `@module("../../package.json")`, which is the
// obvious thing and worked until Vite 7 — that version refuses to serve
// package.json to the browser, and no configuration lifts it. The failure was
// the worst kind: the request 404s, the module graph breaks at that one edge,
// nothing mounts, and the console shows a bare 404 for a file no `<script>`
// ever asked for. A blank page with no error in it.
//
// `define` would have been the easy answer and is the wrong one: it reads the
// file once, when the config loads, so a dev server started before
// `scripts/version.mjs` bumped the number keeps showing the old one — exactly
// the drift the footer exists to rule out. This reads the file on every load
// instead, so the dev server serves it fresh and the build inlines it.
const buildInfo = () => ({
  name: "reactivenet:build-info",
  resolveId: (id) => (id === "virtual:reactivenet/version" ? "\0" + id : undefined),
  load: (id) => {
    if (id !== "\0virtual:reactivenet/version") return undefined;
    const pkg = JSON.parse(readFileSync(new URL("./package.json", import.meta.url), "utf8"));
    return `export const version = ${JSON.stringify(pkg.version)};\n`;
  },
});

export default defineConfig({
  plugins: [
    buildInfo(),
    tailwindcss(),
    react({
      include: ["**/*.res.mjs"],
    }),
    contentSecurityPolicy(),
    VitePWA({
      registerType: "autoUpdate",
      // The injected registration script is a classic <script> that runs before the
      // module graph, i.e. before the Trusted Types policy exists. We register the
      // worker ourselves in src/shell/ServiceWorker.res instead.
      injectRegister: false,
      // No service worker while developing: it would cache the ReScript output
      // and fight with Vite's HMR on every incremental compile.
      devOptions: {
        enabled: false,
      },
      includeAssets: ["logo.svg", "apple-touch-icon-180.png"],
      manifest: {
        name: "ReactiveNET Platform",
        short_name: "ReactiveNET",
        description: "ReactiveNET Platform",
        start_url: "/",
        scope: "/",
        display: "standalone",
        background_color: "#ffffff",
        theme_color: "#16161d",
        icons: [
          { src: "/logo.svg", sizes: "any", type: "image/svg+xml" },
          { src: "/pwa-192.png", sizes: "192x192", type: "image/png" },
          { src: "/pwa-512.png", sizes: "512x512", type: "image/png" },
          {
            src: "/pwa-maskable-512.png",
            sizes: "512x512",
            type: "image/png",
            purpose: "maskable",
          },
        ],
      },
      workbox: {
        globPatterns: ["**/*.{js,mjs,css,html,svg,png,ico,woff2}"],
        // Python's runtime is 13 MB and belongs to the documents that ask for it, not
        // to everyone who opens the app: precaching it would triple the install and
        // blow past Workbox's per-file ceiling. It is fetched on first use and left
        // to the HTTP cache.
        // Neither runtime is precached: Pyodide is 13 MB of vendored assets, and
        // Automerge's wasm (3.9 MB, hashed into assets/) is fetched only the
        // first time an account syncs. Both sit far past Workbox's 2 MB ceiling,
        // which fails the build rather than warning.
        globIgnores: ["**/pyodide/**", "**/*.wasm"],
        cleanupOutdatedCaches: true,
        clientsClaim: true,
        // Workbox's runtime is inlined into sw.js instead of being imported from a
        // second file. By default generateSW emits `importScripts("workbox-<hash>.js")`,
        // and a service worker served with this CSP inherits `require-trusted-types-for
        // 'script'` — under which importScripts demands a TrustedScriptURL and throws
        // "This document requires 'TrustedScriptURL' assignment". The page's own
        // Trusted Types policy cannot help: a worker is a separate global with no
        // policy of its own. The failure is total and silent from the page's side —
        // the worker never installs, so there is no offline app and no navigateFallback
        // — and it only happens where the CSP is real, which is never in `vite dev`.
        inlineWorkboxRuntime: true,
        // The routes are in the path, so /a/<id> is a URL no file answers to. Online
        // a rewrite does it (vite dev and preview out of the box, public/_redirects
        // for static hosts); offline the service worker has to say the same thing, or
        // a bookmarked app is a 404 the moment the network goes.
        navigateFallback: "index.html",
      },
    }),
  ],
  server: {
    // Everything except the CSP, which would break HMR.
    headers: SECURITY_HEADERS,
    // PocketBase on this origin, so connect-src stays 'self'. In production a host
    // rewrite does the same job — see public/_redirects.
    proxy: {
      "/pb": {
        target: "http://127.0.0.1:8090",
        rewrite: (path) => path.replace(/^\/pb/, ""),
      },
      // The open-data service (od-* directives), same arrangement: on this origin
      // so no document can point the app anywhere else, and connect-src holds.
      "/od": {
        target: process.env.OD_SERVER || "http://127.0.0.1:8788",
        rewrite: (path) => path.replace(/^\/od/, ""),
      },
      // The MCP server (bun run mcp), which is what the assistant reads the directive
      // language out of. Same arrangement again, and here it is load-bearing: the
      // model's own endpoint is configurable and the tools' is not, so this one stays
      // on the app's own origin where no document and no setting can point it
      // elsewhere. /mcp is the endpoint, not the root — see mcp/server.mjs.
      "/mcp": {
        target: process.env.MCP_SERVER || "http://127.0.0.1:8789",
      },
      // The catalogue of published apps, on the site — reached on this origin so
      // connect-src 'self' holds and no CORS is involved. `/c/<id>` in the app
      // fetches /catalog/app/<id>.md from here; in production a host rewrite
      // points it at the site, and where neither exists the app says the
      // catalogue did not answer.
      "/catalog": {
        target: process.env.CATALOG_SERVER || "http://localhost:1313",
        rewrite: (path) => path.replace(/^\/catalog/, ""),
      },
      // Pirsch analytics. index.html now loads the script from api.pirsch.io
      // directly, which is what the api.pirsch.io token in script-src pays for, so
      // nothing currently asks for this route. It is kept because it is the way
      // back: a snippet written src="/pa/pa.js" with data-hit-endpoint="/pa/hit",
      // data-event-endpoint="/pa/event" and data-session-endpoint="/pa/session"
      // makes the whole thing same-origin again and lets script-src go back to
      // 'self'. The same route exists in public/_redirects and in the Caddyfile.
      // pa.js does not count localhost visits either way, so dev traffic never
      // reaches the dashboard.
      "/pa": {
        target: "https://api.pirsch.io",
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/pa/, ""),
      },
    },
    watch: {
      // We ignore ReScript build artifacts to avoid unnecessarily triggering HMR on incremental compilation
      ignored: ["**/lib/bs/**", "**/lib/ocaml/**", "**/lib/rescript.lock"],
    },
  },
  build: {
    // The destination is emptied before every build. Vite does this by default
    // while outDir sits inside the project, so this states a guarantee rather
    // than changing behaviour — and keeps it if outDir ever moves, where the
    // default silently flips to leaving the folder alone. What must not survive
    // a build is a hashed asset from the previous one: it is precached by name
    // in the old sw.js, deployed by an rsync that has no reason to delete it,
    // and indistinguishable from a current file.
    emptyOutDir: true,
    // Vite inlines any asset under 4 kB as a data: URL, and a font inlined that way
    // is refused by `font-src 'self'` — a grant this policy has no other reason to
    // widen, since every font here is ours and served from this origin. It bit
    // exactly one file: KaTeX ships one woff2 just small enough to qualify (Size4,
    // the largest delimiters), so under the production CSP big brackets and radicals
    // fell back to whatever the system had, while every other KaTeX face loaded from
    // its own file and looked right. A font is precached either way — woff2 is in
    // globPatterns — so keeping them as files costs nothing but the request.
    assetsInlineLimit: (filePath) => (/\.(woff2?|ttf|otf|eot)$/i.test(filePath) ? false : undefined),
    rollupOptions: {
      output: {
        // Without this the editor libraries land in one chunk that exceeds Workbox's
        // 2 MB precache limit and the PWA build fails outright. Splitting by library
        // also means a Spectrum or KaTeX bump does not invalidate everything else.
        manualChunks(id) {
          if (!id.includes("node_modules")) return undefined;
          if (id.includes("@blocknote") || id.includes("@mantine") || id.includes("prosemirror"))
            return "blocknote";
          // Only CodeMirror's core. The per-language grammars reached through
          // @codemirror/language-data are loaded on demand, and naming them here
          // would drag every one of them into the initial chunk.
          if (/@codemirror\/(view|state|language|commands|autocomplete|search|lang-markdown)/.test(id))
            return "codemirror";
          if (/@lezer\/(common|highlight|lr|markdown)/.test(id)) return "codemirror";
          if (id.includes("katex")) return "katex";
          // On-demand view engines, one chunk each: loaded by their binders the
          // first time a document actually uses them.
          if (id.includes("node_modules/chart.js")) return "charts";
          if (id.includes("node_modules/leaflet")) return "leaflet";
          if (id.includes("node_modules/xlsx")) return "xlsx";
          if (id.includes("@duckdb/duckdb-wasm")) return "duckdb";
          if (id.includes("@finos/perspective") || id.includes("d3fc") || id.includes("node_modules/d3"))
            return "perspective";
          if (id.includes("node_modules/apache-arrow") || id.includes("node_modules/flatbuffers"))
            return "duckdb";
          // The component bundle is 2.6 MB on its own — past Workbox's precache
          // ceiling — so the elements are split from the theme and base runtime the
          // shell needs at startup. The elements chunk is loaded on demand by
          // shell/SpectrumElements.res, only for documents that use a component.
          if (id.includes("@spectrum-web-components/theme") || id.includes("node_modules/lit"))
            return "spectrum-core";
          if (id.includes("@spectrum-web-components")) return undefined;
          return undefined;
        },
      },
    },
  },
  preview: {
    headers: { ...SECURITY_HEADERS, "Content-Security-Policy": cspHeaderValue },
    proxy: {
      "/pb": {
        target: "http://127.0.0.1:8090",
        rewrite: (path) => path.replace(/^\/pb/, ""),
      },
      "/od": {
        target: process.env.OD_SERVER || "http://127.0.0.1:8788",
        rewrite: (path) => path.replace(/^\/od/, ""),
      },
      // The MCP server (bun run mcp), which is what the assistant reads the directive
      // language out of. Same arrangement again, and here it is load-bearing: the
      // model's own endpoint is configurable and the tools' is not, so this one stays
      // on the app's own origin where no document and no setting can point it
      // elsewhere. /mcp is the endpoint, not the root — see mcp/server.mjs.
      "/mcp": {
        target: process.env.MCP_SERVER || "http://127.0.0.1:8789",
      },
      // The catalogue, as in `server` above.
      "/catalog": {
        target: process.env.CATALOG_SERVER || "http://localhost:1313",
        rewrite: (path) => path.replace(/^\/catalog/, ""),
      },
      // Pirsch same-origin, as in `server` above.
      "/pa": {
        target: "https://api.pirsch.io",
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/pa/, ""),
      },
    },
  },
});
