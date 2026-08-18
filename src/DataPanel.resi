/** The app's stored collections, with backup, restore and deletion.
    `clock` supplies the backup timestamp, keeping the component itself free of one. */
@react.component
let make: (~app: option<string>, ~locale: Locale.t, ~clock: unit => string) => Jsx.element
