// Pure. What the ai-* directives ASK and what an answer is allowed to MEAN.
//
// The whole safety story of these directives is in this file, and it is one
// sentence: **the model never produces anything that is executed.** It produces a
// word from a closed list, or a small object whose keys were declared in the
// document — and everything else is refused here, before it reaches a collection.
//
//   - `::ai-classify` and `::ai-field` answer with ONE of `values=`. Anything else
//     is clamped onto that list or dropped; a model that invents a category does
//     not get to invent a column of them.
//   - `::ai-extract`, `::ai-suggest`, `::ai-assist` and `::ai-pipeline` answer with
//     an object. Only the fields the document declared survive, in the type it
//     declared: a `:number` that is not a number is left empty rather than stored
//     as prose.
//   - `::ai-query` answers with a QUERY PLAN — filters, a group-by, one aggregation
//     — whose every field name is checked against the closed list of that
//     collection's own fields. The plan is then run here, in `run`, over rows this
//     device already has. The model writes no code and sees no data it was not
//     handed.
//   - `::ai-rule` is the same shape compiled ONCE and cached: from then on the rule
//     runs with no model at all, which is what makes it deterministic and
//     idempotent.
//
// The prompts live here too, and not in the shell, because a prompt is what decides
// whether the answer is parseable — the two are one design and are tested together.

// A field as the document declares it: `importo:number` is a name and a type, and
// the type is what the answer is then held to.
type field = {name: string, kind: string}

type filter = {field: string, op: string, value: string}

type plan = {
  filters: array<filter>,
  /** "" when the question wants one number rather than a breakdown. */
  groupBy: string,
  metric: string,
  /** "" for count, which needs no field. */
  metricField: string,
  sort: string,
  limit: int,
}

type line = {label: string, value: string}

type answer = {scalar: string, rows: array<line>}

type rule = {
  field: string,
  op: string,
  value: string,
  setField: string,
  setValue: string,
}

let metrics = ["count", "sum", "avg", "min", "max"]

let operators = ["eq", "ne", "gt", "lt", "gte", "lte", "contains", "empty", "not-empty"]

// One reading of "does this row pass this test", shared by the query plan, the
// compiled rule and anything else that grows here. Numbers compare as numbers when
// both sides are numbers and as text otherwise, which is the rule every view in
// this app already follows.
%%raw(`
function rnFold(s) {
  return String(s === null || s === undefined ? "" : s)
    .normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
}
function rnPasses(test, row) {
  const raw = row[test.field];
  const held = raw === null || raw === undefined ? "" : String(raw);
  const wanted = String(test.value || "");
  if (test.op === "empty") return held.trim() === "";
  if (test.op === "not-empty") return held.trim() !== "";
  if (test.op === "contains") return rnFold(held).includes(rnFold(wanted));
  const a = Number(held.trim().replace(",", "."));
  const b = Number(wanted.trim().replace(",", "."));
  const numeric = held.trim() !== "" && wanted.trim() !== "" && Number.isFinite(a) && Number.isFinite(b);
  const x = numeric ? a : rnFold(held);
  const y = numeric ? b : rnFold(wanted);
  if (test.op === "eq") return x === y;
  if (test.op === "ne") return x !== y;
  if (test.op === "gt") return x > y;
  if (test.op === "lt") return x < y;
  if (test.op === "gte") return x >= y;
  if (test.op === "lte") return x <= y;
  return true;
}
`)

/** The first JSON value in a model's answer. Models fence what they are asked for,
    apologise before it and explain after it; a parser that demanded the whole reply
    be JSON would fail on answers that are otherwise perfect. */
let json: string => option<JSON.t> = %raw(`
function (text) {
  const source = String(text || "");
  const direct = (s) => { try { return JSON.parse(s); } catch (e) { return undefined; } };
  const whole = direct(source.trim());
  if (whole !== undefined && typeof whole === "object" && whole !== null) return whole;

  // A fenced block first — it is what the model was asked for. The fence is built
  // from its character code because a backtick inside a raw block would end it.
  const fence = String.fromCharCode(96).repeat(3);
  const parts = source.split(fence);
  if (parts.length >= 3) {
    let inner = parts[1];
    const newline = inner.indexOf("\n");
    if (newline !== -1 && inner.slice(0, newline).trim().length <= 8) inner = inner.slice(newline + 1);
    const value = direct(inner.trim());
    if (value !== undefined) return value;
  }

  // Then the first balanced { } or [ ] anywhere in the prose.
  for (const pair of [["{", "}"], ["[", "]"]]) {
    const open = pair[0], close = pair[1];
    const start = source.indexOf(open);
    if (start === -1) continue;
    let depth = 0, quoted = false, escaped = false;
    for (let i = start; i < source.length; i++) {
      const c = source[i];
      if (escaped) { escaped = false; continue; }
      if (c === "\\") { escaped = true; continue; }
      if (c === '"') { quoted = !quoted; continue; }
      if (quoted) continue;
      if (c === open) depth++;
      else if (c === close) {
        depth--;
        if (depth === 0) {
          const value = direct(source.slice(start, i + 1));
          if (value !== undefined) return value;
          break;
        }
      }
    }
  }
  return undefined;
}
`)

