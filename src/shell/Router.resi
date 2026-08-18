/** The URL's fragment as of *now* — a function, because a value would be the hash
    the module happened to load under. The fragment is where a shared document (or
    its key) rides, and it is never sent to a server. */
let fragment: unit => string

/** The route the URL currently addresses. */
let current: unit => Route.t

/** Navigates with `history.pushState`, so Back works, and announces it — pushState
    fires no event of its own. Navigating to the current route does nothing. */
let navigate: Route.t => unit

/** Navigates by replacing the current history entry: for routes that must not be
    returned to, like a consumed share link. */
let replace: Route.t => unit

/** Subscribes to route changes, the app's own and the browser's; returns the
    unsubscribe. */
let subscribe: (Route.t => unit) => unit => unit

/** Handles a click on a real `<a href>`: follows it inside the app on a plain left
    click, and leaves every other click — modifier, middle button — to the browser. */
let follow: Route.t => ReactEvent.Mouse.t => unit
