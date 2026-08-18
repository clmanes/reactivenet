// Perspective — the exploratory engine behind :::explore — statically imported
// here and nowhere else: reach this module only through the dynamic import()
// in ExploreBinder. It is WASM and workers, megabytes of them, and a document
// with no explore view must never pay for one.

%%raw(`
import perspective from "@finos/perspective";
import perspectiveViewer from "@finos/perspective-viewer";
import "@finos/perspective-viewer-datagrid";
import "@finos/perspective-viewer-d3fc";
// The viewer is styleless without a theme, and the d3fc plugins read their
// palette from it: no theme, null styles, a crash instead of a chart.
import "@finos/perspective-viewer/dist/css/pro.css";
// Under a bundler the WASM halves are not found by themselves: each is named
// as an asset URL and handed to its init. Same-origin either way, so the CSP
// is untouched.
import serverWasm from "@finos/perspective/dist/wasm/perspective-server.wasm?url";
import clientWasm from "@finos/perspective/dist/wasm/perspective-js.wasm?url";
import viewerWasm from "@finos/perspective-viewer/dist/wasm/perspective-viewer.wasm?url";

let workerPromise = null;
const sharedWorker = () => {
  if (!workerPromise) {
    workerPromise = (async () => {
      perspective.init_server(fetch(serverWasm));
      perspective.init_client(fetch(clientWasm));
      await perspectiveViewer.init_client(fetch(viewerWasm));
      return perspective.worker();
    })();
  }
  return workerPromise;
};

globalThis.__rnPerspective = { sharedWorker };
`)

type table

/** A Perspective table over plain row objects; types are inferred, so numbers
    aggregate as numbers. */
let makeTable: array<JSON.t> => promise<table> = %raw(`
async function (rows) {
  const worker = await globalThis.__rnPerspective.sharedWorker();
  return worker.table(rows);
}
`)

let replaceRows: (table, array<JSON.t>) => promise<unit> = %raw(`
async function (table, rows) {
  await table.replace(rows);
}
`)

/** A <perspective-viewer> mounted INTO the host, then loaded and restored —
    in that order: the plugins measure their element, and one loaded while
    detached reads undefined where its layout should be. */
let makeViewer: (Dom.element, table, JSON.t) => promise<Dom.element> = %raw(`
async function (host, table, config) {
  const viewer = document.createElement("perspective-viewer");
  viewer.style.width = "100%";
  viewer.style.height = "100%";
  host.textContent = "";
  host.appendChild(viewer);
  await viewer.load(table);
  // restore() is all-or-nothing, and there is no second chance: a configuration
  // it refuses stays pending on the element, so even restoring the plugin alone
  // afterwards fails with the same complaint. Whatever is handed here has to be
  // one the table can honour — which is why the binder drops column names the
  // rows do not have before this is called.
  try { await viewer.restore(config); } catch {}
  return viewer;
}
`)

/** Takes a viewer out of service. Perspective is explicit that removing a
    `<perspective-viewer>` from the document without this leaks WASM memory, and
    the preview replaces every node it owns on each debounced render — so a
    document being typed next to would leak one viewer per keystroke. It also
    stops the element measuring itself: a detached viewer whose resize still
    fires reads undefined where its layout should be, which is the
    `clientWidth of undefined` this used to throw. The table is deliberately
    NOT deleted: it is ours, it outlives the node, and the next viewer loads it
    again. */
let deleteViewer: Dom.element => promise<unit> = %raw(`
async function (viewer) {
  // delete() rejects if the element never finished loading — a teardown that
  // throws would leave the caller mid-swap, and there is nothing to recover.
  try { await viewer.delete(); } catch {}
  viewer.remove();
}
`)

let saveConfig: Dom.element => promise<JSON.t> = %raw(`
function (viewer) {
  return viewer.save();
}
`)
