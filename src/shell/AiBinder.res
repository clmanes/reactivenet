// The ai-* directives, bound after each preview render with the same discipline as
// every other binder here: the renderer emitted structure and `data-rn-ai-*`, and
// everything that reads storage, carries words or reaches a model happens now.
//
// Four rules hold the whole family together, and they are the reason it is one file
// rather than fourteen:
//
//   - **One model, one setting, one banner.** `AiRunner` answers "is anything
//     configured" once. When nothing is, every directive on the page paints the same
//     sentence and the app keeps working — a document written for a model must not
//     become a page of broken widgets on a browser that has none.
//   - **The answer is data, checked in core.** A category is clamped onto the list
//     the document wrote; a record keeps only the declared fields, in the declared
//     types; a query becomes a PLAN whose every field name was checked against the
//     collection's own — and the plan is then run here, over rows this device
//     already has. Nothing the model writes is ever executed.
//   - **The model proposes and the person disposes.** Everything that would write
//     something a person would have to undo — a row from the agent, a form filled
//     from a sentence — lands in a draft or behind a confirm button. The two that do
//     write directly, `ai-classify` and `ai-rule`, write one declared field of rows
//     that are already there, and only where the value would actually change.
//   - **State lives per container position**, in a WeakMap keyed by the container,
//     exactly as a table's page does. `setInnerHtml` rebuilds every node on each
//     debounced render, so a conversation kept on the node would evaporate on the
//     next keystroke beside the editor.

type labels = {
  notConfigured: string,
  thinking: string,
  ask: string,
  send: string,
  run: string,
  refresh: string,
  rows: string,
  refused: string,
  confirm: string,
  noAnswer: string,
  indexing: string,
}

type helpers = {
  read: (~app: string, ~path: string) => promise<Collection.t>,
  write: (~app: string, ~path: string, Collection.t) => promise<unit>,
  markDerived: (~app: string, ~path: string) => promise<unit>,
  update: (Collection.t, string, array<Collection.field>) => Collection.t,
  find: (Collection.t, string) => option<Collection.record>,
  stamp: (array<Collection.field>, string, option<string>) => array<Collection.field>,
  createdOf: Collection.record => option<string>,
  timestamp: unit => string,
  storeGet: string => Nullable.t<string>,
  storeSet: (string, string) => unit,
  storeSubscribe: (string => unit) => unit,
  idbGet: string => promise<Nullable.t<string>>,
  idbSet: (string, string) => promise<unit>,
  // core/AiDirective — the whole of what an answer is allowed to mean.
  json: string => option<JSON.t>,
  fields: string => array<AiDirective.field>,
  list: string => array<string>,
  clamp: (string, array<string>) => option<string>,
  record: (JSON.t, array<AiDirective.field>) => array<Collection.field>,
  plan: (JSON.t, array<string>) => result<AiDirective.plan, string>,
  runPlan: (AiDirective.plan, array<Dict.t<string>>) => AiDirective.answer,
  rule: (JSON.t, array<string>) => result<AiDirective.rule, string>,
  applies: (AiDirective.rule, array<Dict.t<string>>) => array<Dict.t<string>>,
  sample: (array<Dict.t<string>>, int) => string,
  planPrompt: (~question: string, ~fields: array<string>, ~rows: string) => string,
  rulePrompt: (~when_: string, ~do_: string, ~fields: array<string>, ~rows: string) => string,
  recordPrompt: (~instruction: string, ~fields: array<AiDirective.field>, ~text: string) => string,
  classifyPrompt: (~instruction: string, ~values: array<string>, ~text: string) => string,
  summaryPrompt: (~instruction: string, ~rows: string, ~many: int) => string,
  chatSystem: (~persona: string, ~rows: string) => string,
  // core/AiIndex — the arithmetic of semantic search, and core/Digest, which says
  // whether the index still describes the text it was built from.
  chunks: (string, int) => array<string>,
  rank: (array<float>, array<AiIndex.item>, ~many: int, ~floor: float) => array<AiIndex.hit>,
  passages: array<AiIndex.hit> => string,
  digest: string => string,
  // shell/AiRunner — the one place any of this talks to a model.
  ready: unit => promise<bool>,
  ask: (~system: string, ~user: string, ~images: array<string>=?) => promise<AiRunner.outcome>,
  stream: (
    ~system: string,
    ~history: array<JSON.t>,
    ~user: string,
    ~onText: string => unit,
  ) => promise<AiRunner.outcome>,
  agent: (
    ~system: string,
    ~history: array<JSON.t>,
    ~question: string,
    ~tools: array<JSON.t>,
    ~onText: string => unit,
    ~onCall: (~name: string, ~arguments: string) => unit,
    ~dispatch: (~name: string, ~arguments: string) => promise<string>,
  ) => promise<(AiRunner.outcome, array<JSON.t>)>,
  embed: array<string> => promise<option<array<array<float>>>>,
}

