// The shell. It owns state and effects; every decision it makes is delegated to a
// pure module in `core/`, which is what keeps the logic testable without a DOM.

@react.component
let make = () => {
  // Seeded from the OS preference because IndexedDB cannot be read synchronously;
  // the stored choice arrives one effect later and overrides it if present.
  let (theme, setTheme) = React.useState(ThemeStorage.systemPreference)
  let (palette, setPalette) = React.useState(() => Palette.fallback)
  let (locale, setLocale) = React.useState(LocaleStorage.browserPreference)
  let (mode, setMode) = React.useState(() => EditorMode.initial)
  let (infoOpen, setInfoOpen) = React.useState(() => false)
  let (chatOpen, setChatOpen) = React.useState(() => false)
  let (route, setRoute) = React.useState(Router.current)
  let (apps, setApps) = React.useState(() => [])
  let (source, setSource) = React.useState(() => "")
  let (rendered, setRendered) = React.useState(() => "")
  let (copiedId, setCopiedId) = React.useState(() => None)
  // What an import has to say for itself, if anything. One line under the gallery
  // heading rather than a dialog: nothing has gone wrong and there is nothing to
  // decide — the app is already open.
  let (notice, setNotice) = React.useState((): option<string> => None)
  let (canEdit, setCanEdit) = React.useState(Viewport.canEdit)
  // Until the welcome app has been written, "this browser does not have that app" is
  // not yet an answer: a link straight to it on a fresh browser would bounce to the
  // gallery a moment before it existed.
  let (seeded, setSeeded) = React.useState(() => false)
  // The signed-in account, if any. Hydrated from IndexedDB one effect after mount
  // like every persisted preference, then refreshed against the server: only an
  // explicit "no" from the server signs the user out — an unreachable server is
  // offline, and offline must not log anybody out of their own device.
  let (session, setSession) = React.useState((): option<Session.t> => None)
  let (accountOpen, setAccountOpen) = React.useState(() => false)
  let (assistantOpen, setAssistantOpen) = React.useState(() => false)
  // A question asked from the gallery's opening box, on its way to the panel — which
  // may not be mounted yet at the moment it is asked.
  let (assistantQuestion, setAssistantQuestion) = React.useState((): option<string> => None)
  // Bumped when a document is replaced from outside the editor, which the assistant
  // is the only thing that does. Both editors are uncontrolled and read their value
  // once, at mount, so an applied rewrite is invisible in the pane it changed until
  // the pane is built again — and the block editor would then write the old document
  // back over the new one on the next keystroke.
  let (docEpoch, setDocEpoch) = React.useState(() => 0)

  React.useEffect0(() => {
    let hydrate = async () => {
      switch await Session.load() {
      | None => ()
      | Some(stored) => {
          setSession(_ => Some(stored))
          let answer = await AccountServer.refresh(~token=stored.token)
          if answer.denied {
            await Session.clear()
            setSession(_ => None)
          } else {
            switch answer.fresh {
            | Some(traded) => {
                let updated = {...stored, token: traded.token}
                await Session.save(updated)
                setSession(_ => Some(updated))
              }
            | None => ()
            }
          }
        }
      }
    }
    hydrate()->ignore
    None
  })

  let signOut = () => {
    Session.clear()->ignore
    setSession(_ => None)
    setAccountOpen(_ => false)
  }

  // The sync dialog, and the counter that restarts the engine after anything that
  // changes what it should be doing — creating a space, joining one, leaving.
  let (syncOpen, setSyncOpen) = React.useState(() => false)
  let (syncEpoch, setSyncEpoch) = React.useState(() => 0)
  // An invitation waiting for its one click: (inviteId, key). A join writes a
  // membership and downloads a space — not something a page visit does by itself.
  let (joinPending, setJoinPending) = React.useState((): option<(string, string)> => None)
  let handledJoin = React.useRef(None)
  // The route as the engine's callback sees it *now*, not as it was when the
  // engine started: a remote document must not reseed the editor mid-edit.
  let routeRef = React.useRef(route)
  routeRef.current = route

  // Which app the editor currently holds. Kept in a ref rather than state because the
  // route effect reads it to decide whether a hash change means "load another
  // document" or "the URL followed a rename we just made" — and the second must not
  // reload, or the uncontrolled editor would be seeded from storage mid-edit.
  let openedId = React.useRef(None)

  let refreshApps = () =>
    DocumentStore.list()->Promise.thenResolve(found => setApps(_ => found))->ignore

  React.useEffect0(() => Some(Router.subscribe(next => setRoute(_ => next))))
  React.useEffect0(() => Some(Viewport.subscribe(wide => setCanEdit(_ => wide))))

  // A handset cannot edit, so the editing URL is not merely hidden there — it is
  // rewritten. Leaving the address bar saying /edit while showing the reader's view
  // would be the one thing the routing design is meant to prevent, and rotating a
  // tablet has to settle somewhere honest.
  // A document arriving from outside — a file, or a link somebody sent. It never
  // overwrites: an id already here lands as a copy, because a replaced app cannot be
  // recovered and a duplicate can simply be deleted.
  // The share payload already filed, so the effect below is once-per-link however
  // many times it runs.
  let handledShare = React.useRef(None)

  let receive = (~arrive=Router.navigate, text) =>
    DocumentStore.ids()
    ->Promise.then(taken => {
      let id = AppFile.idFor(~source=text, ~taken, ~fallback=Translations.translate(locale, Untitled))
      // The document is written with the id it was actually stored under, so the
      // frontmatter, the storage key and the URL cannot disagree.
      let source = AppDocument.withId(text, id)
      DocumentStore.save(~id, ~source)->Promise.thenResolve(() => {
        setNotice(_ => AppFile.isCopy(~source=text, ~id) ? Some(Translations.translate(locale, ImportedAsCopy)) : None)
        refreshApps()
        arrive(Route.View(id))
      })
    })


  React.useEffect2(() => {
    switch (canEdit, route) {
    | (false, Route.Edit(id)) => Router.navigate(View(id))
    | _ => ()
    }
    None
  }, (canEdit, Route.toPath(route)))

  // The URL is the app. Everything that opens, creates or renames an app goes through
  // the router, so there is one path into a document and the address bar can never
  // disagree with what is on screen.
  React.useEffect2(() => {
    switch (seeded, route) {
    | (false, _) => ()
    | (true, Route.Gallery) =>
      openedId.current = None
      refreshApps()
    // A link somebody sent: the app is in the fragment, not in this browser. It is
    // decoded, filed like any other import — never overwriting — and opened, so the
    // reader lands in the app rather than on a page telling them about it.
    | (true, Route.Shared(short)) =>
      // Once per link, whatever re-runs the effect — StrictMode's double mount, or
      // Back landing on /s again. And the app *replaces* /s in history when it
      // leaves: a consumed share link kept in the history imported another copy on
      // every press of Back.
      let mark = Route.toPath(route) ++ Router.fragment()
      let file = decoded =>
        switch decoded {
        | Some(text) if Frontmatter.parse(text).meta->Option.isSome =>
          receive(~arrive=Router.replace, text)
        | _ =>
          // A truncated link is said, not guessed at: half a document restored as
          // an app would be worse than none at all.
          setNotice(_ => Some(Translations.translate(locale, BrokenShareLink)))
          Router.replace(Gallery)
          Promise.resolve()
        }
      if handledShare.current == Some(mark) {
        ()
      } else {
        handledShare.current = Some(mark)
        switch short {
        // The short form: the blob from the server — the read is also what renews
        // its 120 days — opened with the key from the fragment. An expired or purged
        // id gets its own sentence: "ask for it again" is actionable, "broken" is not.
        | Some(id) =>
          switch ShareLink.keyOf(Router.fragment()) {
          | None =>
            setNotice(_ => Some(Translations.translate(locale, BrokenShareLink)))
            Router.replace(Gallery)
          | Some(key) =>
            ShareServer.fetchPayload(id)
            ->Promise.then(stored =>
              switch stored {
              | None =>
                setNotice(_ => Some(Translations.translate(locale, ShareExpired)))
                Router.replace(Gallery)
                Promise.resolve()
              | Some(sealed) =>
                ShareCrypto.decrypt(~key, ~payload=sealed)->Promise.then(opened =>
                  switch opened {
                  | None => file(None)
                  | Some(payload) => SharePayload.decode(payload)->Promise.then(file)
                  }
                )
              }
            )
            ->ignore
          }
        // The long form: the document itself is the fragment.
        | None =>
          switch ShareLink.payloadOf(Router.fragment()) {
          | None => Router.replace(Gallery)
          | Some(carried) => SharePayload.decode(carried)->Promise.then(file)->ignore
          }
        }
      }
    // An app of the published catalogue: the address names it and the document is
    // fetched, which is what makes this work for an app of any size — a share link
    // stops where an address does. From there it is an import like any other:
    // filed under a free id, never overwriting, and opened.
    //
    // The same once-per-address guard as a share link, and for the same reason:
    // StrictMode mounts twice, and a catalogue address left in the history would
    // import another copy on every press of Back — so the app replaces it on the
    // way out.
    | (true, Route.Catalog(id)) =>
      let mark = Route.toPath(route)
      if handledShare.current == Some(mark) {
        ()
      } else {
        handledShare.current = Some(mark)
        CatalogServer.fetchDocument(id)
        ->Promise.then(answer =>
          switch answer["text"] {
          | Some(text) if Frontmatter.parse(text).meta->Option.isSome =>
            receive(~arrive=Router.replace, text)
          | _ =>
            // Two failures, two sentences: a link to an app the catalogue does not
            // publish is wrong and can be said so, while nothing arriving at all is
            // the connection — and telling somebody to check their connection when
            // the link is simply wrong sends them looking in the wrong place.
            setNotice(_ => Some(
              Translations.translate(locale, answer["missing"] ? CatalogMissing : CatalogUnreachable),
            ))
            Router.replace(Gallery)
            Promise.resolve()
          }
        )
        ->ignore
      }
    // An invitation is handled by its own effect below — it needs the session,
    // which this effect deliberately does not depend on.
    | (true, Route.Join(_)) => ()
    | (true, Route.View(id)) | (true, Route.Edit(id)) =>
      if openedId.current != Some(id) {
        DocumentStore.load(id)
        ->Promise.thenResolve(stored =>
          switch stored {
          | Some(text) =>
            // A different document, a clean slate of reactive keys: `volume` in this
            // app and `volume` in the last one are namesakes, not the same value.
            ReactiveStore.reset()
            openedId.current = Some(id)
            setSource(_ => text)
            setRendered(_ => text)
          // A link to an app this browser does not have: the gallery is a better
          // answer than an empty editor claiming to be it.
          | None => Router.navigate(Gallery)
          }
        )
        ->ignore
      }
    }
    setMode(current => EditorMode.showEditor(current, Route.isEditing(route)))
    None
  // The fragment joins the deps because for /s the path alone is constant: two
  // different share links in a row would otherwise never re-trigger the import.
  }, (
    seeded,
    Route.toPath(route) ++
    switch route {
    | Route.Shared(_) => Router.fragment()
    | _ => ""
    },
  ))

  // An invitation: /j/<id>#k<key>. It waits for three things — the seed, a
  // signed-in account (the dialog opens by itself when there is none), and one
  // explicit yes in a modal — and is marked handled exactly once, however many
  // times the effect re-runs. A join writes a membership and downloads a space;
  // that is not something merely visiting a URL should do.
  React.useEffect3(() => {
    switch route {
    | Route.Join(inviteId) if seeded =>
      switch session {
      | None => setAccountOpen(_ => true)
      | Some(_) => {
          let mark = Route.toPath(route) ++ Router.fragment()
          if handledJoin.current != Some(mark) {
            handledJoin.current = Some(mark)
            switch SpaceLink.keyOf(Router.fragment()) {
            | None => {
                setNotice(_ => Some(Translations.translate(locale, BrokenShareLink)))
                Router.replace(Gallery)
              }
            | Some(key) => setJoinPending(_ => Some((inviteId, key)))
            }
          }
        }
      }
    | _ => ()
    }
    None
  }, (
    seeded,
    Route.toPath(route) ++
    switch route {
    | Route.Join(_) => Router.fragment()
    | _ => ""
    },
    session->Option.isSome,
  ))

  let confirmJoin = () =>
    switch (joinPending, session) {
    | (Some((inviteId, key)), Some(signed)) => {
        setJoinPending(_ => None)
        DocumentStore.ids()
        ->Promise.then(taken =>
          SpaceSync.join(
            ~inviteId,
            ~key,
            ~session=signed,
            ~taken,
            ~fallback=Translations.translate(locale, Untitled),
          )
        )
        ->Promise.thenResolve(result =>
          switch result {
          | Some(app) => {
              refreshApps()
              setSyncEpoch(count => count + 1)
              Router.replace(View(app))
            }
          | None => {
              setNotice(_ => Some(Translations.translate(locale, InviteInvalid)))
              Router.replace(Gallery)
            }
          }
        )
        ->ignore
      }
    | _ => ()
    }

  let cancelJoin = () => {
    setJoinPending(_ => None)
    Router.replace(Gallery)
  }

  // The engine runs for the open app when it is linked to a space and an account
  // is signed in; opening another app, signing out, or leaving a space stops it.
  // SpaceSync answers "is it linked" from IndexedDB before any of the heavy
  // machinery loads, so for the common unlinked app this effect costs one read.
  React.useEffect4(() => {
    switch (Route.appId(route), session) {
    | (Some(app), Some(signed)) if seeded => {
        SpaceSync.start(~app, ~session=signed, ~onDocument=text =>
          // Remote edits reach the editor only while it is closed: reseeding the
          // uncontrolled editor under the author's cursor would be worse than
          // showing the merge one save later.
          if !Route.isEditing(routeRef.current) {
            setSource(_ => text)
            setRendered(_ => text)
          }
        )->ignore
        Some(() => SpaceSync.stop(~app))
      }
    | _ => None
    }
  }, (
    Route.appId(route)->Option.getOr(""),
    session->Option.map(signed => signed.Session.token)->Option.getOr(""),
    seeded,
    syncEpoch,
  ))

  // The welcome app is always available: it is a real stored app like any other —
  // its own URL, editable, backed up with the rest — but it is written back whenever
  // it is missing, so the gallery is never empty and there is always a working
  // example of every kind of directive to read.
  //
  // It is also written back when it is *stale and untouched*. Seeding only when
  // missing meant a browser that opened this once kept that day's welcome app for
  // good, missing every directive added since — and rewriting it unconditionally
  // would throw away whatever the reader had changed in it. So the seeding records a
  // fingerprint of what it wrote (`WelcomeSeed`), and replaces only a copy that still
  // matches: edit one line of it and it is yours, from then on.
  React.useEffect0(() => {
    let current = AppDocument.welcome(
      ~locale,
      ~date=Clock.timestamp()->String.slice(~start=0, ~end=10),
    )
    let write = () =>
      DocumentStore.save(~id=AppDocument.welcomeId, ~source=current)->Promise.then(() =>
        WelcomeSeed.record(Digest.of_(current))
      )

    Promise.all2((DocumentStore.load(AppDocument.welcomeId), WelcomeSeed.read()))
    ->Promise.then(((existing, recorded)) =>
      switch existing {
      | None => write()
      | Some(stored) if stored != current && Digest.matches(stored, ~recorded) => write()
      // Either the reader has made it theirs, or it is already what we would write.
      | Some(_) => Promise.resolve()
      }
    )
    ->Promise.thenResolve(() => {
      refreshApps()
      setSeeded(_ => true)
    })
    ->ignore
    None
  })

  // Parsed before the effects below, which read the result: ReScript bindings are
  // ordered, and the storage callback needs to know whether the document declared a
  // language of its own.
  let parsedDocument = Frontmatter.parse(rendered)
  let declaredLanguage = parsedDocument.meta->Option.flatMap(meta => Frontmatter.get(meta, "lang"))
  let documentLocale = declaredLanguage->Option.flatMap(Locale.parse)
  let documentLocaleRef = React.useRef(documentLocale)
  documentLocaleRef.current = documentLocale

  React.useEffect0(() => {
    PaletteStorage.load()
    ->Promise.thenResolve(stored =>
      switch stored {
      | Some(persisted) => setPalette(_ => persisted)
      | None => ()
      }
    )
    ->ignore

    ThemeStorage.load()
    ->Promise.thenResolve(stored =>
      switch stored {
      | Some(persisted) => setTheme(_ => persisted)
      | None => ()
      }
    )
    ->ignore

    LocaleStorage.load()
    ->Promise.thenResolve(stored =>
      switch (stored, documentLocaleRef.current) {
      // A document that declares its own language outranks the stored preference.
      // Without this the IndexedDB read, which resolves after the document has been
      // parsed, silently overwrites the language the document asked for.
      | (_, Some(_)) => ()
      | (Some(persisted), None) => setLocale(_ => persisted)
      | (None, None) => ()
      }
    )
    ->ignore
    None
  })

  // Debounced so Mermaid — which parses and lays out a whole diagram — is not re-run
  // on every keystroke. The editor stays responsive because it owns its own document
  // and never waits on this.
  React.useEffect1(() => {
    let timeout = setTimeout(() => setRendered(_ => source), 250)
    Some(() => clearTimeout(timeout))
  }, [source])

  // Saved on the same principle, one beat later: a document is written once the
  // author stops typing, not on every character.
  //
  // The frontmatter's appId is the app's identity, so changing it *moves* the app —
  // document and collections together — and the URL follows. `openedId` is set before
  // navigating, so the hash change this causes is not read back as "open a different
  // document" and the editor is never reseeded under the author's cursor.
  React.useEffect2(() => {
    switch (Route.appId(route), source) {
    | (Some(id), text) if text != "" =>
      let timeout = setTimeout(() => {
        switch AppDocument.declaredId(text) {
        | Some(declared) if declared != id =>
          openedId.current = Some(declared)
          DocumentStore.rename(~from=id, ~to_=declared, ~source=text)
          // The space link moves with the app, before the engine restarts under
          // the new id and goes looking for it. The derived-collection marks
          // ride along for the same reason.
          ->Promise.then(() => SpaceStore.rename(~from=id, ~to_=declared))
          ->Promise.then(() => DerivedPaths.rename(~from=id, ~to_=declared))
          ->Promise.thenResolve(() => {
            Router.navigate(Route.isEditing(route) ? Edit(declared) : View(declared))
            refreshApps()
          })
          ->ignore
        | _ =>
          DocumentStore.save(~id, ~source=text)
          ->Promise.thenResolve(() => {
            refreshApps()
            SpaceSync.localChanged(~app=id)
          })
          ->ignore
        }
      }, 700)
      Some(() => clearTimeout(timeout))
    | _ => None
    }
  }, (source, Route.toPath(route)))

  // The document's own `lang` wins while it is open. Deliberately not persisted: it
  // belongs to the document, not to the user, so opening an untagged document leaves
  // the last language in place rather than overwriting a preference.
  React.useEffect1(() => {
    switch documentLocale {
    | Some(declared) => setLocale(current => current == declared ? current : declared)
    | None => ()
    }
    None
  }, [declaredLanguage->Option.getOr("")])

  let t = key => Translations.translate(locale, key)

  let toggleTheme = () =>
    setTheme(current => {
      let next = Theme.toggle(current)
      ThemeStorage.save(next)
      next
    })

  let selectPalette = next => {
    PaletteStorage.save(next)
    setPalette(_ => next)
  }

  let selectLocale = next => {
    LocaleStorage.save(next)
    setLocale(_ => next)
  }

  let createApp = () => {
    DocumentStore.ids()
    ->Promise.then(taken => {
      let title = t(Translations.Untitled)
      let id = AppId.unique(~desired=title, ~taken)
      let document = AppDocument.blank(
        ~id,
        ~title,
        ~date=Clock.timestamp()->String.slice(~start=0, ~end=10),
        ~locale,
      )
      // Written before navigating: the route effect loads the document by id, and it
      // has to be there when it looks.
      DocumentStore.save(~id, ~source=document)->Promise.thenResolve(() => id)
    })
    ->Promise.thenResolve(id => {
      refreshApps()
      Router.navigate(Edit(id))
    })
    ->ignore
  }

  let deleteApp = id => {
    // A deleted app leaves its space too, where there is an account to do it
    // with; without one the local link is cleared, and the membership row waits
    // for the owner's broom.
    switch session {
    | Some(signed) => SpaceSync.leave(~app=id, ~session=signed)->ignore
    | None => SpaceStore.clear(~app=id)->ignore
    }
    DocumentStore.remove(id)->Promise.thenResolve(() => refreshApps())->ignore
  }

  // The one place where an app IS overwritten, and only because somebody asked for
  // exactly that. Everything else that brings a document in — a file, a share link, a
  // catalogue address — files it as a copy under a free id, because a replaced app
  // cannot be recovered and a duplicate can simply be deleted. Here the reader has
  // read which two versions are involved and what happens to the data, and answered
  // the question: filing this one as a copy would be answering a different question
  // than the one asked, and would leave two cards with the same name.
  //
  // The document is written under the id it already had, with its frontmatter forced
  // to match. The catalogue publishes an app under its own id and that is normally
  // the same string — but «normally» is not a guarantee about a file fetched from
  // elsewhere, and an id that disagreed with the storage key would move the app's
  // collections out from under it.
  let updateApp = id =>
    CatalogServer.fetchDocument(id)
    ->Promise.then(answer =>
      switch answer["text"] {
      | Some(text) if Frontmatter.parse(text).meta->Option.isSome =>
        DocumentStore.save(~id, ~source=AppDocument.withId(text, id))->Promise.thenResolve(() => {
          setNotice(_ => Some(Translations.translate(locale, UpdateDone)))
          // Both editors are uncontrolled and read their value once, so an app open
          // in another pane would keep showing the document it was seeded with.
          setDocEpoch(epoch => epoch + 1)
          refreshApps()
        })
      | _ =>
        // Nothing arrived, or what arrived is not a document: the app stays exactly
        // as it was. Half an update is the one outcome there is no way back from.
        setNotice(_ => Some(Translations.translate(locale, UpdateFailed)))
        Promise.resolve()
      }
    )
    ->ignore

  // A copy opens straight away, in the editor where there is one: the reason to
  // duplicate an app is to change it, and leaving the reader on the gallery in front
  // of two cards with nearly the same name is leaving them to find it again.
  let duplicateApp = id =>
    DocumentStore.duplicate(id)
    ->Promise.thenResolve(copy =>
      switch copy {
      | Some(made) =>
        refreshApps()
        Router.navigate(canEdit ? Edit(made) : View(made))
      | None => ()
      }
    )
    ->ignore

  // An app leaves as the document it is: plain Markdown, frontmatter and all. Read
  // back from storage rather than taken from `source`, so what lands on disk is what
  // the app *is* — the editor's unsaved keystroke belongs to the editor.
  let exportApp = id =>
    DocumentStore.load(id)
    ->Promise.thenResolve(stored =>
      switch stored {
      | Some(text) => FileTransfer.download(AppFile.name(id), text)
      | None => ()
      }
    )
    ->ignore

  // Coming back the other way. An import never overwrites: a file whose id is
  // already here lands as a copy, because a replaced app cannot be recovered and a
  // duplicate can simply be deleted.
  let importApp = () =>
    FileTransfer.readDocument()
    ->Promise.then(chosen =>
      switch chosen {
      | None => Promise.resolve()
      | Some((filename, _)) if !AppFile.isDocument(filename) =>
        setNotice(_ => Some(t(Translations.NotADocument)))
        Promise.resolve()
      | Some((_, text)) => receive(text)
      }
    )
    ->ignore

  // What a shared link carries, and whether it can be carried at all. Encoding is
  // asynchronous — it compresses, encrypts and asks the server — so the dialog opens
  // on the answer rather than before it, and shows nothing half-made.
  let (sharing, setSharing) = React.useState((): option<(string, string, string)> => None)

  let shareApp = id =>
    DocumentStore.load(id)
    ->Promise.then(stored =>
      switch stored {
      | None => Promise.resolve()
      | Some(text) =>
        SharePayload.encode(text)->Promise.then(payload => {
          let card = AppDocument.summary(~id, ~source=text)
          let longLink = ShareLink.fits(payload)
            ? ShareLink.of_(~origin=Clipboard.origin, ~payload)
            : ""
          // The short link: the same payload, sealed under a fresh key and deposited
          // on the server. Any failure along the way — no server, payload past the
          // stored ceiling — resolves to "", and the dialog offers the long link
          // alone: the server is an improvement, never a requirement.
          ShareCrypto.generateKey()
          ->Promise.then(key =>
            ShareCrypto.encrypt(~key, ~text=payload)->Promise.then(sealed =>
              !ShareLink.fitsStored(sealed)
                ? Promise.resolve("")
                : ShareServer.create(sealed)->Promise.thenResolve(made =>
                    switch made {
                    | Some(shareId) =>
                      ShareLink.shortOf(~origin=Clipboard.origin, ~id=shareId, ~key)
                    | None => ""
                    }
                  )
            )
          )
          ->Promise.thenResolve(shortLink =>
            setSharing(_ => Some((card.title, longLink, shortLink)))
          )
        })
      }
    )
    ->ignore

  let copyLink = id =>
    Clipboard.copy(Clipboard.absolute(View(id)))
    ->Promise.thenResolve(copied => setCopiedId(_ => copied ? Some(id) : None))
    ->ignore

  // The document's own declaration, not the route's id: the data directives and the
  // data panel address the collections the *document* claims, so an app whose id is
  // being edited reads and writes under the id it now says it has.
  let appId = parsedDocument.meta->Option.flatMap(meta => Frontmatter.get(meta, "appId"))

  // "Preview" is only true while there is a document being previewed beside it. At
  // /a/<id> the same pane is the running app, so it is named after the app — which
  // is also what a screen reader announces when moving into the region.
  let openedCard = switch Route.appId(route) {
  | Some(id) => Some(AppDocument.summary(~id, ~source=rendered))
  | None => None
  }

  // The chat is the document's to ask for — `chat: true` in the frontmatter — so
  // the button only exists where the document says the conversation belongs.
  let chatEnabled = openedCard->Option.map(card => card.AppDocument.chat)->Option.getOr(false)

  let rightPaneTitle = Route.isEditing(route)
    ? t(PreviewPane)
    : switch openedCard {
      | Some(card) => card.title == "" ? t(AppPane) : card.title
      | None => t(AppPane)
      }

  // Only where the pane *is* the app. Beside an editor the pane is a preview of a
  // document, and a document's mark belongs on the app, not on a view of it.
  let rightPaneIcon = Route.isEditing(route)
    ? None
    : openedCard->Option.map(card => card.AppDocument.icon)

  let editingButton = (editing, icon) =>
    <Spectrum.ActionButton
      label={t(
        switch editing {
        | EditorMode.Markdown => Translations.MarkdownEditor
        | EditorMode.Blocks => Translations.BlockEditor
        },
      )}
      selected={mode.editing == editing}
      onClick={_ => setMode(current => EditorMode.useEditing(current, editing))}>
      icon
    </Spectrum.ActionButton>

  <Spectrum.Theme
    system="spectrum-two"
    color={Theme.toSpectrumColor(theme)}
    // The palette travels as a class rather than a data attribute: ReScript's
    // `@as` rename does not survive into the props object React hands to a custom
    // element, so the attribute would arrive misspelled and the CSS never match.
    className={"rn-palette-" ++
    Palette.toTag(palette) ++ " rn-page flex h-screen flex-col overflow-hidden"}>
    <Navbar
      locale
      route
      canEdit
      onToggleEditing={() =>
        switch Route.appId(route) {
        | Some(id) => Router.navigate(Route.isEditing(route) ? View(id) : Edit(id))
        | None => ()
        }}
      onHome={() => Router.navigate(Gallery)}
      copied={copiedId != None && copiedId == Route.appId(route)}
      onCopyLink={() =>
        switch Route.appId(route) {
        | Some(id) => copyLink(id)
        | None => ()
        }}
      onShare={() =>
        switch Route.appId(route) {
        | Some(id) => shareApp(id)
        | None => ()
        }}
      onSync={() => setSyncOpen(_ => true)}
      onExport={() =>
        switch Route.appId(route) {
        | Some(id) => exportApp(id)
        | None => ()
        }}
      onImport={importApp}
      assistantOpen
      onAssistant={() => setAssistantOpen(shown => !shown)}
    />
    // The panel is a column beside whatever the route is showing, rather than a
    // dialog over it: it is used *while* looking at the app it is changing, and a
    // modal would put the one thing being talked about behind the conversation.
    <div className="rn-panes flex min-h-0 flex-1 overflow-hidden">
    {switch route {
    // A shared link is a moment, not a page: the effect above decodes it and moves
    // on, so what is on screen while that happens is the gallery it is about to
    // land in. A catalogue address is the same moment with a fetch in it.
    | Route.Gallery | Route.Shared(_) | Route.Join(_) | Route.Catalog(_) =>
      <main className="min-h-0 flex-1 overflow-auto">
        <Gallery
          apps
          locale
          onCreate={createApp}
          onDelete={deleteApp}
          onDuplicate={duplicateApp}
          onUpdate={updateApp}
          onCopyLink={copyLink}
          copiedId
          canEdit
          notice
          onAsk={question => {
            setAssistantQuestion(_ => Some(question))
            setAssistantOpen(_ => true)
          }}
        />
      </main>
    | Route.View(_) | Route.Edit(_) =>
      <main
        className={"grid min-h-0 flex-1 " ++ (
          EditorMode.previewIsFullWidth(mode) ? "grid-cols-1" : "grid-cols-1 md:grid-cols-2"
        )}>
        {mode.editorVisible
          ? <section className="rn-divider flex min-h-0 flex-col border-r" ariaLabel={t(EditorPane)}>
              <PaneToolbar title={t(EditorPane)}>
                <>
                  {editingButton(Markdown, Icons.markdown)}
                  {editingButton(Blocks, Icons.blocks)}
                </>
              </PaneToolbar>
              // Keyed on the epoch, which is what makes an applied rewrite visible:
              // the key is on the container so that *both* editors are rebuilt, since
              // only one of them takes a key of its own.
              <div key={"editor-" ++ Int.toString(docEpoch)} className="min-h-0 flex-1">
                {EditorMode.showsMarkdownEditor(mode)
                  // Keyed on the app: the editor is uncontrolled and reads its value
                  // once, so opening another app has to give it a new instance. The
                  // key also flips when the document's load lands — on a cold deep
                  // link into /edit the editor mounts before IndexedDB has answered,
                  // and one seeded from the empty string would stay empty for good.
                  // Typing never flips it back: `openedId` is set when the load
                  // lands and only changes when another document is opened.
                  ? <Editor
                      key={Route.appId(route)->Option.getOr("") ++ (
                        openedId.current == Route.appId(route) ? "" : "-loading"
                      )}
                      initialValue={source}
                      onChange={text => setSource(_ => text)}
                    />
                  : BlockEditor.element(
                      // The whole document: the frontmatter is a block of its own in
                      // there, so BlockNote owns it like everything else.
                      ~initialMarkdown=source,
                      ~onChange=text => setSource(_ => text),
                      ~dark=Theme.isDark(theme),
                      ~locale,
                    )}
              </div>
            </section>
          : React.null}
        <section className="flex min-h-0 flex-col" ariaLabel={rightPaneTitle}>
          <PaneToolbar title={rightPaneTitle} icon=?rightPaneIcon>
            <>
              <Spectrum.ActionButton
                label={t(DocumentInfo)}
                selected={infoOpen}
                onClick={_ => setInfoOpen(shown => !shown)}>
                Icons.info
              </Spectrum.ActionButton>
              <Spectrum.ActionButton
                label={t(DataPanel)}
                selected={mode.dataVisible}
                onClick={_ => setMode(EditorMode.toggleData)}>
                Icons.data
              </Spectrum.ActionButton>
              {chatEnabled
                ? <Spectrum.ActionButton
                    label={t(ChatPanel)}
                    selected={chatOpen}
                    onClick={_ => setChatOpen(shown => !shown)}>
                    Icons.chat
                  </Spectrum.ActionButton>
                : React.null}
              // Sharing and saving the app moved to the navbar, with the other things
              // that are about the app rather than about this pane. What is left here
              // is what the pane shows and how wide it shows it.
              {Route.isEditing(route)
                ? <Spectrum.ActionButton
                    label={EditorMode.previewIsPhone(mode) ? t(FullWidth) : t(PhoneWidth)}
                    selected={EditorMode.previewIsPhone(mode)}
                    onClick={_ => setMode(EditorMode.togglePreviewWidth)}>
                    {EditorMode.previewIsPhone(mode) ? Icons.desktop : Icons.phone}
                  </Spectrum.ActionButton>
                : React.null}
            </>
          </PaneToolbar>
          {infoOpen ? <DocumentInfo meta={parsedDocument.meta} locale /> : React.null}
          {mode.dataVisible
            ? <DataPanel app={appId} locale clock={Clock.timestamp} />
            : React.null}
          {chatEnabled && chatOpen
            ? <ChatPanel
                app={appId}
                locale
                author={session->Option.map(signed => signed.Session.username)}
                clock={Clock.timestamp}
              />
            : React.null}
          <div className="rn-preview min-h-0 flex-1 overflow-auto">
            {EditorMode.previewIsPhone(mode)
              ? <div className="rn-phone-frame">
                  <Render source={parsedDocument.body} theme locale app={appId} />
                </div>
              : <Render source={parsedDocument.body} theme locale app={appId} />}
          </div>
        </section>
      </main>
    }}
      {assistantOpen
        ? <AiPanel
            locale
            app={Route.appId(route)}
            question={assistantQuestion}
            onQuestionTaken={() => setAssistantQuestion(_ => None)}
            onCreated={_ => refreshApps()}
            onOpen={id => Router.navigate(canEdit ? Edit(id) : View(id))}
            onApply={(~id, ~source as text) =>
              // The open app takes the rewrite through the same state the editor
              // writes to, so the debounced save, the rename path and the preview all
              // behave exactly as they do for a typed change. An app that is not the
              // one on screen has no editor to disturb and is written directly.
              if Route.appId(route) == Some(id) {
                setSource(_ => text)
                setDocEpoch(count => count + 1)
              } else {
                DocumentStore.save(~id, ~source=text)
                ->Promise.thenResolve(() => refreshApps())
                ->ignore
              }}
            onClose={() => setAssistantOpen(_ => false)}
          />
        : React.null}
    </div>
    // Always mounted, driven by `open_`, like every other dialog here: opening one in
    // the same commit that first puts it in the document races the node's arrival.
    <ShareDialog
      open_={sharing->Option.isSome}
      locale
      title={switch sharing {
      | Some((title, _, _)) => title
      | None => ""
      }}
      link={switch sharing {
      | Some((_, long, _)) => long
      | None => ""
      }}
      shortLink={switch sharing {
      | Some((_, _, short)) => short
      | None => ""
      }}
      tooBig={switch sharing {
      | Some((_, "", "")) => true
      | _ => false
      }}
      onClose={() => setSharing(_ => None)}
    />
    <AccountDialog
      open_={accountOpen}
      locale
      session
      onClose={() => setAccountOpen(_ => false)}
      onSignedIn={signed => {
        setSession(_ => Some(signed))
        setAccountOpen(_ => false)
      }}
      onSignOut={signOut}
    />
    <SyncDialog
      open_={syncOpen}
      locale
      app={Route.appId(route)}
      session
      onClose={() => setSyncOpen(_ => false)}
      onOpenAccount={() => {
        setSyncOpen(_ => false)
        setAccountOpen(_ => true)
      }}
      onChanged={() => setSyncEpoch(count => count + 1)}
    />
    // The one explicit yes an invitation needs: joining writes a membership and
    // downloads a space, and a modal is where that is said before it happens.
    <ConfirmDialog
      open_={joinPending->Option.isSome}
      title={t(SyncPanel)}
      message={t(JoinQuestion)}
      confirmLabel={t(JoinAction)}
      cancelLabel={t(CancelAction)}
      onConfirm={confirmJoin}
      onCancel={cancelJoin}
    />
    <Footer
      theme
      palette
      locale
      accountName={switch session {
      | Some(signed) => Some(signed.username)
      | None => None
      }}
      onAccount={() => setAccountOpen(_ => true)}
      onToggleTheme={toggleTheme}
      onSelectPalette={selectPalette}
      onSelectLocale={selectLocale}
    />
  </Spectrum.Theme>
}
