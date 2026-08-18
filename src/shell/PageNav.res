// The navigation menu `:::page` produces.
//
// The renderer emits each page on its own, hidden, because it sees one container at a
// time and cannot know how many there are. Everything that needs the whole set — the
// menu, which page is showing, whether there is more than one page at all — is
// decided here, after the document has been rendered and sanitised.
//
// The menu is a `<nav>` of buttons with `aria-current`, not an ARIA tablist. A tablist
// is a promise about arrow-key behaviour and roving tabindex; a list of buttons that
// swap a region is what this actually is, and saying so is better than implementing a
// pattern approximately.
//
// Showing a page is announced as `rn:page`, and that one line is load-bearing for two
// other binders. A hidden panel is `display: none`, so everything inside it has no box
// at all: a map canvas measures 0×0 and Leaflet resolves its fit against nothing, a
// Perspective viewer moves into a host of no height and draws nothing. Neither can be
// repaired afterwards by watching the element, because ResizeObserver and
// IntersectionObserver are delivered by the rendering lifecycle — a frame late at
// best, and never at all while the document is not being rendered. The moment a page
// is shown is known here and nowhere else, so it is said out loud.

type labels = {pages: string}

let install: (
  array<string>,
  unit => promise<Dict.t<array<string>>>,
) => (Dom.element, labels) => unit = %raw(`
function (iconNames, loadIcons) {
  const known = new Set(iconNames);
  // Which page each container is showing. A WeakMap keyed by the container, because
  // the preview replaces its innerHTML on every keystroke and the choice has to
  // survive that — losing it would snap the reader back to the first page as they
  // typed.
  const selected = new WeakMap();

  // The disclosure has to point at the list it opens, and aria-controls needs an id.
  // The menu is rebuilt with the document on every render, so counting up is enough.
  let pageMenus = 0;

  // The drawings arrive as one chunk the first time a document names an icon, and
  // the promise is kept so a document with ten icons loads it once.
  let drawings = null;
  const geometry = () => {
    if (drawings === null) drawings = loadIcons();
    return drawings;
  };

  const drawInto = (host, name) => {
    geometry().then((icons) => {
      const drawing = icons[name];
      if (!drawing || !host.isConnected) return;
      const [viewBox, shapes] = drawing;
      // Parsed rather than assigned: innerHTML on an SVG would need a Trusted Types
      // policy, and DOMParser is not a script sink at all. The shapes come from the
      // library at build time, not from the document.
      const parsed = new DOMParser().parseFromString(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="' + viewBox + '">' + shapes + "</svg>",
        "image/svg+xml"
      );
      const svg = parsed.documentElement;
      if (svg.querySelector("parsererror")) return;
      svg.setAttribute("class", "rn-page-icon");
      svg.setAttribute("fill", "currentColor");
      svg.setAttribute("aria-hidden", "true");
      svg.setAttribute("focusable", "false");
      host.replaceChildren(document.importNode(svg, true));
    });
  };

  // What was hidden now has a size. The binders that need one to build anything are
  // listening; everyone else ignores it.
  const announce = () => {
    window.dispatchEvent(new Event("rn:page"));
  };

  const iconFor = (name) => {
    // Validated against Spectrum's own set: a name that is not one of theirs would
    // draw nothing and leave a gap in the menu that the author cannot see.
    if (!known.has(name)) return null;
    const host = document.createElement("span");
    host.className = "rn-page-icon-host";
    drawInto(host, name);
    return host;
  };

  return function (container, labels) {
    const panels = [...container.querySelectorAll("[data-rn-page]")];
    const existing = container.querySelector(".rn-pages");
    if (existing) existing.remove();
    // One page is not a set of pages: a menu with a single entry is a control that
    // does nothing, so the panel is simply shown.
    if (panels.length === 0) return;
    if (panels.length === 1) {
      panels[0].removeAttribute("hidden");
      announce();
      return;
    }

    const ids = panels.map((panel, index) => panel.getAttribute("data-rn-page") || String(index));
    const remembered = selected.get(container);
    const current = ids.includes(remembered) ? remembered : ids[0];
    selected.set(container, current);

    // The menu and the pages are siblings inside one shell, so the stylesheet can
    // lay them out as a rail beside the content when there is room for one. The
    // panels are moved rather than copied, and the shell is inserted where the first
    // of them was, so anything the author wrote around them keeps its place.
    const shell = document.createElement("div");
    shell.className = "rn-pages";
    const body = document.createElement("div");
    body.className = "rn-page-body";

    const nav = document.createElement("nav");
    nav.className = "rn-page-nav";
    nav.setAttribute("aria-label", labels.pages);

    // Narrow, the menu is a disclosure: a button that says where you are and opens
    // the list. A row of tabs is right when they fit and wrong the moment they do
    // not — it either wraps into a block that pushes the page down or scrolls
    // sideways, and both hide entries behind an edge nobody can see. Which of the two
    // shapes is on screen is the stylesheet's business, decided by a container query;
    // the markup carries both and only the state lives here.
    const toggle = document.createElement("button");
    toggle.type = "button";
    toggle.className = "rn-page-burger";
    toggle.setAttribute("aria-expanded", "false");
    const burgerIcon = document.createElement("span");
    burgerIcon.className = "rn-page-burger-icon";
    burgerIcon.setAttribute("aria-hidden", "true");
    const burgerLabel = document.createElement("span");
    burgerLabel.className = "rn-page-burger-label";
    toggle.append(burgerIcon, burgerLabel);

    const list = document.createElement("div");
    list.className = "rn-page-list";
    list.id = "rn-pages-" + (pageMenus += 1);
    toggle.setAttribute("aria-controls", list.id);

    const openMenu = (open) => {
      nav.classList.toggle("rn-page-nav-open", open);
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
    };
    toggle.addEventListener("click", () => {
      openMenu(toggle.getAttribute("aria-expanded") !== "true");
    });

    const show = (wanted) => {
      selected.set(container, wanted);
      panels.forEach((panel, index) => {
        const isCurrent = ids[index] === wanted;
        if (isCurrent) panel.removeAttribute("hidden");
        else panel.setAttribute("hidden", "");
      });
      for (const button of list.querySelectorAll("button")) {
        const isCurrent = button.getAttribute("data-rn-page-to") === wanted;
        if (isCurrent) button.setAttribute("aria-current", "page");
        else button.removeAttribute("aria-current");
      }
      // The burger says which page you are on, because once the list is closed it is
      // the only thing left saying so.
      const at = panels[ids.indexOf(wanted)];
      burgerLabel.textContent = at
        ? at.getAttribute("data-rn-page-title") || wanted
        : labels.pages;
      // Choosing closes it: a menu that stays open over the page it just opened is a
      // menu the reader has to dismiss before reading anything.
      openMenu(false);
      announce();
    };

    panels.forEach((panel, index) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "rn-page-tab";
      button.setAttribute("data-rn-page-to", ids[index]);
      const icon = panel.getAttribute("data-rn-page-icon");
      if (icon) {
        const element = iconFor(icon);
        if (element) button.appendChild(element);
      }
      const label = document.createElement("span");
      label.textContent = panel.getAttribute("data-rn-page-title") || ids[index];
      button.appendChild(label);
      button.addEventListener("click", () => show(ids[index]));
      list.appendChild(button);
    });

    nav.append(toggle, list);
    panels[0].before(shell);
    shell.append(nav, body);
    for (const panel of panels) body.appendChild(panel);
    show(current);
  };
}
`)

// The drawings come from `IconDrawings`, which keeps the one lazily loaded chunk the
// gallery's cards read from too.
let navigator = install(SpectrumIcons.all, IconDrawings.all)

let bind = (container, ~labels) => navigator(container, labels)
