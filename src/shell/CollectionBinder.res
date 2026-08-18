// Binds the data directives to an app's stored collections, after every preview
// render — the same shape as `ReactiveStore`, and for the same reason: the markdown
// pipeline produces sanitised, inert DOM, and everything that reads or writes storage
// happens afterwards, on nodes the sanitiser has already approved.
//
// Two rules hold the security story together and neither is decoration:
//
//   - A row is written into the document through `textContent`, never `innerHTML`.
//     The values come from whatever someone typed into a form, so a template that
//     built markup would turn every stored value into a scripting vector. Cloning the
//     template and substituting into text nodes means a row containing `<script>` is
//     a row that displays those characters.
//   - The app id comes from the frontmatter, and every key is built by
//     `CollectionKey`, so a document can only ever reach its own namespace.
//
// The decisions — which fields a template refers to, what a new row's id is — live in
// `core/`. What is left here is the DOM and the promises.

type helpers = {
  read: (~app: string, ~path: string) => promise<Collection.t>,
  write: (~app: string, ~path: string, Collection.t) => promise<unit>,
  insert: (Collection.t, Collection.record) => Collection.t,
  remove: (Collection.t, string) => Collection.t,
  update: (Collection.t, string, array<Collection.field>) => Collection.t,
  find: (Collection.t, string) => option<Collection.record>,
  makeId: (~stamp: string, ~taken: array<string>) => string,
  fill: (
    string,
    Collection.record,
    string,
    (string, string, string) => option<string>,
  ) => string,
  timestamp: unit => string,
  aggregate: (string, Collection.t, string, option<int>) => option<string>,
  stamp: (array<Collection.field>, string, option<string>) => array<Collection.field>,
  createdOf: Collection.record => option<string>,
  // What a view shows of a collection, decided in core/RowView and asked for by both
  // the list and the table — they differ in how a row is drawn, not in which rows.
  arrange: (
    array<Collection.record>,
    ~fields: array<string>,
    ~query: string,
    ~filters: array<string>,
    ~sort: string,
    ~dir: string,
    ~limit: int,
  ) => array<Collection.record>,
  /** The distinct values a column holds, which is what a reader is offered. */
  choices: (array<Collection.record>, string) => array<string>,
  // The two-dimensional grid, decided in core/TimeGrid: which values each axis has,
  // and which records fall in each cell. Positional, like `arrange` above, because
  // that is what labelled arguments compile to.
  grid: (
    array<Collection.record>,
    string,
    string,
    string,
    string,
    string,
    string,
  ) => TimeGrid.t,
  /** The forbidden cells, read out of an ordinary collection a validator writes. */
  blocks: array<Collection.record> => array<TimeGrid.block>,
  /** Why this record may not go in that cell, or nothing when it may. */
  refusal: (array<TimeGrid.block>, string, string, string) => option<string>,
  /** Whether the cell is spoken for by some *other* record. */
  warned: (array<TimeGrid.block>, string, string, string) => bool,
  /** Whether a record is pinned by the field named — a lesson somebody fixed. */
  pinned: (Collection.record, string) => bool,
  // The month grid, and the words around it. The arithmetic is pure and tested; the
  // names are the reader's language and can only be asked for per render.
  weeks: (int, int, bool) => array<array<MonthGrid.day>>,
  weekDays: (string, bool) => array<MonthGrid.day>,
  shiftDays: (string, int) => string,
  monthStep: (int, int, int) => (int, int),
  dayOf: string => option<string>,
  covers: (string, string, string) => bool,
  monthOf: string => option<(int, int)>,
  monthLabel: (int, int, string) => string,
  weekdayNames: (string, bool) => array<string>,
  paginate: (array<Collection.record>, int, int) => array<Collection.record>,
  pageCount: (int, int) => int,
  group: (array<Collection.record>, string) => array<(string, array<Collection.record>)>,
  valueOf: (Collection.record, string) => string,
  localize: (string, string) => string,
  // What a draft holds and whether it may be saved, decided in core/Draft. The
  // messages are built here rather than there because a complaint is words, and the
  // locale is only known per render.
  reading: Draft.control => string,
  blank: array<Draft.control> => bool,
  /** The collections a row template reaches into, so they are read before it draws. */
  referenced: string => array<string>,
  /** The device-local content of a large ::file attachment, by id. */
  localFile: (string, string) => promise<option<string>>,
  validate: (array<Draft.control>, string) => array<{"field": string, "message": string}>,
}

type labels = {
  deleteRow: string,
  editRow: string,
  searchRows: string,
  previousPage: string,
  nextPage: string,
  sortedAscending: string,
  sortedDescending: string,
  allValues: string,
  previousMonth: string,
  nextMonth: string,
  previousWeek: string,
  nextWeek: string,
  today: string,
  // What a timetable says when a drop is refused and the author wrote no reason of
  // their own, and what marks a card nobody may move.
  blockedCell: string,
  pinnedRow: string,
}

