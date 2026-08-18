// A modal confirmation, on the native <dialog>.
//
// `showModal()` is what makes this accessible without a line of focus code: the
// browser moves focus in, traps it, makes the rest of the page inert, closes on Esc
// and returns focus to whatever opened it. Every one of those is a thing hand-written
// modals get wrong, and the last one is invisible in testing but obvious to anyone
// working from the keyboard.
//
// Deliberately not `window.confirm`: it is a browser chrome dialog we cannot name,
// translate or style, and it blocks the whole page.

@send external showModal: Dom.element => unit = "showModal"
@send external close: Dom.element => unit = "close"
@get external isOpen: Dom.element => bool = "open"
@send external listen: (Dom.element, string, unit => unit) => unit = "addEventListener"
@send external unlisten: (Dom.element, string, unit => unit) => unit = "removeEventListener"

@react.component
let make = (
  ~open_: bool,
  ~title: string,
  ~message: string,
  ~confirmLabel: string,
  ~cancelLabel: string,
  ~onConfirm: unit => unit,
  ~onCancel: unit => unit,
) => {
  let dialog = React.useRef(Nullable.null)
  let titleId = "rn-confirm-title"

  React.useEffect1(() => {
    switch (dialog.current->Nullable.toOption, open_) {
    | (Some(element), true) =>
      // `close` covers every way out — the buttons, Esc, the backdrop — so cancelling
      // has one path whatever the reader did. The cleanup removes the listener before
      // closing, so a close this component *initiated* does not come back as a cancel.
      let dismissed = () => onCancel()
      element->listen("close", dismissed)
      // Guarded: showModal on an already-open dialog throws.
      if !isOpen(element) {
        showModal(element)
      }
      Some(
        () => {
          element->unlisten("close", dismissed)
          if isOpen(element) {
            close(element)
          }
        },
      )
    | _ => None
    }
  }, [open_])

  <dialog
    ref={ReactDOM.Ref.domRef(dialog)}
    className="rn-dialog"
    ariaLabelledby={titleId}>
    <h2 id={titleId} className="rn-dialog-title"> {React.string(title)} </h2>
    <p className="rn-dialog-message"> {React.string(message)} </p>
    <div className="rn-dialog-actions">
      <Spectrum.Button variant="secondary" treatment="outline" onClick={_ => onCancel()}>
        {React.string(cancelLabel)}
      </Spectrum.Button>
      <Spectrum.Button variant="negative" onClick={_ => onConfirm()}>
        {React.string(confirmLabel)}
      </Spectrum.Button>
    </div>
  </dialog>
}