/** `"voce,importo:number,quando:date"` — how a document declares what it wants
    back. A field with no type is text, which is what a collection stores anyway. */
let fields: string => array<field> = %raw(`
function (given) {
  return String(given || "")
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean)
    .map((entry) => {
      const colon = entry.indexOf(":");
      if (colon === -1) return { name: entry, kind: "text" };
      const kind = entry.slice(colon + 1).trim().toLowerCase();
      return {
        name: entry.slice(0, colon).trim(),
        kind: ["number", "date", "boolean", "text"].includes(kind) ? kind : "text",
      };
    })
    .filter((f) => f.name !== "");
}
`)

/** A comma-separated attribute as the list it is. */
let list: string => array<string> = %raw(`
function (given) {
  return String(given || "").split(",").map((s) => s.trim()).filter(Boolean);
}
`)

/** The model's word, onto the document's list — or nothing. Exact first, then case-
    and accent-blind, then a unique prefix: a model that answers "Casa." for "casa"
    meant casa, and one that answers "either casa or cibo" did not. */
let clamp: (string, array<string>) => option<string> = %raw(`
function (given, values) {
  const flatten = (s) => rnFold(s).replace(/[^a-z0-9]+/g, " ").trim();
  const answer = flatten(given);
  if (answer === "") return undefined;
  for (const value of values) if (String(value) === String(given)) return value;
  for (const value of values) if (flatten(value) === answer) return value;
  // The value said somewhere inside a sentence — "casa, perché è una spesa
  // domestica" — but only when exactly ONE of them is in there. An answer naming
  // two has chosen neither, and picking the first would be inventing the very
  // classification this function exists to refuse.
  const words = (" " + answer + " ");
  const named = values.filter((value) => {
    const folded = flatten(value);
    return folded !== "" && words.includes(" " + folded + " ");
  });
  return named.length === 1 ? named[0] : undefined;
}
`)

/** An answered object as the fields the document declared, in the order it declared
    them. A value of the wrong type is dropped rather than stored: half a row that
    is right beats a whole row that is not. */
let record: (JSON.t, array<field>) => array<Collection.field> = %raw(`
function (value, declared) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return [];
  const out = [];
  for (const field of declared) {
    const given = value[field.name];
    if (given === null || given === undefined || typeof given === "object") continue;
    let text = String(given).trim();
    if (text === "") continue;
    if (field.kind === "number") {
      const number = Number(text.replace(",", "."));
      if (!Number.isFinite(number)) continue;
      text = String(number);
    } else if (field.kind === "boolean") {
      const low = text.toLowerCase();
      const yes = ["true", "yes", "si", "sì", "1", "on"].includes(low);
      const no = ["false", "no", "0", "off"].includes(low);
      if (!yes && !no) continue;
      text = yes ? "true" : "false";
    } else if (field.kind === "date") {
      // Only what a date field of this app would store.
      const match = text.match(/^\d{4}-\d{2}-\d{2}/);
      if (!match) continue;
      text = match[0];
    }
    out.push({ name: field.name, value: text });
  }
  return out;
}
`)

/** The query plan, checked against the closed list of field names. A refusal says
    which name was not a field, because that is the one thing anybody can act on. */
