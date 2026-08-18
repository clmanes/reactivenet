// What has to happen to rendered markdown before a person can use it, wherever it
// came from — the preview's document, the assistant's answer, a message somebody in
// the app sent. Two things, and both are shared rather than copied: a security
// routine with two copies is a security routine with one that will be forgotten, and
// an accessibility one is no different.
//
// --- The links ----------------------------------------------------------------
//
// Defence in depth: DOMPurify has already dropped `javascript:` by the time anything
// gets here. What this adds is the *same* allowlist the rest of the app goes through
// — `SafeUrl.parse`, which strips the ASCII control characters browsers ignore
// mid-scheme, so `java\tscript:` is refused rather than followed — and the
// `noopener noreferrer` that stops an opened page steering the tab it came from.
//
// It lives here rather than in `Render` because the preview is no longer the only
// place markdown becomes DOM: a message in the assistant's panel and a message in an
// app's chat are both somebody else's text with somebody else's links in it. A
// security routine with two copies is a security routine with one that will be
// forgotten.
//
// A link that does not pass is *disarmed, not deleted*: the text stays, marked and
// titled with the reason. Removing it would silently lose what was written, which is
// the failure this whole area exists to avoid.

let collectAnchors: Dom.element => array<Dom.element> = %raw(`
function (container) { return Array.from(container.querySelectorAll("a[href]")); }
`)

let readHref: Dom.element => string = %raw(`
function (anchor) { return anchor.getAttribute("href") || ""; }
`)

let allowHref: (Dom.element, string) => unit = %raw(`
function (anchor, href) {
  anchor.setAttribute("href", href);
  anchor.setAttribute("target", "_blank");
  anchor.setAttribute("rel", "noopener noreferrer");
}
`)

let dropHref: (Dom.element, string) => unit = %raw(`
function (anchor, reason) {
  anchor.removeAttribute("href");
  anchor.setAttribute("title", reason);
  anchor.className = (anchor.className ? anchor.className + " " : "") + "rn-error";
}
`)

let harden = (container, ~removed) =>
  collectAnchors(container)->Array.forEach(anchor =>
    switch anchor->readHref->SafeUrl.parse {
    | Ok(url) => allowHref(anchor, SafeUrl.toString(url))
    | Error(_) => dropHref(anchor, removed)
    }
  )

// --- The wide ones ------------------------------------------------------------
//
// A table is exempt from reflowing (§1.4.10) but not from staying inside the page,
// and a comparison table is what a model answers with. It is *wrapped* rather than
// given `display: block`, which would make it scroll while dropping the row and
// column relationships a screen reader announces — and the wrapper is reachable by
// keyboard and named, because an unnamed `role="region"` is worse than no role at
// all: it announces a landmark it cannot describe.
let wrapWideTables: (Dom.element, string) => unit = %raw(`
function (container, label) {
  container.querySelectorAll("table").forEach((table) => {
    if (table.parentElement && table.parentElement.classList.contains("rn-scroll-x")) return;
    const wrapper = document.createElement("div");
    wrapper.className = "rn-scroll-x";
    wrapper.setAttribute("tabindex", "0");
    wrapper.setAttribute("role", "region");
    wrapper.setAttribute("aria-label", label);
    table.replaceWith(wrapper);
    wrapper.appendChild(table);
  });
}
`)
