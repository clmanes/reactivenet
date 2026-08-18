// Mermaid is ~1 MB and most documents contain no diagram at all, so it is pulled in
// with a dynamic import the first time a `mermaid` fence actually shows up.

let themeName = theme => Theme.isDark(theme) ? "dark" : "default"

let runWithTheme: (Dom.element, string) => unit = %raw(`
function (container, theme) {
  const nodes = container.querySelectorAll("pre.mermaid:not([data-processed])");
  if (nodes.length === 0) return;

  import("mermaid")
    .then(({ default: mermaid }) => {
      mermaid.initialize({
        startOnLoad: false,
        // Mermaid runs its own DOMPurify pass over what it produces.
        securityLevel: "strict",
        theme,
        fontFamily: "inherit",
        // Labels as native SVG <text>, not HTML in a <foreignObject>. The sanitiser
        // strips foreignObject content, which renders every node as an empty box —
        // the diagram draws, but nothing in it is readable.
        htmlLabels: false,
        flowchart: { htmlLabels: false },
      });
      return mermaid.run({ nodes: Array.from(nodes), suppressErrors: true });
    })
    .catch((error) => {
      console.warn("[markdown] mermaid failed to render:", error);
    });
}
`)

let run = (container, ~theme) => runWithTheme(container, themeName(theme))
