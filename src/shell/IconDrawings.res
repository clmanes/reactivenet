// Spectrum's workflow icons, as drawings rather than as elements.
//
// The elements are not an option: 1096 custom elements are 4.3 MB. What ships instead
// is `src/generated/spectrum-icons.json` — a view box and a few paths per icon — and
// it arrives as one lazily imported chunk the first time anything asks for an icon.
//
// One static import, so the bundler resolves it once and splits it into a chunk of
// its own. A dynamic import built from the icon's name looks tempting and is a trap:
// with the path left unanalysed it works in the dev server and fails in the bundle,
// and analysed it produces a thousand chunks.
//
// This module exists because two things now draw them — the page menu and the gallery
// card — and a second copy of the loader would be a second cache, a second chunk and
// a second place to get the Trusted Types question wrong.

let load: unit => promise<Dict.t<array<string>>> = %raw(`
function () {
  return import("../generated/spectrum-icons.json")
    .then((module) => module.default || module)
    .catch(() => ({}));
}
`)

// Kept, so a document naming ten icons loads the chunk once.
let drawings = ref(None)

let all = () =>
  switch drawings.contents {
  | Some(promise) => promise
  | None =>
    let promise = load()
    drawings := Some(promise)
    promise
  }

/** Draws the named icon into the host element, once the chunk arrives. Nothing
    happens for a name Spectrum does not have, or if the host has left the document
    in the meantime.

    Parsed rather than assigned: `innerHTML` on an SVG would need a Trusted Types
    policy, and `DOMParser` is not a script sink at all. The shapes come from the
    library at build time, never from a document. */
let draw: (Dom.element, string) => unit = %raw(`
function (host, name) {
  globalThis.__rnIcons().then((icons) => {
    const drawing = icons[name];
    if (!drawing || !host.isConnected) return;
    const [viewBox, shapes] = drawing;
    const parsed = new DOMParser().parseFromString(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="' + viewBox + '">' + shapes + "</svg>",
      "image/svg+xml"
    );
    const svg = parsed.documentElement;
    if (svg.querySelector("parsererror")) return;
    svg.setAttribute("class", "rn-icon-drawing");
    svg.setAttribute("fill", "currentColor");
    svg.setAttribute("aria-hidden", "true");
    svg.setAttribute("focusable", "false");
    host.replaceChildren(document.importNode(svg, true));
  });
}
`)

let install: (unit => promise<Dict.t<array<string>>>) => unit = %raw(`
function (all) { globalThis.__rnIcons = all; }
`)

install(all)
