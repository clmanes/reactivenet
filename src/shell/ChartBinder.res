// The chart-* directives, bound after each render like every other view over a
// collection. The renderer emits an empty, sanitised `<div data-rn-chart>`; the
// canvas, the engine and every number conversion happen here.
//
// Three rules:
//   - The engine is a lazy chunk. `ChartImpl` (Chart.js) is reached only through
//     the dynamic import below, so a document with no chart never pays for one.
//   - Stored values are strings. What counts as a number is decided once, in
//     `numberOf`: whole-string, decimal comma accepted — a row that does not
//     parse is left out of the series rather than drawn as zero.
//   - The chart follows the store: `rn:data` re-reads the collection and updates
//     in place, which is what makes an IoT stream draw itself.
//
// Inside a `::dashboard` a chart is also a control: clicking a bar or a slice
// selects that x value for the sibling views, and the chart shows the selection
// by dimming everything else — it deliberately does not filter itself, so the
// context stays visible. The selection state lives in shell/Dashboard.

// The Okabe–Ito palette: eight colours distinguishable under the common forms
// of colour-blindness, in a fixed order so series keep their colour as rows move.
let palette = ["#0072B2", "#E69F00", "#009E73", "#CC79A7", "#56B4E9", "#D55E00", "#F0E442", "#999999"]

