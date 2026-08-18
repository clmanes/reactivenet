// What the assistant remembers between visits, in IndexedDB like every other
// preference here — `localStorage` is not used anywhere in this project.
//
// Two values, and they are kept apart on purpose. The settings are a preference and
// belong to the device. The conversation is a document of its own: it is what makes
// "change the colour" mean anything on the second message, and losing it on every
// reload would make the assistant useless for the thing it is for.
//
// Worth saying plainly, because storing a key is a decision and not a detail: the
// key is written to this browser's IndexedDB, which is same-origin storage. Anything
// else running on this origin can read it — including a `::python` block in a
// document somebody imported, since a worker on this origin reaches the same
// database. There is no browser mechanism that would isolate it, which is why the
// local model exists in the settings at all: with Ollama there is no key to store
// and nothing to leak. See doc/security.md.

let settingsKey = "ai.settings"
let historyKey = "ai.history"

let loadSettings = () =>
  Idb.get(settingsKey)->Promise.thenResolve(stored =>
    switch stored->Nullable.toOption {
    | None => AiSettings.blank
    | Some(text) =>
      switch JSON.parseOrThrow(text) {
      | value =>
        switch JSON.Decode.object(value) {
        | None => AiSettings.blank
        | Some(fields) => {
            let read = (name, fallback) =>
              fields
              ->Dict.get(name)
              ->Option.flatMap(JSON.Decode.string)
              ->Option.getOr(fallback)
            AiSettings.normalize({
              key: read("key", ""),
              model: read("model", AiSettings.defaultModel),
              baseUrl: read("baseUrl", AiSettings.hostedBaseUrl),
            })
          }
        }
      | exception _ => AiSettings.blank
      }
    }
  )

let saveSettings = (settings: AiSettings.t) => {
  let normalized = AiSettings.normalize(settings)
  Idb.set(
    settingsKey,
    JSON.stringifyAny({
      "key": normalized.key,
      "model": normalized.model,
      "baseUrl": normalized.baseUrl,
    })->Option.getOr("{}"),
  )
}

/** The conversation, both halves of it: the wire history the provider is sent, and
    the turns the panel draws. They are stored together because they are one thing
    told twice — rebuilding either from the other would mean a second reading of the
    same conversation, and the two would disagree the first time a tool failed. */
let loadHistory = () =>
  Idb.get(historyKey)->Promise.thenResolve(stored =>
    switch stored->Nullable.toOption {
    | None => None
    | Some(text) =>
      switch JSON.parseOrThrow(text) {
      | value => Some(value)
      | exception _ => None
      }
    }
  )

let saveHistory = (value: JSON.t) => Idb.set(historyKey, JSON.stringify(value))

let clearHistory = () => Idb.remove(historyKey)
