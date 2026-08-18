// One message, drawn.
//
// The two panels that show messages — the assistant's answers, and what people say to
// each other inside an app — go through here, so a message means the same thing in
// both and the sanitising happens in exactly one place.
//
// It is `innerHTML` and therefore an effect rather than JSX: `Sanitizer.setInnerHtml`
// accepts nothing but a `trustedHtml`, which is the type system saying that the only
// way markup reaches this app's DOM is through DOMPurify. React's own
// `dangerouslySetInnerHTML` would take a plain string and no policy at all.
//
// Nothing binds this DOM afterwards. That is not an omission: the preview's binders
// are what turn markup into a running app, and a message is not one — see
// `MessageMarkdown` for why the directives are not even parsed.

@react.component
let make = (~text: string, ~locale: Locale.t, ~className: string="") => {
  let container = React.useRef(Nullable.null)

  React.useEffect2(() => {
    switch container.current->Nullable.toOption {
    | Some(element) =>
      Sanitizer.setInnerHtml(element, text->MessageMarkdown.toHtml->Sanitizer.toTrustedHtml)
      // Somebody else's text carries somebody else's links, which is the case this
      // was written for rather than an afterthought. And a model answers with
      // comparison tables, which in a panel this narrow have to scroll inside
      // themselves rather than push the page sideways.
      SafeMarkup.harden(element, ~removed=Translations.translate(locale, LinkRemoved))
      SafeMarkup.wrapWideTables(element, Translations.translate(locale, ScrollableTable))
    | None => ()
    }
    None
  }, (text, Locale.toTag(locale)))

  <div
    ref={ReactDOM.Ref.domRef(container)}
    className={"rn-md" ++ (className == "" ? "" : " " ++ className)}
  />
}
