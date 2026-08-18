// Pure. What an ::api-query answer MEANS: how `pick` walks into the JSON, and
// how the fragment it lands on becomes rows of a collection.
//
// The shapes public APIs actually return, each with its one honest reading:
//
//   - an ARRAY OF OBJECTS is rows already;
//   - an OBJECT OF ARRAYS is columnar (Open-Meteo's style) and zips into rows
//     by index, the shorter columns padding with "";
//   - an OBJECT OF SCALARS is one row — or, `~pairs=true`, one {key, value}
//     row per entry, which is what a chart wants of an exchange-rate table;
//   - a SCALAR is no rows at all: the scalar form ::api-query[key] reads it.
//
// Values are flattened to the strings a collection stores: scalars with
// String(), nested structures as their JSON — visible, greppable, honest.

/** Descends `pick` — dot-separated names and indices, "results.0.series" — or
    answers nothing when the path leaves the document. Empty pick is the root. */
let picked: (JSON.t, string) => option<JSON.t> = %raw(`
function (json, pick) {
  let value = json;
  for (const step of String(pick || "").split(".").map((s) => s.trim()).filter(Boolean)) {
    if (value === null || value === undefined || typeof value !== "object") return undefined;
    value = Array.isArray(value) && /^\d+$/.test(step) ? value[Number(step)] : value[step];
  }
  return value === undefined ? undefined : value;
}
`)

/** The scalar `pick` landed on, for the reactive-key form — or nothing when it
    landed on a structure. */
let scalar: JSON.t => option<string> = %raw(`
function (value) {
  if (value === null) return "";
  const kind = typeof value;
  return kind === "string" || kind === "number" || kind === "boolean" ? String(value) : undefined;
}
`)

/** The fragment as rows: arrays of field lists, in document order. */
let rows: (JSON.t, ~pairs: bool) => option<array<array<Collection.field>>> = %raw(`
function (value, pairs) {
  const flat = (v) => {
    if (v === null || v === undefined) return "";
    return typeof v === "object" ? JSON.stringify(v) : String(v);
  };
  const ofObject = (entry) => {
    const fields = [];
    for (const [name, v] of Object.entries(entry)) {
      if (name === "id") continue;
      fields.push({ name, value: flat(v) });
    }
    return fields;
  };

  if (Array.isArray(value)) {
    return value.map((entry) =>
      entry !== null && typeof entry === "object" && !Array.isArray(entry)
        ? ofObject(entry)
        : [{ name: "value", value: flat(entry) }],
    );
  }
  if (value !== null && typeof value === "object") {
    const entries = Object.entries(value);
    const columnar = entries.length > 0 && entries.every(([, v]) => Array.isArray(v));
    if (columnar) {
      const length = Math.max(...entries.map(([, v]) => v.length));
      const rows = [];
      for (let i = 0; i < length; i++) {
        rows.push(entries.map(([name, v]) => ({ name, value: i < v.length ? flat(v[i]) : "" })));
      }
      return rows;
    }
    if (pairs) {
      return entries.map(([key, v]) => [
        { name: "key", value: key },
        { name: "value", value: flat(v) },
      ]);
    }
    return [ofObject(value)];
  }
  return undefined;
}
`)
