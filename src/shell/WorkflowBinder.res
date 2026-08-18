// `::workflow` — the orchestrator, bound after every render like everything else that
// touches storage or the network.
//
// It adds nothing to what a document can compute. What it adds is the four things no
// engine can have on its own, and each of them is a failure this app has already met
// somewhere else:
//
//   - **An order.** The engines re-run on `rn:data` and settle by cascade, which
//     converges and reports nothing while it does. A chain of four looked identical
//     halfway through and finished.
//   - **A trigger.** Nothing here could start on a saved row or at six in the evening.
//   - **One status.** Five engines are five status lines saying different things about
//     one operation.
//   - **Nothing downstream of a failure.** A number computed from an input that never
//     arrived is worse than no number, because nothing on the page tells them apart —
//     the same reason an unreachable service leaves the last rows in place and says
//     "stale" rather than writing an empty collection over them.
//
// Two decisions carry the design.
//
// **The steps are the engines already in the document**, found by the `data-rn-*`
// attributes they already carry, and the edges are the collection names they already
// name. No node language, nothing new for an author to learn, and one graph — the same
// one `reactive_analyze` builds — rather than two that can disagree.
//
// **The report is the engine's own status line.** `WorkflowHost` hands the run over
// and the strip then reads what the engine painted: the class says whether it worked,
// the text is already in the reader's language because the engine wrote it there. An
// engine therefore learns exactly one thing to become a step, and an engine that grows
// a new message tomorrow is understood here without being touched.
//
// The state is per container position in a WeakMap, addressed by the workflow's place
// in the container — the rule a table's page and a Python block's signature already
// follow, because `setInnerHtml` recreates every node on each debounced render while
// the container is React's and survives. What must outlive the session — when it last
// ran — is in IndexedDB, keyed by the workflow's own id when the author gave it one.

type labels = {
  run: string,
  stop: string,
  steps: string,
  waiting: string,
  running: string,
  skipped: string,
  failed: string,
  last: string,
  next: string,
  never: string,
  cycle: string,
  looped: string,
  empty: string,
  whileOpen: string,
}

type helpers = {
  plan: array<WorkflowGraph.step> => WorkflowGraph.plan,
  downstream: (array<WorkflowGraph.step>, int) => array<int>,
  seconds: string => option<int>,
  minuteOfDay: string => option<int>,
  saves: string => array<string>,
  changes: string => array<string>,
  opens: string => bool,
  dueEvery: (~last: float, ~now: float, ~seconds: int) => bool,
  remainingEvery: (~last: float, ~now: float, ~seconds: int) => int,
  dueAt: (
    ~lastDay: string,
    ~today: string,
    ~nowMinutes: int,
    ~atMinutes: int,
    ~catchup: bool,
  ) => bool,
  remainingAt: (~ranToday: bool, ~nowMinutes: int, ~atMinutes: int) => int,
  runOf: Dom.element => Nullable.t<bool => promise<Nullable.t<string>>>,
  idbGet: string => promise<Nullable.t<string>>,
  idbSet: (string, string) => promise<unit>,
  localize: (string, string) => string,
  subscribe: (string => unit) => unit,
}

