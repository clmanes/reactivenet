# Accessibility

The target is **WCAG 2.2 level AA**.

**In scope:** the app's own chrome — the gallery, the navbar, the toolbars, the
dialogs — and the rendered document, which is to say the *app* a directive document
produces. That second half is the one that matters most: whatever someone builds
here has to be usable, and they should not have to know any of this to get it.

**Out of scope:** the two editors. CodeMirror and BlockNote are third-party editing
surfaces whose conformance is not ours to guarantee.

## Contrast is enforced by tests, not by eye

`core/Contrast.res` implements the WCAG relative-luminance and ratio formulas, and
`Palette_test.res` asserts every palette against its surface. A colour below 4.5:1
fails the build.

This was not a formality: the original six palettes were picked by eye and **all six
failed** on light backgrounds, between 2.06:1 and 3.11:1.

Two things only surfaced by measuring:

- **A palette needs two shades, not one.** No single colour clears AA on both
  polarities: 4.5:1 against white caps relative luminance at 0.178, while 3:1 against
  the lightest dark grey demands at least 0.182. `Palette.brandColour` therefore takes
  a `~dark`, and the CSS selects with `[color="dark"].rn-palette-*`.
- **The worst-case surface is not white.** Brand text sits on `gray-50`, `gray-100`
  *and* `gray-200`, and contrast is lowest against whichever is nearest the text's own
  luminance. Calibrating against white overstated every ratio by about a point and
  left one class failing at 3.6:1.

**Spectrum's own accent tokens are deliberately not overridden.** Changing a
component's background without the label colour Spectrum pairs with it is how
contrast regressions get introduced. A badge, a progress bar and a button therefore
keep Spectrum's colours whatever palette is chosen; the palette recolours the app's
own surfaces around them.

## Reflow (§1.4.10)

Verified by constraining the document to 320 px and measuring
`document.body.scrollWidth`, because Chrome will not size a window below about
628 px.

A table is exempt from reflowing but not from staying inside the page, so each one is
**wrapped** in a scrollable, keyboard-reachable region — wrapped rather than given
`display: block`, which would make it scroll while dropping the row and column
relationships a screen reader announces. That region carries an `aria-label`: an
unnamed `role="region"` is worse than no role, since it announces a landmark it
cannot describe.

## Dialogs

`ConfirmDialog` is the native `<dialog>` with `showModal()`, which supplies the focus
trap, Esc, the inert background and — the part hand-written modals always miss —
returning focus to whatever opened it.

Two things it needs that are easy to get wrong: it is **always mounted** and driven by
a prop, because mounting and calling `showModal()` in the same commit races the node's
arrival in the document; and `margin: auto` has to be **restored**, because a modal
`<dialog>` centres itself through auto margins, which a CSS reset zeroes along with
every other margin.

## Names, targets, focus

- **Labels name the control, not the format (§2.4.6).** The editor buttons read
  "Markdown editor" and "Block editor", not "Markdown" and "Blocks", and both panes
  are named regions. A test asserts that every language says more than the bare format
  name.
- **An icon that changes names the destination**, never the current state: the eye
  means "view this", the moon means "go dark". A bar where some toggles name the state
  and others the destination is a bar where none of them can be read with confidence.
- **Every icon-only control has an accessible name (§4.1.2)**, and a `::slider`
  written without a `legend` falls back to naming itself after the key it writes to
  rather than shipping unlabelled.
- **A visible focus ring at zero specificity (§2.4.7)**, so Spectrum's own conformant
  rings keep priority.
- **`scroll-margin-block` (§2.4.11)**, so a focused control in a scrolling pane does
  not come to rest under the toolbar. The gallery's floating button reserves room
  beneath it for the same reason — no card comes to rest underneath it.
- **A 24×24 CSS px floor (§2.5.8)** on Spectrum's small controls, which sit exactly
  on it.

## Page menus are buttons, not tabs

`::page` renders a `<nav>` of buttons with `aria-current`, deliberately *not* an ARIA
tablist. A tablist is a promise about arrow keys and roving tabindex; a list of
buttons that swaps a region is what this actually is, and claiming otherwise is worse
than claiming nothing.

## Language

The document's `lang` is applied to the page while it is open, so a screen reader
pronounces an app in the language it was written in — and it is deliberately not
persisted, because the language belongs to the document rather than to the reader.
