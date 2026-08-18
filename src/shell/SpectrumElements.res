// Registers every Spectrum custom element the renderer can emit.
//
// Loaded lazily and once: the bundle is large, and a document that uses no component
// directive should not pay for it. Until it resolves, an <sp-*> tag in the preview is
// an inert unknown element rather than an error — it upgrades in place when the
// definitions arrive.

let ensureLoaded: unit => unit = %raw(`
function () {
  if (globalThis.__rnSpectrumLoading) return;
  globalThis.__rnSpectrumLoading = import("@spectrum-web-components/bundle/elements.js").catch(
    (error) => console.warn("[spectrum] component bundle failed to load:", error)
  );
}
`)
