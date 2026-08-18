/** A modal confirmation on the native <dialog>: the browser supplies the focus trap,
    Esc, and the return of focus to whatever opened it. `onCancel` fires for every way
    of dismissing it, including Esc. */
@react.component
let make: (
  ~open_: bool,
  ~title: string,
  ~message: string,
  ~confirmLabel: string,
  ~cancelLabel: string,
  ~onConfirm: unit => unit,
  ~onCancel: unit => unit,
) => Jsx.element