let install: helpers => (Dom.element, string, labels) => unit = %raw(`
function (helpers) {
  const aiState = new WeakMap();
  const stateFor = (container, index) => {
    let states = aiState.get(container);
    if (states === undefined) {
      states = new Map();
      aiState.set(container, states);
    }
    let state = states.get(index);
    if (state === undefined) {
      state = {
        signature: null,   // what the last run was of
        gen: 0,            // against a superseded answer arriving late
        text: "",          // what a summary last said, repainted on a re-render
        status: null,
        turns: [],         // a chat's drawn conversation
        wire: [],          // and its wire history
        busy: false,
        rule: null,        // the compiled ai-rule, once
        question: "",      // what was typed and not yet sent
      };
      states.set(index, state);
    }
    return state;
  };

  // ---------------------------------------------------------------- collections

  const dictOf = (record) => {
    const row = { id: record.id };
    for (const field of record.fields) row[field.name] = field.value;
    return row;
  };

  const namesOf = (records) => {
    const found = [];
    for (const record of records) {
      for (const field of record.fields) if (!found.includes(field.name)) found.push(field.name);
    }
    return found;
  };

  const readRows = async (app, path) => {
    if (!path) return { records: [], rows: [], fields: [] };
    const collection = await helpers.read(app, path);
    return {
      records: collection.records,
      rows: collection.records.map(dictOf),
      fields: namesOf(collection.records),
    };
  };

  // What a prompt may carry of several collections at once: their names and a
  // sample of each. Never the whole of anything — a model does not need three
  // thousand rows to answer a question about them, and with a remote provider
  // sending them would be sending the dataset.
  const readMany = async (app, given, many) => {
    const paths = helpers.list(given || "");
    const parts = [];
    let total = 0;
    for (const path of paths) {
      const held = await readRows(app, path);
      total += held.rows.length;
      parts.push(path + " (" + held.rows.length + " rows): " + helpers.sample(held.rows, many));
    }
    return { text: parts.join("\n"), total, paths };
  };

  // ------------------------------------------------------------- the index
  //
  // Semantic search over fields the document names — including the CONTENT of a
  // ::file attachment, when it is text this browser can read on its own. The index
  // is built here, kept in IndexedDB beside everything else, and rebuilt only when
  // the text it was built from has actually changed: embedding a hundred passages
  // on every render would be a hundred requests for a page nobody asked a question
  // on. PDFs and scans are deliberately out — extracting those would mean a parser
  // and an OCR, and a search that quietly indexed a file's NAME while looking like
  // it had read the file would be worse than not offering it.

  const READABLE = /^data:(text\/|application\/json)/;

  const textOfValue = (given) => {
    const held = String(given || "").trim();
    if (!held.startsWith("{")) return { text: held, label: "" };
    let parsed = null;
    try { parsed = JSON.parse(held); } catch (e) { return { text: held, label: "" }; }
    if (!parsed || typeof parsed !== "object" || !parsed.name) return { text: held, label: "" };
    const url = String(parsed.data || "");
    if (!READABLE.test(url)) {
      // A file whose content this browser cannot read is indexed by its name, and
      // the name is all the citation will ever be able to point at.
      return { text: String(parsed.name), label: String(parsed.name) };
    }
    const comma = url.indexOf(",");
    const head = url.slice(0, comma);
    const payload = url.slice(comma + 1);
    try {
      const text = head.includes(";base64")
        ? new TextDecoder().decode(Uint8Array.from(atob(payload), (c) => c.charCodeAt(0)))
        : decodeURIComponent(payload);
      return { text, label: String(parsed.name) };
    } catch (e) {
      return { text: String(parsed.name), label: String(parsed.name) };
    }
  };

  const rowLabel = (record, field, fallback) => {
    const named = record.fields.find((f) => f.name !== field && String(f.value || "").trim() !== "");
    return named ? String(named.value).slice(0, 60) : fallback;
  };

  const indexOf = async (node, app, spec, labels) => {
    const sources = helpers.list(spec)
      .map((entry) => {
        const dot = entry.indexOf(".");
        return dot === -1 ? null : { path: entry.slice(0, dot), field: entry.slice(dot + 1) };
      })
      .filter(Boolean);
    const passages = [];
    for (const source of sources) {
      const held = await readRows(app, source.path);
      for (const record of held.records) {
        const found = record.fields.find((f) => f.name === source.field);
        if (!found) continue;
        const read = textOfValue(found.value);
        if (read.text.trim() === "") continue;
        const label = read.label || rowLabel(record, source.field, source.path);
        helpers.chunks(read.text, 600).forEach((chunk, i) => {
          passages.push({
            key: source.path + "/" + record.id + "/" + source.field + "#" + i,
            label,
            text: chunk,
          });
        });
      }
    }
    const fingerprint = helpers.digest(passages.map((p) => p.key + ":" + p.text).join("\n"));
    const cacheKey = "ai-index:" + app + ":" + spec;
    const stored = await helpers.idbGet(cacheKey);
    if (stored) {
      try {
        const parsed = JSON.parse(stored);
        if (parsed.digest === fingerprint) return parsed.items;
      } catch (e) { /* a broken cache is a cache to rebuild */ }
    }
    if (passages.length === 0) return [];
    const items = [];
    for (let at = 0; at < passages.length; at += 32) {
      const batch = passages.slice(at, at + 32);
      say(node, labels.indexing + " " + Math.min(at + 32, passages.length) + "/" + passages.length, "muted");
      const vectors = await helpers.embed(batch.map((p) => p.text));
      if (vectors === undefined) return undefined;
      batch.forEach((p, i) => items.push({ key: p.key, label: p.label, text: p.text, vector: vectors[i] }));
    }
    await helpers.idbSet(cacheKey, JSON.stringify({ digest: fingerprint, items }));
    return items;
  };

  const search = async (node, app, spec, labels, question) => {
    const items = await indexOf(node, app, spec, labels);
    if (items === undefined) { say(node, labels.refused, "error"); return undefined; }
    if (items.length === 0) { say(node, "0 " + labels.rows, "muted"); return []; }
    const asked = await helpers.embed([question]);
    if (asked === undefined) { say(node, labels.refused, "error"); return undefined; }
    return helpers.rank(asked[0], items, 5, 0.25);
  };

  // ---------------------------------------------------------------------- DOM

  const clear = (node) => { while (node.firstChild) node.removeChild(node.firstChild); };

  const say = (node, text, kind) => {
    const status = node.querySelector(":scope > .rn-od-status");
    if (!status) return;
    status.textContent = text;
    status.className = "rn-od-status " + (kind === "error" ? "rn-error" : "rn-muted");
  };

  const button = (text, onClick, className) => {
    const element = document.createElement("button");
    element.type = "button";
    element.className = className || "rn-od-go";
    element.textContent = text;
    element.addEventListener("click", onClick);
    return element;
  };

  // A question box and its send button, which four of these directives all want.
  const questionRow = (node, state, placeholder, sendLabel, onSend) => {
    const row = document.createElement("div");
    row.className = "rn-ai-ask";
    const input = document.createElement("input");
    input.type = "text";
    input.className = "rn-ai-input";
    input.placeholder = placeholder;
    input.value = state.question || "";
    input.addEventListener("input", () => { state.question = input.value; });
    const send = () => {
      const asked = input.value.trim();
      if (asked === "" || state.busy) return;
      input.value = "";
      state.question = "";
      onSend(asked);
    };
    input.addEventListener("keydown", (event) => {
      if (event.key === "Enter") { event.preventDefault(); send(); }
    });
    row.appendChild(input);
    row.appendChild(button(sendLabel, send));
    return row;
  };

  const turnElement = (turn) => {
    const element = document.createElement("div");
    element.className = "rn-ai-turn rn-ai-" + turn.role;
    element.textContent = turn.text;
    return element;
  };

  const paintTurns = (node, state) => {
    const out = node.querySelector(":scope > .rn-ai-out");
    if (!out) return;
    clear(out);
    for (const turn of state.turns) out.appendChild(turnElement(turn));
    if (state.proposal) {
      const box = document.createElement("div");
      box.className = "rn-ai-turn rn-ai-proposal";
      box.textContent = state.proposal.text;
      box.appendChild(button(state.proposal.label, state.proposal.confirm, "rn-od-go rn-ai-confirm"));
      out.appendChild(box);
    }
    out.scrollTop = out.scrollHeight;
  };

  // ------------------------------------------------------------------- forms

  const CONTROLS = "input[data-rn-field],select[data-rn-field],textarea[data-rn-field]";

  const formRoot = (container, node, id) =>
    id ? container.querySelector('[data-rn-form="' + CSS.escape(id) + '"]') : node.closest("[data-rn-form]");

  const controlsOf = (root) => (root ? [...root.querySelectorAll(CONTROLS)] : []);

  const controlNamed = (root, name) =>
    controlsOf(root).find((input) => input.getAttribute("data-rn-field") === name);

  // The draft is read from these inputs at save time, so writing the value and
  // announcing it is the whole of "fill the draft" — there is no second copy of it
  // anywhere to keep in step.
  const fillField = (root, name, value) => {
    const input = controlNamed(root, name);
    if (!input) return false;
    if (input.type === "checkbox") input.checked = value === "true";
    else input.value = value;
    input.dispatchEvent(new Event("input", { bubbles: true }));
    return true;
  };

  const readFieldValue = (root, name) => {
    const input = controlNamed(root, name);
    if (!input) return "";
    return input.type === "checkbox" ? String(!!input.checked) : String(input.value || "");
  };

  // What the form ALREADY says, as the model's context: a label and a value per
  // field, which is what makes ai-field a suggestion rather than a guess.
  const formText = (root, except) =>
    controlsOf(root)
      .map((input) => {
        const name = input.getAttribute("data-rn-field");
        if (name === except) return null;
        const value = input.type === "checkbox" ? String(!!input.checked) : String(input.value || "");
        return value.trim() === "" ? null : name + ": " + value;
      })
      .filter(Boolean)
      .join("\n");

  // The fields a form actually has, for the directives that fill a whole draft
  // without the document listing them again. The input's own type is the type.
  const formFields = (root) =>
    controlsOf(root).map((input) => {
      const kind = String(input.getAttribute("type") || "text");
      return {
        name: input.getAttribute("data-rn-field"),
        kind: kind === "number" ? "number" : kind === "date" ? "date" : kind === "checkbox" ? "boolean" : "text",
      };
    }).filter((field) => field.name);

  // ------------------------------------------------------------------ writing

  const writeFields = async (app, path, id, fields) => {
    const collection = await helpers.read(app, path);
    const existing = helpers.find(collection, id);
    const created = existing === undefined ? undefined : helpers.createdOf(existing);
    const stamped = helpers.stamp(fields, helpers.timestamp(), created);
    await helpers.write(app, path, helpers.update(collection, id, stamped));
  };

  const fieldsOfDict = (row) =>
    Object.entries(row)
      .filter((entry) => entry[0] !== "id")
      .map((entry) => ({ name: entry[0], value: String(entry[1] === null || entry[1] === undefined ? "" : entry[1]) }));

  // ------------------------------------------------------------------- kinds

  const notConfigured = (node, labels) => {
    const controls = node.querySelector(":scope > .rn-od-controls");
    if (controls) clear(controls);
    say(node, labels.notConfigured, "error");
  };

  const runSummary = async (node, app, state, labels, index, container) => {
    const data = node.getAttribute("data-rn-ai-data") || "";
    const instruction =
      (node.querySelector(":scope > .rn-ai-instruction")?.textContent || "").trim() ||
      node.getAttribute("data-rn-ai-prompt") || "";
    const held = await readMany(app, data, 100);
    // rag= puts the passages nearest to the instruction in front of the sample: a
    // summary of a hundred rows and one of twelve documents are the same directive,
    // and the second only works if what it reads is chosen rather than truncated.
    const spec = node.getAttribute("data-rn-ai-rag") || "";
    let cited = "";
    if (spec !== "") {
      const hits = await search(node, app, spec, labels, instruction || "summary");
      if (hits !== undefined && hits.length > 0) cited = helpers.passages(hits) + "\n\n";
    }
    const signature = data + "|" + instruction + "|" + cited + held.text;
    if (state.signature === signature && state.text !== "") {
      const out = node.querySelector(":scope > .rn-ai-out");
      if (out) out.textContent = state.text;
      say(node, "", "muted");
      return;
    }
    state.signature = signature;
    const gen = ++state.gen;
    say(node, labels.thinking, "muted");
    const answer = await helpers.ask(
      "",
      helpers.summaryPrompt(instruction || "Describe this table.", cited + held.text, held.total),
      [],
    );
    if (state.gen !== gen) return;
    const target = [...container.querySelectorAll("[data-rn-ai]")][index];
    if (!target || !target.isConnected) return;
    if (!answer.ok) { say(target, answer.error || labels.refused, "error"); return; }
    state.text = answer.text || labels.noAnswer;
    const out = target.querySelector(":scope > .rn-ai-out");
    if (out) out.textContent = state.text;
    say(target, "", "muted");
  };

  const wireChat = (node, app, state, labels, isAgent) => {
    const controls = node.querySelector(":scope > .rn-od-controls");
    if (!controls) return;
    clear(controls);
    const placeholder = node.getAttribute("data-rn-ai-placeholder") || labels.ask;
    controls.appendChild(questionRow(node, state, placeholder, labels.send, async (asked) => {
      state.busy = true;
      state.turns.push({ role: "user", text: asked });
      state.turns.push({ role: "assistant", text: labels.thinking });
      paintTurns(node, state);
      const data = node.getAttribute("data-rn-ai-data") || "";
      const persona =
        (node.querySelector(":scope > .rn-ai-instruction")?.textContent || "").trim() ||
        node.getAttribute("data-rn-ai-persona") || "";
      const held = await readMany(app, data, isAgent ? 3 : 60);
      const spec = node.getAttribute("data-rn-ai-rag") || "";
      let cited = "";
      if (spec !== "") {
        const hits = await search(node, app, spec, labels, asked);
        if (hits !== undefined && hits.length > 0) {
          cited = "Passages found for this question, cite them by their [name]:\n" +
            helpers.passages(hits) + "\n\n";
        }
      }
      const last = () => state.turns[state.turns.length - 1];
      if (isAgent) {
        const allowed = helpers.list(node.getAttribute("data-rn-ai-tools") || "query");
        const outcome = await runAgent(node, app, state, labels, persona, held, allowed, asked, last);
        state.busy = false;
        paintTurns(node, state);
        return;
      }
      let drawn = "";
      const answer = await helpers.stream(
        helpers.chatSystem(persona, cited + held.text),
        state.wire,
        asked,
        (chunk) => {
          drawn += chunk;
          last().text = drawn;
          paintTurns(node, state);
        },
      );
      last().text = answer.ok ? (answer.text || labels.noAnswer) : (answer.error || labels.refused);
      if (!answer.ok) last().role = "error";
      else {
        state.wire.push({ role: "user", content: asked });
        state.wire.push({ role: "assistant", content: answer.text });
      }
      state.busy = false;
      paintTurns(node, state);
    }));
    paintTurns(node, state);
  };

  // The agent's two tools. query READS the declared collections; insert PROPOSES a
  // row and writes nothing — the confirm button is the only thing that writes, and
  // it is the reader's. Everything the model asked for leaves a line in the log,
  // because an agent whose steps are invisible is one nobody can check.
  const agentTools = (allowed, paths) => {
    const tools = [];
    if (allowed.includes("query")) {
      tools.push({
        type: "function",
        function: {
          name: "query",
          description: "Read rows of one of the app's collections: " + paths.join(", "),
          parameters: {
            type: "object",
            properties: {
              collection: { type: "string", enum: paths },
              field: { type: "string", description: "optional field to filter on" },
              value: { type: "string", description: "the value that field must have" },
            },
            required: ["collection"],
          },
        },
      });
    }
    if (allowed.includes("insert")) {
      tools.push({
        type: "function",
        function: {
          name: "insert",
          description: "PROPOSE one row for a collection. It is shown to the person and written only if they confirm.",
          parameters: {
            type: "object",
            properties: {
              collection: { type: "string", enum: paths },
              row: { type: "object", description: "field names and values" },
            },
            required: ["collection", "row"],
          },
        },
      });
    }
    return tools;
  };

  const runAgent = async (node, app, state, labels, persona, held, allowed, asked, last) => {
    const tools = agentTools(allowed, held.paths);
    const system = [
      persona === "" ? "You help the person work with the collections of this app." : persona,
      "Use the query tool before answering anything about the data; never guess a number.",
      "The insert tool only PROPOSES a row: the person confirms it, so say what you propose and why.",
      "The collections are: " + held.paths.join(", ") + ".",
      "A sample of each: " + held.text,
    ].join("\n");

    const dispatch = async (name, argumentsText) => {
      let given = {};
      try { given = JSON.parse(argumentsText || "{}"); } catch (e) { given = {}; }
      const path = String(given.collection || "");
      if (!held.paths.includes(path)) return "That collection is not one this directive may reach.";
      if (name === "query") {
        const rows = (await readRows(app, path)).rows;
        const narrowed = given.field
          ? rows.filter((row) => String(row[given.field] || "") === String(given.value || ""))
          : rows;
        return JSON.stringify(narrowed.slice(0, 50));
      }
      if (name === "insert") {
        const row = given.row && typeof given.row === "object" ? given.row : {};
        const fields = fieldsOfDict(row);
        if (fields.length === 0) return "Nothing to insert.";
        state.proposal = {
          text: path + ": " + fields.map((f) => f.name + " = " + f.value).join(", "),
          label: labels.confirm,
          confirm: async () => {
            const collection = await helpers.read(app, path);
            const stamped = helpers.stamp(fields, helpers.timestamp(), undefined);
            const id = "ai-" + Date.now().toString(36);
            await helpers.write(app, path, { records: collection.records.concat([{ id, fields: stamped }]) });
            state.proposal = null;
            state.turns.push({ role: "tool", text: path + " +1" });
            paintTurns(node, state);
            window.dispatchEvent(new Event("rn:data"));
          },
        };
        return "Proposed. The person has to confirm it; do not propose it again.";
      }
      return "Unknown tool.";
    };

    let drawn = "";
    const answered = await helpers.agent(
      system,
      state.wire,
      asked,
      tools,
      (chunk) => { drawn += chunk; last().text = drawn; paintTurns(node, state); },
      (name, argumentsText) => {
        state.turns.splice(state.turns.length - 1, 0, { role: "tool", text: name + " " + argumentsText });
      },
      (name, argumentsText) => dispatch(name, argumentsText),
    );
    const outcome = answered[0];
    state.wire = answered[1];
    if (!outcome.ok) { last().role = "error"; last().text = outcome.error || labels.refused; }
    else if (drawn.trim() === "" && !state.proposal) last().text = labels.noAnswer;
    return outcome;
  };

  // ai-query: the question becomes a PLAN, and the plan runs here. What the widget
  // shows is the plan itself as well as its answer, because a reader who cannot see
  // what was asked cannot tell a right answer from a plausible one.
  const runQuery = async (node, app, state, labels, asked) => {
    const path = node.getAttribute("data-rn-ai-data") || "";
    const into = node.getAttribute("data-rn-ai-into") || "";
    const held = await readRows(app, path);
    if (held.fields.length === 0) { say(node, labels.refused, "error"); return; }
    say(node, labels.thinking, "muted");
    const answer = await helpers.ask(
      "",
      helpers.planPrompt(asked, held.fields, helpers.sample(held.rows, 5)),
      [],
    );
    if (!answer.ok) { say(node, answer.error || labels.refused, "error"); return; }
    const parsed = helpers.json(answer.text);
    if (parsed === undefined) { say(node, labels.refused, "error"); return; }
    const outcome = helpers.plan(parsed, held.fields);
    if (outcome.TAG !== "Ok") { say(node, labels.refused + " — " + outcome._0, "error"); return; }
    const plan = outcome._0;
    const result = helpers.runPlan(plan, held.rows);
    const shown =
      plan.metric + (plan.metricField ? "(" + plan.metricField + ")" : "") +
      (plan.groupBy ? " by " + plan.groupBy : "") +
      (plan.filters.length ? " where " + plan.filters.map((f) => f.field + " " + f.op + " " + f.value).join(", ") : "");
    const out = node.querySelector(":scope > .rn-ai-out");
    if (out) {
      clear(out);
      const question = document.createElement("p");
      question.className = "rn-ai-turn rn-ai-user";
      question.textContent = asked;
      out.appendChild(question);
      const answered = document.createElement("p");
      answered.className = "rn-ai-answer";
      answered.textContent = result.scalar !== ""
        ? result.scalar
        : result.rows.map((line) => line.label + ": " + line.value).join(" · ");
      out.appendChild(answered);
      const plain = document.createElement("p");
      plain.className = "rn-ai-plan";
      plain.textContent = shown;
      out.appendChild(plain);
    }
    say(node, "", "muted");
    // The breakdown becomes a collection like any other, so a ::table or a
    // ::chart-bar draws it. Derived: it is an answer, not a shared fact, and the
    // ids are stable by position so an unchanged re-ask is a no-op down to the diff.
    if (into && result.rows.length > 0) {
      const records = result.rows.map((line, i) => ({
        id: "ai-" + i,
        fields: [
          { name: plan.groupBy || "gruppo", value: line.label },
          { name: "valore", value: line.value },
        ],
      }));
      await helpers.markDerived(app, into);
      await helpers.write(app, into, { records });
      window.dispatchEvent(new Event("rn:data"));
    }
  };

  // ai-rule: compiled ONCE against the collection's own field names, kept in
  // IndexedDB, and from then on applied with no model at all. That is what makes it
  // reactive without being expensive, and deterministic rather than merely likely.
  const ruleKey = (app, node) =>
    "ai-rule:" + app + ":" + (node.getAttribute("data-rn-ai-data") || "") + "|" +
    (node.getAttribute("data-rn-ai-when") || "") + "|" + (node.getAttribute("data-rn-ai-do") || "");

  const applyRule = async (node, app, state, labels) => {
    if (!state.rule) return;
    const path = node.getAttribute("data-rn-ai-data") || "";
    const held = await readRows(app, path);
    const changing = helpers.applies(state.rule, held.rows);
    if (changing.length === 0) { say(node, state.rule.setField + " = " + state.rule.setValue, "muted"); return; }
    for (const row of changing) {
      const record = held.records.find((r) => r.id === row.id);
      if (!record) continue;
      const fields = record.fields
        .filter((f) => f.name !== state.rule.setField)
        .concat([{ name: state.rule.setField, value: state.rule.setValue }]);
      await writeFields(app, path, row.id, fields);
    }
    say(node, changing.length + " " + labels.rows, "muted");
    window.dispatchEvent(new Event("rn:data"));
  };

  const compileRule = async (node, app, state, labels) => {
    const path = node.getAttribute("data-rn-ai-data") || "";
    const when_ = node.getAttribute("data-rn-ai-when") || "";
    const do_ = node.getAttribute("data-rn-ai-do") || "";
    const held = await readRows(app, path);
    if (held.fields.length === 0) { say(node, labels.refused, "error"); return; }
    say(node, labels.thinking, "muted");
    const answer = await helpers.ask(
      "",
      helpers.rulePrompt(when_, do_, held.fields, helpers.sample(held.rows, 5)),
      [],
    );
    if (!answer.ok) { say(node, answer.error || labels.refused, "error"); return; }
    const parsed = helpers.json(answer.text);
    if (parsed === undefined) { say(node, labels.refused, "error"); return; }
    const outcome = helpers.rule(parsed, held.fields);
    if (outcome.TAG !== "Ok") { say(node, labels.refused + " — " + outcome._0, "error"); return; }
    state.rule = outcome._0;
    await helpers.idbSet(ruleKey(app, node), JSON.stringify(state.rule));
    await applyRule(node, app, state, labels);
  };

  const runClassify = async (node, app, state, labels) => {
    const path = node.getAttribute("data-rn-ai-path") || node.getAttribute("data-rn-ai-data") || "";
    const field = node.getAttribute("data-rn-ai-field") || "";
    const values = helpers.list(node.getAttribute("data-rn-ai-values") || "");
    const overwrite = node.hasAttribute("data-rn-ai-overwrite");
    const instruction =
      (node.querySelector(":scope > .rn-ai-instruction")?.textContent || "").trim() ||
      "Sort this row into one of the categories.";
    if (path === "" || field === "" || values.length === 0) { say(node, labels.refused, "error"); return; }
    const held = await readRows(app, path);
    const todo = held.records.filter((record) => {
      if (overwrite) return true;
      const current = record.fields.find((f) => f.name === field);
      return !current || String(current.value).trim() === "";
    });
    if (todo.length === 0) { say(node, "0 " + labels.rows, "muted"); return; }
    let done = 0;
    for (const record of todo) {
      say(node, labels.thinking + " " + (done + 1) + "/" + todo.length, "muted");
      const text = record.fields
        .filter((f) => f.name !== field)
        .map((f) => f.name + ": " + f.value)
        .join("\n");
      const answer = await helpers.ask("", helpers.classifyPrompt(instruction, values, text), []);
      if (!answer.ok) { say(node, answer.error || labels.refused, "error"); return; }
      const chosen = helpers.clamp(answer.text, values);
      // An answer outside the list is a row left alone, never a new category.
      if (chosen === undefined) continue;
      const fields = record.fields.filter((f) => f.name !== field).concat([{ name: field, value: chosen }]);
      await writeFields(app, path, record.id, fields);
      done += 1;
    }
    say(node, done + " " + labels.rows, "muted");
    window.dispatchEvent(new Event("rn:data"));
  };

  // ai-pipeline: the rows that are NEW — the ones whose first declared field is
  // still empty — and only the declared fields written. A batch is bounded so a
  // collection that grew overnight cannot become a hundred requests on one click.
  const runPipeline = async (node, app, state, labels) => {
    const path = node.getAttribute("data-rn-ai-data") || "";
    const declared = helpers.fields(node.getAttribute("data-rn-ai-fields") || "");
    const instruction = (node.querySelector(":scope > .rn-ai-instruction")?.textContent || "").trim();
    if (path === "" || declared.length === 0) { say(node, labels.refused, "error"); return; }
    const held = await readRows(app, path);
    const first = declared[0].name;
    const todo = held.records.filter((record) => {
      const current = record.fields.find((f) => f.name === first);
      return !current || String(current.value).trim() === "";
    }).slice(0, 25);
    if (todo.length === 0) { say(node, "0 " + labels.rows, "muted"); return; }
    let done = 0;
    for (const record of todo) {
      say(node, labels.thinking + " " + (done + 1) + "/" + todo.length, "muted");
      const text = record.fields
        .filter((f) => !declared.some((d) => d.name === f.name))
        .map((f) => f.name + ": " + f.value)
        .join("\n");
      const answer = await helpers.ask("", helpers.recordPrompt(instruction, declared, text), []);
      if (!answer.ok) { say(node, answer.error || labels.refused, "error"); return; }
      const parsed = helpers.json(answer.text);
      if (parsed === undefined) continue;
      const written = helpers.record(parsed, declared);
      if (written.length === 0) continue;
      const kept = record.fields.filter((f) => !written.some((w) => w.name === f.name));
      await writeFields(app, path, record.id, kept.concat(written));
      done += 1;
    }
    say(node, done + " " + labels.rows, "muted");
    window.dispatchEvent(new Event("rn:data"));
  };

  // The four that fill a form's draft. None of them writes a row: the person
  // presses the form's own save button, which is the same button as always.
  const fillDraft = async (node, container, app, state, labels, kind, text) => {
    const root = formRoot(container, node, node.getAttribute("data-rn-ai-form"));
    if (!root) { say(node, labels.refused, "error"); return; }
    const declared = kind === "assist"
      ? formFields(root)
      : helpers.fields(node.getAttribute("data-rn-ai-fields") || "");
    if (declared.length === 0) { say(node, labels.refused, "error"); return; }

    let instruction = (node.querySelector(":scope > .rn-ai-instruction")?.textContent || "").trim();
    let source = text;
    if (kind === "suggest") {
      const path = node.getAttribute("data-rn-ai-path") || "";
      const held = await readRows(app, path);
      if (held.rows.length === 0) { say(node, "0 " + labels.rows, "muted"); return; }
      instruction = instruction || "Propose the next plausible row, in the shape of the ones below. Do not repeat one of them exactly.";
      source = helpers.sample(held.rows, 20);
    } else if (instruction === "") {
      instruction = "Read the text below and fill in what it actually says.";
    }

    say(node, labels.thinking, "muted");
    const answer = await helpers.ask("", helpers.recordPrompt(instruction, declared, source), []);
    if (!answer.ok) { say(node, answer.error || labels.refused, "error"); return; }
    const parsed = helpers.json(answer.text);
    if (parsed === undefined) { say(node, labels.noAnswer, "error"); return; }
    const written = helpers.record(parsed, declared);
    let filled = 0;
    for (const entry of written) if (fillField(root, entry.name, entry.value)) filled += 1;
    say(node, filled === 0 ? labels.noAnswer : String(filled), filled === 0 ? "error" : "muted");
    if (filled > 0) root.scrollIntoView({ behavior: "smooth", block: "nearest" });
  };

  const runField = async (node, container, app, state, labels) => {
    const root = formRoot(container, node, node.getAttribute("data-rn-ai-form"));
    const field = node.getAttribute("data-rn-ai-field") || "";
    const values = helpers.list(node.getAttribute("data-rn-ai-values") || "");
    if (!root || field === "" || values.length === 0) { say(node, labels.refused, "error"); return; }
    const text = formText(root, field);
    if (text.trim() === "") { say(node, labels.noAnswer, "muted"); return; }
    say(node, labels.thinking, "muted");
    const answer = await helpers.ask(
      "",
      helpers.classifyPrompt("Choose the value of " + field + " for this record.", values, text),
      [],
    );
    if (!answer.ok) { say(node, answer.error || labels.refused, "error"); return; }
    const chosen = helpers.clamp(answer.text, values);
    if (chosen === undefined) { say(node, labels.noAnswer, "error"); return; }
    fillField(root, field, chosen);
    say(node, chosen, "muted");
  };

  // ai-translate and ai-rewrite work on ONE piece of text, wherever it is: a
  // reactive key or a form field. The two are the same act with a different
  // instruction, so they are the same function.
  const runText = async (node, container, app, state, labels, kind) => {
    const key = node.getAttribute("data-rn-ai-key") || "";
    const root = formRoot(container, node, node.getAttribute("data-rn-ai-form"));
    const field = node.getAttribute("data-rn-ai-field") || "";
    const current = key !== ""
      ? String(helpers.storeGet(key) || "")
      : root ? readFieldValue(root, field) : "";
    if (current.trim() === "") { say(node, labels.noAnswer, "muted"); return; }
    const instruction = kind === "translate"
      ? "Translate the text below into " + (node.getAttribute("data-rn-ai-to") || "English") +
        ". Answer with the translation only, nothing else."
      : "Rewrite the text below: " + (node.getAttribute("data-rn-ai-style") || "clearer") +
        ". Keep every fact. Answer with the rewritten text only, nothing else.";
    say(node, labels.thinking, "muted");
    const answer = await helpers.ask("", instruction + "\n\n" + current, []);
    if (!answer.ok) { say(node, answer.error || labels.refused, "error"); return; }
    if (answer.text.trim() === "") { say(node, labels.noAnswer, "error"); return; }
    if (key !== "") helpers.storeSet(key, answer.text);
    else fillField(root, field, answer.text);
    say(node, "", "muted");
  };

  // ai-vision: the image is whatever a ::file field is holding, and only ever a
  // data: URL — the same rule the views follow when they draw one.
  const runVision = async (node, container, app, state, labels) => {
    const root = formRoot(container, node, node.getAttribute("data-rn-ai-form"));
    const field = node.getAttribute("data-rn-ai-field") || "";
    const target = node.getAttribute("data-rn-ai-target") || "";
    if (!root || field === "" || target === "") { say(node, labels.refused, "error"); return; }
    let held = readFieldValue(root, field);
    let url = "";
    try {
      const parsed = JSON.parse(held);
      url = parsed && typeof parsed === "object" ? String(parsed.data || "") : "";
    } catch (e) { url = ""; }
    if (!url.startsWith("data:image/")) { say(node, labels.noAnswer, "muted"); return; }
    say(node, labels.thinking, "muted");
    const answer = await helpers.ask(
      "",
      node.getAttribute("data-rn-ai-prompt") || "Describe this image in one short paragraph.",
      [url],
    );
    if (!answer.ok) { say(node, answer.error || labels.refused, "error"); return; }
    if (answer.text.trim() === "") { say(node, labels.noAnswer, "error"); return; }
    fillField(root, target, answer.text);
    say(node, "", "muted");
  };

  // ------------------------------------------------------------------- wiring

  let live = [];
  let listening = false;
  const listen = () => {
    if (listening) return;
    listening = true;
    // A collection changed: the reactive ones follow it. Everything else waits for
    // its button, because everything else costs a request.
    window.addEventListener("rn:data", () => {
      live = live.filter((entry) => entry.node.isConnected);
      for (const entry of live) if (entry.follows) entry.follows();
    });
  };

  return function (container, app, labels) {
    const nodes = [...container.querySelectorAll("[data-rn-ai]")];
    if (nodes.length === 0) return;
    listen();
    live = live.filter((entry) => entry.node.isConnected && !nodes.includes(entry.node));

    helpers.ready().then((ready) => {
      nodes.forEach((node, index) => {
        const kind = node.getAttribute("data-rn-ai") || "";
        const state = stateFor(container, index);
        const controls = node.querySelector(":scope > .rn-od-controls");
        if (!ready) { notConfigured(node, labels); return; }
        if (controls) clear(controls);
        const label = node.getAttribute("data-rn-ai-label") || "";

        if (kind === "summary") {
          if (controls) controls.appendChild(button(labels.refresh, () => {
            state.signature = null;
            runSummary(node, app, state, labels, index, container);
          }, "rn-od-go rn-ai-refresh"));
          live.push({ node, follows: () => runSummary(node, app, state, labels, index, container) });
          runSummary(node, app, state, labels, index, container);
          return;
        }

        if (kind === "chat" || kind === "agent") {
          wireChat(node, app, state, labels, kind === "agent");
          return;
        }

        if (kind === "query") {
          const placeholder = node.getAttribute("data-rn-ai-placeholder") || labels.ask;
          if (controls) {
            controls.appendChild(questionRow(node, state, placeholder, labels.send, (asked) => {
              runQuery(node, app, state, labels, asked);
            }));
          }
          return;
        }

        if (kind === "rule") {
          helpers.idbGet(ruleKey(app, node)).then((held) => {
            if (held) { try { state.rule = JSON.parse(held); } catch (e) { state.rule = null; } }
            if (controls) {
              controls.appendChild(button(label || labels.run, () => compileRule(node, app, state, labels)));
            }
            if (state.rule) {
              live.push({ node, follows: () => applyRule(node, app, state, labels) });
              applyRule(node, app, state, labels);
            }
          });
          return;
        }

        if (kind === "classify") {
          if (controls) controls.appendChild(button(label || labels.run, () => runClassify(node, app, state, labels)));
          return;
        }

        if (kind === "pipeline") {
          if (controls) controls.appendChild(button(label || labels.run, () => runPipeline(node, app, state, labels)));
          return;
        }

        if (kind === "extract" || kind === "assist") {
          const source = node.getAttribute("data-rn-ai-source") || "";
          if (source.startsWith("#")) {
            // The text is somewhere else on the page already; this is only a button.
            if (controls) {
              controls.appendChild(button(label || labels.run, () => {
                const text = String(helpers.storeGet(source.slice(1)) || "");
                fillDraft(node, container, app, state, labels, kind, text);
              }));
            }
            return;
          }
          if (controls) {
            const placeholder = node.getAttribute("data-rn-ai-placeholder") || labels.ask;
            controls.appendChild(questionRow(node, state, placeholder, label || labels.send, (text) => {
              fillDraft(node, container, app, state, labels, kind, text);
            }));
          }
          return;
        }

        if (kind === "suggest") {
          if (controls) {
            controls.appendChild(button(label || labels.run, () => {
              fillDraft(node, container, app, state, labels, "suggest", "");
            }));
          }
          return;
        }

        if (kind === "field") {
          if (controls) controls.appendChild(button(label || labels.run, () => runField(node, container, app, state, labels)));
          return;
        }

        if (kind === "translate" || kind === "rewrite") {
          if (controls) {
            controls.appendChild(button(label || labels.run, () => runText(node, container, app, state, labels, kind)));
          }
          return;
        }

        if (kind === "search") {
          const spec = node.getAttribute("data-rn-ai-rag") || "";
          const placeholder = node.getAttribute("data-rn-ai-placeholder") || labels.ask;
          const into = node.getAttribute("data-rn-ai-into") || "";
          if (controls) {
            controls.appendChild(questionRow(node, state, placeholder, labels.send, async (asked) => {
              const hits = await search(node, app, spec, labels, asked);
              if (hits === undefined) return;
              const out = node.querySelector(":scope > .rn-ai-out");
              if (out) {
                clear(out);
                if (hits.length === 0) { say(node, "0 " + labels.rows, "muted"); return; }
                for (const hit of hits) {
                  const found = document.createElement("p");
                  found.className = "rn-ai-hit";
                  const name = document.createElement("strong");
                  name.textContent = hit.item.label;
                  found.appendChild(name);
                  found.appendChild(document.createTextNode(" — " + hit.item.text));
                  out.appendChild(found);
                }
              }
              say(node, hits.length + " " + labels.rows, "muted");
              if (into) {
                const records = hits.map((hit, i) => ({
                  id: "ai-" + i,
                  fields: [
                    { name: "titolo", value: hit.item.label },
                    { name: "testo", value: hit.item.text },
                    { name: "punteggio", value: hit.score.toFixed(3) },
                  ],
                }));
                await helpers.markDerived(app, into);
                await helpers.write(app, into, { records });
                window.dispatchEvent(new Event("rn:data"));
              }
            }));
          }
          return;
        }

        if (kind === "vision") {
          if (controls) controls.appendChild(button(label || labels.run, () => runVision(node, container, app, state, labels)));
          return;
        }
      });
    });
  };
}
`)

