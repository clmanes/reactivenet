// BlockNote, its ProseMirror core and Mantine styling come to roughly a megabyte —
// more than the rest of the app put together, and dead weight for anyone who never
// leaves the markdown editor. It is therefore reached through a dynamic import, which
// also keeps the main chunk under Workbox's precache limit.

%%raw(`
import { lazy, createElement as reactCreateElement, Suspense } from "react";

// ReScript modules have no default export, so the dynamic import is adapted into the
// shape React.lazy expects.
const LazyBlockNote = lazy(() =>
  import("./BlockNoteImpl.res.mjs").then((module) => ({ default: module.component }))
);
`)

type props = BlockNoteImpl.props

let render: (props, string) => React.element = %raw(`
function (props, loadingLabel) {
  return reactCreateElement(
    Suspense,
    {
      fallback: reactCreateElement(
        "div",
        { className: "rn-muted flex h-full items-center justify-center text-sm" },
        loadingLabel
      ),
    },
    reactCreateElement(LazyBlockNote, props)
  );
}
`)

let element = (~initialMarkdown, ~onChange, ~dark, ~locale) =>
  render(
    {initialMarkdown, onChange, dark, localeTag: Locale.toTag(locale)},
    Translations.translate(locale, LoadingBlockEditor),
  )
