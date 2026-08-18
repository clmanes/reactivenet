// Pure. The backup envelope: which app the data belongs to, and every collection in
// it.
//
// The app id is carried *inside* the file, not inferred from the filename, because
// restoring one app's data into another silently corrupts both. `parse` reports the
// id it found and refuses nothing on its own — the decision to accept a foreign
// backup belongs to the caller, which is the only layer that can ask the user.

type t = {
  app: string,
  formatVersion: int,
  exportedAt: string,
  collections: array<(string, Collection.t)>,
}

type error =
  | NotJson
  | NotABackup
  | UnsupportedVersion(int)

// Bumped only when the shape changes incompatibly, so an old file can be recognised
// and refused rather than half-read.
let currentVersion = 1

let encode: (string, string, array<(string, Collection.t)>) => string = %raw(`
function (app, exportedAt, collections) {
  const payload = {
    app,
    formatVersion: 1,
    exportedAt,
    collections: Object.fromEntries(
      collections.map(([path, collection]) => [
        path,
        collection.records.map((record) => ({
          id: record.id,
          fields: Object.fromEntries(record.fields.map((f) => [f.name, f.value])),
        })),
      ])
    ),
  };
  return JSON.stringify(payload, null, 2);
}
`)

// Returns a variant-shaped result so the caller has to handle every failure: a
// backup that silently decodes to "no collections" is indistinguishable from an
// empty app, which is exactly the confusion that loses data.
let decode: string => result<t, error> = %raw(`
function (text) {
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    return { TAG: "Error", _0: "NotJson" };
  }

  if (!parsed || typeof parsed !== "object" || typeof parsed.app !== "string" || !parsed.collections) {
    return { TAG: "Error", _0: "NotABackup" };
  }

  const version = typeof parsed.formatVersion === "number" ? parsed.formatVersion : 0;
  if (version !== 1) {
    return { TAG: "Error", _0: { TAG: "UnsupportedVersion", _0: version } };
  }

  const collections = Object.entries(parsed.collections).map(([path, records]) => [
    path,
    {
      records: (Array.isArray(records) ? records : []).map((record) => ({
        id: String(record && record.id !== undefined ? record.id : ""),
        fields: Object.entries((record && record.fields) || {}).map(([name, value]) => ({
          name,
          value: String(value),
        })),
      })),
    },
  ]);

  return {
    TAG: "Ok",
    _0: {
      app: parsed.app,
      formatVersion: version,
      exportedAt: typeof parsed.exportedAt === "string" ? parsed.exportedAt : "",
      collections,
    },
  };
}
`)

let errorToString = error =>
  switch error {
  | NotJson => "The file is not valid JSON."
  | NotABackup => "The file is not a ReactiveNET backup."
  | UnsupportedVersion(found) =>
    `Backup format ${found->Int.toString} is not supported (expected ${currentVersion->Int.toString}).`
  }

/** True when the backup was taken from the app it is about to be restored into. */
let belongsTo = (backup, app) => backup.app == app

let collection = (backup, path) =>
  backup.collections
  ->Array.find(((name, _)) => name == path)
  ->Option.map(((_, collection)) => collection)

let paths = backup => backup.collections->Array.map(((name, _)) => name)
