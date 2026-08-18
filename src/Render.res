// Rendering pipeline: marked -> DOMPurify (inside the Trusted Types policy) -> DOM,
// then a pass over the links that DOMPurify does not do for us.

// True as soon as the document contains any Spectrum element, which is the only
// moment the component bundle is worth loading. The selector is built from the
// registry rather than written out: a hand-kept list had drifted to 37 of the 91
// tags, and a document whose only component was one of the other 54 never loaded the
// bundle — the element stayed inert with no error anywhere.
let spectrumSelector =
  DirectiveRegistry.all
  ->Array.map(component => component.SpectrumRegistry.tag)
  ->Array.filter(tag => tag->String.startsWith("sp-") || tag->String.includes("-"))
  ->Array.join(",")

let usesSpectrumComponents: (Dom.element, string) => bool = %raw(`
function (container, selector) { return container.querySelector(selector) !== null; }
`)

// A question waiting for an answer: what is being deleted, and the resolver of the
// promise the binder is holding on to. Keeping the resolver here rather than a flag
// is what lets the binder stay a plain `then` chain — it asks, it waits, it acts.
type pending = {
  row: string,
  answer: bool => unit,
}

@react.component
let make = (~source: string, ~theme: Theme.t, ~locale: Locale.t, ~app: option<string>) => {
  let container = React.useRef(Nullable.null)
  let (pending, setPending) = React.useState((): option<pending> => None)

  // Deleting a row is confirmed in the app's own modal, for the same reason deleting
  // an app is: it takes data with it and there is nothing to undo it with. The
  // dialog is React's and lives outside the preview container, which the renderer
  // overwrites on every keystroke.
  let confirmDelete = React.useCallback0(row =>
    Promise.make((resolve, _) => setPending(_ => Some({row, answer: agreed => resolve(agreed)})))
  )

  let settle = agreed => () => {
    switch pending {
    | Some(question) => question.answer(agreed)
    | None => ()
    }
    setPending(_ => None)
  }

  React.useEffect4(() => {
    switch container.current->Nullable.toOption {
    | Some(element) =>
      let html = source->MarkdownRenderer.toHtml->Sanitizer.toTrustedHtml
      Sanitizer.setInnerHtml(element, html)

      // Defence in depth, shared with the message panels: DOMPurify has already
      // dropped `javascript:`, and this holds what is left to the same allowlist as
      // the rest of the app.
      SafeMarkup.harden(element, ~removed=Translations.translate(locale, LinkRemoved))

      // Directive views subscribe here: the preview replaces its innerHTML on every
      // render, so the bindings are re-established each time.
      if usesSpectrumComponents(element, spectrumSelector) {
        SpectrumElements.ensureLoaded()
      }
      SafeMarkup.wrapWideTables(element, Translations.translate(locale, ScrollableTable))
      // Before the store and the collections: those bind what is *in* the document,
      // and the page menu decides which part of the document is on screen.
      Columns.bind(element)
      PageNav.bind(element, ~labels={pages: Translations.translate(locale, Pages)})
      ReactiveStore.bind(element)
      // After the store, because a directive can be both: a list is bound here and a
      // slider in the same document is bound above, and neither knows about the other.
      switch app {
      | Some(id) =>
        CollectionBinder.bind(
          element,
          ~app=id,
          ~labels={
            deleteRow: Translations.translate(locale, DeleteRow),
            editRow: Translations.translate(locale, EditRow),
            searchRows: Translations.translate(locale, SearchRows),
            previousPage: Translations.translate(locale, PreviousPage),
            nextPage: Translations.translate(locale, NextPage),
            sortedAscending: Translations.translate(locale, SortedAscending),
            sortedDescending: Translations.translate(locale, SortedDescending),
            allValues: Translations.translate(locale, AllValues),
            previousMonth: Translations.translate(locale, PreviousMonth),
            nextMonth: Translations.translate(locale, NextMonth),
            previousWeek: Translations.translate(locale, PreviousWeek),
            nextWeek: Translations.translate(locale, NextWeek),
            today: Translations.translate(locale, TodayAction),
            blockedCell: Translations.translate(locale, CellBlocked),
            pinnedRow: Translations.translate(locale, PinnedRow),
          },
          ~locale=Locale.toTag(locale),
          ~confirm=confirmDelete,
        )
      | None => ()
      }
      // With the collections bound: what od-* fetches lands in a collection, and
      // the views above are what draw it.
      switch app {
      | Some(id) =>
        OpenDataBinder.bind(
          element,
          ~app=id,
          ~labels={
            loading: Translations.translate(locale, OdLoading),
            rows: Translations.translate(locale, OdRows),
            stale: Translations.translate(locale, OdStale),
            unreachable: Translations.translate(locale, OdUnreachable),
            refused: Translations.translate(locale, OdRefused),
            search: Translations.translate(locale, OdSearchAction),
          },
        )
      | None => ()
      }
      // Charts and maps follow the same rows the views above draw; each engine
      // is a lazy chunk its binder loads only when the document uses it.
      switch app {
      | Some(id) => {
          ChartBinder.bind(element, ~app=id)
          MapBinder.bind(element, ~app=id)
          ExploreBinder.bind(element, ~app=id)
        }
      | None => ()
      }
      GeoBinder.bind(element)
      PrintBinder.bind(
        element,
        // Empty outside an app: printing one section needs no collections at all, and
        // a document with nowhere to read rows from simply cannot repeat.
        ~app=app->Option.getOr(""),
        ~labels={
          print: Translations.translate(locale, PrintAction),
          printEach: Translations.translate(locale, PrintEach),
        },
      )
      switch app {
      | Some(id) =>
        FileFieldBinder.bind(
          element,
          ~app=id,
          ~labels={tooBig: Translations.translate(locale, FileTooBig)},
        )
      | None => ()
      }
      // After the views: the chip repaints from whatever selection this device
      // holds, and the views above have already been narrowed by it.
      Dashboard.bind(
        element,
        ~labels={removeFilter: Translations.translate(locale, RemoveFilter)},
      )
      // The REST connector and the geocoder, beside the od-* binder they imitate.
      switch app {
      | Some(id) =>
        GeocodeBinder.bind(
          element,
          ~app=id,
          ~labels={
            loading: Translations.translate(locale, OdLoading),
            rows: Translations.translate(locale, OdRows),
            stale: Translations.translate(locale, OdStale),
            unreachable: Translations.translate(locale, OdUnreachable),
            refused: Translations.translate(locale, OdRefused),
            search: Translations.translate(locale, OdSearchAction),
          },
        )
        ApiBinder.bind(
          element,
          ~app=id,
          ~labels={
            loading: Translations.translate(locale, OdLoading),
            rows: Translations.translate(locale, OdRows),
            stale: Translations.translate(locale, OdStale),
            unreachable: Translations.translate(locale, OdUnreachable),
            refused: Translations.translate(locale, OdRefused),
            refresh: Translations.translate(locale, ApiRefresh),
          },
        )
      | None => ()
      }
      // Local SQL and the ML directives, with the Python binder's discipline
      // and their own first-run gates.
      switch app {
      | Some(id) =>
        MlBinder.bind(
          element,
          ~app=id,
          ~labels={
            run: Translations.translate(locale, RunAction),
            loading: Translations.translate(locale, OdLoading),
            rows: Translations.translate(locale, OdRows),
            refused: Translations.translate(locale, OdRefused),
            engine: Translations.translate(locale, MlEngineNeeded),
          },
        )
        SqlBinder.bind(
          element,
          ~app=id,
          ~labels={
            run: Translations.translate(locale, RunAction),
            loading: Translations.translate(locale, OdLoading),
            rows: Translations.translate(locale, OdRows),
            refused: Translations.translate(locale, OdRefused),
          },
        )
      | None => ()
      }
      // The ai-* directives, after the views and before Python: they read the same
      // collections the views just drew, and the two that write (classify, rule)
      // announce `rn:data` so those views redraw themselves.
      switch app {
      | Some(id) =>
        AiBinder.bind(
          element,
          ~app=id,
          ~labels={
            notConfigured: Translations.translate(locale, AiNotConfigured),
            thinking: Translations.translate(locale, AiThinking),
            ask: Translations.translate(locale, AiAsk),
            send: Translations.translate(locale, AiSend),
            run: Translations.translate(locale, RunAction),
            refresh: Translations.translate(locale, ApiRefresh),
            rows: Translations.translate(locale, OdRows),
            refused: Translations.translate(locale, OdRefused),
            confirm: Translations.translate(locale, AiConfirm),
            noAnswer: Translations.translate(locale, AiNoAnswer),
            indexing: Translations.translate(locale, AiIndexing),
          },
        )
      | None => ()
      }
      // After the collections: a Python block reads them, and reading them here would
      // be a second path to the same rows.
      switch app {
      | Some(id) =>
        PythonBinder.bind(
          element,
          ~app=id,
          ~labels={
            showCode: Translations.translate(locale, ShowCode),
            hideCode: Translations.translate(locale, HideCode),
            running: Translations.translate(locale, PythonRunning),
            loading: Translations.translate(locale, PythonLoading),
            run: Translations.translate(locale, RunAction),
            stop: Translations.translate(locale, StopAction),
            progress: Translations.translate(locale, InProgress),
          },
        )
      | None => ()
      }
      // Last of the binders, and it has to be: its steps ARE the engines above, and
      // what it drives are the runs each of them registered while binding. Bound any
      // earlier it would find a workflow full of blocks that had not yet said who they
      // are — which is the same ordering ::python already depends on, one layer up.
      switch app {
      | Some(id) =>
        WorkflowBinder.bind(
          element,
          ~app=id,
          ~locale=Locale.toTag(locale),
          ~labels={
            run: Translations.translate(locale, WorkflowRunNow),
            stop: Translations.translate(locale, StopAction),
            steps: Translations.translate(locale, WorkflowSteps),
            waiting: Translations.translate(locale, WorkflowWaiting),
            running: Translations.translate(locale, InProgress),
            skipped: Translations.translate(locale, WorkflowSkipped),
            failed: Translations.translate(locale, WorkflowFailed),
            last: Translations.translate(locale, WorkflowLastRun),
            next: Translations.translate(locale, WorkflowNextRun),
            never: Translations.translate(locale, WorkflowNever),
            cycle: Translations.translate(locale, WorkflowCycle),
            looped: Translations.translate(locale, WorkflowLooped),
            empty: Translations.translate(locale, WorkflowNoSteps),
            whileOpen: Translations.translate(locale, WorkflowWhileOpen),
          },
        )
      | None => ()
      }
      Mermaid.run(element, ~theme)
    | None => ()
    }
    None
  // A flat tuple, never a nested one: `(theme, locale)` inside another tuple would
  // allocate on every render, so React would never see the deps as unchanged and the
  // whole pipeline — marked, DOMPurify, Mermaid layout — would rerun each time.
  //
  // `app` is a dependency because the binders close over it. Editing only the appId
  // line changes `app` without changing `source`, and skipping the effect then left
  // the save button writing into the namespace `rename` had just moved away from.
  }, (source, theme, locale, app->Option.getOr("")))

  // The dialog is a sibling of the container, never a child: the container's
  // innerHTML is replaced on every render of the document, which would take the
  // open dialog with it.
  <>
    <div
      ref={ReactDOM.Ref.domRef(container)} className="rn-markdown px-6 py-4"
    />
    <ConfirmDialog
      open_={pending->Option.isSome}
      title={Translations.translate(locale, DeleteRowQuestion)}
      message={switch pending {
      | Some({row}) if row != "" =>
        row ++ " — " ++ Translations.translate(locale, DeleteRowWarning)
      | _ => Translations.translate(locale, DeleteRowWarning)
      }}
      confirmLabel={Translations.translate(locale, DeleteRow)}
      cancelLabel={Translations.translate(locale, CancelAction)}
      onConfirm={settle(true)}
      onCancel={settle(false)}
    />
  </>
}
