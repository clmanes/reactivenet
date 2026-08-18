// CPython, in a worker.
//
// A worker and not the page, for one reason that decides everything else: Python here
// is somebody's code in a document, and a loop somebody wrote by accident must not
// take the editor with it. On its own thread it can spin, and the page stays a page.
//
// The runtime is served from this origin — `scripts/copy-pyodide.mjs` puts it in
// public/pyodide — so plain Python needs no network at all. Packages are the
// exception and say so: they are megabytes each and come from Pyodide's own CDN, and
// only a document that names one ever asks for it.

let ready = null;

const boot = async () => {
  // The URL is *built*, not written: a literal would be read by the bundler's import
  // analysis, which refuses to follow anything in public/ — rightly, since those files
  // are copied as they are and are not part of the module graph. This one is fetched
  // at runtime, when a document asks for Python and not before.
  const runtimeUrl = new URL("/pyodide/pyodide.mjs", self.location.origin).href;
  const { loadPyodide, version } = await import(/* @vite-ignore */ runtimeUrl);
  const pyodide = await loadPyodide({
    indexURL: "/pyodide/",
    // The wheels are NOT vendored — numpy alone is bigger than the whole app — so
    // package requests go to Pyodide's own CDN, pinned to the vendored version.
    // Without this they resolved against indexURL, where every wheel is a 404 and
    // `packages` could never have worked.
    packageBaseUrl: "https://cdn.jsdelivr.net/pyodide/v" + version + "/full/",
  });
  // Output is collected rather than printed: the page shows it, and a worker has no
  // console anybody reads.
  return pyodide;
};

const runtime = () => {
  if (ready === null) ready = boot();
  return ready;
};

// matplotlib draws to a file, and a file in this filesystem is bytes we can hand back
// as a data URL. Called after the code has run, so a plot survives the run that made
// it without the code having to save anything.
const COLLECT_PLOTS = `
import base64, io, sys
_rn_images = []
_mpl = sys.modules.get("matplotlib.pyplot")
if _mpl is not None:
    for _num in _mpl.get_fignums():
        _figure = _mpl.figure(_num)
        _buffer = io.BytesIO()
        _figure.savefig(_buffer, format="png", dpi=110, bbox_inches="tight")
        _rn_images.append(base64.b64encode(_buffer.getvalue()).decode("ascii"))
    _mpl.close("all")
_rn_images
`;

// What the code offers back as rows. `result` by name rather than the last
// expression, because a block that both prints and produces a collection would
// otherwise have to end on the right line — and because a name says what it is.
const COLLECT_ROWS = `
import json
_rn_rows = None
if isinstance(globals().get("result"), (list, tuple)):
    _rn_rows = json.dumps([
        {str(k): ("" if v is None else str(v)) for k, v in row.items()}
        for row in result if isinstance(row, dict)
    ])
_rn_rows
`;

// The two functions a run may talk through. They are defined in Python rather than
// handed over as JS callbacks directly, so `partial(rows)` receives a real list of
// dicts and turns it into exactly the JSON `result` would have produced — one
// definition of what a row looks like, not two that could drift.
const BRIDGE = `
import json as _rn_json

def progress(done=0, total=0, message=""):
    _rn_progress(float(done), float(total), str(message))

def partial(rows):
    if isinstance(rows, (list, tuple)):
        _rn_partial(_rn_json.dumps([
            {str(k): ("" if v is None else str(v)) for k, v in row.items()}
            for row in rows if isinstance(row, dict)
        ]))
`;

self.onmessage = async (event) => {
  const { id, code, data, packages, writes, params } = event.data;
  const answer = (message) => self.postMessage({ id, ...message });
  try {
    const pyodide = await runtime();

    if (packages && packages.length > 0) {
      await pyodide.loadPackage(packages);
    }

    // The collections, as plain Python: `data["grades"]` is a list of dicts of
    // strings. Read-only in the sense that matters — nothing here writes back, so
    // whatever the code does to its copy stays in the worker.
    pyodide.globals.set("data", pyodide.toPy(data || {}));
    // The reactive keys the block named, as strings — the weights of a model live on
    // sliders, and without this they never reach the code that uses them. Set every
    // run, so a block that names none sees an empty dict rather than the last one's.
    pyodide.globals.set("params", pyodide.toPy(params || {}));

    // Talking back: these two are what `progress()` and `partial()` end up calling.
    // The id is captured here, so a message can only ever be attributed to the run
    // that produced it.
    pyodide.globals.set("_rn_progress", (done, total, message) =>
      self.postMessage({ id, kind: "progress", done, total, message })
    );
    pyodide.globals.set("_rn_partial", (rows) => self.postMessage({ id, kind: "partial", rows }));
    await pyodide.runPythonAsync(BRIDGE);

    // The interpreter is shared between blocks, so `result` from the previous run is
    // still bound in the globals. Left there, a block that never assigns it would
    // hand the *previous* block's rows to its own `writes` target — silently
    // overwriting a collection with somebody else's answer.
    await pyodide.runPythonAsync('globals().pop("result", None)');

    const printed = [];
    pyodide.setStdout({ batched: (line) => printed.push(line) });
    pyodide.setStderr({ batched: (line) => printed.push(line) });

    // runPythonAsync, so `await` works and a top-level import that needs the loader
    // does not deadlock.
    const value = await pyodide.runPythonAsync(code);
    const images = await pyodide.runPythonAsync(COLLECT_PLOTS);
    // Only asked for when the document said where the rows should go: a block with no
    // `writes` has no reason to have its globals rummaged through.
    const rows = writes ? await pyodide.runPythonAsync(COLLECT_ROWS) : null;

    answer({
      rows: rows || "",
      output: printed.join("\n"),
      // The last expression's value, the way a notebook shows it — but only when
      // there is one, so `print`-only code does not end with a stray "None".
      value: value === undefined || value === null ? "" : String(value),
      images: images ? images.toJs() : [],
    });
  } catch (error) {
    // The Python traceback is the useful part; anything else is the loader failing,
    // which is worth saying in the same place.
    answer({ error: String((error && error.message) || error) });
  }
};
