// `::python`, bound after each render — the same shape as the collections binder, and
// for the same reason: the markdown pipeline produces inert, sanitised DOM, and
// everything that runs or reads storage happens afterwards.
//
// Four rules hold this together:
//
//   - The code is read with `textContent`, from the fenced block marked already
//     rendered. It is never assigned as markup and never evaluated in the page: it
//     goes to a worker, over postMessage, as a string.
//   - The output comes back as text and goes in with `textContent` too. A traceback
//     is words; a print is words; neither is markup, and treating them as such would
//     make somebody's data a scripting vector in the one place a document is allowed
//     to compute.
//   - A run is started only when the code, the data, the packages or the *parameters*
//     have actually changed. The preview re-renders on every keystroke, and a Python
//     run per keystroke would make the editor useless.
//   - A `manual` block is never started by any of that. A simulated annealing must not
//     restart because somebody corrected a surname, so the author says so and the
//     block waits for its button — the Run the packages already had, made a choice.

type labels = {
  showCode: string,
  hideCode: string,
  running: string,
  loading: string,
  run: string,
  stop: string,
  progress: string,
}

let install: (
  (
    ~code: string,
    ~data: string,
    ~packages: array<string>,
    ~writes: string,
    ~params: string,
    ~ceiling: int,
    ~onProgress: (float, float, string) => unit,
    ~onPartial: string => unit,
  ) => promise<PythonRunner.outcome>,
  unit => unit,
  (~app: string, ~path: string) => promise<Collection.t>,
  (~app: string, ~path: string, Collection.t) => promise<unit>,
  (~stamp: string, ~taken: array<string>) => string,
  unit => string,
  string => Nullable.t<string>,
  (string => unit) => unit,
) => (Dom.element, string, labels) => unit = %raw(`
function (run, stopRun, read, write, makeId, now, storeGet, storeSubscribe) {
  // Inside a ::workflow this block does not start itself: the order, and whether it
  // runs at all after the step before it failed, is the workflow's answer. Asked
  // defensively, the way the dashboard's cross-filter is, so a document with no
  // workflow in it pays nothing.
  const wfDefers = (node) =>
    globalThis.__rnWorkflow ? globalThis.__rnWorkflow.defers(node) : false;
  const wfRegister = (node, run) => {
    if (globalThis.__rnWorkflow) globalThis.__rnWorkflow.register(node, run);
  };

  // What each block last ran and whether its source is open, per *container*: the
  // container is React's and survives, while every node — the output element
  // included — is recreated by setInnerHtml on each debounced render. The first
  // version kept the signature on the output's dataset, which therefore never
  // matched, and every keystroke anywhere in the document queued a full run of every
  // block.
  const blockState = new WeakMap();

  // Two minutes is the ceiling of a run nobody asked for. A manual block gets ten:
  // a person asked for that one, is watching the bar, and can stop it.
  const AUTOMATIC = 120000;
  const ASKED_FOR = 600000;

  const stateFor = (container, index) => {
    let states = blockState.get(container);
    if (states === undefined) {
      states = new Map();
      blockState.set(container, states);
    }
    let state = states.get(index);
    if (state === undefined) {
      state = { signature: null, shown: null, outcome: null, running: false };
      states.set(index, state);
    }
    return state;
  };

  // What a finished run looks like on the page. Split out because it is needed
  // twice: after a run, and on every re-render whose inputs are unchanged — the
  // render recreated the output node empty, and skipping the run must not also skip
  // showing what it produced last time.
  const paintOutcome = (output, outcome) => {
    output.textContent = "";
    if (outcome.error !== "") {
      const failure = document.createElement("pre");
      failure.className = "rn-python-error";
      failure.textContent = outcome.error;
      output.appendChild(failure);
      return;
    }
    const printed = outcome.output.trim();
    const value = outcome.value.trim();
    if (printed !== "" || value !== "") {
      const text = document.createElement("pre");
      text.className = "rn-python-printed";
      text.textContent = [printed, value].filter(Boolean).join("\n");
      output.appendChild(text);
    }
    for (const image of outcome.images) {
      const figure = document.createElement("img");
      figure.className = "rn-python-figure";
      // A data: URL, which the policy allows for images and nothing else. The bytes
      // come from matplotlib in the worker, not from the document.
      figure.src = "data:image/png;base64," + image;
      figure.alt = "";
      output.appendChild(figure);
    }
  };

  const codeOf = (node) => {
    const block = node.querySelector("pre code, pre");
    return block ? block.textContent.replace(/\n$/, "") : "";
  };

  const listOf = (value) =>
    (value || "").split(",").map((name) => name.trim()).filter(Boolean);

  // The controls: a Run button for a manual block, a Stop button and a bar while a
  // run is in flight. Built here rather than emitted by the renderer, for the same
  // reason the row buttons are — they carry words, and the renderer is installed once
  // with no language.
  const controlsOf = (node) => {
    let controls = node.querySelector(":scope > .rn-python-controls");
    if (!controls) {
      controls = document.createElement("div");
      controls.className = "rn-python-controls";
      node.insertBefore(controls, node.querySelector(":scope > .rn-python-output"));
    }
    return controls;
  };

  // Every block whose parameters are reactive keys, so a slider that changes one of
  // them can re-run exactly the blocks that read it — debounced, like every other
  // reactive engine here.
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

  return function (container, app, labels) {
    const blocks = [...container.querySelectorAll("[data-rn-python]")];
    if (blocks.length === 0) return;
    ensureSubscribed();

    blocks.forEach((node, index) => {
      const output = node.querySelector(":scope > .rn-python-output");
      const source = node.querySelector("pre");
      if (!output || !source) return;
      const state = stateFor(container, index);

      // The code is what the author wrote, not what the app shows first: a document
      // full of Python reads as its results, and the source is one press away.
      // Whether it is open right now survives the re-render, in the same state the
      // signature does.
      source.classList.add("rn-python-source");
      if (state.shown === null) state.shown = node.hasAttribute("data-rn-python-show");
      source.hidden = !state.shown;
      if (!node.querySelector(":scope > .rn-python-toggle")) {
        const toggle = document.createElement("button");
        toggle.type = "button";
        toggle.className = "rn-python-toggle";
        toggle.setAttribute("aria-expanded", state.shown ? "true" : "false");
        toggle.textContent = state.shown ? labels.hideCode : labels.showCode;
        toggle.addEventListener("click", () => {
          state.shown = source.hidden;
          source.hidden = !state.shown;
          toggle.setAttribute("aria-expanded", state.shown ? "true" : "false");
          toggle.textContent = state.shown ? labels.hideCode : labels.showCode;
        });
        node.insertBefore(toggle, source);
      }

      const code = codeOf(node);
      const paths = listOf(node.getAttribute("data-rn-python-data"));
      const packages = listOf(node.getAttribute("data-rn-python-packages"));
      const manual = node.hasAttribute("data-rn-python-manual");
      // A block that wrote to a collection it also reads would re-run itself for
      // ever. Refused here rather than left to spin.
      const writesTo = node.getAttribute("data-rn-python-writes") || "";
      const writes = paths.includes(writesTo) ? "" : writesTo;

      // The reactive keys the block named. They are read at the moment of the run and
      // are part of the signature, so moving a slider re-runs the block and moving it
      // back does not run it twice.
      const keys = listOf(node.getAttribute("data-rn-python-params"));
      const parameters = () => {
        const found = {};
        for (const key of keys) {
          const held = storeGet(key);
          found[key] = held === null || held === undefined ? "" : String(held);
        }
        return found;
      };

      // The node the reader is actually looking at: this closure may be a render or
      // two older than the DOM, because the preview replaces every node it owns.
      const liveNode = () => [...container.querySelectorAll("[data-rn-python]")][index];
      const paintProgress = (done, total, message) => {
        const target = liveNode();
        const bar = target && target.querySelector(":scope > .rn-python-controls .rn-python-bar");
        const said = target && target.querySelector(":scope > .rn-python-controls .rn-python-said");
        if (bar) {
          // No total is an honest "no idea how long": an indeterminate bar says that,
          // and a bar pretending to be at 0% does not.
          if (total > 0) {
            bar.max = total;
            bar.value = done;
          } else {
            bar.removeAttribute("value");
          }
        }
        if (said) said.textContent = message !== "" ? message : labels.progress;
      };

      const runNow = (payload, params, signature) => {
        const controls = controlsOf(node);
        state.signature = signature;
        state.running = true;
        output.textContent = "";
        const pending = document.createElement("p");
        pending.className = "rn-python-pending rn-muted";
        // The first run pays for the runtime, and several seconds of nothing reads
        // as broken; after that it is quick and the message is just honest.
        pending.textContent = globalThis.__rnPython && globalThis.__rnPython.worker
          ? labels.running
          : labels.loading;
        output.appendChild(pending);

        controls.textContent = "";
        const bar = document.createElement("progress");
        bar.className = "rn-python-bar";
        bar.setAttribute("aria-label", labels.progress);
        const said = document.createElement("span");
        said.className = "rn-python-said rn-muted";
        said.textContent = labels.progress;
        const halt = document.createElement("button");
        halt.type = "button";
        halt.className = "rn-od-go rn-python-stop";
        halt.textContent = labels.stop;
        // Stop kills the interpreter and answers with the last partial(). That is
        // the honest half of the promise: without a partial there is nothing to keep,
        // and the block says as much by writing nothing.
        halt.addEventListener("click", () => stopRun());
        controls.append(bar, said, halt);

        return run(
          code, payload, packages, writes, JSON.stringify(params), manual ? ASKED_FOR : AUTOMATIC,
          paintProgress,
          () => undefined
        ).then((outcome) => {
          state.running = false;
          // A later run of the same block has already replaced this one — and the
          // output node itself may be a render older than the one on screen.
          if (state.signature !== signature) return;
          state.outcome = outcome;
          const target = liveNode();
          if (!target) return;
          const shown = target.querySelector(":scope > .rn-python-output");
          if (shown) paintOutcome(shown, outcome);
          offerRun(target);
          if (outcome.error !== "") return;
          // Rows the code offered back become a collection of this app: the same
          // shape everything else stores, ids and all, so a ::list can read what
          // Python worked out. An id the code carried is kept, which is what makes
          // a second run *update* those rows instead of doubling them. After a stop
          // these are the last partial() rows — which is the point of publishing one.
          if (writes !== "" && outcome.rows !== "") {
            const offered = JSON.parse(outcome.rows);
            const taken = [];
            const records = offered.map((row) => {
              const fields = [];
              let id = "";
              for (const [name, value] of Object.entries(row)) {
                if (name === "id") { id = String(value); continue; }
                fields.push({ name, value: String(value) });
              }
              if (id === "" || taken.includes(id)) id = makeId(now(), taken);
              taken.push(id);
              return { id, fields };
            });
            write(app, writes, { records }).then(() => {
              // The views of that collection are bound elsewhere and have no idea
              // this happened; this is the same announcement the data panel makes.
              window.dispatchEvent(new Event("rn:data"));
            });
          }
        });
      };

      // A manual block always shows the way to start it — before the first run and
      // after every one, because "run it again with what I have just changed" is the
      // whole reason its inputs are allowed to move without starting anything.
      //
      // The clearing comes FIRST and applies to every block, manual or not. Leaving
      // early for an automatic one left it holding the bar, the word "running" and a
      // Stop button for ever: the run was over, the answer was printed right above,
      // and the block went on saying it was working. It only ever showed where
      // nothing re-renders, which is the app running on its own address — beside the
      // editor the next keystroke built a fresh node and took the stale controls
      // with it, which is why it hid for so long.
      const offerRun = (target) => {
        const holder = target || liveNode();
        if (!holder) return;
        const controls = controlsOf(holder);
        controls.textContent = "";
        if (!manual) return;
        const start = document.createElement("button");
        start.type = "button";
        start.className = "rn-od-go";
        start.textContent = labels.run;
        start.addEventListener("click", () => gather(true));
        controls.appendChild(start);
      };

      const gather = (asked) =>
        Promise.all(paths.map((path) => read(app, path).then((collection) => [path, collection])))
          .then((pairs) => {
            // Plain values, the way Python will see them: a list of dicts of strings,
            // which is what a collection is.
            const data = {};
            for (const [path, collection] of pairs) {
              data[path] = collection.records.map((record) => {
                const row = { id: record.id };
                for (const field of record.fields) row[field.name] = field.value;
                return row;
              });
            }
            const payload = JSON.stringify(data);
            const params = parameters();
            // Nothing has changed since the last run of this block, so there is
            // nothing to run. This is what makes a document with Python in it
            // typeable — and the parameters are in here, so a slider is an input like
            // any other rather than a thing the block never notices.
            const signature =
              packages.join(",") + "\u0000" + writes + "\u0000" + code + "\u0000" +
              JSON.stringify(params) + "\u0000" + payload;
            if (!asked) {
              // A manual block runs on its button and on nothing else. Its last
              // outcome is repainted into the fresh node, exactly as an unchanged
              // automatic block's is.
              if (manual) {
                if (state.outcome && !state.running) paintOutcome(output, state.outcome);
                if (!state.running) offerRun(node);
                // Inside a workflow that is a step waiting for its button, and a
                // workflow told otherwise would tick it off and carry on to the steps
                // that need what it never produced.
                return state.outcome ? undefined : "waiting";
              }
              if (state.signature === signature) {
                // Same inputs, fresh DOM: repaint what the last run produced.
                if (state.outcome) paintOutcome(output, state.outcome);
                return;
              }
            }
            return runNow(payload, params, signature);
          })
          .catch(() => undefined);

      // Re-run when a key this block reads moves — and only then: live is keyed by
      // the node, which is new on every render, so the old entries go with it.
      live = live.filter((entry) => entry.node.isConnected && entry.node !== node);
      // A step of a workflow keeps "manual" meaning what it means everywhere else —
      // "only when asked" — and inside one the workflow is who asks: its Run button
      // forces, its cascade does not. The block's own button stays where it is, which
      // is why the strip hides an engine's status and never its controls.
      if (wfDefers(node)) {
        wfRegister(node, (asked) => gather(asked));
        offerRun(node);
        if (state.outcome && !state.running) paintOutcome(output, state.outcome);
        return;
      }
      if (keys.length > 0 && !manual) {
        live.push({ node, keys, rerun: () => gather(false), timer: null });
      }

      gather(false);
    });
  };
}
`)

let runner = install(
  PythonRunner.runWatched,
  PythonRunner.stop,
  CollectionStore.read,
  CollectionStore.write,
  RecordId.make,
  Clock.timestamp,
  ReactiveStore.get,
  ReactiveStore.subscribe,
)

let bind = (container, ~app, ~labels) => runner(container, app, labels)
