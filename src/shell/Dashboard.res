// `::dashboard` — the cross-filter of the real BI tools, one WeakMap deep.
//
// A click on a bar or a slice of a nested chart SELECTS that x value; the
// sibling views — lists, tables, boards, calendars, maps — narrow to the rows
// that match, and a chip at the top shows the filter with its ✕. A second
// click on the same bar clears it. Three rules carried from the tools this
// imitates:
//
//   - The clicked chart does not filter itself: it shows the selection by
//     dimming everything else, so the context stays visible.
//   - A view over another collection filters only the rows that HAVE the
//     selected field; rows without it are none of the filter's business.
//   - The selection is this device's alone — it lives in a WeakMap keyed by
//     the dashboard's container-side element and is never written anywhere,
//     so it survives document edits and is invisible to sync.
//
// The hook is installed once, at module load, as globalThis.__rnDashboard:
// the chart binder drives `toggle`, and every row-reading binder asks
// `rowsFor` on its way to drawing. The chip is rebuilt here on every bind and
// on every toggle, because its words come from Translations and its nodes are
// sanitiser output recreated each render.

type labels = {removeFilter: string}

%%raw(`
const selections = new WeakMap();
let lastLabels = { removeFilter: "✕" };

const dashOf = (node) => (node && node.closest ? node.closest("[data-rn-dashboard]") : null);

const fieldOf = (record, name) => {
  for (const field of record.fields) {
    if (field.name.toLowerCase() === name.toLowerCase()) return field.value;
  }
  return undefined;
};

const paintChip = (dash) => {
  const holder = dash.querySelector(":scope > .rn-dashboard-chip");
  if (!holder) return;
  holder.textContent = "";
  const selection = selections.get(dash);
  if (!selection) return;
  const chip = document.createElement("span");
  chip.className = "rn-chip";
  const text = document.createElement("span");
  text.textContent = selection.field + " = " + selection.value;
  const clear = document.createElement("button");
  clear.type = "button";
  clear.className = "rn-chip-clear";
  clear.setAttribute("aria-label", lastLabels.removeFilter);
  clear.setAttribute("title", lastLabels.removeFilter);
  clear.textContent = "✕";
  clear.addEventListener("click", () => {
    selections.delete(dash);
    paintChip(dash);
    window.dispatchEvent(new Event("rn:data"));
  });
  chip.appendChild(text);
  chip.appendChild(clear);
  holder.appendChild(chip);
};

globalThis.__rnDashboard = {
  // The selection governing this node, or null outside any dashboard.
  selectionFor(node) {
    const dash = dashOf(node);
    return dash ? selections.get(dash) || null : null;
  },

  // What a view inside a dashboard actually shows: the rows that match the
  // selection — or carry no such field at all.
  rowsFor(node, records) {
    const dash = dashOf(node);
    if (!dash) return records;
    const selection = selections.get(dash);
    if (!selection) return records;
    return records.filter((record) => {
      const value = fieldOf(record, selection.field);
      return value === undefined || String(value) === selection.value;
    });
  },

  // A chart's click: select, or clear when it is the same value again.
  toggle(node, field, value) {
    const dash = dashOf(node);
    if (!dash || !field) return;
    const current = selections.get(dash);
    if (current && current.field === field && current.value === value) selections.delete(dash);
    else selections.set(dash, { field, value });
    paintChip(dash);
    window.dispatchEvent(new Event("rn:data"));
  },
};
`)

let install: labels => Dom.element => unit = %raw(`
function (labels) {
  return function (container) {
    lastLabels = labels;
    container.querySelectorAll("[data-rn-dashboard]").forEach(paintChip);
  };
}
`)

let bind = (container, ~labels) => install(labels)(container)
