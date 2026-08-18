// The home page: every app this browser has stored, each addressable by its own URL.
//
// No floating action button. Spectrum Two has no FAB, and one here would overlay the
// grid — a control pinned above the content is the case §2.4.11 is about, and a card
// under it cannot be reached without scrolling it out of the way. The heading is
// sticky instead: creating an app stays one click away at any scroll position,
// without anything covering what it is next to.
//
// The cards are links, not click handlers on a div: an app has a URL, so the way to
// open it should be the thing browsers already know how to open — middle-click, copy,
// open in a new tab, and a keyboard focus order that costs nothing to maintain.

@react.component
let make = (
  ~apps: array<AppDocument.summary>,
  ~locale,
  ~onCreate,
  ~onDelete,
  ~onDuplicate,
  ~onUpdate,
  ~onCopyLink,
  ~copiedId: option<string>,
  ~canEdit: bool,
  // What an import had to say for itself, if anything.
  ~notice: option<string>,
  ~onAsk: string => unit,
) => {
  let t = key => Translations.translate(locale, key)
  let (query, setQuery) = React.useState(() => "")
  // The first line of the conversation, said here rather than in the panel. The
  // panel is a good place to *have* a conversation and a poor place to be offered
  // one: it is behind a button in the bar, and nothing about that button says that
  // describing an app in a sentence is a way to make one. So the invitation is on
  // the page, in the place where apps are made, and pressing send opens the panel
  // with the question already asked.
  let (opening, setOpening) = React.useState(() => "")
  let visible = AppSearch.filter(apps, query)

  // The create tile sits at the top of the grid, which is enough while the grid fits
  // on screen. Once it does not, the tile is scrolled away and the only way to make
  // an app is to scroll back — so past this many cards a floating button appears as
  // well. The grid reserves room underneath it (see `.rn-gallery` padding), because a
  // control that covers a card's own buttons is the case §2.4.11 is about.
  let floatingThreshold = 6
  let floating = visible->Array.length >= floatingThreshold
  // A modal rather than a second click: deleting an app takes its stored data with
  // it and cannot be undone, which is worth a sentence saying so — a two-step button
  // can only repeat its own label. The dialog holds the whole summary so the question
  // can name the app being deleted.
  let (pendingDelete, setPendingDelete) = React.useState(() => None)
  // Same reasoning for taking an update: the document is replaced by another and the
  // one it replaces cannot be recovered. A button that did it on one click would be
  // asking somebody to lose their own changes without a sentence saying so.
  let (pendingUpdate, setPendingUpdate) = React.useState(() => None)

  // Il catalogo pubblicato: quello che c'è sul sito e non è ancora qui. Si legge
  // una volta sola, all'apertura, e se non risponde la sezione semplicemente non
  // c'è — la galleria delle proprie app non deve dipendere dalla rete.
  let (catalogue, setCatalogue) = React.useState(() => [])
  React.useEffect0(() => {
    CatalogServer.fetchIndex()
    ->Promise.thenResolve(entries => setCatalogue(_ => entries))
    ->ignore
    None
  })
  let here = apps->Array.map(app => app.id)
  let offered = catalogue->Array.filter(entry => !(here->Array.includes(entry["id"])))

  // E l'altra metà della stessa domanda: delle app che ci sono già, quali il
  // catalogo pubblica in una versione più nuova. Prima l'unico modo di prendere
  // una versione uscita dopo era cancellare l'app e riprenderla — cioè
  // l'operazione che nessuno fa, perché cancellare un'app cancella i suoi dati.
  let updates = CatalogUpdate.offers(
    ~installed=apps,
    ~published=catalogue->Array.map((entry): CatalogUpdate.entry => {
      id: entry["id"],
      title: entry["title"],
      version: entry["version"],
    }),
  )

  let card = (app: AppDocument.summary) => {
    let update = CatalogUpdate.offerFor(~id=app.id, ~offers=updates)
    <li key={app.id} className="rn-app-card">
      <a
        className="rn-app-card-open"
        href={Route.toPath(View(app.id))}
        onClick={Router.follow(View(app.id))}>
        <h3 className="rn-app-card-title">
          // The app's own mark, from its frontmatter. A grid of cards is a list of
          // names until the names have marks beside them.
          <AppIcon name={app.icon} />
          {React.string(app.title == "" ? t(Untitled) : app.title)}
        </h3>
        {app.description == ""
          ? React.null
          : <p className="rn-app-card-description"> {React.string(app.description)} </p>}
        <p className="rn-app-card-meta">
          <code> {React.string(app.id)} </code>
          {app.version == ""
            ? React.null
            : <span className="rn-app-card-version"> {React.string("v" ++ app.version)} </span>}
          // Quale versione c'è di là, scritta accanto a quella che c'è qui: le
          // due insieme sono la ragione del pulsante, e il pulsante da solo
          // chiederebbe di fidarsi.
          {switch update {
          | Some(offer) =>
            <span className="rn-app-card-update">
              {React.string(t(UpdateAvailable) ++ " · v" ++ offer.published)}
            </span>
          | None => React.null
          }}
          // Shown the way the reader writes a date, not the way the document stores
          // one. The frontmatter keeps its ISO day — that is what sorts the gallery.
          {app.date == ""
            ? React.null
            : <span> {React.string(Clock.localize(app.date, ~locale=Locale.toTag(locale)))} </span>}
          {app.author == "" ? React.null : <span> {React.string(app.author)} </span>}
        </p>
      </a>
      <div className="rn-app-card-actions">
        // Solo quando c'è davvero qualcosa da prendere. Un pulsante «aggiorna»
        // sempre presente e quasi sempre inutile insegna a non guardarlo, ed è
        // esattamente il giorno in cui serve che non verrebbe visto.
        {switch update {
        | Some(offer) =>
          <Spectrum.ActionButton
            label={t(UpdateApp) ++ " · v" ++ offer.installed ++ " → v" ++ offer.published}
            onClick={_ => setPendingUpdate(_ => Some(offer))}
            quiet=true>
            Icons.sync
          </Spectrum.ActionButton>
        | None => React.null
        }}
        {canEdit
          ? <Spectrum.ActionButton
              label={t(EditApp)} onClick={_ => Router.navigate(Edit(app.id))} quiet=true>
              Icons.pencil
            </Spectrum.ActionButton>
          : React.null}
        <Spectrum.ActionButton
          label={copiedId == Some(app.id) ? t(LinkCopied) : t(CopyLink)}
          selected={copiedId == Some(app.id)}
          onClick={_ => onCopyLink(app.id)}
          quiet=true>
          Icons.link
        </Spectrum.ActionButton>
        // Next to the link and the bin, because all three are things you do *to* this
        // app rather than with it. A copy is the honest way to start from one that
        // works, which is what everybody does with the welcome app.
        <Spectrum.ActionButton
          label={t(DuplicateApp)} onClick={_ => onDuplicate(app.id)} quiet=true>
          Icons.copy
        </Spectrum.ActionButton>
        <Spectrum.ActionButton
          label={t(DeleteApp)} onClick={_ => setPendingDelete(_ => Some(app))} quiet=true>
          Icons.trash
        </Spectrum.ActionButton>
      </div>
    </li>
  }

  <section className={"rn-gallery" ++ (floating ? " rn-gallery-floating" : "")} ariaLabel={t(Gallery)}>
    <header className="rn-gallery-header">
      <h2 className="rn-gallery-heading"> {React.string(t(AppsHeading))} </h2>
      // Filtering is instant and local: there is nothing to submit, so there is no
      // form and no button — the list narrows as the query is typed.
      <label className="rn-gallery-search">
        <span className="sr-only"> {React.string(t(SearchApps))} </span>
        <input
          type_="search"
          className="rn-gallery-search-input"
          placeholder={t(SearchApps)}
          value={query}
          onChange={event => setQuery(_ => ReactEvent.Form.target(event)["value"])}
        />
      </label>
    </header>
    {{
      let start = () => {
        let question = opening->String.trim
        if question != "" {
          setOpening(_ => "")
          onAsk(question)
        }
      }
      <form
        className="rn-gallery-ask"
        onSubmit={event => {
          // A real form, so Enter submits and the button is a submit button: this is
          // one field and one action, which is the shape a form is for. The search
          // above is not a form for the opposite reason — it has nothing to submit.
          ReactEvent.Form.preventDefault(event)
          start()
        }}>
        <span className="rn-gallery-ask-icon" ariaHidden={true}> {Icons.sparkle} </span>
        // A textarea and not a single-line input: what is described here is a whole
        // app, which is several sentences often enough that one line would make it a
        // field to fight with. Enter sends and shift+Enter breaks the line — the same
        // two keys the composer in the panel answers to, because a person who has
        // learnt them once has learnt them here.
        <textarea
          className="rn-gallery-ask-input"
          rows={1}
          placeholder={t(AiPlaceholder)}
          ariaLabel={t(AiPlaceholder)}
          value={opening}
          onChange={event => setOpening(_ => ReactEvent.Form.target(event)["value"])}
          onKeyDown={event =>
            if ReactEvent.Keyboard.key(event) == "Enter" && !ReactEvent.Keyboard.shiftKey(event) {
              ReactEvent.Keyboard.preventDefault(event)
              start()
            }}
        />
        <Spectrum.Button variant="accent" disabled={opening->String.trim == ""} onClick={_ => start()}>
          {React.string(t(ChatSend))}
        </Spectrum.Button>
      </form>
    }}
    // Creating is the first tile rather than a button in the header: it sits in the
    // grid it adds to, it is the same size as what it produces, and on a narrow
    // screen it stays a full-width target instead of competing with the search box
    // for the header's remaining space. It is not filtered away by a search — the
    // query narrows what exists, it does not take away the way to make more.
    <ul className="rn-app-grid">
      <li key="new" className="rn-app-card rn-app-card-new">
        <button type_="button" className="rn-app-new" onClick={_ => onCreate()}>
          <span className="rn-app-new-icon" ariaHidden={true}> {Icons.add} </span>
          <span className="rn-app-new-label"> {React.string(t(NewApp))} </span>
        </button>
      </li>
      {visible->Array.map(card)->React.array}
    </ul>
    // Il catalogo del sito. Le app già presenti non compaiono: offrire di nuovo
    // quello che si ha significherebbe proporre una copia, che è quello che
    // succederebbe davvero aprendo l'indirizzo una seconda volta.
    {offered->Array.length == 0
      ? React.null
      : <section className="rn-catalogue" ariaLabel={t(CatalogueHeading)}>
          <h3 className="rn-catalogue-heading"> {React.string(t(CatalogueHeading))} </h3>
          <p className="rn-catalogue-lead"> {React.string(t(CatalogueLead))} </p>
          <ul className="rn-catalogue-grid">
            {offered
            ->Array.map(entry =>
              <li key={entry["id"]} className="rn-catalogue-card">
                // Un indirizzo vero, non un bottone: si copia, si apre in una
                // scheda nuova, e porta con sé quello che fa — /c/<id>.
                <a className="rn-catalogue-open" href={Route.toPath(Catalog(entry["id"]))}>
                  <span className="rn-catalogue-title"> {React.string(entry["title"])} </span>
                  <span className="rn-catalogue-desc"> {React.string(entry["description"])} </span>
                  <span className="rn-catalogue-action">
                    {React.string(t(CatalogueAdd))}
                    <span ariaHidden={true}> {React.string(" →")} </span>
                  </span>
                </a>
              </li>
            )
            ->React.array}
          </ul>
        </section>}
    {switch notice {
    | Some(message) => <p className="rn-gallery-note"> {React.string(message)} </p>
    | None => React.null
    }}
    {visible->Array.length == 0 && apps->Array.length > 0
      ? <p className="rn-gallery-note"> {React.string(t(NoMatches))} </p>
      : React.null}
    {apps->Array.length == 0
      ? <p className="rn-gallery-note"> {React.string(t(NoApps))} </p>
      : React.null}
    <ConfirmDialog
      open_={pendingDelete->Option.isSome}
      title={t(DeleteAppQuestion)}
      message={switch pendingDelete {
      | Some(app) => app.title ++ " — " ++ t(DeleteAppWarning)
      | None => t(DeleteAppWarning)
      }}
      confirmLabel={t(DeleteApp)}
      cancelLabel={t(CancelAction)}
      onConfirm={() => {
        switch pendingDelete {
        | Some(app) => onDelete(app.id)
        | None => ()
        }
        setPendingDelete(_ => None)
      }}
      onCancel={() => setPendingDelete(_ => None)}
    />
    // La domanda dice le due versioni e che cosa succede ai dati. Quella seconda
    // frase è la sola che conta davvero: le righe non stanno nel documento, e
    // chi ha sei mesi di dati dentro un'app deve poterlo leggere prima di
    // premere, non scoprirlo dopo.
    <ConfirmDialog
      open_={pendingUpdate->Option.isSome}
      title={t(UpdateQuestion)}
      message={switch pendingUpdate {
      | Some(offer) =>
        offer.publishedTitle ++
        " — v" ++
        offer.installed ++
        " → v" ++
        offer.published ++
        ". " ++
        t(UpdateWarning)
      | None => t(UpdateWarning)
      }}
      confirmLabel={t(UpdateApp)}
      cancelLabel={t(CancelAction)}
      onConfirm={() => {
        switch pendingUpdate {
        | Some(offer) => onUpdate(offer.id)
        | None => ()
        }
        setPendingUpdate(_ => None)
      }}
      onCancel={() => setPendingUpdate(_ => None)}
    />
    {floating
      ? <button
          type_="button"
          className="rn-fab"
          ariaLabel={t(NewApp)}
          title={t(NewApp)}
          onClick={_ => onCreate()}>
          <span ariaHidden={true}> {Icons.add} </span>
        </button>
      : React.null}
  </section>
}
