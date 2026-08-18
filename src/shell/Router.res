// The URL, as the app reads and writes it.
//
// `Route` decides what a path means; this only carries it to and from the browser.
// With the routes in the path, navigation is `history.pushState` — which, unlike
// assigning a hash, fires nothing. So every push announces itself, and `subscribe`
// listens for both that announcement and the browser's own `popstate`, which is what
// Back and Forward produce.

@val @scope("location") external path: string = "pathname"

// A function, not a @val external: an external re-exported across modules
// materialises as a module-level binding — `let fragment = location.hash` evaluated
// once, at load. A page opened at the gallery therefore carried an empty fragment
// forever, and every short link followed in-app read as truncated.
let fragment: unit => string = %raw(`function () { return location.hash; }`)

let changed = "rn:navigate"

// pushState pushes a history entry, so Back works; the event is what tells the app a
// route it did not ask for is now on screen.
let push: string => unit = %raw(`
function (value) {
  history.pushState(null, "", value);
  window.dispatchEvent(new Event("rn:navigate"));
}
`)

// Replaces the current entry instead of pushing one. For the moments that must not
// stay in history: a shared link's /s has done its work the instant the app is
// filed, and Back returning to it would import another copy.
let replaceState: string => unit = %raw(`
function (value) {
  history.replaceState(null, "", value);
  window.dispatchEvent(new Event("rn:navigate"));
}
`)

let current = () => Route.parse(path)

// Pushing the same path again would fill the history with copies of the page you are
// already on: clicking the app you are already in must not need three presses of Back
// to leave.
let navigate = route => {
  let next = Route.toPath(route)
  path == next ? () : push(next)
}

let replace = route => replaceState(Route.toPath(route))

@val @scope("window")
external addListener: (string, unit => unit) => unit = "addEventListener"
@val @scope("window")
external removeListener: (string, unit => unit) => unit = "removeEventListener"

/** Calls back on every route change, whether the app pushed it or the reader pressed
    Back; returns the unsubscribe. */
let subscribe = onChange => {
  let handler = () => onChange(current())
  addListener("popstate", handler)
  addListener(changed, handler)
  () => {
    removeListener("popstate", handler)
    removeListener(changed, handler)
  }
}

// A link is a link: it carries the URL, it can be copied, opened in a new tab and
// read by anything that reads links. Following it inside the app is an optimisation
// on top — so a plain left click is intercepted and anything else (a modifier, the
// middle button) is left to the browser, which is what makes ⌘-click still work.
let follow = (route: Route.t) => (event: ReactEvent.Mouse.t) =>
  if (
    !ReactEvent.Mouse.defaultPrevented(event) &&
    ReactEvent.Mouse.button(event) == 0 &&
    !ReactEvent.Mouse.metaKey(event) &&
    !ReactEvent.Mouse.ctrlKey(event) &&
    !ReactEvent.Mouse.shiftKey(event) &&
    !ReactEvent.Mouse.altKey(event)
  ) {
    ReactEvent.Mouse.preventDefault(event)
    navigate(route)
  }
