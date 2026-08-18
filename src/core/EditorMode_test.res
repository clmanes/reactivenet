open BunTest

// Local, not from the module under test: user-facing names live in Translations now,
// and a test should not force the state machine to carry a display concern.
let describeState = (state: EditorMode.t) => {
  let editing = switch state.editing {
  | Markdown => "Markdown"
  | Blocks => "Blocks"
  }
  editing ++ (state.editorVisible ? "/visible" : "/hidden")
}

describe("EditorMode", () => {
  test("starts on the markdown editor, visible", () => {
    expect(EditorMode.initial->describeState)->toBe("Markdown/visible")
  })

  test("toggling hides and shows the editor", () => {
    let hidden = EditorMode.showEditor(EditorMode.initial, false)
    expect(hidden->describeState)->toBe("Markdown/hidden")
    expect(EditorMode.showEditor(hidden, true)->describeState)->toBe("Markdown/visible")
  })

  test("toggling twice returns to the starting state", () => {
    let round = EditorMode.showEditor(EditorMode.showEditor(EditorMode.initial, false), true)
    expect(round->describeState)->toBe(EditorMode.initial->describeState)
  })

  test("choosing an editor reveals it even when hidden", () => {
    let hidden = EditorMode.showEditor(EditorMode.initial, false)
    expect(EditorMode.useEditing(hidden, Blocks)->describeState)->toBe("Blocks/visible")
  })

  // The invariant that keeps the two editors from both owning the document.
  test("never mounts both editors at once", () => {
    let states = [
      EditorMode.initial,
      EditorMode.useEditing(EditorMode.initial, Blocks),
      EditorMode.showEditor(EditorMode.initial, false),
      EditorMode.showEditor(EditorMode.useEditing(EditorMode.initial, Blocks), false),
    ]
    let both =
      states->Array.filter(s => EditorMode.showsMarkdownEditor(s) && EditorMode.showsBlockEditor(s))
    expect(both->Array.length)->toBe(0)
  })

  test("phone width toggles independently of which editor is showing", () => {
    let phone = EditorMode.initial->EditorMode.togglePreviewWidth
    expect(phone->EditorMode.previewIsPhone)->toBe(true)
    expect(EditorMode.useEditing(phone, Blocks)->EditorMode.previewIsPhone)->toBe(true)
    // Phone width belongs to the author's check, so leaving the editor drops it.
    expect(EditorMode.showEditor(phone, false)->EditorMode.previewIsPhone)->toBe(false)
    expect(EditorMode.showEditor(phone, true)->EditorMode.previewIsPhone)->toBe(true)
  })

  test("phone width toggles back", () => {
    let round = EditorMode.initial->EditorMode.togglePreviewWidth->EditorMode.togglePreviewWidth
    expect(round->EditorMode.previewIsPhone)->toBe(false)
  })

  test("the frontmatter form belongs to the block editor alone", () => {
    expect(EditorMode.initial->EditorMode.showsFrontmatterForm)->toBe(false)
    let blocks = EditorMode.useEditing(EditorMode.initial, Blocks)
    expect(blocks->EditorMode.showsFrontmatterForm)->toBe(true)
  })

  test("the frontmatter form can be hidden and shown again", () => {
    let blocks = EditorMode.useEditing(EditorMode.initial, Blocks)
    let hidden = blocks->EditorMode.toggleFrontmatter
    expect(hidden->EditorMode.showsFrontmatterForm)->toBe(false)
    expect(hidden->EditorMode.toggleFrontmatter->EditorMode.showsFrontmatterForm)->toBe(true)
  })

  test("hiding the whole editor also hides the frontmatter form", () => {
    let blocks = EditorMode.showEditor(EditorMode.useEditing(EditorMode.initial, Blocks), false)
    expect(blocks->EditorMode.showsFrontmatterForm)->toBe(false)
  })

  // The preference survives a trip through the markdown editor.
  test("the frontmatter preference is remembered across editor switches", () => {
    let hidden = EditorMode.useEditing(EditorMode.initial, Blocks)->EditorMode.toggleFrontmatter
    let roundTrip = EditorMode.useEditing(hidden, Markdown)->EditorMode.useEditing(_, Blocks)
    expect(roundTrip->EditorMode.showsFrontmatterForm)->toBe(false)
  })

  test("the directive panel also belongs to the block editor alone", () => {
    let blocks = EditorMode.useEditing(EditorMode.initial, Blocks)
    expect(blocks->EditorMode.showsDirectiveFields)->toBe(false)
    expect(blocks->EditorMode.toggleDirectives->EditorMode.showsDirectiveFields)->toBe(true)
    expect(
      EditorMode.initial->EditorMode.toggleDirectives->EditorMode.showsDirectiveFields,
    )->toBe(false)
  })

  test("hiding the editor hides the directive panel", () => {
    let blocks =
      EditorMode.useEditing(EditorMode.initial, Blocks)
      ->EditorMode.toggleDirectives
      ->EditorMode.showEditor(false)
    expect(blocks->EditorMode.showsDirectiveFields)->toBe(false)
  })

  test("the data panel belongs to the preview and survives hiding the editor", () => {
    let shown = EditorMode.initial->EditorMode.toggleData
    expect(shown.dataVisible)->toBe(true)
    expect(EditorMode.showEditor(shown, false)->(s => s.EditorMode.dataVisible))->toBe(true)
    expect(shown->EditorMode.toggleData->(s => s.EditorMode.dataVisible))->toBe(false)
  })

  test("hiding the editor gives the preview the full width", () => {
    expect(EditorMode.initial->EditorMode.previewIsFullWidth)->toBe(false)
    expect(EditorMode.showEditor(EditorMode.initial, false)->EditorMode.previewIsFullWidth)->toBe(true)
  })

  test("a hidden editor mounts neither editor", () => {
    let hidden = EditorMode.showEditor(EditorMode.initial, false)
    expect(EditorMode.showsMarkdownEditor(hidden) || EditorMode.showsBlockEditor(hidden))->toBe(
      false,
    )
  })
})
