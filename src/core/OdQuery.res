// Pure. What a `{#key}` placeholder in an od-query's SQL means: a PREPARED
// parameter, never text pasted into the statement. The value comes from a
// reactive key — which is to say from whatever a reader typed into a control —
// so concatenation would hand every reader a SQL injection into the open-data
// service. Binding turns each placeholder into `?` and carries the values
// separately; nothing a reader types can change the shape of the query.
//
// The quoted form '{#key}' is accepted and the quotes are consumed with the
// placeholder: writing WHERE name = '{#q}' is the natural spelling for anyone
// who knows SQL, and leaving the quotes would put the ? inside a string
// literal where it stops being a parameter at all.

let references: string => array<string> = %raw(`
function (sql) {
  const seen = [];
  const pattern = /'\{#([A-Za-z0-9_.]+)\}'|\{#([A-Za-z0-9_.]+)\}/g;
  let found;
  while ((found = pattern.exec(sql))) {
    const key = found[1] || found[2];
    if (key && !seen.includes(key)) seen.push(key);
  }
  return seen;
}
`)

let bind: (string, string => option<string>) => (string, array<string>) = %raw(`
function (sql, lookup) {
  const params = [];
  const bound = sql.replace(
    /'\{#([A-Za-z0-9_.]+)\}'|\{#([A-Za-z0-9_.]+)\}/g,
    (_, quoted, bare) => {
      const value = lookup(quoted || bare);
      params.push(value === undefined ? "" : value);
      return "?";
    },
  );
  return [bound, params];
}
`)
