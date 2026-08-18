// Pure. What the "add directive" control offers.
//
// Kept next to the scanner rather than in the component so a template that does not
// parse back into the directive it claims to be is a test failure, not something a
// user discovers by inserting it.

type t = {
  label: string,
  form: DirectiveScan.form,
  name: string,
  snippet: string,
}

let all = [
  {
    label: "Reactive value",
    form: Inline,
    name: "value",
    snippet: `:value[v]{ref="#key"}`,
  },
  {
    label: "Slider",
    form: Leaf,
    name: "slider",
    snippet: `::slider[key]{min="0" max="100" value="50" legend="Label"}`,
  },
  {
    label: "Accordion",
    form: Container,
    name: "accordion",
    // Spectrum composes an accordion as a wrapper around its items, so the snippet
    // nests one container in the other. Both are written the same way: each close
    // names what it ends, so nothing has to be counted.
    snippet: `::accordion{density="compact"}
::accordion-item{label="First" open}
Content.
::/accordion-item
::accordion-item{label="Second"}
More content.
::/accordion-item
::/accordion`,
  },
]

// Appended as its own block, with the blank line markdown needs to treat it as one.
let append = (source, template) => {
  let trimmed = source->String.trimEnd
  trimmed == "" ? template.snippet ++ "\n" : trimmed ++ "\n\n" ++ template.snippet ++ "\n"
}