let plan: (JSON.t, array<string>) => result<plan, string> = %raw(`
function (value, allowed) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return { TAG: "Error", _0: "not an object" };
  }
  const ops = ["eq", "ne", "gt", "lt", "gte", "lte", "contains", "empty", "not-empty"];
  const known = (name) => allowed.includes(String(name));
  const filters = [];
  for (const entry of Array.isArray(value.filters) ? value.filters : []) {
    if (entry === null || typeof entry !== "object") continue;
    const field = String(entry.field || "");
    if (!known(field)) return { TAG: "Error", _0: "unknown field: " + field };
    filters.push({
      field,
      op: ops.includes(String(entry.op)) ? String(entry.op) : "eq",
      value: entry.value === null || entry.value === undefined ? "" : String(entry.value),
    });
  }
  const groupBy = value.groupBy === null || value.groupBy === undefined ? "" : String(value.groupBy);
  if (groupBy !== "" && !known(groupBy)) return { TAG: "Error", _0: "unknown field: " + groupBy };
  const metric = ["count", "sum", "avg", "min", "max"].includes(String(value.metric))
    ? String(value.metric) : "count";
  const metricField = value.field === null || value.field === undefined ? "" : String(value.field);
  if (metric !== "count" && !known(metricField)) return { TAG: "Error", _0: "unknown field: " + metricField };
  const asked = Number(value.limit);
  return {
    TAG: "Ok",
    _0: {
      filters,
      groupBy,
      metric,
      metricField: metric === "count" ? "" : metricField,
      sort: String(value.sort) === "asc" ? "asc" : "desc",
      limit: Number.isFinite(asked) ? Math.max(1, Math.min(200, Math.trunc(asked))) : 20,
    },
  };
}
`)

/** Whether one row passes one test. */
let passes: (filter, Dict.t<string>) => bool = %raw(`
function (test, row) { return rnPasses(test, row); }
`)

/** The plan, run here — over rows this device already holds. What a value that is
    not a number means is what it means everywhere else in this app: not counted,
    rather than counted as zero. */
let run: (plan, array<Dict.t<string>>) => answer = %raw(`
function (plan, rows) {
  const kept = rows.filter((row) => plan.filters.every((test) => rnPasses(test, row)));
  const numbersOf = (list) => list
    .map((row) => {
      const held = row[plan.metricField];
      const text = held === null || held === undefined ? "" : String(held).trim().replace(",", ".");
      return text === "" ? NaN : Number(text);
    })
    .filter((n) => Number.isFinite(n));
  const round = (n) => String(Math.round(n * 100) / 100);
  const measure = (list) => {
    if (plan.metric === "count") return String(list.length);
    const numbers = numbersOf(list);
    if (numbers.length === 0) return "—";
    if (plan.metric === "sum") return round(numbers.reduce((a, b) => a + b, 0));
    if (plan.metric === "avg") return round(numbers.reduce((a, b) => a + b, 0) / numbers.length);
    if (plan.metric === "min") return round(Math.min.apply(null, numbers));
    return round(Math.max.apply(null, numbers));
  };

  if (plan.groupBy === "") return { scalar: measure(kept), rows: [] };

  const groups = new Map();
  for (const row of kept) {
    const held = row[plan.groupBy];
    const label = held === null || held === undefined || String(held).trim() === "" ? "—" : String(held);
    if (!groups.has(label)) groups.set(label, []);
    groups.get(label).push(row);
  }
  const lines = [...groups.entries()].map((entry) => ({ label: entry[0], value: measure(entry[1]) }));
  lines.sort((a, b) => {
    const x = Number(a.value), y = Number(b.value);
    const numeric = Number.isFinite(x) && Number.isFinite(y);
    const order = numeric ? x - y : String(a.label).localeCompare(String(b.label));
    return plan.sort === "asc" ? order : -order;
  });
  return { scalar: "", rows: lines.slice(0, plan.limit) };
}
`)

/** A rule, compiled once. Same closed-list discipline as a plan: the field it
    watches and the field it writes must both be fields of that collection. */
let rule: (JSON.t, array<string>) => result<rule, string> = %raw(`
function (value, allowed) {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return { TAG: "Error", _0: "not an object" };
  }
  const ops = ["eq", "ne", "gt", "lt", "gte", "lte", "contains", "empty", "not-empty"];
  const field = String(value.field || "");
  const setField = String(value.setField || "");
  if (!allowed.includes(field)) return { TAG: "Error", _0: "unknown field: " + field };
  if (!allowed.includes(setField)) return { TAG: "Error", _0: "unknown field: " + setField };
  const setValue = value.setValue === null || value.setValue === undefined ? "" : String(value.setValue);
  if (setValue === "") return { TAG: "Error", _0: "the rule writes nothing" };
  return {
    TAG: "Ok",
    _0: {
      field,
      op: ops.includes(String(value.op)) ? String(value.op) : "eq",
      value: value.value === null || value.value === undefined ? "" : String(value.value),
      setField,
      setValue,
    },
  };
}
`)

/** Which rows the rule changes — and only the ones it would actually change, which
    is what makes running it twice the same as running it once. */
