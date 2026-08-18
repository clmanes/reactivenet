/** Registers the directive extensions on the shared marked instance. Runs on import;
    exposed so the wiring is visible rather than an invisible side effect. */
let installDirectives: (
  (string, string) => option<string>,
  string => option<string>,
  string => array<DirectiveAttributes.t>,
  array<SpectrumRegistry.component>,
) => unit

/** Markdown (GFM) to HTML, with KaTeX math. The result is NOT yet safe to insert —
    it must go through [Sanitizer.toTrustedHtml]. Mermaid fences come back as
    `<pre class="mermaid">` for [Mermaid.run] to process once they are in the DOM. */
let toHtml: string => string
