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

let currentVersion: int

/** Serialises every collection of an app. The timestamp is passed in rather than
    read, so this stays deterministic. */
let encode: (string, string, array<(string, Collection.t)>) => string

/** Every failure is named: a backup that silently decodes to "no collections" is
    indistinguishable from an empty app. */
let decode: string => result<t, error>

let errorToString: error => string

/** Whether the backup came from the app it is about to be restored into. */
let belongsTo: (t, string) => bool

let collection: (t, string) => option<Collection.t>
let paths: t => array<string>
