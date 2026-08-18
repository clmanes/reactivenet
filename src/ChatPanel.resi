/** The chat between the people using an app: rows of the `chat` collection, shown
    as messages. They store, back up and sync exactly like every other collection —
    end-to-end encrypted when the app is linked to a shared space. `author` is the
    signed-in username, or nothing for a guest; `clock` stamps what is sent. */
@react.component
let make: (
  ~app: option<string>,
  ~locale: Locale.t,
  ~author: option<string>,
  ~clock: unit => string,
) => Jsx.element
