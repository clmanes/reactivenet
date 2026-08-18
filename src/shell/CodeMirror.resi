type view

/** Mounts an editor into `parent`. `complete` is called with the whole line up to
    the cursor and decides what the autocomplete popup offers. */
let create: (
  ~parent: Dom.element,
  ~doc: string,
  ~onChange: string => unit,
  ~complete: string => array<DirectiveCompletion.completion>,
) => view

let destroy: view => unit