let install: helpers => (Dom.element, string, labels, string) => unit = %raw(`
function (helpers) {
  // Every engine that produces something. Written as one selector because the order
  // that matters is document order — which is what querySelectorAll gives — and not
  // the order of this list.
  const ENGINES =
    "[data-rn-od],[data-rn-api],[data-rn-sql],[data-rn-ml],[data-rn-python],[data-rn-ai]";

  const list = (given) => (given || "").split(",").map((s) => s.trim()).filter(Boolean);

  // The rows an engine reads and the rows it writes, read off the attributes the
  // renderer already emitted. Nothing here parses a document: by the time a workflow
  // binds, the grammar has been read once, in core, and this is the result of it.
  const describe = (node) => {
    const at = (name) => node.getAttribute(name);
    if (node.hasAttribute("data-rn-od")) {
      // od-search is a box a reader types in, not a step: it runs when somebody
      // presses it and never on its own. Counting it would put a line in the strip
      // that says "done" about a search nobody has made.
      const kind = at("data-rn-od");
      if (kind === "search") return null;
      return { name: "od-" + kind, reads: [], writes: list(at("data-rn-od-into")) };
    }
    if (node.hasAttribute("data-rn-api")) {
      return { name: "api-query", reads: [], writes: list(at("data-rn-api-into")) };
    }
    if (node.hasAttribute("data-rn-sql")) {
      return {
        name: "sql",
        reads: list(at("data-rn-sql-data")),
        writes: list(at("data-rn-sql-into")),
      };
    }
    if (node.hasAttribute("data-rn-ml")) {
      return {
        name: "ml-" + at("data-rn-ml"),
        reads: list(at("data-rn-ml-data")),
        writes: list(at("data-rn-ml-into")),
      };
    }
    if (node.hasAttribute("data-rn-python")) {
      return {
        name: "python",
        reads: list(at("data-rn-python-data")),
        writes: list(at("data-rn-python-writes")),
      };
    }
    if (node.hasAttribute("data-rn-ai")) {
      // An ai-classify, ai-rule or ai-pipeline writes ONE FIELD back into the rows it
      // read: the collection is its input and its output at once, which is not a
      // cycle — it is one value of one row moving. Declaring it a writer would make
      // two of them over the same collection feed each other and both would be
      // reported as a circle. So they declare what they read and nothing else, and
      // their place in the run is the place the author wrote them in, which is what
      // the stable order is for. It is the same distinction the analyzer draws: they
      // change a collection, they do not OWN it the way a ::python{writes} does.
      // Only the four that work through a collection on their own are steps. A chat,
      // an agent, a question box and the ones that fill a form's draft all wait for a
      // person, and a strip reporting them as finished would be reporting on somebody
      // who has not arrived yet.
      const kind = at("data-rn-ai");
      if (!["summary", "classify", "rule", "pipeline"].includes(kind)) return null;
      return {
        name: "ai-" + kind,
        reads: list(at("data-rn-ai-data")),
        writes: list(at("data-rn-ai-into")),
      };
    }
    return null;
  };

  // The engines belonging to THIS workflow: a nested one owns its own, and asking
  // closest() is the same containment question a field asks about its form.
  const collect = (host) => {
    const found = [];
    for (const node of host.querySelectorAll(ENGINES)) {
      if (node.closest("[data-rn-workflow]") !== host) continue;
      const step = describe(node);
      if (step) found.push({ node, step });
    }
    return found;
  };

  // What the engine said about itself. The class is the verdict — structural, so it
  // does not depend on anybody's language — and the text is the engine's own words,
  // already translated because it wrote them.
  const reportOf = (node) => {
    const status = node.querySelector(":scope > .rn-od-status");
    if (status) {
      return {
        kind: status.classList.contains("rn-error") ? "error" : "done",
        text: (status.textContent || "").trim(),
      };
    }
    // Python says it in its output rather than in a status line: a traceback is a
    // failure, and its last line is the part that names what went wrong.
    const printed = node.querySelector(":scope > .rn-python-output");
    if (printed) {
      const failure = printed.querySelector(".rn-python-error");
      if (failure) {
        const lines = (failure.textContent || "").trim().split("\n");
        return { kind: "error", text: lines[lines.length - 1] || "" };
      }
      return { kind: "done", text: "" };
    }
    return { kind: "done", text: "" };
  };

  const stamp = (value) => String(value).padStart(2, "0");
  const localDay = (when) =>
    when.getFullYear() + "-" + stamp(when.getMonth() + 1) + "-" + stamp(when.getDate());
  const localMinutes = (when) => when.getHours() * 60 + when.getMinutes();

  const wfState = new WeakMap();
  const stateFor = (container, index) => {
    let states = wfState.get(container);
    if (states === undefined) {
      states = new Map();
      wfState.set(container, states);
    }
    let state = states.get(index);
    if (state === undefined) {
      state = {
        gen: 0,
        running: false,
        marks: [],
        order: [],
        message: null,
        last: 0,
        lastDay: "",
        loaded: false,
        settledAt: 0,
        poll: null,
        timer: null,
      };
      states.set(index, state);
    }
    return state;
  };

  // Every workflow currently on a page, for the triggers that arrive from outside a
  // render: a saved row, a moved key, a tick of the clock. Pruned by liveness, like
  // the od-query and Python binders' own lists.
  let live = [];
  let listening = false;

  const pokeAll = (reason) => {
    live = live.filter((entry) => entry.node.isConnected);
    for (const entry of live) entry.hear(reason);
  };

  const ensureListening = () => {
    if (listening) return;
    listening = true;
    // A saved row. The event carries the collection so a workflow can ask about the
    // one it was told to watch rather than re-running on every write in the app.
    window.addEventListener("rn:collection-write", (event) => {
      const path = event && event.detail ? event.detail.path : undefined;
      pokeAll({ kind: "write", path: path || "" });
    });
    // Anything else that moved the data — a CSV import, another workflow, a form.
    window.addEventListener("rn:data", () => pokeAll({ kind: "data" }));
    helpers.subscribe((key) => pokeAll({ kind: "key", key }));
    // A laptop that slept through six o'clock finds out the moment it is looked at,
    // instead of waiting for the next tick of a timer that was not running either.
    document.addEventListener("visibilitychange", () => {
      if (!document.hidden) pokeAll({ kind: "visible" });
    });
  };

  return function (container, app, labels, locale) {
    const hosts = [...container.querySelectorAll("[data-rn-workflow]")];
    if (hosts.length === 0) return;
    ensureListening();

    hosts.forEach((host, index) => {
      const state = stateFor(container, index);
      const at = (name) => host.getAttribute("data-rn-workflow-" + name);
      const title = at("title") || "";
      const every = helpers.seconds(at("every") || "");
      const atMinutes = helpers.minuteOfDay(at("at") || "");
      const on = at("on") || "";
      const watched = helpers.saves(on);
      const keys = helpers.changes(on);
      const catchup = host.hasAttribute("data-rn-workflow-catchup");
      const scheduled = every !== undefined || atMinutes !== undefined;
      const memory = "workflow:" + app + ":" + (host.id || String(index));

      // The node on screen NOW: this closure may be a render or two older than the
      // DOM, because the preview replaces every node it owns.
      const liveHost = () => [...container.querySelectorAll("[data-rn-workflow]")][index];

      const paint = () => {
        const target = liveHost();
        if (!target) return;
        const head = target.querySelector(":scope > .rn-wf-strip > .rn-wf-head");
        const steps = target.querySelector(":scope > .rn-wf-strip > .rn-wf-steps");
        if (!head || !steps) return;

        head.textContent = "";
        if (title !== "") {
          const name = document.createElement("span");
          name.className = "rn-wf-title";
          name.textContent = title;
          head.appendChild(name);
        }
        const actions = document.createElement("span");
        actions.className = "rn-wf-actions";
        if (state.marks.length > 0) {
          const go = document.createElement("button");
          go.type = "button";
          go.className = "rn-od-go";
          go.textContent = at("label") || labels.run;
          go.disabled = state.running;
          go.addEventListener("click", () => runAll(true));
          actions.appendChild(go);
        }
        if (state.running) {
          const halt = document.createElement("button");
          halt.type = "button";
          halt.className = "rn-od-go rn-wf-stop";
          halt.textContent = labels.stop;
          // Between steps, not inside one: a fetch already in flight finishes and a
          // Python block keeps its own Stop. What this guarantees is that nothing
          // FURTHER runs, which is the half that matters — the rest would be a
          // promise about somebody else's code.
          halt.addEventListener("click", () => {
            state.gen = state.gen + 1;
            state.running = false;
            paint();
          });
          actions.appendChild(halt);
        }
        head.appendChild(actions);

        const said = document.createElement("p");
        said.className = "rn-wf-when rn-muted";
        said.textContent = whenLine();
        head.appendChild(said);

        if (state.message) {
          const note = document.createElement("p");
          note.className = state.message.kind === "error" ? "rn-error" : "rn-muted";
          note.textContent = state.message.text;
          head.appendChild(note);
        }

        steps.textContent = "";
        if (state.marks.length === 0) return;
        const ordered = document.createElement("ol");
        ordered.className = "rn-wf-list";
        ordered.setAttribute("aria-label", labels.steps);
        // Listed in the order they RUN, not the order they were written — that is
        // what the strip is reporting on, and a chain written back to front would
        // otherwise show a document nobody is reading beside a run nobody can follow.
        // A step no order could place comes last, where it can be seen not to run.
        const shown = state.running || state.order.length > 0
          ? state.order.concat(state.marks.map((_, i) => i).filter((i) => !state.order.includes(i)))
          : state.marks.map((_, i) => i);
        shown.map((position) => state.marks[position]).forEach((mark) => {
          if (!mark) return;
          const line = document.createElement("li");
          line.className = "rn-wf-step rn-wf-" + mark.kind;
          const glyph = document.createElement("span");
          glyph.className = "rn-wf-mark";
          // The glyph carries the state, not the colour: §1.4.1 says colour may not
          // be the only way of telling, and the word beside it says it a third time.
          glyph.textContent = MARKS[mark.kind] || "·";
          glyph.setAttribute("aria-hidden", "true");
          const name = document.createElement("span");
          name.className = "rn-wf-name";
          name.textContent = mark.name;
          const say = document.createElement("span");
          say.className = mark.kind === "error" ? "rn-wf-say rn-error" : "rn-wf-say rn-muted";
          say.textContent = mark.say;
          line.append(glyph, name, say);
          ordered.appendChild(line);
        });
        steps.appendChild(ordered);
      };

      const whenLine = () => {
        const parts = [];
        parts.push(
          labels.last + " " + (state.last > 0
            ? helpers.localize(new Date(state.last).toISOString(), locale)
            : labels.never)
        );
        if (scheduled) {
          const now = new Date();
          if (every !== undefined) {
            const left = helpers.remainingEvery(state.last, now.getTime(), every);
            parts.push(
              labels.next + " " +
                helpers.localize(new Date(now.getTime() + left * 1000).toISOString(), locale)
            );
          } else if (atMinutes !== undefined) {
            const left = helpers.remainingAt(
              state.lastDay === localDay(now),
              localMinutes(now),
              atMinutes
            );
            parts.push(
              labels.next + " " +
                helpers.localize(new Date(now.getTime() + left * 60000).toISOString(), locale)
            );
          }
          // Said out loud, because it is precisely what the word "automation" makes a
          // reader expect and precisely what a browser tab cannot do. There is no
          // server here and the service worker precaches rather than executes.
          parts.push(labels.whileOpen);
        }
        return parts.join(" · ");
      };

      const remember = (when) => {
        state.last = when.getTime();
        state.lastDay = localDay(when);
        return helpers.idbSet(memory, JSON.stringify({ last: state.last, day: state.lastDay }));
      };

      const runAll = async (force) => {
        const target = liveHost();
        if (!target || !target.isConnected || state.running) return;
        const found = collect(target);
        const steps = found.map((entry) => entry.step);
        const plan = helpers.plan(steps);

        if (found.length === 0) {
          state.marks = [];
          state.message = { kind: "muted", text: labels.empty };
          paint();
          return;
        }

        const gen = state.gen + 1;
        state.gen = gen;
        state.running = true;
        state.order = plan.order;
        state.message = plan.cycle.length > 0 ? { kind: "error", text: labels.cycle } : null;
        state.marks = found.map((entry) => ({
          kind: "waiting",
          name: nameOf(entry.step),
          say: labels.waiting,
        }));
        // A step no order could place never runs, and the strip says which ones and
        // why rather than leaving them for ever at "waiting".
        plan.cycle.forEach((position) => {
          state.marks[position] = {
            kind: "cycle",
            name: nameOf(steps[position]),
            say: labels.looped,
          };
        });
        paint();

        const blocked = new Set();
        for (const position of plan.order) {
          if (state.gen !== gen) break;
          const entry = found[position];
          if (blocked.has(position)) {
            state.marks[position] = {
              kind: "skipped",
              name: nameOf(entry.step),
              say: labels.skipped,
            };
            continue;
          }
          state.marks[position] = {
            kind: "running",
            name: nameOf(entry.step),
            say: labels.running,
          };
          paint();
          const run = helpers.runOf(entry.node);
          let verdict = "";
          if (run) {
            // An engine that throws has already painted why; what must not happen is
            // the loop stopping on it, because the steps beside it are none of its
            // business.
            try {
              verdict = (await run(force)) || "";
            } catch (error) {
              void error;
            }
          }
          if (state.gen !== gen) break;
          // "waiting" is the engine saying it declined: a gate is closed and a person
          // has to press its button. It is NOT a step that finished — the difference
          // is the whole point of the strip, and everything below it must be held
          // back exactly as it is after a failure, because what it needed did not
          // arrive either way.
          if (verdict === "waiting") {
            state.marks[position] = {
              kind: "waiting",
              name: nameOf(entry.step),
              say: labels.waiting,
            };
            for (const later of helpers.downstream(steps, position)) blocked.add(later);
            paint();
            continue;
          }
          const report = reportOf(entry.node);
          state.marks[position] = {
            kind: report.kind,
            name: nameOf(entry.step),
            say: report.kind === "error" && report.text === "" ? labels.failed : report.text,
          };
          if (report.kind === "error") {
            for (const later of helpers.downstream(steps, position)) blocked.add(later);
          }
          paint();
        }

        if (state.gen !== gen) {
          state.running = false;
          paint();
          return;
        }
        state.running = false;
        state.settledAt = Date.now();
        // A run in which some step was still waiting for a person is not a run that
        // happened: stamping it would let a daily schedule tick itself off without
        // having produced anything, and nothing would try again until tomorrow.
        if (!state.marks.some((mark) => mark && mark.kind === "waiting")) {
          await remember(new Date());
        }
        paint();
      };

      const due = () => {
        const now = new Date();
        if (every !== undefined && helpers.dueEvery(state.last, now.getTime(), every)) return true;
        if (
          atMinutes !== undefined &&
          helpers.dueAt(state.lastDay, localDay(now), localMinutes(now), atMinutes, catchup)
        ) {
          return true;
        }
        return false;
      };

      const hear = (reason) => {
        if (state.running) return;
        if (reason.kind === "write") {
          if (watched.length > 0 && watched.includes(reason.path)) runAll(true);
          return;
        }
        if (reason.kind === "key") {
          if (keys.includes(reason.key)) {
            clearTimeout(state.timer);
            state.timer = setTimeout(() => runAll(true), 400);
          }
          return;
        }
        if (reason.kind === "visible") {
          if (due()) runAll(true);
          else paint();
          return;
        }
        // rn:data — the ordinary cascade, and the reason a workflow is no less
        // reactive than the loose directives were. It costs nothing when nothing
        // changed: every engine's own signature makes an unchanged step a no-op.
        //
        // The quiet period is what stops the echo: the steps of a run that has just
        // finished announced rn:data themselves, and answering that would walk the
        // whole chain again to discover that none of it moved.
        if (Date.now() - state.settledAt < 800) return;
        clearTimeout(state.timer);
        state.timer = setTimeout(() => runAll(false), 300);
      };

      live = live.filter((entry) => entry.node.isConnected && entry.node !== host);
      live.push({ node: host, hear });

      // A schedule needs a bell of its own: nothing else would ring at six o'clock.
      // Thirty seconds is the resolution — the minute is the unit anybody writes, and
      // a background tab is throttled to about a tick a minute anyway.
      if (scheduled && state.poll === null) {
        state.poll = setInterval(() => {
          const alive = liveHost();
          if (!alive || !alive.isConnected) {
            clearInterval(state.poll);
            state.poll = null;
            return;
          }
          if (!state.running && due()) runAll(true);
          else paint();
        }, 30000);
      }

      // The last run outlives the session, so it is read once and the strip is
      // repainted with it — otherwise a reload would say "never run" about a workflow
      // that ran an hour ago, and a daily schedule would fire a second time.
      const start = (first) => {
        paint();
        // Forced when the clock says so, or when the document asked to be brought up
        // to date on opening; otherwise the ordinary pass, which every engine's own
        // signature turns into a no-op if nothing moved.
        if ((scheduled && due()) || (first && helpers.opens(on))) runAll(true);
        else runAll(false);
      };
      if (state.loaded) {
        start(false);
      } else {
        state.loaded = true;
        helpers.idbGet(memory).then((held) => {
          if (held) {
            try {
              const kept = JSON.parse(held);
              state.last = Number(kept.last) || 0;
              state.lastDay = String(kept.day || "");
            } catch (error) {
              void error;
            }
          }
          start(true);
        });
      }
    });
  };

  function nameOf(step) {
    const produced = step.writes.filter(Boolean);
    return produced.length === 0 ? step.name : step.name + " \u2192 " + produced.join(", ");
  }
}
`)

