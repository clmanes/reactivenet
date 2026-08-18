type outcome = {
  /** The rows the code offered back, as JSON, when the block named a collection to
      write them to. Empty when it offered none — and, after a stop, the last rows
      `partial()` published. */
  rows: string,
  /** Everything the code printed, stdout and stderr together, in order. */
  output: string,
  /** The value of the last expression, the way a notebook shows it. Empty when there
      is none, so `print`-only code does not end with a stray "None". */
  value: string,
  /** Any matplotlib figures, base64 PNG. */
  images: array<string>,
  /** The traceback, or the loader's complaint. Empty when the run succeeded. */
  error: string,
}

/** Runs the code in the one shared interpreter, watching it as it goes. `data` and
    `params` are JSON — they arrive in Python as `data["name"]` (a list of dicts of
    strings) and `params["name"]` (the reactive keys the block named). `ceiling` is
    how long the run may take before the worker is killed. `onProgress` and
    `onPartial` are what the code's own `progress()` and `partial()` calls arrive as.
    Runs are serialised: two blocks in a document are two runs of one interpreter. */
let runWatched: (
  ~code: string,
  ~data: string,
  ~packages: array<string>,
  ~writes: string,
  ~params: string,
  ~ceiling: int,
  ~onProgress: (float, float, string) => unit,
  ~onPartial: string => unit,
) => promise<outcome>

/** Kills the interpreter and answers the run in flight with its last `partial()` and
    no error. Not a polite cancellation, and cannot be: CPython in a tight loop reads
    no flag. The next run starts a fresh runtime. */
let stop: unit => unit

/** The plain run: two minutes, no parameters, nobody watching. */
let run: (
  ~code: string,
  ~data: string,
  ~packages: array<string>,
  ~writes: string,
) => promise<outcome>