let install: helpers => (Dom.element, string, labels, string, string => promise<bool>) => unit = %raw(`
function (helpers) {
  // Every container currently bound, so a re-render replaces its handlers rather than
  // stacking a second copy on the same node.
  const bound = new WeakSet();

  // The parameters of each container's most recent bind, read by the one rn:data
  // listener it keeps for its whole life.
  const latest = new WeakMap();

  const pathsIn = (container) => {
    const found = new Set();
    for (const node of container.querySelectorAll(
      "[data-rn-list],[data-rn-table],[data-rn-board],[data-rn-calendar],[data-rn-timetable]," +
      "[data-rn-when],[data-rn-count],[data-rn-aggregate]"
    )) {
      const path = node.getAttribute("data-rn-list") || node.getAttribute("data-rn-table") ||
        node.getAttribute("data-rn-board") || node.getAttribute("data-rn-calendar") ||
        node.getAttribute("data-rn-timetable") ||
        node.getAttribute("data-rn-path") || node.getAttribute("data-rn-count");
      if (path) found.add(path);
      // The forbidden cells are a collection of their own, and one nothing else in the
      // document need mention: a timetable that never read it would refuse nothing.
      const blocked = node.getAttribute("data-rn-tt-blocked");
      if (blocked) found.add(blocked);
    }
    // A field that points at another collection, and a template that shows a value
    // from one: both need that collection read before anything can be drawn.
    for (const select of container.querySelectorAll("[data-rn-ref]")) {
      const path = select.getAttribute("data-rn-ref");
      if (path) found.add(path);
    }
    // ::choose likewise — and it is the one directive whose collection may be
    // mentioned NOWHERE else in the document: a dropdown of comuni exists to steer a
    // query over something else entirely, so nothing here would read it otherwise and
    // the control would render with no options at all.
    for (const select of container.querySelectorAll("[data-rn-choose]")) {
      const path = select.getAttribute("data-rn-choose");
      if (path) found.add(path);
    }
    for (const template of container.querySelectorAll(".rn-list-template")) {
      for (const path of helpers.referenced(template.textContent || "")) found.add(path);
    }
    return [...found];
  };

  // A ::file value, recognised where it lands: a small JSON of {name, data}
  // or {name, local}. Only data: URLs are ever rendered — a stored value that
  // claims another scheme is somebody probing, and shows as its characters.
  const fileValue = (text) => {
    const candidate = text.trim();
    if (!candidate.startsWith('{"')) return null;
    try {
      const parsed = JSON.parse(candidate);
      if (typeof parsed.name !== "string") return null;
      if (typeof parsed.data === "string" && parsed.data.startsWith("data:"))
        return { name: parsed.name, data: parsed.data };
      if (typeof parsed.local === "string") return { name: parsed.name, local: parsed.local };
      return null;
    } catch {
      return null;
    }
  };

  const fileLink = (name, dataUrl) => {
    const link = document.createElement("a");
    link.href = dataUrl;
    link.download = name;
    link.className = "rn-file";
    if (dataUrl.startsWith("data:image/")) {
      const image = document.createElement("img");
      image.src = dataUrl;
      image.alt = name;
      image.className = "rn-file-image";
      image.loading = "lazy";
      link.appendChild(image);
    } else {
      link.textContent = name;
    }
    return link;
  };

  const fileElement = (found, app) => {
    if (found.data) return fileLink(found.name, found.data);
    // A device-local file: the name always, the content when THIS device has
    // it — resolved after the fact, because IndexedDB does not answer inline.
    const holder = document.createElement("span");
    holder.className = "rn-file";
    holder.textContent = found.name;
    helpers.localFile(app, found.local).then((dataUrl) => {
      if (dataUrl !== undefined && holder.isConnected) holder.replaceWith(fileLink(found.name, dataUrl));
    });
    return holder;
  };

  // Substitution walks text nodes only — see the note above.
  const applyTemplate = (element, record, locale, collections, app) => {
    const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
    const texts = [];
    while (walker.nextNode()) texts.push(walker.currentNode);
    // A relation is resolved against what this render already read, so a list showing
    // a referenced name costs no extra reads however many rows it draws.
    const resolve = (path, id, label) => {
      const collection = collections && collections[path];
      if (!collection) return undefined;
      const found = helpers.find(collection, id);
      if (found === undefined) return undefined;
      const value = helpers.valueOf(found, label);
      return value === "" ? undefined : value;
    };
    for (const text of texts) {
      const filled = helpers.fill(text.nodeValue, record, locale, resolve);
      // A file shows as itself — preview or named download — not as its JSON.
      const found = fileValue(filled);
      if (found) {
        text.parentNode.replaceChild(fileElement(found, app), text);
      } else if (filled !== text.nodeValue) {
        text.nodeValue = filled;
      }
    }
  };

  // The row actions are built here rather than emitted by the renderer, because the
  // renderer writes one template and there is one button per row.
  const rowAction = (className, label, symbol, attribute, id) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = className;
    button.setAttribute("aria-label", label);
    button.setAttribute("title", label);
    button.setAttribute(attribute, id);
    button.textContent = symbol;
    return button;
  };

  // What a view asks core/RowView for, read off the node. A missing attribute is the
  // neutral answer — no filter, no sort, no limit — so a view with none of them shows
  // the collection as stored.
  // Positional, because that is what a ReScript function with labelled arguments
  // compiles to — an object here would arrive as the first argument and everything
  // else as undefined.
  // The author's filter and the reader's are the same kind of thing and are applied
  // the same way; they are two filters, not a filter and an exception to it.
  //
  // The author's filter may name a reactive key — filter="classe=#classeSel" — and
  // then the view follows whatever that key holds. It is resolved HERE, in the one
  // funnel every row-reading view goes through, so a list, a table, a board and a
  // timetable cannot disagree about what a filter means. A filter with no # in it
  // never touches the store.
  const withKeys = (expression) =>
    expression.indexOf("#") === -1
      ? expression
      : expression.replace(/#([A-Za-z0-9_-]+)/g, (whole, key) => {
          const store = globalThis.__rnReactive;
          const held = store ? store.values.get(key) : undefined;
          return held === undefined || held === null ? "" : held;
        });

  const arrangeFor = (node, records, fields, query, sort, dir, chosen) =>
    helpers.arrange(
      // A dashboard's cross-filter comes first, before the view's own filter,
      // search and sort: it narrows what the view is *of*, exactly as if the
      // collection had fewer rows. Outside a dashboard this is the identity.
      globalThis.__rnDashboard ? globalThis.__rnDashboard.rowsFor(node, records) : records,
      fields,
      query || "",
      [withKeys(node.getAttribute("data-rn-filter") || "")].concat(chosen || []),
      sort !== undefined ? sort : node.getAttribute("data-rn-sort") || "",
      dir !== undefined ? dir : node.getAttribute("data-rn-dir") || "",
      Number(node.getAttribute("data-rn-limit")) || 0
    );

  // Which columns a table lets the reader narrow by, in the order they were named.
  const filterFields = (node) =>
    (node.getAttribute("data-rn-filters") || "")
      .split(",")
      .map((name) => name.trim())
      .filter(Boolean);

  const chosenFilters = (node, state) =>
    filterFields(node)
      .map((field) => (state.filters[field] ? field + "=" + state.filters[field] : ""))
      .filter(Boolean);

  // Every field a row carries, so a search with no columns to go on still has
  // something to look in.
  const fieldsOfRecords = (records) => {
    const found = [];
    for (const record of records) {
      for (const entry of record.fields) if (!found.includes(entry.name)) found.push(entry.name);
    }
    return found;
  };

  const rowActions = (labels, deletable, editform, id) => {
    if (!deletable && !editform) return null;
    const actions = document.createElement("div");
    actions.className = "rn-list-row-actions";
    if (editform) {
      actions.appendChild(rowAction("rn-row-edit", labels.editRow, "✎", "data-rn-edit", id));
    }
    if (deletable) {
      actions.appendChild(rowAction("rn-row-delete", labels.deleteRow, "×", "data-rn-delete", id));
    }
    return actions;
  };

  const renderList = (node, collection, labels, locale, collections, app) => {
    const template = node.querySelector(":scope > .rn-list-template");
    const rows = node.querySelector(":scope > .rn-list-rows");
    if (!template || !rows) return;
    const deletable = node.hasAttribute("data-rn-deletable");
    const editform = node.getAttribute("data-rn-editform");
    rows.textContent = "";

    const arranged = arrangeFor(
      node, collection.records, fieldsOfRecords(collection.records), "", undefined, undefined, []
    );
    const drawRow = (record) => {
      const row = template.cloneNode(true);
      row.removeAttribute("hidden");
      row.className = "rn-list-row";
      applyTemplate(row, record, locale, collections, app);
      const actions = rowActions(labels, deletable, editform, record.id);
      if (actions) row.appendChild(actions);
      rows.appendChild(row);
    };

    const groupBy = node.getAttribute("data-rn-group-by") || "";
    if (groupBy === "") {
      for (const record of arranged) drawRow(record);
      return;
    }
    // A heading per group, and the rows under it. The heading is text, like every
    // other stored value that reaches the document.
    for (const [name, members] of helpers.group(arranged, groupBy)) {
      const heading = document.createElement("p");
      heading.className = "rn-list-group";
      heading.textContent = name;
      rows.appendChild(heading);
      for (const record of members) drawRow(record);
    }
  };

  // A board: the rows in columns, one per value of a field. Moving a card between
  // columns is not a rearrangement — it writes that field on that row, which is the
  // only reason a board is worth having over a grouped list.
  //
  // The drag is the HTML one. It works with a mouse and with a keyboard's context
  // menu where the platform provides one, and not at all on touch — which is why the
  // card's own edit button stays: dragging is the fast way, not the only way.
  const renderBoard = (node, collection, labels, locale, collections, app) => {
    const template = node.querySelector(":scope > .rn-list-template");
    const host = node.querySelector(":scope > .rn-board-columns");
    if (!template || !host) return;
    const field = node.getAttribute("data-rn-group-by") || "";
    const deletable = node.hasAttribute("data-rn-deletable");
    const editform = node.getAttribute("data-rn-editform");
    const arranged = arrangeFor(
      node, collection.records, fieldsOfRecords(collection.records), "", undefined, undefined, []
    );

    // The columns the author named, then any value that turned up and was not among
    // them: a card is never hidden because nobody predicted its value.
    const named = (node.getAttribute("data-rn-board-columns") || "")
      .split(",").map((name) => name.trim()).filter(Boolean);
    const present = helpers.group(arranged, field).map(([name]) => name);
    const columns = named.concat(present.filter((name) => !named.includes(name)));

    host.textContent = "";
    for (const name of columns) {
      const column = document.createElement("section");
      column.className = "rn-board-column";
      column.setAttribute("data-rn-board-value", name);
      const heading = document.createElement("h3");
      heading.className = "rn-board-heading";
      // The empty name is the column of rows nobody has filed yet; it is labelled
      // with the placeholder rather than left blank, which would read as a bug.
      heading.textContent = name === "" ? "—" : name;
      const count = document.createElement("span");
      count.className = "rn-board-count";
      const members = arranged.filter((record) => helpers.valueOf(record, field) === name);
      count.textContent = String(members.length);
      heading.appendChild(count);
      column.appendChild(heading);

      for (const record of members) {
        const card = template.cloneNode(true);
        card.removeAttribute("hidden");
        card.className = "rn-list-row rn-board-card";
        card.setAttribute("draggable", "true");
        card.setAttribute("data-rn-card", record.id);
        applyTemplate(card, record, locale, collections, app);
        const actions = rowActions(labels, deletable, editform, record.id);
        if (actions) card.appendChild(actions);
        column.appendChild(card);
      }
      host.appendChild(column);
    }
  };

  // Attached once per board, because the columns and cards are rebuilt on every
  // refresh and per-card handlers would pile up behind them.
  const boardDragging = (node, path, container, app, labels, locale) => {
    node.addEventListener("dragstart", (event) => {
      const card = event.target.closest("[data-rn-card]");
      if (!card) return;
      event.dataTransfer.setData("text/plain", card.getAttribute("data-rn-card"));
      event.dataTransfer.effectAllowed = "move";
      card.classList.add("rn-board-card-moving");
    });
    node.addEventListener("dragend", (event) => {
      const card = event.target.closest("[data-rn-card]");
      if (card) card.classList.remove("rn-board-card-moving");
    });
    node.addEventListener("dragover", (event) => {
      const column = event.target.closest("[data-rn-board-value]");
      if (!column) return;
      // Without this the browser refuses the drop, and the card springs back with no
      // explanation.
      event.preventDefault();
      event.dataTransfer.dropEffect = "move";
      column.classList.add("rn-board-column-over");
    });
    node.addEventListener("dragleave", (event) => {
      const column = event.target.closest("[data-rn-board-value]");
      if (column && !column.contains(event.relatedTarget)) {
        column.classList.remove("rn-board-column-over");
      }
    });
    node.addEventListener("drop", (event) => {
      const column = event.target.closest("[data-rn-board-value]");
      if (!column) return;
      event.preventDefault();
      column.classList.remove("rn-board-column-over");
      const id = event.dataTransfer.getData("text/plain");
      const field = node.getAttribute("data-rn-group-by") || "";
      const wanted = column.getAttribute("data-rn-board-value");
      if (!id || field === "") return;
      helpers.read(app, path).then((collection) => {
        const record = helpers.find(collection, id);
        if (record === undefined) return;
        if (helpers.valueOf(record, field) === wanted) return;
        // The field is rewritten and everything else kept, stamps included: moving a
        // card is an edit of one field, so updatedAt moves and createdAt does not.
        const fields = record.fields
          .filter((entry) => entry.name !== field)
          .concat([{ name: field, value: wanted }]);
        const stamped = helpers.stamp(fields, helpers.timestamp(), helpers.createdOf(record));
        return helpers.write(app, path, helpers.update(collection, id, stamped))
          .then(() => refresh(container, app, labels, locale));
      });
    });
  };

  // Every view's own state — a table's query, sort and page, a calendar's shown
  // month — kept per *container*, keyed by the view's position in it. The node is the
  // one thing it must not be keyed by: setInnerHtml recreates every node on each
  // debounced render, so state hung on a node evaporated on every keystroke beside
  // the editor. The container is React's and survives; PageNav keys its choice the
  // same way, and the earlier claim of parity with it was written before checking.
  const viewState = new WeakMap();

  const stateFor = (container, key, make) => {
    let states = viewState.get(container);
    if (states === undefined) {
      states = new Map();
      viewState.set(container, states);
    }
    let state = states.get(key);
    if (state === undefined) {
      state = make();
      states.set(key, state);
    }
    return state;
  };

  // The view's address inside its container: kind plus position, so two tables over
  // the same path keep separate pages.
  const viewKey = (container, node, marker) =>
    marker + ":" + [...container.querySelectorAll("[" + marker + "]")].indexOf(node);

  // The calendar, in its four views. One placement pass — a row is a point or
  // a span — then the view decides the shape: the month grid, one taller week,
  // the agenda's chronological list, or the matrix whose columns are the
  // values of by=. Everything the reader steers (which month, which week)
  // lives in per-position state and survives the render.
  const CAL_PALETTE = ["#0072B2", "#E69F00", "#009E73", "#CC79A7", "#56B4E9", "#D55E00", "#F0E442", "#999999"];

  const renderCalendar = (node, collection, labels, locale, collections, container, app) => {
    const template = node.querySelector(":scope > .rn-list-template");
    const host = node.querySelector(":scope > .rn-calendar-body");
    if (!template || !host) return;
    const from = node.getAttribute("data-rn-from-field") || "";
    const to = node.getAttribute("data-rn-to-field") || "";
    const startsMonday = !node.hasAttribute("data-rn-sunday");
    const view = node.getAttribute("data-rn-view") || "month";
    const by = node.getAttribute("data-rn-by") || "";
    const timeField = node.getAttribute("data-rn-time-field") || "";
    const dayForm = node.getAttribute("data-rn-day-form") || "";
    const tooltip = node.getAttribute("data-rn-tooltip");

    const today = helpers.dayOf(helpers.timestamp());
    // Opens on today; from then on, wherever the reader steered it. anchor
    // is the week view's cursor, kept in step when the month arrows move.
    const state = stateFor(container, viewKey(container, node, "data-rn-calendar"), () => {
      const now = helpers.monthOf(helpers.timestamp()) || [2026, 1];
      return { year: now[0], month: now[1], anchor: today };
    });
    if (!state.anchor) state.anchor = today;

    const arranged = arrangeFor(
      node, collection.records, fieldsOfRecords(collection.records), "", undefined, undefined, []
    );
    // A row is a point or a span. Given an end it is on every day from one
    // date to the other, and each day knows whether the span starts, ends, or
    // merely passes through.
    const placed = [];
    const byValues = [];
    for (const record of arranged) {
      const starts = from === "" ? undefined : helpers.dayOf(helpers.valueOf(record, from));
      if (starts === undefined) continue;
      const ends = to === "" ? "" : helpers.dayOf(helpers.valueOf(record, to)) || "";
      const group = by === "" ? "" : helpers.valueOf(record, by);
      if (by !== "" && !byValues.includes(group)) byValues.push(group);
      placed.push({ record, starts, ends, group });
    }
    const colourOf = (group) => CAL_PALETTE[Math.max(0, byValues.indexOf(group)) % CAL_PALETTE.length];
    const entriesOn = (day) => {
      const found = placed.filter((entry) => helpers.covers(day, entry.starts, entry.ends));
      // Inside the day the clock decides, when there is one (HH:MM compares
      // as text); rows without one keep their stored order, stably.
      if (timeField !== "") {
        found.sort((a, b) => {
          const ta = helpers.valueOf(a.record, timeField);
          const tb = helpers.valueOf(b.record, timeField);
          return ta < tb ? -1 : ta > tb ? 1 : 0;
        });
      }
      return found;
    };

    const rerender = () =>
      renderCalendar(node, collection, labels, locale, collections, container, app);

    host.textContent = "";

    const header = document.createElement("div");
    header.className = "rn-calendar-header";
    const step = (direction) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "rn-calendar-step";
      const text = view === "week"
        ? (direction < 0 ? labels.previousWeek : labels.nextWeek)
        : (direction < 0 ? labels.previousMonth : labels.nextMonth);
      button.setAttribute("aria-label", text);
      button.title = text;
      button.textContent = direction < 0 ? "\u2039" : "\u203a";
      button.addEventListener("click", () => {
        if (view === "week") {
          state.anchor = helpers.shiftDays(state.anchor, direction * 7);
          const landed = helpers.monthOf(state.anchor);
          if (landed) { state.year = landed[0]; state.month = landed[1]; }
        } else {
          const moved = helpers.monthStep(state.year, state.month, direction);
          state.year = moved[0];
          state.month = moved[1];
          state.anchor = String(state.year).padStart(4, "0") + "-" + String(state.month).padStart(2, "0") + "-01";
        }
        rerender();
      });
      return button;
    };
    const title = document.createElement("span");
    title.className = "rn-calendar-title";
    const weekOf = view === "week" ? helpers.weekDays(state.anchor, startsMonday) : null;
    title.textContent = view === "week" && weekOf.length === 7
      ? helpers.localize(weekOf[0].date, locale) + " \u2013 " + helpers.localize(weekOf[6].date, locale)
      : helpers.monthLabel(state.year, state.month, locale);
    // Today: the way back to the present, which the arrows only ever leave.
    const home = document.createElement("button");
    home.type = "button";
    home.className = "rn-calendar-step rn-calendar-today-button";
    home.textContent = labels.today;
    home.addEventListener("click", () => {
      const now = helpers.monthOf(helpers.timestamp()) || [state.year, state.month];
      state.year = now[0];
      state.month = now[1];
      state.anchor = today;
      rerender();
    });
    header.append(step(-1), title, home, step(1));
    host.appendChild(header);

    // The legend, when values carry colours and the matrix is not already
    // saying it with its column headings.
    if (by !== "" && view !== "matrix" && byValues.length > 0) {
      const legend = document.createElement("div");
      legend.className = "rn-calendar-legend";
      for (const group of byValues) {
        const item = document.createElement("span");
        item.className = "rn-calendar-legend-item";
        const dot = document.createElement("span");
        dot.className = "rn-calendar-legend-dot";
        dot.style.setProperty("background", colourOf(group));
        item.append(dot, document.createTextNode(group === "" ? "\u2014" : group));
        legend.appendChild(item);
      }
      host.appendChild(legend);
    }

    // Every event carries its row as a tooltip — automatic, template-driven,
    // or off. The title attribute is words, which is all a row is.
    const tooltipOf = (record) => {
      if (tooltip === "false") return null;
      if (tooltip !== null && tooltip !== "") return helpers.fill(tooltip, record, locale, () => undefined);
      return record.fields
        .map((field) => field.name + ": " + helpers.localize(field.value, locale))
        .join("\n");
    };

    const makeEntry = (placement, day) => {
      const entry = template.cloneNode(true);
      entry.removeAttribute("hidden");
      entry.className = "rn-list-row rn-calendar-entry";
      const spans = placement.ends !== "" && placement.ends !== placement.starts;
      if (spans) {
        entry.classList.add("rn-calendar-span");
        if (day === placement.starts) entry.classList.add("rn-calendar-span-start");
        if (day === placement.ends) entry.classList.add("rn-calendar-span-end");
      }
      if (by !== "") {
        entry.style.setProperty("border-inline-start", "3px solid " + colourOf(placement.group));
        entry.style.setProperty("background", colourOf(placement.group) + "22");
      }
      const said = tooltipOf(placement.record);
      if (said !== null) entry.title = said;
      applyTemplate(entry, placement.record, locale, collections, app);
      return entry;
    };

    // "Click the 12th to book": the day fills the form's date field and brings
    // the form into view. Keyboard-reachable, because a click always is here.
    const wireDayPick = (cell, day) => {
      if (dayForm === "") return;
      cell.classList.add("rn-calendar-clickable");
      cell.setAttribute("tabindex", "0");
      cell.setAttribute("role", "button");
      cell.setAttribute("aria-label", helpers.localize(day, locale));
      const pick = () => {
        const form = container.querySelector('[data-rn-form="' + dayForm + '"]');
        if (!form) return;
        const input = form.querySelector('input[type="date"].rn-field-input') ||
          form.querySelector(".rn-field-input");
        if (!input) return;
        input.value = day;
        input.dispatchEvent(new Event("input", { bubbles: true }));
        form.scrollIntoView({ behavior: "smooth", block: "center" });
      };
      cell.addEventListener("click", (event) => {
        if (event.target.closest(".rn-calendar-entry")) return;
        pick();
      });
      cell.addEventListener("keydown", (event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          pick();
        }
      });
    };

    const dayCell = (day) => {
      const cell = document.createElement("div");
      cell.className = "rn-calendar-day";
      if (!day.inMonth) cell.classList.add("rn-calendar-outside");
      if (day.date === today) cell.classList.add("rn-calendar-today");
      const number = document.createElement("span");
      number.className = "rn-calendar-number";
      number.textContent = String(day.number);
      cell.appendChild(number);
      for (const placement of entriesOn(day.date)) cell.appendChild(makeEntry(placement, day.date));
      wireDayPick(cell, day.date);
      return cell;
    };

    if (view === "agenda") {
      // The month as a reading list: only the days that have something to say.
      const agenda = document.createElement("div");
      agenda.className = "rn-calendar-agenda";
      for (const week of helpers.weeks(state.year, state.month, startsMonday)) {
        for (const day of week) {
          if (!day.inMonth) continue;
          const entries = entriesOn(day.date);
          if (entries.length === 0) continue;
          const block = document.createElement("div");
          block.className = "rn-calendar-agenda-day";
          if (day.date === today) block.classList.add("rn-calendar-today");
          const heading = document.createElement("h4");
          heading.className = "rn-calendar-agenda-heading";
          heading.textContent = helpers.localize(day.date, locale);
          block.appendChild(heading);
          for (const placement of entries) block.appendChild(makeEntry(placement, day.date));
          wireDayPick(block, day.date);
          agenda.appendChild(block);
        }
      }
      host.appendChild(agenda);
      return;
    }

    if (view === "matrix") {
      // Rows are days, columns the values of by= — the planner for rooms and
      // shifts. A real table: the day/value relationships are what a screen
      // reader announces, and that is the point of this view.
      const table = document.createElement("table");
      table.className = "rn-calendar-matrix";
      const head = document.createElement("thead");
      const headRow = document.createElement("tr");
      headRow.appendChild(document.createElement("th"));
      for (const group of byValues) {
        const th = document.createElement("th");
        th.scope = "col";
        th.textContent = group === "" ? "\u2014" : group;
        headRow.appendChild(th);
      }
      head.appendChild(headRow);
      table.appendChild(head);
      const bodyEl = document.createElement("tbody");
      for (const week of helpers.weeks(state.year, state.month, startsMonday)) {
        for (const day of week) {
          if (!day.inMonth) continue;
          const row = document.createElement("tr");
          if (day.date === today) row.className = "rn-calendar-today";
          const th = document.createElement("th");
          th.scope = "row";
          th.textContent = String(day.number);
          wireDayPick(th, day.date);
          row.appendChild(th);
          const entries = entriesOn(day.date);
          for (const group of byValues) {
            const td = document.createElement("td");
            for (const placement of entries) {
              if (placement.group === group) td.appendChild(makeEntry(placement, day.date));
            }
            row.appendChild(td);
          }
          bodyEl.appendChild(row);
        }
      }
      table.appendChild(bodyEl);
      host.appendChild(table);
      return;
    }

    // month and week share the grid; the week is one row of taller cells.
    const grid = document.createElement("div");
    grid.className = view === "week" ? "rn-calendar-grid rn-calendar-week" : "rn-calendar-grid";
    for (const name of helpers.weekdayNames(locale, startsMonday)) {
      const heading = document.createElement("span");
      heading.className = "rn-calendar-weekday";
      heading.textContent = name;
      grid.appendChild(heading);
    }
    const weeksShown = view === "week"
      ? [helpers.weekDays(state.anchor, startsMonday)]
      : helpers.weeks(state.year, state.month, startsMonday);
    for (const week of weeksShown) {
      for (const day of week) grid.appendChild(dayCell(day));
    }
    host.appendChild(grid);
  };

  // A timetable: the rows of a collection on a grid of two fields, where dragging a
  // card writes BOTH of them. A board asks one question of a row and this asks two,
  // and the pair is the cell — which is the whole reason it is a directive rather
  // than a grouped list with a second heading.
  //
  // A real <table>, like the calendar's matrix and for the same reason: what a screen
  // reader announces is that this lesson is in that hour on that day, and only a table
  // carries the two relationships. The grid itself — which values the axes have, which
  // record falls where — is decided in core/TimeGrid, which has no DOM and is tested.
  const renderTimetable = (node, collection, blocked, labels, locale, collections, container, app) => {
    const template = node.querySelector(":scope > .rn-list-template");
    const host = node.querySelector(":scope > .rn-timetable-body");
    if (!template || !host) return;
    const rowField = node.getAttribute("data-rn-tt-rows") || "";
    const colField = node.getAttribute("data-rn-tt-cols") || "";
    const pinField = node.getAttribute("data-rn-tt-pin") || "";
    const colourField = node.getAttribute("data-rn-tt-colour") || "";
    const deletable = node.hasAttribute("data-rn-deletable");
    const editform = node.getAttribute("data-rn-editform");
    const state = stateFor(container, viewKey(container, node, "data-rn-timetable"), () => ({
      blocks: [],
      rowField: "",
      colField: "",
    }));

    const arranged = arrangeFor(
      node, collection.records, fieldsOfRecords(collection.records), "", undefined, undefined, []
    );
    const grid = helpers.grid(
      arranged,
      rowField,
      colField,
      node.getAttribute("data-rn-tt-row-values") || "",
      node.getAttribute("data-rn-tt-col-values") || "",
      node.getAttribute("data-rn-tt-row-labels") || "",
      node.getAttribute("data-rn-tt-col-labels") || ""
    );
    // The prohibitions are read once per render and kept in the per-position state:
    // a dragover has to answer instantly, and IndexedDB does not answer inline.
    state.blocks = helpers.blocks(blocked ? blocked.records : []);
    state.rowField = rowField;
    state.colField = colField;

    // One colour per value of colour=, in the palette the charts and the calendar
    // already use. The tint is never the only thing saying which value a card has:
    // the legend below names every colour, and the card carries the value as its
    // title — a colour on its own is a rule this project does not allow.
    const colours = colourField === "" ? [] : helpers.choices(arranged, colourField);
    const colourOf = (value) =>
      CAL_PALETTE[Math.max(0, colours.indexOf(value)) % CAL_PALETTE.length];

    host.textContent = "";
    const table = document.createElement("table");
    table.className = "rn-timetable-grid";
    const head = document.createElement("thead");
    const headRow = document.createElement("tr");
    // The corner cell names nothing, so it says nothing rather than repeating a
    // heading that belongs to the row below it.
    headRow.appendChild(document.createElement("th"));
    grid.colLabels.forEach((label) => {
      const th = document.createElement("th");
      th.scope = "col";
      th.textContent = label === "" ? "—" : label;
      headRow.appendChild(th);
    });
    head.appendChild(headRow);
    table.appendChild(head);

    const body = document.createElement("tbody");
    grid.rows.forEach((rowValue, rowIndex) => {
      const line = document.createElement("tr");
      const th = document.createElement("th");
      th.scope = "row";
      th.textContent = grid.rowLabels[rowIndex] === "" ? "—" : grid.rowLabels[rowIndex];
      line.appendChild(th);
      grid.cols.forEach((colValue, colIndex) => {
        const cell = document.createElement("td");
        cell.className = "rn-timetable-cell";
        cell.setAttribute("data-rn-cell", "");
        cell.setAttribute("data-rn-cell-row", rowValue);
        cell.setAttribute("data-rn-cell-col", colValue);
        // A cell forbidden to everyone says so before anybody drags anything: it is a
        // standing fact about the timetable, not an answer to a gesture. The glyph is
        // there because the colour must never be the only thing carrying it.
        const forbidden = helpers.refusal(state.blocks, rowValue, colValue, "");
        if (forbidden !== undefined) {
          cell.classList.add("rn-timetable-forbidden");
          const mark = document.createElement("span");
          mark.className = "rn-timetable-mark";
          mark.setAttribute("role", "img");
          mark.setAttribute("aria-label", forbidden === "" ? labels.blockedCell : forbidden);
          mark.title = forbidden === "" ? labels.blockedCell : forbidden;
          mark.textContent = "⊘";
          cell.appendChild(mark);
        }
        for (const record of grid.cells[rowIndex][colIndex]) {
          const card = template.cloneNode(true);
          card.removeAttribute("hidden");
          card.className = "rn-list-row rn-timetable-card";
          card.setAttribute("data-rn-card", record.id);
          const fixed = helpers.pinned(record, pinField);
          // Pinned means pinned: the lesson somebody fixed by hand is the one a solver
          // must not touch, so the browser is told it is not draggable rather than the
          // drop being refused after the fact.
          card.setAttribute("draggable", fixed ? "false" : "true");
          if (fixed) card.setAttribute("data-rn-pinned", "");
          if (colourField !== "") {
            const value = helpers.valueOf(record, colourField);
            card.style.setProperty("border-inline-start", "4px solid " + colourOf(value));
            card.style.setProperty("background", colourOf(value) + "22");
            if (value !== "") card.title = value;
          }
          applyTemplate(card, record, locale, collections, app);
          if (fixed) {
            const pin = document.createElement("span");
            pin.className = "rn-timetable-pin";
            pin.setAttribute("role", "img");
            pin.setAttribute("aria-label", labels.pinnedRow);
            pin.title = labels.pinnedRow;
            pin.textContent = "⚑";
            card.appendChild(pin);
          }
          const actions = rowActions(labels, deletable, editform, record.id);
          if (actions) card.appendChild(actions);
          cell.appendChild(card);
        }
        line.appendChild(cell);
      });
      body.appendChild(line);
    });
    table.appendChild(body);
    host.appendChild(table);

    if (colourField !== "" && colours.length > 0) {
      const legend = document.createElement("div");
      legend.className = "rn-calendar-legend";
      for (const value of colours) {
        const item = document.createElement("span");
        item.className = "rn-calendar-legend-item";
        const dot = document.createElement("span");
        dot.className = "rn-calendar-legend-dot";
        dot.style.setProperty("background", colourOf(value));
        item.append(dot, document.createTextNode(value));
        legend.appendChild(item);
      }
      host.appendChild(legend);
    }

    // The rows nobody has placed yet, under the grid: a lesson without an hour is not
    // in any cell, and leaving it out of the page entirely would look like data loss.
    const waiting = node.querySelector(":scope > .rn-timetable-waiting");
    if (waiting) {
      waiting.textContent = "";
      for (const record of grid.unplaced) {
        const card = template.cloneNode(true);
        card.removeAttribute("hidden");
        card.className = "rn-list-row rn-timetable-card";
        card.setAttribute("data-rn-card", record.id);
        card.setAttribute("draggable", helpers.pinned(record, pinField) ? "false" : "true");
        applyTemplate(card, record, locale, collections, app);
        const actions = rowActions(labels, deletable, editform, record.id);
        if (actions) card.appendChild(actions);
        waiting.appendChild(card);
      }
    }
  };

  // Attached once per timetable, on the container rather than per cell: the cells are
  // rebuilt on every refresh, so per-cell handlers would have to be reattached each
  // time and the old ones would pile up behind them — the board's rule.
  const timetableDragging = (node, path, container, app, labels, locale) => {
    const state = stateFor(container, viewKey(container, node, "data-rn-timetable"), () => ({
      blocks: [],
      rowField: "",
      colField: "",
    }));
    // What is being dragged, kept here because dataTransfer refuses to be read during
    // dragover — and dragover is exactly where a cell has to decide whether it will
    // take this card.
    let carried = "";

    const say = (message) => {
      const status = node.querySelector(":scope > .rn-timetable-status");
      if (status) status.textContent = message;
    };

    const clearMarks = () => {
      for (const cell of node.querySelectorAll("[data-rn-cell]")) {
        cell.classList.remove("rn-timetable-refuses", "rn-timetable-warns", "rn-timetable-over");
      }
      for (const mark of node.querySelectorAll(".rn-timetable-mark-drag")) mark.remove();
    };

    // The glyph that goes with the tint. A cell that answers only by changing colour
    // answers nobody who cannot see the colour, so the answer is drawn as well —
    // added for the length of the drag and taken away with the rest of the marks.
    const markCell = (cell, symbol, said) => {
      const mark = document.createElement("span");
      mark.className = "rn-timetable-mark rn-timetable-mark-drag";
      mark.setAttribute("role", "img");
      mark.setAttribute("aria-label", said);
      mark.title = said;
      mark.textContent = symbol;
      cell.appendChild(mark);
    };

    node.addEventListener("dragstart", (event) => {
      const card = event.target.closest("[data-rn-card]");
      if (!card || card.hasAttribute("data-rn-pinned")) return;
      carried = card.getAttribute("data-rn-card");
      event.dataTransfer.setData("text/plain", carried);
      event.dataTransfer.effectAllowed = "move";
      card.classList.add("rn-board-card-moving");
      say("");
      // Every cell answers before the card reaches it: allowed, spoken for by another
      // lesson, or forbidden. Three states and three glyphs — the classes only tint
      // what the marks already say.
      for (const cell of node.querySelectorAll("[data-rn-cell]")) {
        const row = cell.getAttribute("data-rn-cell-row");
        const col = cell.getAttribute("data-rn-cell-col");
        const refused = helpers.refusal(state.blocks, row, col, carried);
        if (refused !== undefined) {
          cell.classList.add("rn-timetable-refuses");
          // A cell forbidden to everyone already carries its mark; this one is about
          // the card in the air, and goes when the drag does.
          if (!cell.querySelector(".rn-timetable-mark")) {
            markCell(cell, "⊘", refused === "" ? labels.blockedCell : refused);
          }
        } else if (helpers.warned(state.blocks, row, col, carried)) {
          cell.classList.add("rn-timetable-warns");
          markCell(cell, "!", labels.blockedCell);
        }
      }
    });

    node.addEventListener("dragend", (event) => {
      const card = event.target.closest("[data-rn-card]");
      if (card) card.classList.remove("rn-board-card-moving");
      carried = "";
      clearMarks();
    });

    node.addEventListener("dragover", (event) => {
      const cell = event.target.closest("[data-rn-cell]");
      if (!cell) return;
      const row = cell.getAttribute("data-rn-cell-row");
      const col = cell.getAttribute("data-rn-cell-col");
      // Not calling preventDefault is what refuses the drop, and it is the browser
      // that then springs the card back — which is why the reason is said out loud
      // below rather than left to a cursor shape.
      if (helpers.refusal(state.blocks, row, col, carried) !== undefined) {
        event.dataTransfer.dropEffect = "none";
        return;
      }
      event.preventDefault();
      event.dataTransfer.dropEffect = "move";
      cell.classList.add("rn-timetable-over");
    });

    node.addEventListener("dragleave", (event) => {
      const cell = event.target.closest("[data-rn-cell]");
      if (cell && !cell.contains(event.relatedTarget)) cell.classList.remove("rn-timetable-over");
    });

    node.addEventListener("drop", (event) => {
      const cell = event.target.closest("[data-rn-cell]");
      if (!cell) return;
      event.preventDefault();
      clearMarks();
      const id = event.dataTransfer.getData("text/plain");
      const row = cell.getAttribute("data-rn-cell-row");
      const col = cell.getAttribute("data-rn-cell-col");
      const rowField = state.rowField;
      const colField = state.colField;
      if (!id || rowField === "" || colField === "") return;
      const refused = helpers.refusal(state.blocks, row, col, id);
      if (refused !== undefined) {
        // The author's own sentence when they wrote one: they know why the cell is
        // shut and the reader never sees the constraint that shut it.
        say(refused === "" ? labels.blockedCell : refused);
        return;
      }
      say("");
      helpers.read(app, path).then((collection) => {
        const record = helpers.find(collection, id);
        if (record === undefined) return;
        if (helpers.valueOf(record, rowField) === row && helpers.valueOf(record, colField) === col) {
          return;
        }
        // BOTH fields rewritten and everything else kept, stamps included: moving a
        // card is an edit of two fields, so updatedAt moves and createdAt does not.
        const fields = record.fields
          .filter((entry) => entry.name !== rowField && entry.name !== colField)
          .concat([{ name: rowField, value: row }, { name: colField, value: col }]);
        const stamped = helpers.stamp(fields, helpers.timestamp(), helpers.createdOf(record));
        return helpers.write(app, path, helpers.update(collection, id, stamped))
          .then(() => refresh(container, app, labels, locale));
      });
    });
  };

  // What is typed in a table's search box, which column it is sorted by, which page
  // it is on and what the reader has narrowed by — held in viewState above, so it
  // survives the render that recreates the node.
  const stateOf = (container, node) =>
    stateFor(container, viewKey(container, node, "data-rn-table"), () => ({
      query: "",
      sort: node.getAttribute("data-rn-sort") || "",
      dir: node.getAttribute("data-rn-dir") || "asc",
      page: 0,
      filters: {},
    }));

  const columnsOf = (node) =>
    [...node.querySelectorAll("thead th[data-rn-field]")].map((cell) => ({
      cell,
      field: cell.getAttribute("data-rn-field"),
      align: cell.getAttribute("data-rn-align") || "",
    }));

  const renderTable = (node, collection, labels, locale, collections, container, app) => {
    const body = node.querySelector("tbody.rn-table-rows");
    if (!body) return;
    const state = stateOf(container, node);
    const columns = columnsOf(node);
    const deletable = node.hasAttribute("data-rn-deletable");
    const editform = node.getAttribute("data-rn-editform");

    const fields = columns.length > 0
      ? columns.map((column) => column.field)
      : fieldsOfRecords(collection.records);
    const arranged = arrangeFor(
      node, collection.records, fields, state.query, state.sort, state.dir,
      chosenFilters(node, state)
    );

    // The values on offer come from the rows the *other* filters leave, so a choice
    // that would show nothing is not offered at all.
    for (const field of filterFields(node)) {
      const select = node.querySelector('[data-rn-filter-field="' + CSS.escape(field) + '"]');
      if (!select) continue;
      const others = filterFields(node)
        .filter((name) => name !== field)
        .map((name) => (state.filters[name] ? name + "=" + state.filters[name] : ""))
        .filter(Boolean);
      const available = helpers.choices(
        arrangeFor(node, collection.records, fields, state.query, "", "", others),
        field
      );
      const chosen = state.filters[field] || "";
      select.textContent = "";
      const all = document.createElement("option");
      all.value = "";
      all.textContent = labels.allValues;
      select.appendChild(all);
      for (const value of available) {
        const option = document.createElement("option");
        option.value = value;
        option.textContent = helpers.localize(value, locale);
        select.appendChild(option);
      }
      // A value that has stopped existing is still shown, or the control would
      // silently disagree with the rows it is filtering.
      if (chosen !== "" && !available.includes(chosen)) {
        const gone = document.createElement("option");
        gone.value = chosen;
        gone.textContent = helpers.localize(chosen, locale);
        select.appendChild(gone);
      }
      select.value = chosen;
    }

    const size = Number(node.getAttribute("data-rn-page-size")) || 0;
    const pages = helpers.pageCount(arranged.length, size);
    if (state.page > pages - 1) state.page = pages - 1;
    const shown = helpers.paginate(arranged, size, state.page);

    body.textContent = "";
    for (const record of shown) {
      const row = document.createElement("tr");
      row.className = "rn-table-row";
      for (const column of columns) {
        const cell = document.createElement("td");
        if (column.align) cell.className = "rn-align-" + column.align;
        // textContent, never markup — the same rule the list template follows, and
        // for the same reason: these values are whatever someone typed into a form.
        // A column may name a reference — field="who>people.name" — and then what it
        // shows is the referenced row's value. It is filled through the same template
        // machinery as a list, so there is one definition of what that token means.
        const shown = column.field.includes(">")
          ? helpers.fill("{" + column.field + "}", record, locale, (path, id, label) => {
              const other = collections && collections[path];
              if (!other) return undefined;
              const found = helpers.find(other, id);
              if (found === undefined) return undefined;
              const value = helpers.valueOf(found, label);
              return value === "" ? undefined : value;
            })
          : helpers.localize(helpers.valueOf(record, column.field), locale);
        // A ::file value in a column shows as itself, exactly as in a list.
        const attached = fileValue(shown);
        if (attached) cell.appendChild(fileElement(attached, app));
        else cell.textContent = shown;
        row.appendChild(cell);
      }
      const actions = rowActions(labels, deletable, editform, record.id);
      if (actions) {
        const cell = document.createElement("td");
        cell.className = "rn-table-actions";
        cell.appendChild(actions);
        row.appendChild(cell);
      }
      body.appendChild(row);
    }

    // The header says which column is sorted and which way, in the attribute a
    // screen reader reads and in the glyph everyone else does.
    for (const column of columns) {
      const isSorted = column.field === state.sort;
      const ascending = state.dir !== "desc";
      column.cell.setAttribute(
        "aria-sort", isSorted ? (ascending ? "ascending" : "descending") : "none"
      );
      const button = column.cell.querySelector(".rn-th-sort");
      if (button) {
        button.dataset.rnSorted = isSorted ? (ascending ? "asc" : "desc") : "";
        button.title = isSorted
          ? (ascending ? labels.sortedAscending : labels.sortedDescending)
          : "";
      }
    }

    const pager = node.querySelector(".rn-table-pager");
    if (pager) {
      pager.hidden = size <= 0 || pages <= 1;
      const indicator = pager.querySelector(".rn-table-page");
      if (indicator) indicator.textContent = (state.page + 1) + " / " + pages;
      const previous = pager.querySelector("[data-rn-page-step='-1']");
      const next = pager.querySelector("[data-rn-page-step='1']");
      if (previous) previous.disabled = state.page <= 0;
      if (next) next.disabled = state.page >= pages - 1;
    }
  };

  // A field that points at another collection is a choice of its rows. The options
  // are rebuilt on every render, because the rows they name change under it — and the
  // chosen value is put back afterwards, or editing a row would lose its reference
  // the moment anything else was saved.
  const fillReferences = (container, collections) => {
    for (const select of container.querySelectorAll("select[data-rn-ref]")) {
      const collection = collections[select.getAttribute("data-rn-ref")];
      if (!collection) continue;
      const label = select.getAttribute("data-rn-ref-label") || "";
      const chosen = select.value;
      select.textContent = "";
      // Blank first: a field nobody filled in must be expressible, and a select with
      // no empty option silently answers with its first row.
      const empty = document.createElement("option");
      empty.value = "";
      empty.textContent = "—";
      select.appendChild(empty);
      for (const record of collection.records) {
        const option = document.createElement("option");
        option.value = record.id;
        // The id is the fallback, so a row with nothing in the label field is still
        // choosable rather than a blank line.
        const shown = label === "" ? "" : helpers.valueOf(record, label);
        option.textContent = shown === "" ? record.id : shown;
        select.appendChild(option);
      }
      select.value = chosen;
    }
  };

  // ::choose is a reference field pointed the other way: the same options built from
  // the same rows, but what the choice writes is a REACTIVE KEY, so it lands in
  // ReactiveStore and every ::od-query whose SQL mentions {#key} re-runs. The wiring
  // itself is already there — ReactiveStore treats anything with data-reactive-source
  // as a source and listens for its change event — so all that is missing is the
  // options.
  //
  // Two things here are load-bearing and neither is obvious:
  //
  //  - ReactiveStore.bind runs BEFORE this, in Render.res. At seed time the select has
  //    no options at all, so select.value is "" and the chosen option cannot be read
  //    off the node. It is restored from the STORE instead — which is also what makes
  //    the choice survive the preview replacing every node on each keystroke.
  //  - a collection still being read is an EMPTY collection, and rebuilding an empty
  //    dropdown would clear the key: the query would flap between filtered and
  //    unfiltered on every render, once per keystroke beside the editor. So no rows
  //    means nothing happens at all.
  const fillChoices = (container, collections) => {
    const store = globalThis.__rnReactive;
    for (const select of container.querySelectorAll("select[data-rn-choose]")) {
      const collection = collections[select.getAttribute("data-rn-choose")];
      if (!collection || collection.records.length === 0) continue;
      const key = select.getAttribute("data-reactive-source");
      const valueField = select.getAttribute("data-rn-choose-field") || "";
      const labelField = select.getAttribute("data-rn-choose-label") || valueField;
      const sortField = select.getAttribute("data-rn-choose-sort") || "";
      const descending = (select.getAttribute("data-rn-choose-dir") || "") === "desc";
      const known = store ? store.values.get(key) : undefined;
      const chosen = known === undefined ? select.value : known;

      // Omitting field stores the row id, exactly as ::input{type="ref"} does — that is
      // the reference that survives a rename. Naming one stores that column, which is
      // what a fetched table wants: chosen by name, queried by code.
      const valueOf = (record) =>
        valueField === "" ? record.id : helpers.valueOf(record, valueField);
      const labelOf = (record) => {
        const shown = labelField === "" ? "" : helpers.valueOf(record, labelField);
        return shown === "" ? valueOf(record) : shown;
      };

      // A dropdown is for FINDING, so the default order is what the reader reads.
      // ::list keeps insertion order because a list is a record of what happened; 7896
      // comuni in the order they came back from a query cannot be found at all.
      const rows = collection.records.slice();
      const by = sortField === "" ? labelOf : (record) => helpers.valueOf(record, sortField);
      rows.sort((a, b) => {
        // numeric: true so "10" sorts after "9" — the same rule RowView applies, and the
        // one that is wrong in nothing.
        const order = String(by(a)).localeCompare(String(by(b)), undefined, { numeric: true });
        return descending ? -order : order;
      });

      select.textContent = "";
      // Blank first, and it is a real answer rather than a placeholder: "all of them"
      // is what a reader asks by unchoosing. A select with no empty option answers with
      // its first row without anyone having picked it.
      const empty = document.createElement("option");
      empty.value = "";
      empty.textContent = select.getAttribute("data-rn-choose-blank") || "—";
      select.appendChild(empty);
      const seen = new Set();
      for (const record of rows) {
        const value = valueOf(record);
        // One comune arrives once per row of whatever was fetched — a query over the
        // sections of a region names the same comune hundreds of times. The reader
        // wants it once.
        if (value === "" || seen.has(value)) continue;
        seen.add(value);
        const option = document.createElement("option");
        option.value = value;
        option.textContent = labelOf(record);
        select.appendChild(option);
      }
      select.value = chosen;
      // And NOTHING is written back. Assigning a value the options do not carry leaves
      // the select blank, and the tempting repair — telling the store what the control
      // ended up showing — makes a paint into a writer, which is a cycle waiting for
      // the day something repaints on a key change. A paint reads; only a gesture
      // writes.
    }
  };

  const paint = (container, collections, labels, locale, app) => {
    fillReferences(container, collections);
    fillChoices(container, collections);
    for (const node of container.querySelectorAll("[data-rn-table]")) {
      const collection = collections[node.getAttribute("data-rn-table")];
      if (collection) renderTable(node, collection, labels, locale, collections, container, app);
    }
    for (const node of container.querySelectorAll("[data-rn-list]")) {
      const collection = collections[node.getAttribute("data-rn-list")];
      if (collection) renderList(node, collection, labels, locale, collections, app);
    }
    for (const node of container.querySelectorAll("[data-rn-board]")) {
      const collection = collections[node.getAttribute("data-rn-board")];
      if (collection) renderBoard(node, collection, labels, locale, collections, app);
    }
    for (const node of container.querySelectorAll("[data-rn-timetable]")) {
      const collection = collections[node.getAttribute("data-rn-timetable")];
      // The forbidden cells are optional: a timetable without them refuses nothing,
      // which is the right answer for a grid nobody has written a validator for yet.
      const blocked = collections[node.getAttribute("data-rn-tt-blocked")];
      if (collection) {
        renderTimetable(node, collection, blocked, labels, locale, collections, container, app);
      }
    }
    for (const node of container.querySelectorAll("[data-rn-calendar]")) {
      const collection = collections[node.getAttribute("data-rn-calendar")];
      if (collection) renderCalendar(node, collection, labels, locale, collections, container, app);
    }
    for (const node of container.querySelectorAll("[data-rn-aggregate]")) {
      const collection = collections[node.getAttribute("data-rn-path")];
      if (!collection) continue;
      const decimals = node.getAttribute("data-rn-decimals");
      const value = helpers.aggregate(
        node.getAttribute("data-rn-aggregate"),
        collection,
        node.getAttribute("data-rn-field") || "",
        decimals === null ? undefined : Number(decimals)
      );
      // Nothing to say is said with the placeholder: an empty collection has no
      // average, and printing 0 would claim it did.
      node.textContent = value === undefined ? (node.dataset.placeholder || "—") : value;
    }
    for (const node of container.querySelectorAll("[data-rn-when]")) {
      const collection = collections[node.getAttribute("data-rn-path")];
      if (!collection) continue;
      const any = collection.records.length > 0;
      const wants = node.getAttribute("data-rn-when") === "any" ? any : !any;
      if (wants) node.removeAttribute("hidden");
      else node.setAttribute("hidden", "");
    }
    for (const node of container.querySelectorAll("[data-rn-count]")) {
      const collection = collections[node.getAttribute("data-rn-count")];
      if (collection) node.textContent = String(collection.records.length);
    }
  };

  const refresh = (container, app, labels, locale) =>
    Promise.all(pathsIn(container).map((path) =>
      helpers.read(app, path).then((collection) => [path, collection])
    )).then((pairs) => {
      const collections = {};
      for (const [path, collection] of pairs) collections[path] = collection;
      paint(container, collections, labels, locale, app);
    });

  // Does any view in this container narrow by that reactive key? The word boundary is
  // the point: #chi must not match #chiave, or one key would repaint every view whose
  // filter merely starts the same way.
  const usesKey = (container, key) => {
    // No escaping needed: a reactive key is [A-Za-z0-9_-]+ by grammar — the same class
    // withKeys above matches — so nothing here can be a regex metacharacter.
    if (!/^[A-Za-z0-9_-]+$/.test(key)) return false;
    const edge = new RegExp("#" + key + "(?![A-Za-z0-9_-])");
    for (const node of container.querySelectorAll("[data-rn-filter]")) {
      if (edge.test(node.getAttribute("data-rn-filter") || "")) return true;
    }
    return false;
  };

  // A view whose filter names a reactive key — filter="who=#chi" — is supposed to
  // follow it, and nothing was making that happen. This binder paints on rn:data (the
  // DATA moved) and when the preview re-renders (the DOCUMENT moved); a key moving is
  // neither, so the key was resolved once, at paint, and then stood still. Beside the
  // editor it looked right, because every keystroke re-renders the document anyway —
  // for a reader at /a/<id>, who types in no editor, the view simply never narrowed.
  // Every app using the master-detail shape had it: inclusione, segreteria,
  // graduatorie-interne.
  //
  // Two bounds, both deliberate: only containers that actually mention the key are
  // repainted, and the repaint waits for the writes to stop — a ::textfield[k] writes
  // on every keystroke, and redrawing every table in the document per character is how
  // a preview stops responding.
  //
  // The bound WeakSet cannot be walked, so the containers to visit are kept here too —
  // a strong reference, which is why every flush drops the ones that have left the
  // document. There are only ever one or two: the preview container is React's and
  // survives the innerHTML it replaces.
  const following = new Set();
  const pendingKeys = new Set();
  let keyTimer = null;
  let subscribed = false;
  const followKeys = () => {
    const store = globalThis.__rnReactive;
    if (subscribed || !store) return;
    subscribed = true;
    store.listeners.add((key) => {
      pendingKeys.add(key);
      if (keyTimer !== null) clearTimeout(keyTimer);
      keyTimer = setTimeout(() => {
        keyTimer = null;
        const keys = [...pendingKeys];
        pendingKeys.clear();
        for (const container of [...following]) {
          if (!container.isConnected) {
            following.delete(container);
            continue;
          }
          const current = latest.get(container);
          if (current && keys.some((key) => usesKey(container, key)))
            refresh(container, current.app, current.labels, current.locale);
        }
      }, 100);
    });
  };

  // Which row each form is editing, if any. Per container, so two previews cannot
  // confuse each other, and cleared as soon as the row is saved.
  const editing = new WeakMap();

  const editingIn = (container, form) => (editing.get(container) || {})[form];

  const setEditing = (container, form, id) => {
    const current = editing.get(container) || {};
    if (id === null) delete current[form];
    else current[form] = id;
    editing.set(container, current);
  };

  // Which form a control belongs to is a question the DOM already answers: a field
  // written inside ::form is inside its <div>. data-rn-in-form is only present
  // when the author put a field somewhere else and had to say so, and it is the one
  // case that cannot be read off containment.
  const formRoot = (container, node, id) => {
    if (id) {
      return container.querySelector('[data-rn-form="' + CSS.escape(id) + '"]');
    }
    return node.closest("[data-rn-form]");
  };

  // A form's own fields: the ones whose nearest form ancestor is this form, so a
  // form nested in another does not have its fields saved by both. Only form
  // controls — [data-rn-field] is also how an aggregation names its column.
  const CONTROLS = "input[data-rn-field],select[data-rn-field],textarea[data-rn-field]";

  const fieldsOf = (container, root, id) => {
    const found = [];
    if (root) {
      for (const input of root.querySelectorAll(CONTROLS)) {
        const stated = input.getAttribute("data-rn-in-form");
        if (stated && id && stated !== id) continue;
        if (input.closest("[data-rn-form]") === root) found.push(input);
      }
    }
    if (id) {
      for (const input of container.querySelectorAll(
        '[data-rn-in-form="' + CSS.escape(id) + '"]'
      )) {
        if (input.matches(CONTROLS) && !found.includes(input)) found.push(input);
      }
    }
    return found;
  };

  // A form is identified by its id where it has one and by its path otherwise, which
  // is what lets a list say editform without naming anything.
  const idOf = (root) => (root ? root.getAttribute("data-rn-form") : null);

  const formAtPath = (container, path) =>
    container.querySelector('[data-rn-form][data-rn-path="' + CSS.escape(path) + '"]');

  const fillDraft = (fields, record) => {
    for (const input of fields) {
      const field = input.getAttribute("data-rn-field");
      const found = record.fields.find((entry) => entry.name === field);
      const value = found ? found.value : "";
      if (input.type === "checkbox") input.checked = value === "true";
      else input.value = value;
    }
  };

  // The controls as core/Draft describes them: what they hold, and what the author
  // said they must hold. Reading them off the page is this file's business; deciding
  // whether the draft is empty or wrong is not.
  const labelOf = (input) => {
    const wrapper = input.closest(".rn-field");
    const name = wrapper ? wrapper.querySelector(".rn-field-name") : null;
    return name ? name.textContent.trim() : "";
  };

  // A field's guidance is *described by*, not named by: the label's text is the
  // control's accessible name, so guidance inside it would be announced as part of
  // the name. It needs an id to be pointed at, and the renderer cannot mint one — it
  // sees one directive at a time and two forms may hold a field of the same name — so
  // the ids are made here, where the whole document is in view. They are remade with
  // the DOM on every render, which is why a counter is enough.
  let described = 0;
  const describeFields = (container) => {
    for (const help of container.querySelectorAll("[data-rn-help]")) {
      if (help.id) continue;
      const field = help.closest(".rn-field");
      const input = field ? field.querySelector("[data-rn-field]") : null;
      if (!input) continue;
      described += 1;
      help.id = "rn-help-" + described;
      input.setAttribute("aria-describedby", help.id);
    }
  };

  // What the field is described by when nothing is wrong with it: its guidance, if it
  // has any. A complaint is added to this and taken away again, so clearing one does
  // not take the guidance with it.
  const describedBy = (input, extra) => {
    const field = input.closest(".rn-field");
    const help = field ? field.querySelector("[data-rn-help]") : null;
    const ids = [help && help.id, extra].filter(Boolean);
    if (ids.length === 0) input.removeAttribute("aria-describedby");
    else input.setAttribute("aria-describedby", ids.join(" "));
  };

  const controlsOf = (fields) =>
    fields.map((input) => ({
      field: input.getAttribute("data-rn-field"),
      label: labelOf(input),
      value: input.type === "checkbox" ? "" : String(input.value == null ? "" : input.value),
      kind: input.getAttribute("type") || "text",
      ticked: !!input.checked,
      required: input.hasAttribute("required"),
      min: input.getAttribute("min") || "",
      max: input.getAttribute("max") || "",
      pattern: input.getAttribute("pattern") || "",
      patternMessage: input.getAttribute("data-rn-message") || "",
    }));

  const draftOf = (controls) =>
    controls.map((control) => ({ name: control.field, value: helpers.reading(control) }));

  // A complaint belongs beside the field it is about, and goes as soon as that field
  // is touched: a message that outlives the mistake is a message the reader learns to
  // ignore.
  const clearComplaints = (root) => {
    for (const message of root.querySelectorAll(".rn-field-error")) message.remove();
    for (const marked of root.querySelectorAll("[aria-invalid]")) {
      marked.removeAttribute("aria-invalid");
      describedBy(marked, null);
    }
  };

  const showComplaints = (root, complaints) => {
    let first = null;
    for (const complaint of complaints) {
      const input = root.querySelector(
        '[data-rn-field="' + CSS.escape(complaint.field) + '"]'
      );
      if (!input) continue;
      input.setAttribute("aria-invalid", "true");
      const message = document.createElement("p");
      message.className = "rn-field-error";
      described += 1;
      message.id = "rn-complaint-" + described;
      // textContent, like every other string that reaches the document: the author's
      // own message is document text and gets the same treatment as a stored value.
      message.textContent = complaint.message;
      const field = input.closest(".rn-field") || input.parentElement;
      field.appendChild(message);
      // Described by the complaint *and* the guidance: the reader needs to know what
      // the field wanted as well as what was wrong with what they wrote.
      describedBy(input, message.id);
      if (!first) first = input;
    }
    // Focus follows the first complaint, which is the first one on the page: the
    // reader is put where the work is, not sent looking for it.
    if (first) first.focus();
  };

  const clearDraft = (fields) => {
    for (const input of fields) {
      if (input.type === "checkbox") input.checked = false;
      else input.value = "";
    }
  };

  // What the confirmation names: the row's own text, without the buttons that sit at
  // its end. "Delete this row?" on its own is a question about something the reader
  // has to go and find again; naming it makes the dialog answerable where it stands.
  const rowText = (button) => {
    const row = button.closest(".rn-list-row, .rn-table-row");
    if (!row) return "";
    let text = "";
    for (const node of row.childNodes) {
      if (node.nodeType === 1 && node.classList.contains("rn-list-row-actions")) continue;
      if (node.nodeType === 1 && node.classList.contains("rn-table-actions")) continue;
      text += node.textContent + " ";
    }
    text = text.replace(/\s+/g, " ").trim();
    return text.length > 80 ? text.slice(0, 79) + "…" : text;
  };

  // Delegated once per view, because the rows are rebuilt on every refresh: a handler
  // per row would have to be reattached each time and the old ones would pile up. A
  // list and a table draw rows differently and answer their buttons identically.
  const rowActionsListener = (view, path, container, app, labels, locale, confirm) => {
    view.addEventListener("click", (event) => {
      const remove = event.target.closest("[data-rn-delete]");
      if (remove) {
        const id = remove.getAttribute("data-rn-delete");
        // Confirmed before it happens, not undone afterwards: a row is someone's
        // data and there is no history to restore it from. The dialog itself is
        // React's — the binder only asks, so the question stays translated and the
        // markup stays out of the sanitised preview.
        Promise.resolve(confirm(rowText(remove))).then((agreed) => {
          if (!agreed) return;
          return helpers.read(app, path)
            .then((collection) => helpers.write(app, path, helpers.remove(collection, id)))
            .then(() => refresh(container, app, labels, locale));
        });
        return;
      }
      const edit = event.target.closest("[data-rn-edit]");
      if (edit) {
        // Written bare, editform means the form on this same path — which is the
        // usual case, and one the author should not have to name twice.
        const stated = view.getAttribute("data-rn-editform");
        const root = stated && stated !== "true"
          ? formRoot(container, view, stated)
          : formAtPath(container, path);
        if (!root) return;
        const form = idOf(root);
        const id = edit.getAttribute("data-rn-edit");
        helpers.read(app, path).then((collection) => {
          const record = helpers.find(collection, id);
          if (record === undefined) return;
          fillDraft(fieldsOf(container, root, form), record);
          setEditing(container, form, id);
        });
      }
    });
  };

  // Built here rather than emitted by the renderer, for the same reason the row
  // buttons are: they carry words, and the renderer is installed once with no
  // language. Built once per table node, which is new on every preview render.
  const buildTools = (container, node, labels, repaint) => {
    const state = stateOf(container, node);

    if (node.hasAttribute("data-rn-search")) {
      const label = document.createElement("label");
      label.className = "rn-table-search";
      const name = document.createElement("span");
      name.className = "sr-only";
      name.textContent = labels.searchRows;
      const input = document.createElement("input");
      input.type = "search";
      input.className = "rn-table-search-input";
      input.placeholder = labels.searchRows;
      input.value = state.query;
      input.addEventListener("input", () => {
        state.query = input.value;
        // A narrower result set means the page you were on may not exist any more.
        state.page = 0;
        repaint();
      });
      label.append(name, input);
      node.insertBefore(label, node.firstChild);
    }

    // One control per named column, beside the search box: they are the same kind of
    // question — which rows — and putting them anywhere else would make the reader
    // look in two places for it.
    const fields = filterFields(node);
    if (fields.length > 0) {
      const bar = document.createElement("div");
      bar.className = "rn-table-filters";
      for (const field of fields) {
        const label = document.createElement("label");
        label.className = "rn-table-filter";
        const name = document.createElement("span");
        // The column's own header names the control, so the two agree by
        // construction; the field name is the fallback for a column with no header.
        const header = node.querySelector('thead th[data-rn-field="' + CSS.escape(field) + '"]');
        name.textContent = header ? header.textContent.trim() : field;
        const select = document.createElement("select");
        select.className = "rn-table-filter-input";
        select.setAttribute("data-rn-filter-field", field);
        select.addEventListener("change", () => {
          state.filters[field] = select.value;
          // Narrower rows mean the page you were on may not exist any more.
          state.page = 0;
          repaint();
        });
        label.append(name, select);
        bar.appendChild(label);
      }
      node.insertBefore(bar, node.firstChild);
    }

    const step = (amount, text) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "rn-table-step";
      button.dataset.rnPageStep = String(amount);
      button.setAttribute("aria-label", text);
      button.title = text;
      button.textContent = amount < 0 ? "‹" : "›";
      button.addEventListener("click", () => {
        state.page += amount;
        repaint();
      });
      return button;
    };

    const pager = document.createElement("div");
    pager.className = "rn-table-pager";
    pager.hidden = true;
    const indicator = document.createElement("span");
    indicator.className = "rn-table-page";
    pager.append(step(-1, labels.previousPage), indicator, step(1, labels.nextPage));
    node.appendChild(pager);

    for (const cell of node.querySelectorAll("thead th[data-rn-field]")) {
      const button = cell.querySelector(".rn-th-sort");
      if (!button) continue;
      button.addEventListener("click", () => {
        const field = cell.getAttribute("data-rn-field");
        // Clicking the column already sorted turns it around; clicking another
        // starts it ascending, which is what every table does.
        if (state.sort === field) state.dir = state.dir === "desc" ? "asc" : "desc";
        else { state.sort = field; state.dir = "asc"; }
        repaint();
      });
    }
  };

  return function (container, app, labels, locale, confirm) {
    if (!container || !app) return;

    for (const table of container.querySelectorAll("[data-rn-table]")) {
      if (bound.has(table)) continue;
      bound.add(table);
      const path = table.getAttribute("data-rn-table");
      buildTools(container, table, labels, () => refresh(container, app, labels, locale));
      rowActionsListener(table, path, container, app, labels, locale, confirm);
    }

    for (const board of container.querySelectorAll("[data-rn-board]")) {
      if (bound.has(board)) continue;
      bound.add(board);
      const path = board.getAttribute("data-rn-board");
      rowActionsListener(board, path, container, app, labels, locale, confirm);
      boardDragging(board, path, container, app, labels, locale);
    }

    for (const timetable of container.querySelectorAll("[data-rn-timetable]")) {
      if (bound.has(timetable)) continue;
      bound.add(timetable);
      const path = timetable.getAttribute("data-rn-timetable");
      rowActionsListener(timetable, path, container, app, labels, locale, confirm);
      timetableDragging(timetable, path, container, app, labels, locale);
    }

    for (const list of container.querySelectorAll("[data-rn-list]")) {
      if (bound.has(list)) continue;
      bound.add(list);
      rowActionsListener(
        list, list.getAttribute("data-rn-list"), container, app, labels, locale, confirm
      );
    }

    for (const button of container.querySelectorAll("[data-rn-add]")) {
      if (bound.has(button)) continue;
      bound.add(button);
      button.addEventListener("click", () => {
        // The button is inside the form it saves, so neither the form nor the path
        // has to be repeated on it; both are only read from the button when the
        // author put it somewhere else.
        const root = formRoot(container, button, button.getAttribute("data-rn-add"));
        if (!root) return;
        const form = idOf(root);
        const path = button.getAttribute("data-rn-path") || root.getAttribute("data-rn-path");
        if (!path) return;
        const inputs = fieldsOf(container, root, form);
        const controls = controlsOf(inputs);
        const fields = draftOf(controls);
        clearComplaints(root);
        // An empty draft is a mis-click, not a row: saving it would grow the
        // collection with nothing in it and there would be no way to tell. An
        // unticked box is empty for this purpose — it answers "false", which is a
        // value, and reading it as one let a form with a checkbox in it save blank
        // rows however many times the button was pressed.
        if (helpers.blank(controls)) return;
        // A half-written row is worse than no row: it is found later, by someone who
        // has to guess what was meant. The rules are the author's, checked in core.
        const complaints = helpers.validate(controls, locale);
        if (complaints.length > 0) {
          showComplaints(root, complaints);
          return;
        }
        const editingId = editingIn(container, form);
        helpers.read(app, path).then((collection) => {
          const now = helpers.timestamp();
          if (editingId !== undefined) {
            const existing = helpers.find(collection, editingId);
            // The creation time survives an edit; only the modification time moves.
            const stamped = helpers.stamp(
              fields,
              now,
              existing === undefined ? undefined : helpers.createdOf(existing)
            );
            return helpers.write(app, path, helpers.update(collection, editingId, stamped));
          }
          const record = {
            id: helpers.makeId(now, collection.records.map((row) => row.id)),
            fields: helpers.stamp(fields, now, undefined),
          };
          return helpers.write(app, path, helpers.insert(collection, record));
        }).then(() => {
          setEditing(container, form, null);
          clearDraft(inputs);
          return refresh(container, app, labels, locale);
        });
      });
    }

    describeFields(container);

    // The data panel and the Python binder write to the same collections this preview
    // is showing, and neither can reach in here — so they announce it, and every
    // bound preview reads its collections again. The listener is registered once per
    // container, but it reads its parameters from the latest-bind map: the closure
    // captured whatever was open at first bind, and a container that outlives a
    // navigation would otherwise keep refreshing the app it started with.
    latest.set(container, { app, labels, locale });
    if (!bound.has(container)) {
      bound.add(container);
      window.addEventListener("rn:data", () => {
        const current = latest.get(container);
        if (current) refresh(container, current.app, current.labels, current.locale);
      });
    }
    following.add(container);
    followKeys();

    refresh(container, app, labels, locale);
  };
}
`)

