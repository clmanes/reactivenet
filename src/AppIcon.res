// The mark an app carries, named in its frontmatter.
//
// A gallery of cards is a list of names until the names have marks beside them; an
// app that says `icon: calendar` gets one, and one that says nothing gets the default
// below rather than a gap — a card missing the thing every other card has reads as
// broken rather than as plain.
//
// The name is validated against Spectrum's own set in `AppDocument.summary`, so what
// arrives here is either a real icon or the empty string.

@react.component
let make = (~name: string, ~className: string="rn-app-card-icon") => {
  let host = React.useRef(Nullable.null)

  React.useEffect1(() => {
    switch host.current->Nullable.toOption {
    | Some(element) => IconDrawings.draw(element, name == "" ? AppDocument.defaultIcon : name)
    | None => ()
    }
    None
  }, [name])

  <span className ref={ReactDOM.Ref.domRef(host)} ariaHidden={true} />
}