let install: (
  (~app: string, ~path: string) => promise<Collection.t>,
  unit => promise<(Dom.element, {..}) => ChartImpl.chart>,
  unit => promise<ChartImpl.chart => unit>,
  array<string>,
  string => option<string>,
) => (Dom.element, string) => unit = %raw(`
function (read, loadRender, loadDestroy, palette, misuraCss) {
  // Chart instances per container position: the nodes are recreated on every
  // render, so the old instance must be destroyed or it keeps animating a
  // detached canvas for ever.
  const chartState = new WeakMap();
  const stateFor = (container, index) => {
    let states = chartState.get(container);
    if (states === undefined) {
      states = new Map();
      chartState.set(container, states);
    }
    let state = states.get(index);
    if (state === undefined) {
      state = { chart: null, signature: null, canvas: null };
      states.set(index, state);
    }
    return state;
  };

  // Whole-string numbers, decimal comma accepted: "12,5" is 12.5, "10 items"
  // is nothing. Same philosophy as core/Numeric, widened by the comma because
  // chart data often arrives from CSV and open datasets.
  const numberOf = (value) => {
    const text = String(value ?? "").trim().replace(",", ".");
    if (text === "") return null;
    const parsed = Number(text);
    return Number.isFinite(parsed) ? parsed : null;
  };

  const fieldOf = (record, name) => {
    for (const field of record.fields) {
      if (field.name.toLowerCase() === name.toLowerCase()) return field.value;
    }
    return undefined;
  };

  const listOf = (value) => (value || "").split(",").map((s) => s.trim()).filter(Boolean);

  // The dashboard hook: which value is selected in the dashboard this node sits
  // in, if any — and the setter a click drives. Both no-ops outside one.
  const dash = () => globalThis.__rnDashboard;

  const themeColors = (node) => {
    const style = getComputedStyle(node);
    const text = style.color || "#222";
    return { text, grid: "color-mix(in srgb, " + text + " 18%, transparent)" };
  };

  const configFor = (kind, node, records) => {
    const colors = themeColors(node);
    // Highlight, never self-filter: the selection dims the other bars of the
    // chart whose own field is selected, and leaves every other chart whole —
    // the context stays visible, the way the BI tools do it.
    const selectedRaw = dash() ? dash().selectionFor(node) : null;
    const selectedOn = (field) =>
      selectedRaw && field && selectedRaw.field === field ? selectedRaw : null;
    const common = {
      responsive: true,
      maintainAspectRatio: false,
      animation: false,
      plugins: { legend: { labels: { color: colors.text } } },
    };
    const axes = {
      scales: {
        x: { ticks: { color: colors.text }, grid: { color: colors.grid } },
        y: { ticks: { color: colors.text }, grid: { color: colors.grid } },
      },
    };
    const dimBy = (selection) => (base, label) =>
      selection && selection.value !== label ? base + "55" : base;

    if (kind === "pie" || kind === "doughnut") {
      const labelField = node.getAttribute("data-rn-chart-label") || "";
      const dim = dimBy(selectedOn(labelField));
      const valueField = node.getAttribute("data-rn-chart-value") || "";
      const labels = [];
      const values = [];
      for (const record of records) {
        const label = fieldOf(record, labelField);
        const value = numberOf(fieldOf(record, valueField));
        if (label === undefined || value === null) continue;
        labels.push(String(label));
        values.push(value);
      }
      return {
        type: kind,
        data: {
          labels,
          datasets: [{
            data: values,
            backgroundColor: labels.map((label, i) => dim(palette[i % palette.length], label)),
          }],
        },
        options: { ...common },
      };
    }

    if (kind === "scatter") {
      const xField = node.getAttribute("data-rn-chart-x") || "";
      const yField = node.getAttribute("data-rn-chart-y") || "";
      const points = [];
      for (const record of records) {
        const x = numberOf(fieldOf(record, xField));
        const y = numberOf(fieldOf(record, yField));
        if (x === null || y === null) continue;
        points.push({ x, y });
      }
      return {
        type: "scatter",
        data: { datasets: [{ data: points, backgroundColor: palette[0] }] },
        options: { ...common, ...axes },
      };
    }

    // bar, line, area and radar: x is the label field, y one or MORE numeric
    // fields — one series per field, colours in palette order. Area is a line
    // with the ground coloured in; radar swaps the axes for spokes.
    const xField = node.getAttribute("data-rn-chart-x") || "";
    const yFields = listOf(node.getAttribute("data-rn-chart-y"));
    const labels = [];
    const rows = [];
    for (const record of records) {
      const label = fieldOf(record, xField);
      if (label === undefined) continue;
      labels.push(String(label));
      rows.push(record);
    }
    const stacked = node.hasAttribute("data-rn-chart-stacked");
    const withAlpha = (color) => color + "66";
    const dim = dimBy(selectedOn(xField));
    const datasets = yFields.map((field, i) => ({
      label: field,
      data: rows.map((record) => numberOf(fieldOf(record, field))),
      backgroundColor: kind === "bar"
        ? labels.map((label) => dim(palette[i % palette.length], label))
        : kind === "area" || kind === "radar"
          ? withAlpha(palette[i % palette.length])
          : palette[i % palette.length],
      borderColor: palette[i % palette.length],
      fill: kind === "area" ? (stacked && i > 0 ? "-1" : "origin") : kind === "radar",
      spanGaps: true,
    }));
    if (kind === "radar") {
      return {
        type: "radar",
        data: { labels, datasets },
        options: {
          ...common,
          scales: { r: { ticks: { color: colors.text, backdropColor: "transparent" }, grid: { color: colors.grid }, angleLines: { color: colors.grid }, pointLabels: { color: colors.text } } },
        },
      };
    }
    const options = { ...common, ...axes };
    // Bars sideways when the labels are long; series piled when the total is
    // the point. Both are the document's to say, as flags.
    if (kind === "bar" && node.hasAttribute("data-rn-chart-horizontal")) options.indexAxis = "y";
    if (stacked) {
      options.scales.x.stacked = true;
      options.scales.y.stacked = true;
    }
    return {
      type: kind === "area" ? "line" : kind,
      data: { labels, datasets },
      options,
    };
  };

  // Containers that have charts, for the rn:data refresh — WeakRef'd so a
  // closed preview is not kept alive by its charts.
  const known = [];
  let listening = false;
  const ensureListening = () => {
    if (listening) return;
    listening = true;
    window.addEventListener("rn:data", () => {
      for (const entry of [...known]) {
        const container = entry.ref.deref();
        if (!container || !container.isConnected) continue;
        rebind(container, entry.app, true);
      }
    });
  };

  async function rebind(container, app, fromEvent) {
    const nodes = [...container.querySelectorAll("[data-rn-chart]")];
    if (nodes.length === 0) return;
    const render = await loadRender();
    const destroy = await loadDestroy();

    nodes.forEach((node, index) => {
      const kind = node.getAttribute("data-rn-chart");
      const path = node.getAttribute("data-rn-chart-data");
      if (!path) return;
      const state = stateFor(container, index);
      const height = node.getAttribute("data-rn-chart-height");
      // Through the CSS parser, never concatenated into a style: the value
      // comes from a document, and setProperty refuses what is not a length.
      // Stessa regola della mappa, e per lo stesso guasto silenzioso: un numero
      // nudo non e' una lunghezza CSS. La decisione sta in core/CssLength, una
      // volta sola, perche' due copie di una regola sono due copie che divergono.
      if (height) {
        const misura = misuraCss(height);
        if (misura !== undefined) node.style.setProperty("height", misura);
      }

      read(app, path).then((collection) => {
        const live = [...container.querySelectorAll("[data-rn-chart]")][index];
        if (!live || !live.isConnected) return;
        const selected = dash() ? dash().selectionFor(live) : null;
        const signature = JSON.stringify([kind, collection.records, selected]);
        if (state.signature === signature && state.canvas && state.canvas.isConnected) return;
        state.signature = signature;

        if (state.chart) destroy(state.chart);
        let canvas = live.querySelector("canvas");
        if (!canvas) {
          canvas = document.createElement("canvas");
          live.appendChild(canvas);
        }
        state.canvas = canvas;
        const config = configFor(kind, live, collection.records);
        // The dashboard's control surface: a click on a bar or a slice selects
        // that x value for the sibling views; a second click clears it.
        config.options.onClick = (_event, elements) => {
          const d = dash();
          if (!d || elements.length === 0) return;
          const label = config.data.labels ? config.data.labels[elements[0].index] : null;
          if (label === undefined || label === null) return;
          const field = kind === "pie"
            ? live.getAttribute("data-rn-chart-label")
            : live.getAttribute("data-rn-chart-x");
          d.toggle(live, field, String(label));
        };
        state.chart = render(canvas, config);
      });
    });
  }

  return function (container, app) {
    if (container.querySelector("[data-rn-chart]") === null) return;
    ensureListening();
    if (!known.some((entry) => entry.ref.deref() === container)) {
      known.push({ ref: new WeakRef(container), app });
    } else {
      for (const entry of known) if (entry.ref.deref() === container) entry.app = app;
    }
    rebind(container, app, false);
  };
}
`)

// The lazy edge: ChartImpl is imported the first time a chart is actually on a
// page, and never again after that.
let loaded: ref<option<promise<(Dom.element, {..}) => ChartImpl.chart>>> = ref(None)

let loadRender = () =>
  switch loaded.contents {
  | Some(pending) => pending
  | None => {
      let pending = import(ChartImpl.render)
      loaded.contents = Some(pending)
      pending
    }
  }

let loadDestroy = () => import(ChartImpl.destroy)

let binder = install(CollectionStore.read, loadRender, loadDestroy, palette, CssLength.normalise)

let bind = (container, ~app) => binder(container, app)
