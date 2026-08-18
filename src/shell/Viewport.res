// Whether there is room to edit.
//
// The threshold is the same one the stylesheet uses to stop showing the two panes
// side by side. Below it an editor and a preview would each get half a screen minus
// two toolbars, and CodeMirror and BlockNote are desktop editing surfaces — neither
// is usable at that size, and offering them anyway is worse than not offering them.
//
// This is a capability of the device, not a preference, so it is not persisted and
// not exposed as a setting: rotating a tablet changes it, and the app follows.

let editingBreakpoint = "(min-width: 48rem)"

@val external matchMedia: string => {"matches": bool} = "matchMedia"

let canEdit = () =>
  try matchMedia(editingBreakpoint)["matches"] catch {
  // No matchMedia at all is old or exotic; assume the larger layout rather than
  // locking editing away where it might be the only way in.
  | _ => true
  }

let subscribe: (bool => unit) => unit => unit = %raw(`
function (onChange) {
  if (typeof matchMedia !== "function") return function () {};
  const query = matchMedia("(min-width: 48rem)");
  const handler = (event) => onChange(event.matches);
  query.addEventListener("change", handler);
  return function () { query.removeEventListener("change", handler); };
}
`)
