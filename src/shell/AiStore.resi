/** What the assistant remembers between visits, in IndexedDB like every other
    preference here.

    The key is written to this browser's same-origin storage, which anything else on
    this origin can read — a `::python` block in an imported document included, since
    a worker reaches the same database. No browser mechanism isolates it; the local
    model is the answer for anybody that matters to, because there is then no key at
    all. See doc/security.md. */

let loadSettings: unit => promise<AiSettings.t>

let saveSettings: AiSettings.t => promise<unit>

/** The conversation, wire history and drawn turns together: one thing told twice,
    and rebuilding either from the other would give two readings that disagree the
    first time a tool failed. */
let loadHistory: unit => promise<option<JSON.t>>

let saveHistory: JSON.t => promise<unit>

let clearHistory: unit => promise<unit>
