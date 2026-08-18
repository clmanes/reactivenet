// The sharing panel of an app's data: who is in the space, inviting somebody,
// leaving, and the one action that starts it all.
//
// The dialog answers three situations in order of how much exists yet: no
// account (the one thing sync needs and nothing else does), an account but no
// space (one button, which is the moment the app's data becomes shared), and a
// running space (the member list, the invitation maker, and the exit).
//
// Everything here is words over SpaceSync calls; the decisions — keys, epochs,
// what a role may do — live in the engine and on the server, and this component
// could not override them if it tried, which is the point of where they live.

type fieldTarget = {value: string}
@get external fieldValue: JsxEvent.Form.t => fieldTarget = "target"

type status =
  | Loading
  | NotLinked
  | Linked(string)

@react.component
let make = (
  ~open_: bool,
  ~locale: Locale.t,
  ~app: option<string>,
  ~session: option<Session.t>,
  ~onClose: unit => unit,
  ~onOpenAccount: unit => unit,
  ~onChanged: unit => unit,
) => {
  let t = key => Translations.translate(locale, key)
  let dialog = React.useRef(Nullable.null)
  let (status, setStatus) = React.useState(() => Loading)
  let (members, setMembers) = React.useState((): array<SpaceServer.member> => [])
  let (inviteRole, setInviteRole) = React.useState(() => "editor")
  let (inviteLink, setInviteLink) = React.useState(() => "")
  let (copied, setCopied) = React.useState(() => false)
  let (busy, setBusy) = React.useState(() => false)

  React.useEffect1(() => {
    switch dialog.current->Nullable.toOption {
    | Some(element) => NativeDialog.follow(element, ~open_, ~onDismiss=() => onClose())
    | None => None
    }
  }, [open_])

  let reload = () => {
    switch (app, session) {
    | (Some(app), Some(signed)) => {
        let run = async () => {
          switch await SpaceSync.roleOf(~app) {
          | None => setStatus(_ => NotLinked)
          | Some(role) => {
              setStatus(_ => Linked(role))
              let rows = await SpaceSync.members(~app, ~session=signed)
              setMembers(_ => rows)
            }
          }
        }
        run()->ignore
      }
    | _ => setStatus(_ => NotLinked)
    }
  }

  React.useEffect2(() => {
    if open_ {
      setInviteLink(_ => "")
      setCopied(_ => false)
      setStatus(_ => Loading)
      reload()
    }
    None
  }, (open_, app->Option.getOr("")))

  let startSharing = () =>
    switch (app, session) {
    | (Some(app), Some(signed)) => {
        setBusy(_ => true)
        let run = async () => {
          let made = await SpaceSync.create(~app, ~session=signed)
          if made {
            onChanged()
          }
          reload()
          setBusy(_ => false)
        }
        run()->ignore
      }
    | _ => ()
    }

  let makeInvite = () =>
    switch (app, session) {
    | (Some(app), Some(signed)) => {
        setBusy(_ => true)
        let run = async () => {
          switch await SpaceSync.invite(~app, ~session=signed, ~role=inviteRole) {
          | Some(link) => setInviteLink(_ => link)
          | None => ()
          }
          setBusy(_ => false)
        }
        run()->ignore
      }
    | _ => ()
    }

  let leave = () =>
    switch (app, session) {
    | (Some(app), Some(signed)) => {
        setBusy(_ => true)
        let run = async () => {
          await SpaceSync.leave(~app, ~session=signed)
          onChanged()
          setBusy(_ => false)
          onClose()
        }
        run()->ignore
      }
    | _ => ()
    }

  let remove = memberId =>
    switch (app, session) {
    | (Some(app), Some(signed)) => {
        setBusy(_ => true)
        let run = async () => {
          let _ = await SpaceSync.removeMember(~app, ~session=signed, ~memberId)
          onChanged()
          reload()
          setBusy(_ => false)
        }
        run()->ignore
      }
    | _ => ()
    }

  let copyInvite = () =>
    Clipboard.copy(inviteLink)->Promise.thenResolve(done => setCopied(_ => done))->ignore

  let roleName = role =>
    switch role {
    | "owner" => t(RoleOwner)
    | "editor" => t(RoleEditor)
    | _ => t(RoleReader)
    }

  <dialog
    ref={ReactDOM.Ref.domRef(dialog)}
    className="rn-dialog rn-surface"
    ariaLabelledby="rn-sync-title">
    <h2 id="rn-sync-title" className="rn-dialog-title"> {React.string(t(SyncPanel))} </h2>
    {switch (session, status) {
    | (None, _) =>
      <>
        <p className="rn-dialog-message rn-muted"> {React.string(t(SyncNeedsAccount))} </p>
        <div className="rn-dialog-actions">
          <Spectrum.Button variant="secondary" onClick={_ => onClose()}>
            {React.string(t(CancelAction))}
          </Spectrum.Button>
          <Spectrum.Button variant="accent" onClick={_ => onOpenAccount()}>
            {React.string(t(AccountLabel))}
          </Spectrum.Button>
        </div>
      </>
    | (Some(_), Loading) => <p className="rn-dialog-message rn-muted"> {React.string("…")} </p>
    | (Some(_), NotLinked) =>
      <>
        <p className="rn-dialog-message rn-muted"> {React.string(t(SyncOnInfo))} </p>
        <div className="rn-dialog-actions">
          <Spectrum.Button variant="secondary" disabled={busy} onClick={_ => onClose()}>
            {React.string(t(CancelAction))}
          </Spectrum.Button>
          <Spectrum.Button variant="accent" disabled={busy} onClick={_ => startSharing()}>
            {React.string(t(SyncThisApp))}
          </Spectrum.Button>
        </div>
      </>
    | (Some(signed), Linked(role)) =>
      <>
        <p className="rn-dialog-message rn-muted"> {React.string(t(SyncOnInfo))} </p>
        <h3 className="rn-account-subtitle"> {React.string(t(MembersHeading))} </h3>
        <ul className="rn-member-list">
          {members
          ->Array.map(row =>
            <li key={row.id} className="rn-member-row">
              <span className="rn-member-name">
                {React.string(row.label == "" ? row.user : row.label)}
              </span>
              <span className="rn-member-role rn-muted"> {React.string(roleName(row.role))} </span>
              {role == "owner" && row.user != signed.userId
                ? <Spectrum.Button
                    variant="secondary" size="s" disabled={busy} onClick={_ => remove(row.id)}>
                    {React.string(t(RemoveMember))}
                  </Spectrum.Button>
                : React.null}
            </li>
          )
          ->React.array}
        </ul>
        {role == "owner"
          ? <>
              <div className="rn-share-row">
                <Spectrum.Picker
                  value={inviteRole}
                  label={t(InviteAction)}
                  size="s"
                  onChange={event => {
                    let next = fieldValue(event).value
                    if next != inviteRole && (next == "editor" || next == "reader") {
                      setInviteRole(_ => next)
                    }
                  }}>
                  <Spectrum.MenuItem value="editor" selected={inviteRole == "editor"}>
                    {React.string(t(RoleEditor))}
                  </Spectrum.MenuItem>
                  <Spectrum.MenuItem value="reader" selected={inviteRole == "reader"}>
                    {React.string(t(RoleReader))}
                  </Spectrum.MenuItem>
                </Spectrum.Picker>
                <Spectrum.Button variant="accent" disabled={busy} onClick={_ => makeInvite()}>
                  {React.string(t(InviteAction))}
                </Spectrum.Button>
              </div>
              {inviteLink == ""
                ? React.null
                : <>
                    <div className="rn-share-row">
                      <input
                        className="rn-share-link"
                        type_="text"
                        readOnly=true
                        value={inviteLink}
                        ariaLabel={t(InviteAction)}
                      />
                      <Spectrum.Button variant="secondary" onClick={_ => copyInvite()}>
                        {React.string(copied ? t(LinkCopied) : t(CopyAction))}
                      </Spectrum.Button>
                    </div>
                    <p className="rn-share-note rn-muted"> {React.string(t(InviteLinkInfo))} </p>
                  </>}
            </>
          : React.null}
        <div className="rn-dialog-actions">
          {role == "owner"
            ? React.null
            : <Spectrum.Button variant="secondary" disabled={busy} onClick={_ => leave()}>
                {React.string(t(LeaveSpace))}
              </Spectrum.Button>}
          <Spectrum.Button variant="accent" onClick={_ => onClose()}>
            {React.string(t(CancelAction))}
          </Spectrum.Button>
        </div>
      </>
    }}
  </dialog>
}
