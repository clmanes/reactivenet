// Copying an app's URL. Resolves to false rather than rejecting when the browser
// refuses — the clipboard needs a user gesture and a secure context, and neither is
// worth an exception at the call site: the caller shows "copied" or it does not.

let copy: string => promise<bool> = %raw(`
function (text) {
  try {
    if (!navigator.clipboard || !navigator.clipboard.writeText) return Promise.resolve(false);
    return navigator.clipboard.writeText(text).then(() => true, () => false);
  } catch {
    return Promise.resolve(false);
  }
}
`)

/** The absolute URL of a route, for pasting somewhere else. */
@val @scope("location") external origin: string = "origin"

let absolute = route => origin ++ Route.toPath(route)
