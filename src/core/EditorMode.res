// Pure. What the workspace can look like, and how the controls move between those
// states — kept out of the components so the transitions can be tested directly.

type editing =
  | Markdown // CodeMirror over the raw source
  | Blocks // BlockNote, Notion-style

// How wide the preview renders. Phone mode is a layout check, not a device
// emulation: it constrains the preview to a handset width so you can see where the
// document wraps without leaving the app.
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

let initial = {
  editing: Markdown,
  editorVisible: true,
  previewWidth: Full,
  frontmatterVisible: true,
  directivesVisible: false,
  dataVisible: false,
}

// Whether an editor is on screen is the URL's business: /a/<id> is the app as its
// readers see it, /a/<id>/edit is the same app open for editing. A local toggle
// beside that would be a second answer to the same question, and the two would
// disagree the moment someone copied the address bar.
// Phone width goes with it. It is a layout check for whoever is writing the
// document — a way to see where it wraps without leaving the app — so a reader
// arriving at the app's own URL must not inherit a handset frame from whatever the
// author last looked at.
let showEditor = (state, visible) => {
  ...state,
  editorVisible: visible,
  previewWidth: visible ? state.previewWidth : Full,
}

// Choosing an editor implies wanting to see it; silently switching a hidden editor
// would leave the button in a state the user cannot explain.
let useEditing = (state, editing) => {...state, editing, editorVisible: true}

let togglePreviewWidth = state => {
  ...state,
  previewWidth: switch state.previewWidth {
  | Full => Phone
  | Phone => Full
  },
}

let previewIsPhone = state => state.previewWidth == Phone

let toggleFrontmatter = state => {...state, frontmatterVisible: !state.frontmatterVisible}

let toggleDirectives = state => {...state, directivesVisible: !state.directivesVisible}

// The data panel belongs to the preview, not to an editor: it describes the running
// app, so it stays available with the editor hidden.
let toggleData = state => {...state, dataVisible: !state.dataVisible}

// BlockNote round-trips through *lossy* markdown, so the two editors cannot both own
// the document. Only one is mounted at a time, and this says which.
let showsMarkdownEditor = state => state.editorVisible && state.editing == Markdown

let showsBlockEditor = state => state.editorVisible && state.editing == Blocks

// Only the block editor has a frontmatter form: in markdown mode the block is right
// there in the text, so a second way to edit it would be two sources of truth.
let showsFrontmatterForm = state => showsBlockEditor(state) && state.frontmatterVisible

// Same reasoning as the frontmatter form: directives cannot be typed into BlockNote,
// so the structural editor exists only where the block editor does.
let showsDirectiveFields = state => showsBlockEditor(state) && state.directivesVisible

// With no editor on screen the preview takes the full width.
let previewIsFullWidth = state => !state.editorVisible