// The glyphs, out of the closure so they are built once. A tick, a cross and a dot are
// the whole vocabulary: the word beside them says the same thing, and the colour says
// it a third time — never alone, which is §1.4.1.
%%raw(`
const MARKS = {
  waiting: "\u00b7",
  running: "\u27f3",
  done: "\u2713",
  error: "\u2717",
  skipped: "\u00b7",
  cycle: "\u27f2",
};
`)

let binder = install({
  plan: WorkflowGraph.plan,
  downstream: WorkflowGraph.downstream,
  seconds: WorkflowTrigger.seconds,
  minuteOfDay: WorkflowTrigger.minuteOfDay,
  saves: WorkflowTrigger.saves,
  changes: WorkflowTrigger.changes,
  opens: WorkflowTrigger.opens,
  dueEvery: WorkflowTrigger.dueEvery,
  remainingEvery: WorkflowTrigger.remainingEvery,
  dueAt: WorkflowTrigger.dueAt,
  remainingAt: WorkflowTrigger.remainingAt,
  runOf: WorkflowHost.runOf,
  idbGet: Idb.get,
  idbSet: Idb.set,
  localize: (value, locale) => Clock.localize(value, ~locale),
  subscribe: ReactiveStore.subscribe,
})

let bind = (container, ~app, ~labels, ~locale) => binder(container, app, labels, locale)
