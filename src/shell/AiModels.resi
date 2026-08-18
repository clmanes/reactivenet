/** The models the local daemon actually has, so the settings form can offer a list
    rather than a text field: a name typed from memory is the commonest way this ends
    in a 404, and the names are versioned and unguessable.

    `tools` is the capability that decides whether a model can do this job at all —
    one that cannot call a tool cannot read the directive catalogue, and will invent
    directives. Unknown counts as yes: on a daemon that does not publish
    capabilities, marking every model incapable would leave an unusable list. */

type model = {name: string, tools: bool}

/** Empty when the daemon is not there, which is the ordinary case and not an error.
    `baseUrl` is the chat endpoint; Ollama's own API sits beside it, not under it. */
let installed: (~baseUrl: string) => promise<array<model>>
