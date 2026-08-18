// The four calls a native <dialog> needs, in one place.
//
// `showModal()` is what makes a modal accessible without a line of focus code: the
// browser moves focus in, traps it, makes the rest inert, closes on Esc and returns
// focus to whatever opened it. Two dialogs need exactly this and nothing more, and a
// second copy of the externals would be a second place to get the guard wrong —
// showModal on an already-open dialog throws.

@send external showModal: Dom.element => unit = "showModal"
@send external close: Dom.element => unit = "close"
@get external isOpen: Dom.element => bool = "open"
@send external listen: (Dom.element, string, unit => unit) => unit = "addEventListener"
@send external unlisten: (Dom.element, string, unit => unit) => unit = "removeEventListener"

/** Opens or closes to match, and returns the cleanup: the close listener is removed
    before closing, so a close this code *initiated* does not come back as a
    dismissal. */
let follow = (element, ~open_, ~onDismiss) =>
  if open_ {
    element->listen("close", onDismiss)
    if !isOpen(element) {
      showModal(element)
    }
    Some(
      () => {
        element->unlisten("close", onDismiss)
        if isOpen(element) {
          close(element)
        }
      },
    )
  } else {
    if isOpen(element) {
      close(element)
    }
    None
  }
