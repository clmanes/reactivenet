// Pure. The distinction the whole reactive model rests on.
//
// A leading `#` marks a *reactive reference*: a view that subscribes to a path and
// re-renders when the value behind it changes. A bare id is a *store key*: where a
// source control writes. So `::slider[volume]` writes to `volume`, and
// `:value[v]{ref="#volume"}` reads from `#volume`.
//
// They are deliberately different types rather than one string, because confusing
// them is silent: a view bound to a store key simply never updates, and nothing
// anywhere reports an error.

type t =
  | Reactive(string)
  | StoreKey(string)

let marker = "#"

let parse = raw => {
  let trimmed = raw->String.trim

  if trimmed->String.startsWith(marker) {
    let key =
      trimmed
      ->String.slice(~start=String.length(marker), ~end=String.length(trimmed))
      ->String.trim
    // A lone "#" references nothing.
    key == "" ? None : Some(Reactive(key))
  } else if trimmed == "" {
    None
  } else {
    Some(StoreKey(trimmed))
  }
}

let key = reference =>
  switch reference {
  | Reactive(key) | StoreKey(key) => key
  }

let isReactive = reference =>
  switch reference {
  | Reactive(_) => true
  | StoreKey(_) => false
  }

let toString = reference =>
  switch reference {
  | Reactive(key) => marker ++ key
  | StoreKey(key) => key
  }

// The boundary used by the renderer: only a reactive reference may be bound to a
// live view, so a plain store key answers `None` rather than quietly binding to
// something that will never emit.
let reactiveKey = raw =>
  switch parse(raw) {
  | Some(Reactive(key)) => Some(key)
  | Some(StoreKey(_)) | None => None
  }