let binder = install({
  read: CollectionStore.read,
  write: CollectionStore.write,
  markDerived: DerivedPaths.mark,
  update: Collection.update,
  find: Collection.find,
  stamp: (fields, now, createdAt) => Stamps.apply(fields, ~now, ~createdAt=?createdAt),
  createdOf: Stamps.createdOf,
  timestamp: Clock.timestamp,
  storeGet: ReactiveStore.get,
  storeSet: ReactiveStore.set,
  storeSubscribe: ReactiveStore.subscribe,
  idbGet: Idb.get,
  idbSet: Idb.set,
  json: AiDirective.json,
  fields: AiDirective.fields,
  list: AiDirective.list,
  clamp: AiDirective.clamp,
  record: AiDirective.record,
  plan: AiDirective.plan,
  runPlan: AiDirective.run,
  rule: AiDirective.rule,
  applies: AiDirective.applies,
  sample: AiDirective.sample,
  planPrompt: AiDirective.planPrompt,
  rulePrompt: AiDirective.rulePrompt,
  recordPrompt: AiDirective.recordPrompt,
  classifyPrompt: AiDirective.classifyPrompt,
  summaryPrompt: AiDirective.summaryPrompt,
  chatSystem: AiDirective.chatSystem,
  chunks: AiIndex.chunks,
  rank: AiIndex.rank,
  passages: AiIndex.context,
  digest: Digest.of_,
  ready: AiRunner.ready,
  ask: AiRunner.ask,
  stream: AiRunner.stream,
  agent: AiRunner.agent,
  embed: AiRunner.embed,
})

let bind = (container, ~app, ~labels) => binder(container, app, labels)
