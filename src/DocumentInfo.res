// The frontmatter, shown as authored: keys are not translated or renamed, because
// they are the document's own vocabulary rather than this app's UI.
@react.component
let make = (~meta: option<Frontmatter.t>, ~locale: Locale.t) =>
  <aside className="rn-info rn-divider border-b px-6 py-3 text-sm">
    <h2 className="mb-2 text-xs font-semibold tracking-wide uppercase">
      {React.string(Translations.translate(locale, DocumentInfo))}
    </h2>
    {switch meta {
    | Some(meta) if meta.fields->Array.length > 0 =>
      <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1">
        {meta.fields
        ->Array.mapWithIndex((field, index) =>
          <React.Fragment key={field.Frontmatter.key ++ "-" ++ Int.toString(index)}>
            <dt className="rn-muted font-mono text-xs"> {React.string(field.key)} </dt>
            <dd> {React.string(field.value)} </dd>
          </React.Fragment>
        )
        ->React.array}
      </dl>
    | _ =>
      <p className="rn-muted">
        {React.string(Translations.translate(locale, NoDocumentInfo))}
      </p>
    }}
  </aside>
