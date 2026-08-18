// The last line of defence against DOM XSS.
//
// The CSP sends `require-trusted-types-for 'script'`, which makes every innerHTML-
// shaped sink reject plain strings. Two things in the stack still need such a sink:
//
//   * Lit builds component templates through its own "lit-html" policy — fine, it is
//     named explicitly in the CSP and handles its own strings.
//   * Spectrum's <sp-theme> assigns the literal "<slot></slot>" to innerHTML while
//     building its shadow root. It does not use a policy, so without a default one it
//     silently fails to render and every Spectrum token goes missing.
//   * Mermaid builds its rendered SVG the same way.
//
// So a default policy is required — but a pass-through one would defeat the point,
// re-permitting every string sink in the app. This one has two tiers instead: an
// exact-match allowlist for the constant strings we know about, and DOMPurify for
// everything else. Nothing reaches the DOM unexamined.

let installWith: (string => string) => unit = %raw(`
function (sanitize) {
  const trustedTypes = globalThis.trustedTypes;
  if (!trustedTypes || typeof trustedTypes.createPolicy !== "function") return;

  // Exact strings the component library is known to assign. Not a pattern, not a
  // sanitiser — a fixed set. Adding to it should require knowing exactly why.
  const ALLOWED_HTML = new Set(["<slot></slot>"]);

  try {
    trustedTypes.createPolicy("default", {
      createHTML: (value) => {
        if (ALLOWED_HTML.has(value)) return value;
        // Everything else is third-party code building markup: Mermaid assembles
        // its rendered SVG this way. Throwing here silently blanks those diagrams,
        // so the value is sanitised instead — same DOMPurify configuration the
        // markdown pipeline uses, so the guarantee is identical.
        return sanitize(String(value));
      },
      // Covers navigator.serviceWorker.register() and any other script URL sink.
      createScriptURL: (value) => {
        const url = new URL(value, document.baseURI);
        if (url.origin === location.origin) return url.href;
        throw new TypeError("Blocked a cross-origin script URL: " + String(value));
      },
      // Nothing in this app turns a string into executable code.
      createScript: () => {
        throw new TypeError("Blocked evaluation of a script built from a string");
      },
    });
  } catch (error) {
    // Swallowing this silently is how you end up debugging "Spectrum renders
    // unstyled" for an hour: if the CSP in force does not list "default" among its
    // trusted-types policies, creation throws here and every sink stays blocked.
    if (!String(error).includes("already exists")) {
      console.warn("[security] default Trusted Types policy not installed:", error);
    }
  }
}
`)

// Wired to the same sanitiser the markdown pipeline uses, rather than a second
// configuration that could drift away from it.
let install = () => installWith(Sanitizer.sanitizeToString)
