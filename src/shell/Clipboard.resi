/** Writes text to the clipboard. False when the browser refused. */
let copy: string => promise<bool>

/** The full URL of a route, suitable for sending to someone. */
let absolute: Route.t => string

/** Where this app is served from, which a shared link has to carry: the reader who
    opens it may never have been here before. */
let origin: string
