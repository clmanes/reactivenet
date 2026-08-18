/** Containment for the engines inside a `::workflow`, installed at module load as
    `globalThis.__rnWorkflow`.

    An engine asks `__rnWorkflow.defers(node)`; when the answer is yes it hands its own
    run over with `register` instead of calling it, because the order — and whether it
    runs at all after the step before it failed — is the workflow's business.

    The report travels the other way through the engine's own `.rn-od-status`: the
    class says whether it worked, the text is already in the reader's language. That
    is the whole protocol, and keeping it at one channel is what stops the two from
    drifting. */

/** The run an engine registered for this node, or null.

    The argument is *force*: false lets the engine's own signature guard make an
    unchanged step a no-op. It resolves `"waiting"` when the engine declined — a
    closed download gate, a manual block — and anything else when it ran. A step that
    declined is not a step that finished, and nothing downstream of it may run. */
let runOf: Dom.element => Nullable.t<bool => promise<Nullable.t<string>>>
