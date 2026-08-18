// `::columns` asks for one measurement — the narrowest a column may be — and the
// grid works out how many fit. That number is a CSS custom property, and this is what
// puts it there.
//
// It is set through `setProperty` rather than written into the markup as a style
// attribute, and the reason is the value's provenance: it comes from a document,
// which is to say from outside. `setProperty` hands it to the CSS parser as a single
// value, so `18rem` lands and `18rem; background: url(…)` is refused whole — an
// author cannot smuggle a second declaration in through a column width. The
// alternative, an inline style built by string concatenation, is the CSS version of
// the mistake the rest of this app spends its time not making.
//
// Everything else about the layout lives in index.css, where `auto-fit` and a
// container query mean there is no breakpoint to keep in step with anything.

let bind: Dom.element => unit = %raw(`
function (container) {
  container.querySelectorAll("[data-rn-columns]").forEach((element) => {
    const min = element.getAttribute("data-rn-columns");
    if (min) element.style.setProperty("--rn-col-min", min);
  });
}
`)
