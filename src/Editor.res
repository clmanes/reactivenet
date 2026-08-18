// Uncontrolled on purpose: CodeMirror owns the document. Feeding React state back in
// on every keystroke would fight its own undo history and move the caret.
@react.component
let make = (~initialValue: string, ~onChange: string => unit) => {
  let container = React.useRef(Nullable.null)
  let latestOnChange = React.useRef(onChange)
  latestOnChange.current = onChange

  React.useEffect0(() => {
    switch container.current->Nullable.toOption {
    | Some(element) =>
      let view = CodeMirror.create(
        ~parent=element,
        ~doc=initialValue,
        // Read through the ref so the editor is never rebuilt just because the
        // parent re-rendered with a fresh closure.
        ~onChange=text => latestOnChange.current(text),
        // The line up to the cursor, not the word: the completion decides between
        // directive, attribute and value from context.
        ~complete=line => DirectiveCompletion.completions(
          DirectiveCompletion.analyse(line),
          DirectiveRegistry.all,
        ),
      )
      Some(() => CodeMirror.destroy(view))
    | None => None
    }
  })

  <div ref={ReactDOM.Ref.domRef(container)} className="rn-editor h-full overflow-auto" />
}
