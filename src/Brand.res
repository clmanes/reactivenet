// The mark, inline rather than `<img src="/logo.svg">`.
//
// An <img> is an opaque document: nothing outside it can reach its colours, so the
// mark stayed teal whatever palette was chosen and was the one thing on screen that
// did not follow. Inline, the strokes take `--color-brand` and re-colour with
// everything else.
//
// `logo.svg` at the repository root stays the source of truth for the *rasterised*
// icons — the PWA and apple-touch images, which cannot be re-coloured at runtime and
// have no reason to be. This is the same drawing with its two teals replaced by the
// brand: the back ellipse at reduced opacity, so the two-tone reads at any hue
// instead of needing a second colour that would have to be derived and checked.
//
// The badge keeps a fixed light-grey ground. It is what the rounded corners are cut
// from in the maskable icon, and a mark whose ground moved with the palette would
// stop being one mark. Grey rather than the brand: the ground is what the strokes are
// read *against*, so it has to stay put while they move.

@react.component
let make = (~className="h-7 w-7") =>
  <svg viewBox="0 0 512 512" className ariaHidden={true} focusable="false">
    <rect width="512" height="512" rx="112" fill="#dcdce2" />
    <g fill="none" strokeWidth="20" stroke="var(--color-brand)">
      <ellipse
        cx="256" cy="256" rx="186" ry="72" transform="rotate(-45 256 256)" opacity="0.62"
      />
      <ellipse cx="256" cy="256" rx="186" ry="72" transform="rotate(45 256 256)" />
    </g>
    <circle cx="256" cy="256" r="60" fill="var(--color-brand)" />
  </svg>
