/** The path segment that names the catalogue: `/c/<id>`. */
let segment: string

let path: string

/** The document of one catalogue app, relative to the catalogue's origin. */
let documentPath: string => string

/** The catalogue's own index, relative to its origin. */
let indexPath: string

/** The whole address that opens a catalogue app in this application. */
let of_: (~origin: string, ~id: string) => string
