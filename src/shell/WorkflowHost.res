// The one thing an engine has to learn to be a step of a workflow, and it is two
// lines: *am I inside one*, and if so *here is my run, you call it*.
//
// Installed once at module load as `globalThis.__rnWorkflow`, the way the dashboard's
// cross-filter is — a binder cannot import another binder without the two importing
// each other, and a global that is asked for defensively (`__rnWorkflow ? … : false`)
// costs nothing when the document has no workflow in it.
//
// Containment is `closest("[data-rn-workflow]")`, the rule a field already uses to
// find the form it belongs to. **The workflow reads what the engine painted into its
// own `.rn-od-status` as the report**, so no engine has a second channel to keep in
// step: the class says succeeded-or-failed — structural, not linguistic — and the text
// is already in the reader's language because the engine wrote it there.
//
// The run resolves ONE word beyond that, and it exists because a painted status cannot
// express it: `"waiting"` means the engine DECLINED — the DuckDB download, the
// scikit-learn packages, a `::python{manual}` block. A step waiting behind a button
// somebody has to press is not a step that finished, and the difference is invisible
// in the DOM: the status line is empty or still says "loading", which reads as success.
// Reporting it as done, and then running the steps that needed what it never produced,
// is exactly the silent success the directive exists to prevent.
//
// Why an engine must not start itself inside a workflow: the order is the workflow's
// answer, and a step that ran early ran against inputs that had not arrived. Worse,
// nothing downstream of a failed step may run at all, and a step that started on its
// own is a step nobody could stop.

%%raw(`
const workflowRuns = new WeakMap();

globalThis.__rnWorkflow = {
  // The only question an engine asks on the common path, where there is no workflow
  // anywhere in the document: one closest() up a tree it is already standing in.
  defers(node) {
    return node && node.closest ? node.closest("[data-rn-workflow]") !== null : false;
  },

  // The engine's own run, kept against the node. The nodes are recreated by every
  // debounced render, so every render re-registers — which is exactly right: the
  // closure has to be the one that knows about the node on screen now. It resolves
  // "waiting" when it declined, and anything else when it ran.
  register(node, run) {
    if (node) workflowRuns.set(node, run);
  },

  runOf(node) {
    return (node && workflowRuns.get(node)) || null;
  },
};
`)

@val @scope("__rnWorkflow")
external runOf: Dom.element => Nullable.t<bool => promise<Nullable.t<string>>> = "runOf"
