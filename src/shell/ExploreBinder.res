// `::explore` — the analysis view a reader drives: drag columns, group, pivot,
// switch chart, filter, all without touching the document. Complementary to
// ::table: the table shows what the author decided, this lets the reader ask.
//
//   - The engine (Perspective, WASM) is a lazy chunk, loaded the first time a
//     document actually holds an explore view.
//   - Column types are inferred from the data — a stringly "12,5" becomes the
//     number it is — so aggregations sum instead of concatenating.
//   - The configuration the reader builds SURVIVES document edits: it is saved
//     on every change into per-position state, and restored onto the fresh
//     viewer the next render creates.
//   - The optional fenced body is the viewer's own JSON configuration, which
//     wins over the attributes.
//   - THE VIEWER IS NOT BUILT ON A HOST OF NO SIZE, the same rule the map
//     follows and for the same reason: a `::page` that is not showing carries
//     `hidden`, which is `display: none`, and an element with no box measures
//     0×0. Perspective sizes its grid when the viewer moves in, so one built
//     there renders nothing and goes on rendering nothing after the page is
//     opened. The position is marked deferred instead, and `rn:page` — PageNav
//     saying it just showed a panel — is what builds it.

let install: (
  (~app: string, ~path: string) => promise<Collection.t>,
  unit => promise<array<JSON.t> => promise<ExploreImpl.table>>,
  unit => promise<(ExploreImpl.table, array<JSON.t>) => promise<unit>>,
  unit => promise<(Dom.element, ExploreImpl.table, JSON.t) => promise<Dom.element>>,
  unit => promise<Dom.element => promise<JSON.t>>,
  unit => promise<Dom.element => promise<unit>>,
) => (Dom.element, string) => unit = %raw(`
function (read, loadMakeTable, loadReplaceRows, loadMakeViewer, loadSaveConfig, loadDeleteViewer) {
  const PLUGINS = {
    datagrid: "Datagrid",
    bar: "Y Bar",
    line: "Y Line",
    area: "Y Area",
    scatter: "X/Y Scatter",
    heatmap: "Heatmap",
    treemap: "Treemap",
    sunburst: "Sunburst",
  };

  const exploreState = new WeakMap();
  const stateFor = (container, index) => {
    let states = exploreState.get(container);
    if (states === undefined) {
      states = new Map();
      exploreState.set(container, states);
    }
    let state = states.get(index);
    if (state === undefined) {
      state = {
        table: null,
        viewer: null,
        host: null,
        config: null,
        rowsJson: "",
        deferred: false,
      };
      states.set(index, state);
    }
    return state;
  };

  // Stored values are strings; Perspective infers a column's type from what it
  // is given. Whole-string numbers (decimal comma accepted) go in as numbers.
  const typedRows = (records) =>
    records.map((record) => {
      const row = {};
      for (const field of record.fields) {
        const text = String(field.value).trim().replace(",", ".");
        const parsed = text === "" ? NaN : Number(text);
        row[field.name] = Number.isFinite(parsed) ? parsed : field.value;
      }
      return row;
    });

  const listOf = (value) => (value || "").split(",").map((s) => s.trim()).filter(Boolean);

  // Every field name the rows actually carry. A view is configured by column
  // name, and a name that is not one is refused by the viewer.
  const columnsOf = (rows) => {
    const names = new Set();
    for (const row of rows) for (const name of Object.keys(row)) names.add(name);
    return names;
  };

  const configFrom = (node, columns) => {
    // The body, when it is a fenced JSON block, is the viewer's native
    // configuration and wins whole — including anything it names that is not a
    // stored column, since expressions invent their own.
    const fenced = node.querySelector(":scope > .rn-explore-config pre");
    if (fenced) {
      try {
        return JSON.parse(fenced.textContent || "");
      } catch {}
    }
    const config = {};
    const view = node.getAttribute("data-rn-explore-view") || "datagrid";
    config.plugin = PLUGINS[view] || "Datagrid";
    // Names the rows do not have are dropped rather than carried in. restore()
    // is all-or-nothing and leaves what it refused pending on the element, so
    // one mistyped column in group-by does not cost the grouping — it costs the
    // whole configuration, the chart included, and the reader gets a datagrid
    // where the document asked for a chart with nothing saying why.
    const known = (names) => names.filter((name) => columns.has(name));
    const groupBy = known(listOf(node.getAttribute("data-rn-explore-group-by")));
    const splitBy = known(listOf(node.getAttribute("data-rn-explore-split-by")));
    const chosen = known(listOf(node.getAttribute("data-rn-explore-columns")));
    if (groupBy.length) config.group_by = groupBy;
    if (splitBy.length) config.split_by = splitBy;
    if (chosen.length) config.columns = chosen;
    return config;
  };

  // Is any position in this container still waiting for a host with a box?
  // Asked of the states rather than kept as a second list, which could only get
  // out of step with them.
  const waiting = (container) => {
    const states = exploreState.get(container);
    if (!states) return false;
    for (const state of states.values()) if (state.deferred) return true;
    return false;
  };

  const known = [];
  let listening = false;
  const ensureListening = () => {
    if (listening) return;
    listening = true;
    window.addEventListener("rn:data", () => {
      for (const entry of [...known]) {
        const container = entry.ref.deref();
        if (!container || !container.isConnected) continue;
        rebind(container, entry.app);
      }
    });
    // PageNav has just changed which panel is showing, so something that had no
    // box has one now — and, just as important, something that HAD one may have
    // lost it. Both are handled by rebind, so every container is visited rather
    // than only the ones with work put down: a page that goes away leaves a
    // viewer mounted on a host of no size, and that is the state Perspective
    // cannot draw in. A hidden position costs one measurement and returns.
    window.addEventListener("rn:page", () => {
      for (const entry of [...known]) {
        const container = entry.ref.deref();
        if (!container || !container.isConnected) continue;
        rebind(container, entry.app);
      }
    });
  };

  async function rebind(container, app) {
    const nodes = [...container.querySelectorAll("[data-rn-explore]")];
    if (nodes.length === 0) return;
    const makeTable = await loadMakeTable();
    const replaceRows = await loadReplaceRows();
    const makeViewer = await loadMakeViewer();
    const saveConfig = await loadSaveConfig();
    const deleteViewer = await loadDeleteViewer();

    nodes.forEach(async (node, index) => {
      const path = node.getAttribute("data-rn-explore");
      const host = node.querySelector(":scope > .rn-explore-host");
      if (!path || !host) return;
      const state = stateFor(container, index);
      const height = node.getAttribute("data-rn-explore-height");
      if (height) host.style.setProperty("height", height);

      // The host has no box — a page that is not showing, most of the time. The
      // viewer would measure zero and draw nothing, so the work is put down
      // here and the rn:page announcement picks it up. Reading the rows is
      // skipped with it: they are read when the page comes back, which is the
      // moment they are looked at.
      if (host.clientWidth === 0 || host.clientHeight === 0) {
        // A viewer already standing here is withdrawn rather than left. Not
        // building on a host of no size and leaving one there when the size
        // goes away are the same rule; keeping it is what leaves Perspective
        // drawing against a box of nothing, which is where it reads undefined
        // for its own layout. The configuration the reader built is in
        // state.config and the table is ours, so coming back costs a mount.
        if (state.viewer) {
          deleteViewer(state.viewer);
          state.viewer = null;
          state.host = null;
        }
        state.deferred = true;
        return;
      }
      state.deferred = false;

      const collection = await read(app, path);
      if (!host.isConnected) return;
      const rows = typedRows(collection.records);
      const rowsJson = JSON.stringify(rows);

      if (!state.table) {
        state.table = await makeTable(rows.length ? rows : [{}]);
        state.rowsJson = rowsJson;
      } else if (state.rowsJson !== rowsJson && rows.length) {
        // The view follows the store live — an IoT stream draws itself.
        await replaceRows(state.table, rows);
        state.rowsJson = rowsJson;
      }

      if (state.host !== host) {
        // A fresh render made a fresh node: the viewer moves in, wearing the
        // configuration the reader last built. The one on the node that just
        // went away is taken out of service first — left alone it keeps its own
        // observers, goes on measuring an element no longer in the document,
        // and leaks WASM memory Perspective can only free through delete().
        const previous = state.viewer;
        state.host = host;
        state.viewer = null;
        if (previous) deleteViewer(previous);
        const viewer = await makeViewer(host, state.table, state.config || configFrom(node, columnsOf(rows)));
        // Loading is asynchronous and the render is debounced: the document may
        // have moved on while this one was arriving, and a viewer whose host has
        // left draws against nothing. It is deleted rather than kept, since the
        // node it was built for no longer exists.
        if (!host.isConnected) {
          deleteViewer(viewer);
          return;
        }
        state.viewer = viewer;
        viewer.addEventListener("perspective-config-update", async () => {
          try { state.config = await saveConfig(viewer); } catch {}
        });
      }
    });
  }

  return function (container, app) {
    if (container.querySelector("[data-rn-explore]") === null) return;
    ensureListening();
    if (!known.some((entry) => entry.ref.deref() === container)) {
      known.push({ ref: new WeakRef(container), app });
    } else {
      for (const entry of known) if (entry.ref.deref() === container) entry.app = app;
    }
    rebind(container, app);
  };
}
`)

let loaded: ref<option<promise<array<JSON.t> => promise<ExploreImpl.table>>>> = ref(None)

let loadMakeTable = () =>
  switch loaded.contents {
  | Some(pending) => pending
  | None => {
      let pending = import(ExploreImpl.makeTable)
      loaded.contents = Some(pending)
      pending
    }
  }

let binder = install(
  CollectionStore.read,
  loadMakeTable,
  () => import(ExploreImpl.replaceRows),
  () => import(ExploreImpl.makeViewer),
  () => import(ExploreImpl.saveConfig),
  () => import(ExploreImpl.deleteViewer),
)

let bind = (container, ~app) => binder(container, app)
