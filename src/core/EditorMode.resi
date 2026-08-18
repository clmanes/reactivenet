type editing =
  | Markdown
  | Blocks

type previewWidth =
  | Full
  | Phone

type t = {
  editing: editing,
  editorVisible: bool,
  previewWidth: previewWidth,
  frontmatterVisible: bool,
  directivesVisible: bool,
  dataVisible: bool,
}

let initial: t

/** Sets whether an editor is on screen, and resets the preview to full width when it
    is not: phone width is the author's layout check, not part of the app. Driven by
    the route, which is the single answer to that question. */
let showEditor: (t, bool) => t

/** Picking an editor also reveals it. */
let useEditing: (t, editing) => t

let showsMarkdownEditor: t => bool
let showsBlockEditor: t => bool
let previewIsFullWidth: t => bool

let togglePreviewWidth: t => t
let previewIsPhone: t => bool

let toggleFrontmatter: t => t

let toggleDirectives: t => t

/** Belongs to the preview, so it survives hiding the editor. */
let toggleData: t => t

/** True only in Blocks mode: markdown mode edits the block as text. */
let showsFrontmatterForm: t => bool

/** True only in Blocks mode, for the same reason. */
let showsDirectiveFields: t => bool
