/** Notion-style block editor. Markdown conversion is lossy in both directions, so
    only one editor is ever mounted at a time — see [EditorMode]. */
let element: (
  ~initialMarkdown: string,
  ~onChange: string => unit,
  ~dark: bool,
  ~locale: Locale.t,
) => React.element
