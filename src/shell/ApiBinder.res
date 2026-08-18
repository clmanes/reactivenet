// `::api-query` — the generic REST connector, bound after each render with the
// same discipline as the od-* binder it sits beside:
//
//   - `{#key}` placeholders in the URL are reactive: percent-encoded on the
//     way in (a URL, so encoding is the escaping — there is no prepared-
//     statement seam here), re-run debounced when a key changes.
//   - A fetch runs when its resolved inputs changed — signature per container
//     position — plus a refresh button that always exists, and `every=` for
//     declared polling, floored at 60 seconds because public APIs rate-limit.
//   - Only https. The scheme is checked here even though the renderer already
//     refused anything else: this is the function that actually calls out.
//   - What lands is decided in core/ApiRows; the collection is marked DERIVED,
//     so it stays on this device and out of the sync.
//   - The scalar form (a store key in the brackets, a `pick` that lands on a
//     scalar) writes a reactive key instead of a collection: a ticker in a
//     :value, refreshed on the same button.

type labels = {
  loading: string,
  rows: string,
  stale: string,
  unreachable: string,
  refused: string,
  refresh: string,
}

let install: (
  (~app: string, ~path: string) => promise<Collection.t>,
  (~app: string, ~path: string, Collection.t) => promise<unit>,
  (~app: string, ~path: string) => promise<unit>,
  string => Nullable.t<string>,
  (string, string) => unit,
  (string => unit) => unit,
  (JSON.t, string) => option<JSON.t>,
  JSON.t => option<string>,
  (JSON.t, ~pairs: bool) => option<array<array<Collection.field>>>,
) => (Dom.element, string, labels) => unit = %raw(`
function (read, write, markDerived, storeGet, storeSet, storeSubscribe, picked, scalarOf, rowsOf) {
  // Inside a ::workflow this block does not start itself: the order, and whether it
  // runs at all after the step before it failed, is the workflow's answer. Asked
  // defensively, the way the dashboard's cross-filter is, so a document with no
  // workflow in it pays nothing.
  const wfDefers = (node) =>
    globalThis.__rnWorkflow ? globalThis.__rnWorkflow.defers(node) : false;
  const wfRegister = (node, run) => {
    if (globalThis.__rnWorkflow) globalThis.__rnWorkflow.register(node, run);
  };

  const apiState = new WeakMap();
  const stateFor = (container, index) => {
    let states = apiState.get(container);
    if (states === undefined) {
      states = new Map();
      apiState.set(container, states);
    }
    let state = states.get(index);
    if (state === undefined) {
      state = { signature: null, status: null, gen: 0, poll: null };
      states.set(index, state);
    }
    return state;
  };

  const KEY_PATTERN = /\{#([A-Za-z0-9_.]+)\}/g;
  const keysOf = (url) => {
    const found = [];
    let hit;
    const pattern = new RegExp(KEY_PATTERN.source, "g");
    while ((hit = pattern.exec(url))) if (!found.includes(hit[1])) found.push(hit[1]);
    return found;
  };
  const resolved = (url) =>
    url.replace(new RegExp(KEY_PATTERN.source, "g"), (_, key) => {
      const value = storeGet(key);
      return encodeURIComponent(value === null || value === undefined ? "" : value);
    });

  let live = [];
  let subscribed = false;
  const ensureSubscribed = () => {
    if (subscribed) return;
    subscribed = true;
    storeSubscribe((key) => {
      live = live.filter((entry) => entry.node.isConnected);
      for (const entry of live) {
        if (!entry.keys.includes(key)) continue;
        clearTimeout(entry.timer);
        entry.timer = setTimeout(entry.rerun, 400);
      }
    });
  };

  const paintStatus = (node, status) => {
    const element = node.querySelector(":scope > .rn-od-status");
    if (!element || !status) return;
    element.textContent = status.text;
    element.className = "rn-od-status " + (status.kind === "error" ? "rn-error" : "rn-muted");
  };

  return function (container, app, labels) {
    const nodes = [...container.querySelectorAll("[data-rn-api]")];
    if (nodes.length === 0) return;
    ensureSubscribed();

    nodes.forEach((node, index) => {
      const url = node.getAttribute("data-rn-api-url") || "";
      const into = node.getAttribute("data-rn-api-into");
      const key = node.getAttribute("data-rn-api-key");
      const pick = node.getAttribute("data-rn-api-pick") || "";
      const pairs = node.hasAttribute("data-rn-api-pairs");
      const everyGiven = parseInt(node.getAttribute("data-rn-api-every") || "", 10);
      // Public APIs rate-limit; the floor is the feature, not a nuisance.
      const every = Number.isNaN(everyGiven) ? 0 : Math.max(60, everyGiven);
      const state = stateFor(container, index);

      const run = (force) => {
        const target = [...container.querySelectorAll("[data-rn-api]")][index];
        if (!target || !target.isConnected) return;
        const address = resolved(url);
        if (!address.startsWith("https://")) return;
        const signature = app + " " + address + " " + (into || "") + " " + (key || "") + " " + pick + " " + pairs;
        if (!force && state.signature === signature) {
          paintStatus(target, state.status);
          return;
        }
        state.signature = signature;
        const gen = ++state.gen;
        state.status = { text: labels.loading, kind: "muted" };
        paintStatus(target, state.status);

        // Returned for the same reason od-query's is: a workflow awaits the step.
        return fetch(address, { headers: { accept: "application/json" } })
          .then(async (res) => {
            const body = await res.json().catch(() => null);
            if (!res.ok || body === null) throw new Error(labels.refused + " " + res.status);
            return body;
          })
          .then(async (body) => {
            if (state.gen !== gen) return;
            const fragment = picked(body, pick);
            if (fragment === undefined) throw new Error(labels.refused + " pick=" + pick);
            // The scalar form: a reactive key, not a collection.
            if (key) {
              const value = scalarOf(fragment);
              if (value === undefined) throw new Error(labels.refused + " pick=" + pick);
              storeSet(key, value);
              state.status = { text: value, kind: "muted" };
              paintStatus(target, state.status);
              return;
            }
            const fieldRows = rowsOf(fragment, pairs);
            if (fieldRows === undefined) throw new Error(labels.refused + " pick=" + pick);
            const records = fieldRows.map((fields, i) => ({ id: "api-" + i, fields }));
            await markDerived(app, into);
            await write(app, into, { records });
            if (state.gen !== gen) return;
            window.dispatchEvent(new Event("rn:data"));
            state.status = { text: records.length + " " + labels.rows, kind: "muted" };
            paintStatus(target, state.status);
          })
          .catch(async (error) => {
            if (state.gen !== gen) return;
            const message = String(error && error.message ? error.message : error);
            if (into && !message.startsWith(labels.refused)) {
              // Unreachable: the collection is the offline copy, as with od-*.
              const held = await read(app, into);
              if (state.gen !== gen) return;
              state.status = held.records.length > 0
                ? { text: held.records.length + " " + labels.rows + " — " + labels.stale, kind: "error" }
                : { text: labels.unreachable, kind: "error" };
            } else {
              state.status = { text: message.startsWith(labels.refused) ? message : labels.unreachable, kind: "error" };
            }
            paintStatus(target, state.status);
          });
      };

      // The refresh button always exists: polling is opt-in, a hand refresh is
      // not. Rebuilt each render like every control that carries words.
      const controls = node.querySelector(":scope > .rn-od-controls");
      if (controls) {
        controls.textContent = "";
        const refresh = document.createElement("button");
        refresh.type = "button";
        refresh.className = "rn-od-go";
        refresh.textContent = "↻";
        refresh.setAttribute("aria-label", labels.refresh);
        refresh.setAttribute("title", labels.refresh);
        refresh.addEventListener("click", () => run(true));
        controls.appendChild(refresh);
      }

      // A step of a workflow keeps its refresh button — a reader asking for fresh
      // rows is not out of order, it just makes the chain below it stale, which the
      // rn:data announcement already handles. What it gives up is starting itself and
      // its own poll: the workflow's every= is where a schedule belongs when there is
      // one, and two timers over one fetch would be two answers to one question.
      if (wfDefers(node)) {
        wfRegister(node, (asked) => run(asked));
        return;
      }
      live = live.filter((entry) => entry.node.isConnected && entry.node !== node);
      live.push({ node, keys: keysOf(url), rerun: () => run(false), timer: null });

      if (every > 0 && state.poll === null) {
        state.poll = setInterval(() => {
          const target = [...container.querySelectorAll("[data-rn-api]")][index];
          if (!target || !target.isConnected) {
            clearInterval(state.poll);
            state.poll = null;
            return;
          }
          run(true);
        }, every * 1000);
      }

      run(false);
    });
  };
}
`)

let binder = install(
  CollectionStore.read,
  CollectionStore.write,
  DerivedPaths.mark,
  ReactiveStore.get,
  ReactiveStore.set,
  ReactiveStore.subscribe,
  ApiRows.picked,
  ApiRows.scalar,
  ApiRows.rows,
)

let bind = (container, ~app, ~labels) => binder(container, app, labels)
