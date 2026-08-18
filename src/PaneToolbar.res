// The strip above each pane. Kept generic so the editor and preview toolbars line up
// on the same baseline instead of drifting apart as they grow.
@react.component
let make = (~title: string, ~icon: option<string>=?, ~children) =>
  // Sticky, so it is still there once the page has scrolled. Side by side this
  // changes nothing — the panes scroll inside a fixed layout and the strip never
  // moves — but below the breakpoint the *page* is the scroller, and a toolbar that
  // scrolls away takes the controls for the pane it names with it.
  <div
    className="rn-pane-bar rn-surface flex h-9 shrink-0 items-center justify-between gap-2 border-b px-2">
    <span className="rn-muted flex items-center pl-1 text-xs font-medium tracking-wide uppercase">
      // The app's own mark, where the pane is the app: the same icon the gallery card
      // carries, so an app is recognisable from its card to inside itself.
      {switch icon {
      | Some(name) => <AppIcon name className="rn-pane-icon" />
      | None => React.null
      }}
      {React.string(title)}
    </span>
    <div className="flex items-center gap-1"> children </div>
  </div>
