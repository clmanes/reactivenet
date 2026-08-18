// marked configured once, at module scope: GFM on, KaTeX through the official
// extension, and fenced `mermaid` blocks left as markers for the preview to render
// after the HTML is in the DOM (Mermaid needs real elements, not a string).

%%raw(`
import { Marked } from "marked";
import markedKatex from "marked-katex-extension";
import "katex/dist/katex.min.css";

const marked = new Marked({
  gfm: true,
  breaks: false,
});

marked.use(
  markedKatex({
    // A half-typed formula is the normal state of an editor; it should render as
    // an error inline, not throw and blank the whole preview.
    throwOnError: false,
    nonStandard: false,
  })
);

const escapeHtml = (value) =>
  value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");

marked.use({
  renderer: {
    code({ text, lang }) {
      if ((lang || "").trim().toLowerCase() !== "mermaid") return false;
      // The diagram source is escaped here and read back via textContent by Mermaid,
      // so it never round-trips through the HTML parser as markup.
      return '<pre class="mermaid">' + escapeHtml(text) + "</pre>";
    },
  },
});
`)

// Registered once, at module load. The parsers come from `core/` rather than being
// re-implemented here, so the attribute grammar and the `#ref` rule have exactly one
// definition and it is the tested one.
let installDirectives: (
  (string, string) => option<string>,
  string => option<string>,
  string => array<DirectiveAttributes.t>,
  array<SpectrumRegistry.component>,
) => unit = %raw(`
function (attribute, reactiveKey, parseAttributes, registry) {
  // One renderer for every Spectrum component: the registry is generated from the
  // library's own manifests, so a component gains its attributes here without any
  // code being written for it.
  const components = new Map(registry.map((c) => [c.directive, c]));

  // A component that carries a value is a source: its [label] names the store key it
  // writes to, the same way ::slider[volume] does.
  const isSource = (component) =>
    component.attributes.some((a) => a.name === "value" || a.name === "checked");

  const renderAttributes = (component, raw) => {
    const rejected = [];
    const rendered = [];
    const bindings = [];
    for (const given of parseAttributes(raw)) {
      const spec = component.attributes.find(
        (a) => a.name.toLowerCase() === given.name.toLowerCase()
      );
      if (!spec) {
        rejected.push(given.name);
        continue;
      }
      // A Choice attribute lists the values the component accepts; anything else
      // would be silently ignored by the element, so it is reported instead.
      if (spec.kind === "Choice" && spec.choices.length > 0 && !spec.choices.includes(given.value)) {
        rejected.push(given.name + '="' + given.value + '"');
        continue;
      }
      // A value written as #key is a *binding*, not a literal: the attribute takes
      // whatever that key holds and follows it as it changes. Recorded here and wired
      // by ReactiveStore once the element is in the DOM.
      const boundTo = reactiveKey(given.value);
      if (boundTo !== null && boundTo !== undefined) {
        bindings.push(spec.name + ":" + boundTo);
        continue;
      }
      if (spec.kind === "Flag") {
        if (given.value !== "false") rendered.push(escapeHtml(spec.name));
        continue;
      }
      rendered.push(escapeHtml(spec.name) + '="' + escapeHtml(given.value) + '"');
    }
    return { rendered, rejected, bindings };
  };

  const renderSpectrum = (component, token, body) => {
    const { rendered, rejected, bindings } = renderAttributes(component, token.attrs);
    const key = (token.label || "").trim();
    const source = key !== "" && isSource(component)
      ? ' data-reactive-source="' + escapeHtml(key) + '"'
      : "";
    const label = key !== "" && !isSource(component) ? escapeHtml(key) : "";
    const warning = rejected.length === 0
      ? ""
      : '<span class="rn-error" title="not an attribute of ' + escapeHtml(component.tag) +
        '"> ' + escapeHtml(rejected.join(", ")) + "</span>";
    const attrs = rendered.length === 0 ? "" : " " + rendered.join(" ");
    const bound = bindings.length === 0
      ? ""
      : ' data-reactive-bind="' + escapeHtml(bindings.join(";")) + '"';
    return "<" + component.tag + attrs + source + bound + ">" + label + (body || "") +
      "</" + component.tag + ">" + warning;
  };
  const value = (source, name) => {
    const found = attribute(source, name);
    return found === undefined ? null : found;
  };

  const renderInline = (token) => {
    const aggregates = ["count", "sum", "avg", "min", "max", "median", "stddev", "mode"];
    if (aggregates.includes(token.name)) {
      const path = value(token.attrs, "path");
      if (path === null) return missingPath(token);
      const field = value(token.attrs, "field");
      // Only count works without a field: everything else summarises one column.
      if (token.name !== "count" && field === null) {
        return '<span class="rn-error">' + escapeHtml(token.raw) +
          " — needs field=&quot;name&quot;</span>";
      }
      return '<span class="rn-value" data-rn-aggregate="' + escapeHtml(token.name) +
        '" data-rn-path="' + escapeHtml(path) + '"' +
        (field === null ? "" : ' data-rn-field="' + escapeHtml(field) + '"') +
        (value(token.attrs, "decimals") === null
          ? ""
          : ' data-rn-decimals="' + escapeHtml(value(token.attrs, "decimals")) + '"') +
        ">—</span>";
    }
    if (token.name === "calc") {
      const expression = value(token.attrs, "expr");
      if (expression === null) {
        return '<span class="rn-error">' + escapeHtml(token.raw) +
          " — calc needs expr</span>";
      }
      return '<span class="rn-value" data-rn-calc="' + escapeHtml(expression) + '"' +
        (value(token.attrs, "decimals") === null
          ? ""
          : ' data-rn-decimals="' + escapeHtml(value(token.attrs, "decimals")) + '"') +
        ">—</span>";
    }
    if (token.name !== "value") {
      const component = components.get(token.name);
      if (component) return renderSpectrum(component, token, "");
      // An unimplemented directive is shown as written rather than swallowed: a
      // document should never lose text because the renderer did not recognise it.
      return escapeHtml(token.raw);
    }
    const ref = value(token.attrs, "ref");
    const key = ref === null ? null : reactiveKey(ref);
    // A bare store key is where a source writes; subscribing a view to it would
    // never emit, so it is surfaced as an error rather than rendered inert.
    if (key === null) {
      return '<span class="rn-error" title="value needs ref=&quot;#key&quot;">' +
        escapeHtml(token.raw) + "</span>";
    }
    return '<span class="rn-value" data-reactive-key="' + escapeHtml(key) +
      '" data-placeholder="—">—</span>';
  };

  // --- ReactiveNET's data directives --------------------------------------
  //
  // These are not Spectrum components: they describe an app's relationship with a
  // stored collection, and there is no element that means "a list of rows from
  // the collection named voti". The renderer emits structure and data-rn-* attributes
  // only — every
  // read and write happens in CollectionBinder, after the sanitiser has run, which
  // is what keeps the markdown pipeline free of storage and the storage free of HTML.

  const missingPath = (token) =>
    '<p class="rn-error">' + escapeHtml(token.raw.trim()) +
    " — needs path=&quot;collection&quot;</p>";

  // The id attribute is a global of every directive in the registry, because it is
  // how one directive points at another — and ::print{target} finds the section it
  // prints by nothing else. The Spectrum path emits it with the rest of the validated
  // attributes; these hand-built elements have to say it themselves, and until they
  // did, a document that wrote an id got an element without one: ::print looked for a
  // node that was not there and the click did nothing at all, which is the worst
  // shape a failure can take.
  const htmlId = (token) => {
    const given = value(token.attrs, "id");
    return given === null ? "" : ' id="' + escapeHtml(given) + '"';
  };

  // The ai-* family. Structure only, as ever: this renderer has no locale, no
  // settings and no network, so the words of a button, the question box, the
  // banner that says no model is configured and every request itself belong to
  // shell/AiBinder. What the element carries is what the DOCUMENT said.
  //
  // The body — the persona of a chat, the instruction of a summary or a pipeline —
  // is kept in a hidden division and read back with textContent, exactly as the
  // Python block's code is: it is words for a model, never markup for a page.
  const AI_DIRECTIVES = [
    "ai-summary", "ai-chat", "ai-agent", "ai-pipeline", "ai-query", "ai-rule",
    "ai-classify", "ai-extract", "ai-field", "ai-suggest", "ai-assist",
    "ai-translate", "ai-rewrite", "ai-vision", "ai-search",
  ];

  const aiBlock = (token, body) => {
    const optional = (name) => {
      const given = value(token.attrs, name);
      return given === null ? "" : " data-rn-ai-" + name + '="' + escapeHtml(given) + '"';
    };
    const storeKey = token.label ? token.label.trim() : "";
    return '<div class="rn-ai rn-od" data-rn-ai="' + escapeHtml(token.name.slice(3)) + '"' +
      htmlId(token) +
      (storeKey === "" ? "" : ' data-rn-ai-key="' + escapeHtml(storeKey) + '"') +
      optional("data") + optional("path") + optional("into") + optional("form") +
      optional("field") + optional("fields") + optional("values") + optional("target") +
      optional("source") + optional("to") + optional("style") + optional("prompt") +
      optional("persona") + optional("placeholder") + optional("tools") +
      optional("when") + optional("do") + optional("rag") + optional("label") +
      (value(token.attrs, "overwrite") === null ? "" : " data-rn-ai-overwrite") +
      '><div class="rn-ai-instruction" hidden>' + body + "</div>" +
      '<div class="rn-od-controls"></div>' +
      '<div class="rn-ai-out"></div>' +
      '<p class="rn-od-status rn-muted"></p></div>';
  };

  const dataContainer = (token, body) => {
    if (AI_DIRECTIVES.includes(token.name)) return aiBlock(token, body);
    const path = value(token.attrs, "path");
    // The orchestrator. Structure only, as ever — the strip carries words (waiting,
    // skipped, "last run"), and this renderer is installed once at module load with
    // no locale, so WorkflowBinder builds it.
    //
    // The steps are the engine nodes in the body, which render exactly as they do
    // outside one: nothing here has to know what a ::sql is. What the wrapper adds is
    // the handle closest("[data-rn-workflow]") finds — the containment rule the
    // forms already use — so each engine can ask whether it is inside one and hand
    // its run over instead of starting itself.
    if (token.name === "workflow") {
      const optional = (name, given) =>
        given === null ? "" : " data-rn-workflow-" + name + '="' + escapeHtml(given) + '"';
      const flag = (name) =>
        value(token.attrs, name) === null ? "" : " data-rn-workflow-" + name;
      const title = (token.label || "").trim();
      const quiet = value(token.attrs, "quiet") !== null;
      return '<div class="rn-workflow' +
        (value(token.attrs, "show") === null ? "" : " rn-wf-open") +
        (quiet ? " rn-wf-quiet" : "") +
        '" data-rn-workflow' + htmlId(token) +
        (title === "" ? "" : ' data-rn-workflow-title="' + escapeHtml(title) + '"') +
        optional("every", value(token.attrs, "every")) +
        optional("at", value(token.attrs, "at")) +
        optional("on", value(token.attrs, "on")) +
        optional("label", value(token.attrs, "label")) +
        flag("catchup") + flag("show") + flag("quiet") +
        '><div class="rn-wf-strip"' + (quiet ? " hidden" : "") + ">" +
        '<div class="rn-wf-head"></div><div class="rn-wf-steps"></div></div>' +
        '<div class="rn-wf-body">' + body + "</div></div>";
    }
    if (token.name === "form") {
      // A div, not a form element: nothing here submits anywhere, and the sanitiser
      // forbids form elements on purpose. The id is what an input and its save
      // button use to find each other.
      const id = value(token.attrs, "id") || path;
      if (id === null) return missingPath(token);
      return '<div class="rn-form" data-rn-form="' + escapeHtml(id) + '"' + htmlId(token) +
        (path === null ? "" : ' data-rn-path="' + escapeHtml(path) + '"') + ">" + body + "</div>";
    }
    if (token.name === "columns") {
      // The narrowest a column may be is the only measurement given; the grid works
      // out how many fit. It is carried as a data attribute rather than an inline
      // style because the value comes from a document: shell/Columns hands it to
      // setProperty, where the browser refuses anything that is not a length, and
      // nothing an author writes can become a rule of its own.
      const min = value(token.attrs, "min");
      const asked = value(token.attrs, "gap");
      const gap = ["s", "m", "l"].includes(asked) ? asked : "m";
      return '<div class="rn-columns rn-columns-' + gap + '"' + htmlId(token) +
        (min === null ? "" : ' data-rn-columns="' + escapeHtml(min) + '"') +
        ">" + body + "</div>";
    }
    if (token.name === "page") {
      // Each page is emitted on its own, hidden. The renderer sees one container at a
      // time and cannot know how many there are, so the menu is built afterwards by
      // PageNav, which is also the only thing that can decide which one is showing.
      const pageId = value(token.attrs, "id") || value(token.attrs, "title") || "";
      return '<section class="rn-page-panel" hidden' + htmlId(token) +
        ' data-rn-page="' + escapeHtml(pageId) +
        '" data-rn-page-title="' + escapeHtml(value(token.attrs, "title") || pageId) + '"' +
        (value(token.attrs, "icon") === null
          ? ""
          : ' data-rn-page-icon="' + escapeHtml(value(token.attrs, "icon")) + '"') +
        ">" + body + "</section>";
    }
    if (token.name === "table") {
      if (path === null) return missingPath(token);
      const optional = (name, given) =>
        given === null ? "" : " data-rn-" + name + '="' + escapeHtml(given) + '"';
      const editform = value(token.attrs, "editform");
      const deletable = value(token.attrs, "deletable");
      const search = value(token.attrs, "search");
      // The head is the body: each ::column in there rendered itself as a <th>. The
      // search box and the pager are NOT here — the binder builds those, because they
      // carry text and this renderer is installed once, with no language.
      return '<div class="rn-table" data-rn-table="' + escapeHtml(path) + '"' + htmlId(token) +
        (search === null || search === "false" ? "" : " data-rn-search") +
        (deletable === null || deletable === "false" ? "" : " data-rn-deletable") +
        optional("page-size", value(token.attrs, "page-size")) +
        optional("sort", value(token.attrs, "sort")) +
        optional("dir", value(token.attrs, "dir")) +
        optional("filter", value(token.attrs, "filter")) +
        optional("filters", value(token.attrs, "filters")) +
        (editform === null ? "" : ' data-rn-editform="' + escapeHtml(editform) + '"') +
        '><table class="rn-table-grid"><thead><tr>' + body +
        '</tr></thead><tbody class="rn-table-rows"></tbody></table></div>';
    }
    // Cards are a list whose rows are drawn as cards in a grid that reflows: the same
    // rows, the same template, the same everything except the shape. It carries
    // data-rn-list too, so the binder has one code path and gains nothing to keep in
    // step.
    if (token.name === "list" || token.name === "cards") {
      if (path === null) return missingPath(token);
      const asCards = token.name === "cards";
      const min = value(token.attrs, "min");
      // The body is the row template, kept as real sanitised DOM rather than as a
      // string: the binder clones it per row and substitutes into TEXT NODES, so a
      // stored value can never become markup however it was typed.
      const deletable = value(token.attrs, "deletable");
      const editform = value(token.attrs, "editform");
      const optional = (name, given) =>
        given === null ? "" : " data-rn-" + name + '="' + escapeHtml(given) + '"';
      return '<div class="' + (asCards ? "rn-cards" : "rn-list") +
        '" data-rn-list="' + escapeHtml(path) + '"' + htmlId(token) +
        (asCards && min !== null ? ' data-rn-columns="' + escapeHtml(min) + '"' : "") +
        (deletable === null || deletable === "false" ? "" : " data-rn-deletable") +
        (editform === null ? "" : ' data-rn-editform="' + escapeHtml(editform) + '"') +
        optional("sort", value(token.attrs, "sort")) +
        optional("dir", value(token.attrs, "dir")) +
        optional("filter", value(token.attrs, "filter")) +
        optional("limit", value(token.attrs, "limit")) +
        optional("group-by", value(token.attrs, "group-by")) +
        ">" +
        '<div class="rn-list-template" hidden>' + body + "</div>" +
        '<div class="rn-list-rows' + (asCards ? " rn-columns" : "") + '"></div></div>';
    }
    if (token.name === "board") {
      if (path === null) return missingPath(token);
      const optional = (name, given) =>
        given === null ? "" : " data-rn-" + name + '="' + escapeHtml(given) + '"';
      const deletable = value(token.attrs, "deletable");
      const editform = value(token.attrs, "editform");
      const min = value(token.attrs, "min");
      return '<div class="rn-board" data-rn-board="' + escapeHtml(path) + '"' + htmlId(token) +
        (deletable === null || deletable === "false" ? "" : " data-rn-deletable") +
        (editform === null ? "" : ' data-rn-editform="' + escapeHtml(editform) + '"') +
        (min === null ? "" : ' data-rn-columns="' + escapeHtml(min) + '"') +
        optional("group-by", value(token.attrs, "group-by")) +
        optional("board-columns", value(token.attrs, "columns")) +
        optional("sort", value(token.attrs, "sort")) +
        optional("dir", value(token.attrs, "dir")) +
        optional("filter", value(token.attrs, "filter")) +
        ">" +
        '<div class="rn-list-template" hidden>' + body + "</div>" +
        '<div class="rn-board-columns rn-columns"></div></div>';
    }
    // ::timetable — the board's drag, in two dimensions. Structure only, as ever:
    // which values the axes have, which cells are forbidden and which card may be
    // dragged are all read from storage by CollectionBinder. The hidden body is the
    // CELL template, and it carries the list's own rn-list-template class rather than a
    // second one, because it is filled by the same code and must stay that way.
    if (token.name === "timetable") {
      if (path === null) return missingPath(token);
      const optional = (name, given) =>
        given === null ? "" : " data-rn-" + name + '="' + escapeHtml(given) + '"';
      const deletable = value(token.attrs, "deletable");
      const editform = value(token.attrs, "editform");
      return '<div class="rn-timetable" data-rn-timetable="' + escapeHtml(path) + '"' + htmlId(token) +
        (deletable === null || deletable === "false" ? "" : " data-rn-deletable") +
        (editform === null ? "" : ' data-rn-editform="' + escapeHtml(editform) + '"') +
        optional("tt-rows", value(token.attrs, "rows")) +
        optional("tt-cols", value(token.attrs, "cols")) +
        optional("tt-row-values", value(token.attrs, "row-values")) +
        optional("tt-col-values", value(token.attrs, "col-values")) +
        optional("tt-row-labels", value(token.attrs, "row-labels")) +
        optional("tt-col-labels", value(token.attrs, "col-labels")) +
        optional("tt-pin", value(token.attrs, "pin")) +
        optional("tt-blocked", value(token.attrs, "blocked")) +
        optional("tt-colour", value(token.attrs, "colour")) +
        optional("filter", value(token.attrs, "filter")) +
        ">" +
        '<div class="rn-list-template" hidden>' + body + "</div>" +
        '<div class="rn-timetable-body"></div>' +
        // The records placed in no cell, and the sentence a refused drop leaves
        // behind. Both are filled by the binder — one holds rows, the other words.
        '<div class="rn-timetable-waiting"></div>' +
        '<p class="rn-timetable-status rn-error" role="status"></p></div>';
    }
    if (token.name === "calendar") {
      if (path === null) return missingPath(token);
      const optional = (name, given) =>
        given === null ? "" : " data-rn-" + name + '="' + escapeHtml(given) + '"';
      // field/end are the newer names for from/to; both spellings are read so
      // no document loses its calendar to a rename.
      const calView = value(token.attrs, "view");
      return '<div class="rn-calendar" data-rn-calendar="' + escapeHtml(path) + '"' + htmlId(token) +
        optional("from-field", value(token.attrs, "from") ?? value(token.attrs, "field")) +
        optional("to-field", value(token.attrs, "to") ?? value(token.attrs, "end")) +
        optional("view", ["month", "week", "agenda", "matrix"].includes(calView) ? calView : null) +
        optional("by", value(token.attrs, "by")) +
        optional("time-field", value(token.attrs, "time")) +
        optional("day-form", value(token.attrs, "form")) +
        optional("tooltip", value(token.attrs, "tooltip")) +
        optional("sort", value(token.attrs, "sort")) +
        optional("dir", value(token.attrs, "dir")) +
        optional("filter", value(token.attrs, "filter")) +
        (value(token.attrs, "sunday") === null ? "" : " data-rn-sunday") +
        ">" +
        '<div class="rn-list-template" hidden>' + body + "</div>" +
        '<div class="rn-calendar-body"></div></div>';
    }
    if (token.name === "python") {
      // Structure only, as ever: the body is the fenced code block, rendered by
      // marked into <pre><code> — which is what preserves the indentation Python
      // needs — and the shell reads it back with textContent. The renderer runs
      // nothing and knows nothing about a runtime.
      const optional = (name, given) =>
        given === null ? "" : " data-rn-" + name + '="' + escapeHtml(given) + '"';
      return '<div class="rn-python" data-rn-python' + htmlId(token) +
        optional("python-data", value(token.attrs, "data")) +
        optional("python-packages", value(token.attrs, "packages")) +
        optional("python-writes", value(token.attrs, "writes")) +
        // The reactive keys the code reads as params["name"]. They are named here and
        // resolved by the binder, which is the only side that can see the store.
        optional("python-params", value(token.attrs, "params")) +
        (value(token.attrs, "manual") === null ? "" : " data-rn-python-manual") +
        (value(token.attrs, "show") === null ? "" : " data-rn-python-show") +
        ">" + body + '<div class="rn-python-output"></div></div>';
    }
    if (token.name === "dashboard") {
      if (path === null) return missingPath(token);
      // The chip holder comes first, empty: the words a selection needs are the
      // binder's, and there is no selection at render time anyway.
      return '<div class="rn-dashboard" data-rn-dashboard="' + escapeHtml(path) + '"' +
        htmlId(token) + ">" +
        '<div class="rn-dashboard-chip"></div>' + body + "</div>";
    }
    if (token.name === "map") {
      if (path === null) return missingPath(token);
      // Structure only: the hidden body is the popup template, the empty canvas
      // is what MapBinder gives to Leaflet. Tiles and credit ride as data
      // attributes; the binder validates the URL before using it.
      const optional = (name, given) =>
        given === null ? "" : " data-rn-map-" + name + '="' + escapeHtml(given) + '"';
      return '<div class="rn-map" data-rn-map="' + escapeHtml(path) + '"' + htmlId(token) +
        optional("coords", value(token.attrs, "coords")) +
        optional("lat", value(token.attrs, "lat")) +
        optional("lon", value(token.attrs, "lon")) +
        optional("geojson", value(token.attrs, "geojson")) +
        optional("fill", value(token.attrs, "fill")) +
        optional("center", value(token.attrs, "center")) +
        optional("zoom", value(token.attrs, "zoom")) +
        optional("height", value(token.attrs, "height")) +
        optional("tiles", value(token.attrs, "tiles")) +
        optional("attribution", value(token.attrs, "attribution")) +
        ">" +
        '<div class="rn-map-template" hidden>' + body + "</div>" +
        '<div class="rn-map-canvas"></div></div>';
    }
    if (token.name === "explore") {
      if (path === null) return missingPath(token);
      // The body, when present, is the viewer's own JSON configuration in a
      // fenced block; it stays hidden and the binder reads it back as text.
      const optional = (name, given) =>
        given === null ? "" : " data-rn-explore-" + name + '="' + escapeHtml(given) + '"';
      return '<div class="rn-explore" data-rn-explore="' + escapeHtml(path) + '"' + htmlId(token) +
        optional("view", value(token.attrs, "view")) +
        optional("group-by", value(token.attrs, "group-by")) +
        optional("split-by", value(token.attrs, "split-by")) +
        optional("columns", value(token.attrs, "columns")) +
        optional("height", value(token.attrs, "height")) +
        ">" +
        '<div class="rn-explore-config" hidden>' + body + "</div>" +
        '<div class="rn-explore-host"></div></div>';
    }
    if (token.name === "sql") {
      const into = value(token.attrs, "into");
      if (into === null) {
        return '<p class="rn-error">' + escapeHtml(token.raw.trim()) +
          " — sql needs into=&quot;collection&quot;</p>";
      }
      // The body is the fenced SELECT, rendered by marked into <pre><code> —
      // which preserves it exactly — and read back with textContent, the same
      // road ::python's code takes.
      const optional = (name, given) =>
        given === null ? "" : " data-rn-sql-" + name + '="' + escapeHtml(given) + '"';
      return '<div class="rn-sql" data-rn-sql data-rn-sql-into="' + escapeHtml(into) + '"' +
        htmlId(token) +
        optional("data", value(token.attrs, "data")) +
        optional("limit", value(token.attrs, "limit")) +
        ">" + body +
        '<div class="rn-od-controls"></div><p class="rn-od-status rn-muted"></p></div>';
    }
    if (token.name === "if-any" || token.name === "if-empty") {
      if (path === null) return missingPath(token);
      // Hidden until the binder has read the collection: showing "nothing here yet"
      // for the instant before the data arrives is worse than showing nothing.
      return '<div class="rn-when" hidden data-rn-when="' +
        (token.name === "if-any" ? "any" : "empty") +
        '" data-rn-path="' + escapeHtml(path) + '"' + htmlId(token) + ">" + body + "</div>";
    }
    return null;
  };

  const dataLeaf = (token) => {
    // Two directives whose body is genuinely optional: the map's popup template
    // and the explore view's JSON configuration are both things an author may
    // simply not write, and a block nobody closed is a leaf. Their rendering
    // lives with the containers, so it is asked for here with an empty body —
    // otherwise they fall through to the registry and come out as the bare
    // <div> the manifest describes, which is the element the binder looks for
    // with every attribute it reads stripped off. It renders, it is empty, and
    // nothing says why.
    // A ::workflow nobody closed is a workflow with no steps. It goes through the
    // container path with an empty body so the binder can SAY that, rather than
    // falling to the registry and coming out as a bare div with every attribute
    // stripped — rendered, empty, and silent about why, which is the failure the map
    // and the explore view each hit once.
    if (token.name === "map" || token.name === "explore" || token.name === "workflow")
      return dataContainer(token, "");
    // Every ai-* directive is written as a leaf far more often than as a container:
    // only the chat, the agent, the summary and the pipeline have anything to put
    // inside them, and the other ten are a button and a status line.
    if (AI_DIRECTIVES.includes(token.name)) return aiBlock(token, "");
    if (token.name === "column") {
      const field = value(token.attrs, "field");
      if (field === null) {
        return '<p class="rn-error">' + escapeHtml(token.raw.trim()) +
          " — column needs field</p>";
      }
      const align = value(token.attrs, "align");
      // The header is a button because it does something. A <th> that reorders the
      // table on click and is not focusable is a control only a mouse can reach.
      return '<th class="rn-th" scope="col" data-rn-field="' + escapeHtml(field) + '"' +
        (align === null ? "" : ' data-rn-align="' + escapeHtml(align) + '"') +
        '><button type="button" class="rn-th-sort">' +
        escapeHtml(value(token.attrs, "label") || field) + "</button></th>";
    }
    if (token.name === "input") {
      const field = value(token.attrs, "field");
      if (field === null) {
        return '<p class="rn-error">' + escapeHtml(token.raw.trim()) +
          " — input needs field</p>";
      }
      // form is only written when a field lives outside the form it belongs to.
      // Inside one, containment already says which form this is — repeating it on
      // every field is a second place for the same fact to be wrong.
      const form = value(token.attrs, "form");
      const attr = (name) => value(token.attrs, name);
      const legend = attr("legend");
      const optional = (name, given) =>
        given === null || given === undefined ? "" : " " + name + '="' + escapeHtml(given) + '"';
      // The label wraps the control, so it names it without a for/id pair — and two
      // forms with a field of the same name cannot collide on an id that the
      // renderer, which sees one directive at a time, has no way to make unique.
      const help = attr("help");
      const kind = attr("type") || "text";
      // A reference is a choice of rows, so it is a <select> the binder fills after
      // reading that collection. The renderer never reads storage — it says which
      // collection and which field to show, and stops there.
      if (kind === "ref") {
        const refPath = attr("path");
        if (refPath === null) {
          return '<span class="rn-error">' + escapeHtml(token.raw) +
            " — ref needs path=&quot;collection&quot;</span>";
        }
        return '<div class="rn-field">' +
          '<label class="rn-field-label">' +
          '<span class="rn-field-name">' + escapeHtml(legend === null ? field : legend) +
          "</span>" +
          '<select class="rn-field-input" data-rn-field="' + escapeHtml(field) + '"' +
          (form === null ? "" : ' data-rn-in-form="' + escapeHtml(form) + '"') +
          ' data-rn-ref="' + escapeHtml(refPath) + '"' +
          ' data-rn-ref-label="' + escapeHtml(attr("label") || "") + '"' +
          (attr("required") === null ? "" : " required") +
          "></select></label>" +
          (help === null
            ? ""
            : '<span class="rn-field-help" data-rn-help>' + escapeHtml(help) + "</span>") +
          "</div>";
      }
      // The guidance sits outside the <label>, because a label's text *is* the
      // control's accessible name: put it inside and the field is announced as
      // "Postcode Five digits, no spaces". Outside, CollectionBinder points
      // aria-describedby at it, which is the relationship this actually is.
      return '<div class="rn-field">' +
        '<label class="rn-field-label">' +
        '<span class="rn-field-name">' + escapeHtml(legend === null ? field : legend) + "</span>" +
        '<input class="rn-field-input" type="' + escapeHtml(attr("type") || "text") +
        '" data-rn-field="' + escapeHtml(field) + '"' +
        (form === null ? "" : ' data-rn-in-form="' + escapeHtml(form) + '"') +
        optional("placeholder", attr("placeholder")) +
        optional("value", attr("value")) +
        optional("min", attr("min")) +
        optional("max", attr("max")) +
        optional("step", attr("step")) +
        // The author's rule travels as the HTML attribute it is named after, so the
        // browser's own hint agrees with ours; the message beside it is the app's,
        // and is what the reader is actually shown when the rule refuses.
        optional("pattern", attr("pattern")) +
        optional("data-rn-message", attr("message")) +
        (attr("required") === null ? "" : " required") +
        " /></label>" +
        (help === null
          ? ""
          : '<span class="rn-field-help" data-rn-help>' + escapeHtml(help) + "</span>") +
        "</div>";
    }
    // ::choose — the control that turns a collection into a reactive key, which is
    // what lets a reader steer an ::od-query instead of reading whatever the author
    // hard-coded into the SQL. The brackets are the STORE KEY, as they are on every
    // source; what a reader sees comes from the label attribute.
    //
    // A <select> and not an sp-picker, for the reason ::input{type="ref"} is one: the
    // options come from storage, a native select already works before the Spectrum
    // bundle has loaded, and on a handset the browser gives it a proper picker for
    // free. As ever the renderer says WHICH collection and stops there — it never
    // reads storage, so the options are the binder's to build.
    if (token.name === "choose") {
      const key = (token.label || "").trim();
      if (key === "") {
        return '<p class="rn-error">' + escapeHtml(token.raw.trim()) +
          " — choose needs a key, as ::choose[key]</p>";
      }
      const attr = (name) => value(token.attrs, name);
      const from = attr("path");
      if (from === null) {
        return '<p class="rn-error">' + escapeHtml(token.raw.trim()) +
          " — choose needs path=&quot;collection&quot;</p>";
      }
      const optional = (name, given) =>
        given === null ? "" : " " + name + '="' + escapeHtml(given) + '"';
      const legend = attr("legend");
      const help = attr("help");
      // The label wraps the control, so it names it with no for/id pair. Without a
      // legend the key is the fallback, because an unnamed control is unusable with a
      // screen reader — the same choice ::slider makes with its aria-label.
      return '<div class="rn-field">' +
        '<label class="rn-field-label">' +
        '<span class="rn-field-name">' + escapeHtml(legend === null ? key : legend) + "</span>" +
        '<select class="rn-field-input rn-choose" data-reactive-source="' + escapeHtml(key) +
        '" data-rn-choose="' + escapeHtml(from) + '"' +
        optional("data-rn-choose-field", attr("field")) +
        optional("data-rn-choose-label", attr("label")) +
        optional("data-rn-choose-blank", attr("placeholder")) +
        optional("data-rn-choose-sort", attr("sort")) +
        optional("data-rn-choose-dir", attr("dir")) +
        optional("value", attr("value")) +
        "></select></label>" +
        (help === null
          ? ""
          : '<span class="rn-field-help" data-rn-help>' + escapeHtml(help) + "</span>") +
        "</div>";
    }
    // ::print — a button naming the container it prints, and with repeat= the
    // collection it prints it once per row of. The click, the copies and the
    // print-only classes live in PrintBinder.
    //
    // The button is emitted EMPTY when the author wrote no label: the default is
    // words, and this renderer is installed once, at module load, with no language.
    // PrintBinder fills it, the same way the row buttons and a table's search box are
    // built there.
    if (token.name === "print") {
      const target = value(token.attrs, "target");
      if (target === null) {
        return '<p class="rn-error">' + escapeHtml(token.raw.trim()) +
          " — print needs target=&quot;id&quot;</p>";
      }
      const optional = (name, given) =>
        given === null ? "" : " data-rn-print-" + name + '="' + escapeHtml(given) + '"';
      const label = value(token.attrs, "label");
      return '<button type="button" class="rn-print" data-rn-print="' + escapeHtml(target) + '"' +
        optional("repeat", value(token.attrs, "repeat")) +
        optional("key", value(token.attrs, "key")) +
        optional("field", value(token.attrs, "field")) +
        (value(token.attrs, "landscape") === null ? "" : " data-rn-print-landscape") +
        ">" + (label === null ? "" : escapeHtml(label)) + "</button>";
    }
    // ::geo — a form field like any other, plus the button that fills it with
    // the device's position as "lat, lon". The button carries a glyph, not a
    // word; its accessible name is the field's.
    if (token.name === "geo") {
      const field = value(token.attrs, "field");
      if (field === null) {
        return '<p class="rn-error">' + escapeHtml(token.raw.trim()) +
          " — geo needs field</p>";
      }
      const form = value(token.attrs, "form");
      const legend = value(token.attrs, "legend");
      const name = legend === null ? field : legend;
      return '<div class="rn-field rn-geo">' +
        '<label class="rn-field-label">' +
        '<span class="rn-field-name">' + escapeHtml(name) + "</span>" +
        '<span class="rn-geo-row">' +
        '<input class="rn-field-input" type="text" data-rn-field="' + escapeHtml(field) + '"' +
        (form === null ? "" : ' data-rn-in-form="' + escapeHtml(form) + '"') +
        ' placeholder="45.46, 9.18" />' +
        '<button type="button" class="rn-geo-button" data-rn-geo aria-label="' +
        escapeHtml(name) + '">◎</button>' +
        "</span></label></div>";
    }
    // The chart directives: an empty division the binder fills with a canvas.
    // The renderer emits no canvas itself — the element is not in the
    // sanitiser's vocabulary, and it does not need to be: binder-built DOM is
    // not sanitiser output.
    if (token.name === "chart-bar" || token.name === "chart-line" ||
        token.name === "chart-pie" || token.name === "chart-scatter" ||
        token.name === "chart-area" || token.name === "chart-doughnut" ||
        token.name === "chart-radar") {
      const data = value(token.attrs, "data");
      if (data === null) {
        return '<p class="rn-error">' + escapeHtml(token.raw.trim()) +
          " — needs data=&quot;collection&quot;</p>";
      }
      const optional = (name, given) =>
        given === null ? "" : " data-rn-chart-" + name + '="' + escapeHtml(given) + '"';
      return '<div class="rn-chart" data-rn-chart="' + token.name.slice(6) +
        '" data-rn-chart-data="' + escapeHtml(data) + '"' + htmlId(token) +
        optional("x", value(token.attrs, "x")) +
        optional("y", value(token.attrs, "y")) +
        optional("label", value(token.attrs, "label")) +
        optional("value", value(token.attrs, "value")) +
        optional("height", value(token.attrs, "height")) +
        (value(token.attrs, "horizontal") === null ? "" : " data-rn-chart-horizontal") +
        (value(token.attrs, "stacked") === null ? "" : " data-rn-chart-stacked") +
        "></div>";
    }
    // ::file — a form field holding a file. The visible input picks; the
    // hidden .rn-field-input carries the value the draft reads, so saving and
    // editing work exactly as for any other field. Reading, capping and the
    // preview live in FileFieldBinder.
    if (token.name === "file") {
      const field = value(token.attrs, "field");
      if (field === null) {
        return '<p class="rn-error">' + escapeHtml(token.raw.trim()) +
          " — file needs field</p>";
      }
      const form = value(token.attrs, "form");
      const legend = value(token.attrs, "legend");
      const optional = (name, given) =>
        given === null ? "" : " data-rn-file-" + name + '="' + escapeHtml(given) + '"';
      return '<div class="rn-field rn-file-field">' +
        '<label class="rn-field-label">' +
        '<span class="rn-field-name">' + escapeHtml(legend === null ? field : legend) + "</span>" +
        '<input type="file" class="rn-file-input" data-rn-file' +
        optional("accept", value(token.attrs, "accept")) +
        optional("maxkb", value(token.attrs, "maxkb")) +
        " /></label>" +
        '<input type="hidden" class="rn-field-input" data-rn-field="' + escapeHtml(field) + '"' +
        (form === null ? "" : ' data-rn-in-form="' + escapeHtml(form) + '"') +
        " />" +
        '<span class="rn-file-preview"></span>' +
        '<p class="rn-od-status rn-muted"></p></div>';
    }
    // ::geocode — address to coordinates, always on a click. Structure only;
    // the requests, the pacing and the words live in GeocodeBinder.
    if (token.name === "geocode") {
      const geoPath = value(token.attrs, "path");
      const single = value(token.attrs, "value");
      const storeKey = token.label ? token.label.trim() : "";
      if ((geoPath === null || value(token.attrs, "from") === null) && (single === null || storeKey === "")) {
        return '<p class="rn-error">' + escapeHtml(token.raw.trim()) +
          " — geocode needs path + from, or [storekey] + value</p>";
      }
      const optional = (name, given) =>
        given === null ? "" : " data-rn-geocode-" + name + '="' + escapeHtml(given) + '"';
      return '<div class="rn-geocode" data-rn-geocode' +
        optional("path", geoPath) +
        optional("from", value(token.attrs, "from")) +
        optional("to", value(token.attrs, "to")) +
        optional("value", single) +
        (storeKey === "" ? "" : ' data-rn-geocode-key="' + escapeHtml(storeKey) + '"') +
        optional("url", value(token.attrs, "url")) +
        '><button type="button" class="rn-od-go rn-geocode-run">' +
        escapeHtml(value(token.attrs, "label") || "Geocode") + "</button>" +
        '<span class="rn-od-status rn-muted"></span></div>';
    }
    // The ml-* directives: an empty division the binder fills with a status
    // line and, before the first package download, a Run button.
    if (token.name === "ml-cluster" || token.name === "ml-anomaly" ||
        token.name === "ml-predict" || token.name === "ml-correlate" ||
        token.name === "ml-forecast") {
      const mlData = value(token.attrs, "data");
      const mlInto = value(token.attrs, "into");
      if (mlData === null || mlInto === null) {
        return '<p class="rn-error">' + escapeHtml(token.raw.trim()) +
          " — needs data=&quot;collection&quot; and into=&quot;collection&quot;</p>";
      }
      const optional = (name) => {
        const given = value(token.attrs, name);
        return given === null ? "" : " data-rn-ml-" + name + '="' + escapeHtml(given) + '"';
      };
      return '<div class="rn-ml rn-od" data-rn-ml="' + token.name.slice(3) +
        '" data-rn-ml-data="' + escapeHtml(mlData) +
        '" data-rn-ml-into="' + escapeHtml(mlInto) + '"' +
        optional("features") + optional("target") + optional("x") + optional("y") +
        optional("k") + optional("contamination") + optional("model") +
        optional("horizon") + optional("season") +
        '><div class="rn-od-controls"></div><p class="rn-od-status rn-muted"></p></div>';
    }
    // ::api-query — the generic REST connector. https only, refused here at
    // the border; the label, when present, is the reactive key a scalar pick
    // writes. Structure only, as ever.
    if (token.name === "api-query") {
      const url = value(token.attrs, "url");
      if (url === null || !url.startsWith("https://")) {
        return '<p class="rn-error">' + escapeHtml(token.raw.trim()) +
          " — api-query needs url=&quot;https://…&quot;</p>";
      }
      const into = value(token.attrs, "into");
      const storeKey = token.label ? token.label.trim() : "";
      if (into === null && storeKey === "") {
        return '<p class="rn-error">' + escapeHtml(token.raw.trim()) +
          " — api-query needs into=&quot;collection&quot;, or a [storekey] with a scalar pick</p>";
      }
      const optional = (name, given) =>
        given === null ? "" : " data-rn-api-" + name + '="' + escapeHtml(given) + '"';
      return '<div class="rn-od rn-api" data-rn-api data-rn-api-url="' + escapeHtml(url) + '"' +
        (into === null ? "" : ' data-rn-api-into="' + escapeHtml(into) + '"') +
        (storeKey === "" ? "" : ' data-rn-api-key="' + escapeHtml(storeKey) + '"') +
        optional("pick", value(token.attrs, "pick")) +
        (value(token.attrs, "as") === "pairs" ? " data-rn-api-pairs" : "") +
        optional("every", value(token.attrs, "every")) +
        '><div class="rn-od-controls"></div><p class="rn-od-status rn-muted"></p></div>';
    }
    // The open-data directives. Structure only, as ever: the fetch, the words of
    // the status line and the search box all belong to shell/OpenDataBinder —
    // this DOM is sanitiser output and the renderer has no locale and no network.
    if (token.name === "od-query" || token.name === "od-datasets" || token.name === "od-search") {
      const into = value(token.attrs, "into");
      if (into === null) {
        return '<p class="rn-error">' + escapeHtml(token.raw.trim()) +
          " — needs into=&quot;collection&quot;</p>";
      }
      if (token.name === "od-query" && value(token.attrs, "sql") === null) {
        return '<p class="rn-error">' + escapeHtml(token.raw.trim()) +
          " — od-query needs sql=&quot;SELECT …&quot;</p>";
      }
      const optional = (name, given) =>
        given === null ? "" : " data-rn-od-" + name + '="' + escapeHtml(given) + '"';
      return '<div class="rn-od" data-rn-od="' + token.name.slice(3) +
        '" data-rn-od-into="' + escapeHtml(into) + '"' +
        optional("sql", value(token.attrs, "sql")) +
        optional("limit", value(token.attrs, "limit")) +
        optional("placeholder", value(token.attrs, "placeholder")) +
        optional("table", value(token.attrs, "table")) +
        '><div class="rn-od-controls"></div><p class="rn-od-status rn-muted"></p></div>';
    }
    // add-form is the name this had before the form became the thing you write it
    // inside; both are accepted so documents written under the old name still run.
    if (token.name === "save" || token.name === "add-form") {
      const form = value(token.attrs, "form");
      const path = value(token.attrs, "path");
      return '<button type="button" class="rn-form-save" data-rn-add' +
        (form === null ? "" : '="' + escapeHtml(form) + '"') +
        (path === null ? "" : ' data-rn-path="' + escapeHtml(path) + '"') + ">" +
        escapeHtml(value(token.attrs, "label") || "Add") + "</button>";
    }
    return null;
  };

  const renderLeaf = (token) => {
    const fromData = dataLeaf(token);
    if (fromData !== null) return fromData;
    const component = components.get(token.name);
    if (component) return renderSpectrum(component, token, "");
    if (token.name !== "slider") {
      return '<p class="rn-directive-unknown">' + escapeHtml(token.raw.trim()) + "</p>";
    }
    // The label is the *store key* the control writes to — a bare id, never a #ref.
    // A slider that emits nowhere has no effect at all, so it is an error.
    const key = token.label.trim();
    if (key === "") {
      return '<p class="rn-error">' + escapeHtml(token.raw.trim()) +
        " — slider needs a key, as ::slider[key]</p>";
    }
    const attr = (name, fallback) => {
      const found = value(token.attrs, name);
      return found === null ? fallback : found;
    };
    const legend = value(token.attrs, "legend");
    const inputId = "rn-slider-" + key;
    // A control with no accessible name is unusable with a screen reader, so a
    // missing legend falls back to the key the control writes to rather than
    // shipping an unlabelled slider.
    return '<div class="rn-slider">' +
      (legend === null
        ? ""
        : '<label class="rn-slider-legend" for="' + escapeHtml(inputId) + '">' +
          escapeHtml(legend) + "</label>") +
      '<input type="range"' +
      (legend === null ? ' aria-label="' + escapeHtml(key) + '"' : "") +
      ' id="' + escapeHtml(inputId) +
      '" data-reactive-source="' + escapeHtml(key) +
      '" min="' + escapeHtml(attr("min", "0")) +
      '" max="' + escapeHtml(attr("max", "100")) +
      '" step="' + escapeHtml(attr("step", "1")) +
      '" value="' + escapeHtml(attr("value", "0")) + '" />' +
      "</div>";
  };

  const renderContainer = function (token) {
    const body = this.parser.parse(token.tokens);
    const fromData = dataContainer(token, body);
    if (fromData !== null) return fromData;
    const component = components.get(token.name);
    if (component) return renderSpectrum(component, token, body);
    // Same principle as inline: keep the content, mark what it was meant to be.
    return '<div class="rn-directive-unknown" data-directive="' +
      escapeHtml(token.name) + '">' + body + "</div>";
  };

  marked.use({
    extensions: [
      {
        name: "reactiveInline",
        level: "inline",
        start(src) {
          const at = src.search(/:[A-Za-z]/);
          return at === -1 ? undefined : at;
        },
        tokenizer(src) {
          // The negative lookahead keeps :: and ::: for the block forms, and
          // requiring a letter after the colon keeps "10:30" and "https://" out.
          const rule = /^:(?!:)([A-Za-z][A-Za-z0-9_-]*)(?:\[([^\]]*)\])?(?:\{((?:"[^"]*"|'[^']*'|[^}])*)\})?/;
          const match = rule.exec(src);
          if (!match) return undefined;
          return {
            type: "reactiveInline",
            raw: match[0],
            name: match[1],
            label: match[2] === undefined ? "" : match[2],
            attrs: match[3] === undefined ? "" : match[3],
          };
        },
        renderer: renderInline,
      },
      // One block form, matching the scanner in core/: ::name{…} opens a block and
      // a ::/name below it — if there is one — makes it a container. Two separate
      // tokenizers cannot express that, because the leaf one would consume the
      // opening line before the container one ever saw it.
      {
        name: "reactiveBlock",
        level: "block",
        start(src) {
          const at = src.search(/^::[A-Za-z]/m);
          return at === -1 ? undefined : at;
        },
        tokenizer(src) {
          const opening =
            /^::(?!:)([A-Za-z][A-Za-z0-9_-]*)(?:\[([^\]]*)\])?(?:\{((?:"[^"]*"|'[^']*'|[^}])*)\})?[ \t]*(?:\n|$)/.exec(src);
          if (!opening) return undefined;
          const name = opening[1];
          const lines = src.split("\n");
          // Depth is counted per name, so a form inside a form still ends at its own
          // close. Names are [A-Za-z][A-Za-z0-9_-]*, which carries nothing a regular
          // expression would read as syntax.
          const opener = new RegExp("^::(?!:)" + name + "(?:\\[|\\{|[ \\t]*$)");
          const closer = new RegExp("^::/" + name + "[ \\t]*$");
          let depth = 0;
          let closes = -1;
          for (let i = 1; i < lines.length; i++) {
            const line = lines[i].trimEnd();
            if (closer.test(line)) {
              if (depth === 0) { closes = i; break; }
              depth--;
            } else if (opener.test(line)) depth++;
          }

          const token = {
            type: "reactiveBlock",
            container: closes !== -1,
            name,
            label: opening[2] === undefined ? "" : opening[2],
            attrs: opening[3] === undefined ? "" : opening[3],
          };
          // Nobody closed it, so it is a leaf. The two are the same line; only the
          // close tells them apart.
          if (closes === -1) {
            token.raw = opening[0];
            return token;
          }
          token.raw = lines.slice(0, closes + 1).join("\n") + "\n";
          token.tokens = this.lexer.blockTokens(lines.slice(1, closes).join("\n"), []);
          return token;
        },
        renderer: function (token) {
          return token.container ? renderContainer.call(this, token) : renderLeaf(token);
        },
      },
    ],
  });
}
`)

installDirectives(
  DirectiveAttributes.attribute,
  ReactiveRef.reactiveKey,
  DirectiveAttributes.parse,
  DirectiveRegistry.all,
)

let toHtml: string => string = %raw(`
function (source) {
  try {
    return marked.parse(source, { async: false });
  } catch (error) {
    return '<p class="rn-error">Markdown could not be rendered: ' +
      String(error && error.message ? error.message : error) + "</p>";
  }
}
`)