let applies: (rule, array<Dict.t<string>>) => array<Dict.t<string>> = %raw(`
function (rule, rows) {
  return rows.filter((row) => {
    const held = row[rule.setField];
    if ((held === null || held === undefined ? "" : String(held)) === rule.setValue) return false;
    return rnPasses({ field: rule.field, op: rule.op, value: rule.value }, row);
  });
}
`)

// ---------------------------------------------------------------------------
// The prompts. In English, deliberately: the instruction is to the model, and the
// document's own words travel inside it. Each one ends by saying the SHAPE of the
// answer, because that is the half of the contract this file then enforces.
// ---------------------------------------------------------------------------

/** The rows a prompt may carry: a sample, never the collection. A model does not
    need three thousand rows to be told what a row looks like, and sending them all
    would be sending the whole dataset to a provider. */
let sample: (array<Dict.t<string>>, int) => string = %raw(`
function (rows, many) { return JSON.stringify(rows.slice(0, many)); }
`)

let planPrompt: (~question: string, ~fields: array<string>, ~rows: string) => string = %raw(`
function (question, fields, rows) {
  return [
    "You turn a question about a table into a query plan. You never write code and never invent data.",
    "The table's fields are exactly: " + fields.join(", ") + ".",
    "A few rows, so you can see what the values look like: " + rows,
    "",
    "Answer with this JSON object:",
    '{"filters":[{"field":"<one of the fields>","op":"eq|ne|gt|lt|gte|lte|contains|empty|not-empty","value":"<text>"}],',
    ' "groupBy":"<one of the fields, or empty for a single number>",',
    ' "metric":"count|sum|avg|min|max", "field":"<the numeric field the metric works on, empty for count>",',
    ' "sort":"asc|desc", "limit":<a number>}',
    "",
    "Every field name must be one of the fields listed above; do not invent one.",
    "The question is: " + question,
    "Answer with JSON and nothing else.",
  ].join("\n");
}
`)

let rulePrompt: (~when_: string, ~do_: string, ~fields: array<string>, ~rows: string) => string = %raw(`
function (when_, do_, fields, rows) {
  return [
    "You compile a rule about a table into JSON. The rule then runs without you, so it must be exact.",
    "The table's fields are exactly: " + fields.join(", ") + ".",
    "A few rows: " + rows,
    "",
    "Answer with this JSON object:",
    '{"field":"<the field the condition looks at>","op":"eq|ne|gt|lt|gte|lte|contains|empty|not-empty","value":"<text>",',
    ' "setField":"<the field to write>","setValue":"<the value to write>"}',
    "",
    "Every field name must be one of the fields listed above.",
    "The condition is: " + when_,
    "The action is: " + do_,
    "Answer with JSON and nothing else.",
  ].join("\n");
}
`)

let recordPrompt: (~instruction: string, ~fields: array<field>, ~text: string) => string = %raw(`
function (instruction, fields, text) {
  const shape = fields.map((f) => '"' + f.name + '": "' +
    (f.kind === "number" ? "a number"
      : f.kind === "date" ? "YYYY-MM-DD"
      : f.kind === "boolean" ? "true or false" : "text") + '"');
  return [
    instruction,
    "Answer with a JSON object with exactly these keys: {" + shape.join(", ") + "}.",
    "Leave a key out when the text does not say what it is. Do not invent values.",
    "Answer with JSON and nothing else.",
    "",
    text,
  ].join("\n");
}
`)

let classifyPrompt: (~instruction: string, ~values: array<string>, ~text: string) => string = %raw(`
function (instruction, values, text) {
  return [
    instruction,
    "Answer with exactly one of these words, and nothing else: " + values.join(", ") + ".",
    "",
    text,
  ].join("\n");
}
`)

let summaryPrompt: (~instruction: string, ~rows: string, ~many: int) => string = %raw(`
function (instruction, rows, many) {
  return [
    "You describe a table for the person who owns it. Be short, concrete and honest:",
    "give numbers where the data has them, and say nothing the data does not support.",
    "The table has " + many + " rows. Here are up to a hundred of them: " + rows,
    "",
    instruction,
  ].join("\n");
}
`)

let chatSystem: (~persona: string, ~rows: string) => string = %raw(`
function (persona, rows) {
  return [
    persona === "" ? "You answer questions about the data below." : persona,
    "You may only use the data below. If it does not answer the question, say so plainly.",
    "Do not invent rows, totals or names.",
    "",
    "The data: " + rows,
  ].join("\n");
}
`)