let binder = install({
  read: CollectionStore.read,
  write: CollectionStore.write,
  insert: Collection.insert,
  remove: Collection.remove,
  update: Collection.update,
  find: Collection.find,
  makeId: RecordId.make,
  // A row is shown to a reader, so its dates are written the way that reader writes
  // them. Only the display changes: what is stored stays ISO, which is what makes it
  // sortable and portable between time zones.
  fill: (template, record, locale, resolve) =>
    RowTemplate.fill(
      template,
      {
        ...record,
        fields: record.fields->Array.map(field => {
          ...field,
          value: Clock.localize(field.value, ~locale),
        }),
      },
      // The referenced value is localized too: a date shown through a relation is
      // still a date, and reading it differently from the row's own would be a
      // difference with no reason behind it.
      ~resolve=(~path, ~id, ~label) =>
        resolve(path, id, label)->Option.map(value => Clock.localize(value, ~locale)),
    ),
  timestamp: Clock.timestamp,
  aggregate: (name, collection, field, decimals) =>
    Aggregate.parse(name)->Option.flatMap(kind =>
      Aggregate.compute(kind, collection, ~field, ~decimals?)
    ),
  stamp: (fields, now, createdAt) => Stamps.apply(fields, ~now, ~createdAt?),
  createdOf: Stamps.createdOf,
  arrange: (records, ~fields, ~query, ~filters, ~sort, ~dir, ~limit) =>
    records
    ->RowView.filterAll(~expressions=filters)
    ->RowView.search(~query, ~fields)
    ->RowView.sort(~field=sort, ~direction=RowView.directionOf(dir))
    ->RowView.limit(~count=limit),
  choices: (records, field) => RowView.values(records, ~field),
  grid: (records, rowField, colField, rowValues, colValues, rowLabels, colLabels) =>
    TimeGrid.build(records, ~rowField, ~colField, ~rowValues, ~colValues, ~rowLabels, ~colLabels),
  blocks: TimeGrid.blocks,
  refusal: (blocks, row, col, id) => TimeGrid.refusal(blocks, ~row, ~col, ~id),
  warned: (blocks, row, col, id) => TimeGrid.warned(blocks, ~row, ~col, ~id),
  pinned: (record, field) => TimeGrid.pinned(record, ~field),
  weeks: (year, month, startsMonday) => MonthGrid.weeks(~year, ~month, ~startsMonday),
  weekDays: (anchor, startsMonday) => MonthGrid.weekDays(~anchor, ~startsMonday),
  shiftDays: (day, by) => MonthGrid.shiftDays(~day, ~by),
  monthStep: (year, month, by) => MonthGrid.shift(~year, ~month, ~by),
  dayOf: MonthGrid.dayOf,
  covers: (day, from, until) => MonthGrid.covers(~day, ~from, ~until),
  monthOf: MonthGrid.monthOf,
  monthLabel: Clock.monthLabel,
  weekdayNames: Clock.weekdayNames,
  paginate: (records, size, index) => RowView.page(records, ~size, ~index),
  pageCount: (total, size) => RowView.pageCount(total, ~size),
  group: (records, field) => RowView.groups(records, ~field),
  valueOf: RowView.valueOf,
  localize: (value, locale) => Clock.localize(value, ~locale),
  reading: Draft.reading,
  blank: Draft.blank,
  referenced: RowTemplate.referenced,
  localFile: (app, id) => FileStore.load(~app, ~id),
  // The complaint names the field the way the reader sees it, and a bound says which
  // bound: "too small" without the number sends them back to the document to find out
  // what would be big enough.
  validate: (controls, locale) => {
    let tag = Locale.parse(locale)->Option.getOr(Locale.fallback)
    let say = key => Translations.translate(tag, key)
    let withLimit = (key, limit) => say(key)->String.replace("{n}", limit)
    controls
    ->Draft.check
    ->Array.map(complaint => {
      let message = switch complaint.problem {
      | Missing => say(FieldRequired)
      | NotANumber => say(FieldNotANumber)
      | NotADate => say(FieldNotADate)
      | NotATime => say(FieldNotATime)
      | NotAnEmail => say(FieldNotAnEmail)
      | NotAUrl => say(FieldNotAUrl)
      | Below(limit) => withLimit(FieldBelow, limit)
      | Above(limit) => withLimit(FieldAbove, limit)
      // The author's own words when they wrote any: they know what the expression
      // means and the reader never sees it.
      | NotMatching("") => say(FieldNotMatching)
      | NotMatching(said) => said
      }
      {"field": complaint.field, "message": complaint.label ++ " — " ++ message}
    })
  },
})

let bind = (container, ~app, ~labels, ~locale, ~confirm) =>
  binder(container, app, labels, locale, confirm)
