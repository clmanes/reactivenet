// Signing in, and the one time an account is created.
//
// The dialog says up front what an account is *for* — syncing shared data, nothing
// else — because everything else in this app works without one and should not start
// looking like it needs one. Registration mints the keypair on this device, seals
// the private half under the password and under a recovery code, and shows that
// code exactly once, before the account is usable: a screen shown after would be a
// screen nobody reads.
//
// The password is used and dropped. What outlives this dialog is the session —
// token and opened keys — which `Session` keeps in IndexedDB like every other
// preference.

type fieldTarget = {value: string}
@get external fieldValue: JsxEvent.Form.t => fieldTarget = "target"
@get external keyOf: JsxEvent.Keyboard.t => string = "key"

type view =
  | Credentials
  | Recovery(string, Session.t)

let usernamePattern = RegExp.fromString("^[a-z0-9][a-z0-9-]{2,31}$")

@react.component
let make = (
  ~open_: bool,
  ~locale: Locale.t,
  ~session: option<Session.t>,
  ~onClose: unit => unit,
  ~onSignedIn: Session.t => unit,
  ~onSignOut: unit => unit,
) => {
  let t = key => Translations.translate(locale, key)
  let dialog = React.useRef(Nullable.null)
  let (view, setView) = React.useState(() => Credentials)
  let (username, setUsername) = React.useState(() => "")
  let (password, setPassword) = React.useState(() => "")
  let (error, setError) = React.useState(() => None)
  let (busy, setBusy) = React.useState(() => false)
  let (codeCopied, setCodeCopied) = React.useState(() => false)

  React.useEffect1(() => {
    switch dialog.current->Nullable.toOption {
    | Some(element) => NativeDialog.follow(element, ~open_, ~onDismiss=() => onClose())
    | None => None
    }
  }, [open_])

  // A fresh opening is a fresh form: leftover errors — and above all a leftover
  // password — must not survive a close.
  React.useEffect1(() => {
    if !open_ {
      setView(_ => Credentials)
      setPassword(_ => "")
      setError(_ => None)
      setBusy(_ => false)
      setCodeCopied(_ => false)
    }
    None
  }, [open_])

  let finishSignIn = (answer: AccountServer.session, priv, pub) => {
    let session: Session.t = {
      token: answer.token,
      userId: answer.userId,
      username: answer.username,
      pub,
      priv,
    }
    session
  }

  let submitSignIn = () => {
    setBusy(_ => true)
    setError(_ => None)
    let run = async () => {
      switch await AccountServer.signIn(~username, ~password) {
      | None => setError(_ => Some(Translations.AccountFailed))
      | Some(answer) =>
        switch KeyBundle.decode(answer.keyBundle) {
        | None => setError(_ => Some(Translations.AccountFailed))
        | Some(bundle) =>
          switch await AccountCrypto.unwrapWithSecret(
            ~secret=password,
            ~salt=bundle.salt,
            ~iterations=bundle.iterations,
            ~payload=bundle.vault,
          ) {
          | None => setError(_ => Some(Translations.AccountFailed))
          | Some(priv) => {
              let session = finishSignIn(answer, priv, bundle.pub)
              await Session.save(session)
              onSignedIn(session)
            }
          }
        }
      }
      setBusy(_ => false)
    }
    run()->ignore
  }

  let submitRegister = () => {
    if !RegExp.test(usernamePattern, username) {
      setError(_ => Some(Translations.UsernameHint))
    } else if String.length(password) < 8 {
      setError(_ => Some(Translations.PasswordHint))
    } else {
      setBusy(_ => true)
      setError(_ => None)
      let run = async () => {
        let identity = await AccountCrypto.generateIdentity()
        let salt = AccountCrypto.newSalt()
        let vault = await AccountCrypto.wrapWithSecret(
          ~secret=password,
          ~salt,
          ~iterations=AccountCrypto.iterations,
          ~text=identity.priv,
        )
        let code = RecoveryCode.format(AccountCrypto.randomBytes(RecoveryCode.byteLength))
        switch code {
        | None => setError(_ => Some(Translations.AccountFailed))
        | Some(code) => {
            let recoveryVault = await AccountCrypto.wrapWithSecret(
              ~secret=code,
              ~salt=AccountCrypto.recoverySalt,
              ~iterations=AccountCrypto.iterations,
              ~text=identity.priv,
            )
            let bundle = KeyBundle.encode({
              pub: identity.pub,
              salt,
              iterations: AccountCrypto.iterations,
              vault,
              recoveryVault,
            })
            let outcome = await AccountServer.register(~username, ~password, ~keyBundle=bundle)
            if outcome.taken {
              setError(_ => Some(Translations.UsernameTaken))
            } else if !outcome.ok {
              setError(_ => Some(Translations.AccountFailed))
            } else {
              switch await AccountServer.signIn(~username, ~password) {
              | None => setError(_ => Some(Translations.AccountFailed))
              | Some(answer) =>
                // The recovery code stands between registration and the signed-in
                // state on purpose: shown afterwards it would compete with whatever
                // the user came here to do, and lose.
                setView(_ => Recovery(code, finishSignIn(answer, identity.priv, identity.pub)))
              }
            }
          }
        }
        setBusy(_ => false)
      }
      run()->ignore
    }
  }

  let completeRecovery = (session: Session.t) => {
    let run = async () => {
      await Session.save(session)
      onSignedIn(session)
    }
    run()->ignore
  }

  let copyCode = code =>
    Clipboard.copy(code)->Promise.thenResolve(done => setCodeCopied(_ => done))->ignore

  <dialog
    ref={ReactDOM.Ref.domRef(dialog)}
    className="rn-dialog rn-surface"
    ariaLabelledby="rn-account-title">
    <h2 id="rn-account-title" className="rn-dialog-title"> {React.string(t(AccountLabel))} </h2>
    {switch (view, session) {
    | (Recovery(code, pending), _) =>
      <>
        <h3 className="rn-account-subtitle"> {React.string(t(RecoveryCodeTitle))} </h3>
        <p className="rn-dialog-message"> {React.string(t(RecoveryCodeInfo))} </p>
        <div className="rn-share-row">
          <output className="rn-recovery-code"> {React.string(code)} </output>
          <Spectrum.Button variant="secondary" onClick={_ => copyCode(code)}>
            {React.string(codeCopied ? t(LinkCopied) : t(CopyAction))}
          </Spectrum.Button>
        </div>
        <div className="rn-dialog-actions">
          <Spectrum.Button variant="accent" onClick={_ => completeRecovery(pending)}>
            {React.string(t(RecoveryCodeDone))}
          </Spectrum.Button>
        </div>
      </>
    | (Credentials, Some(signed)) =>
      <>
        <p className="rn-dialog-message">
          {React.string(t(SignedInAs) ++ " ")}
          <strong> {React.string(signed.username)} </strong>
        </p>
        <div className="rn-dialog-actions">
          <Spectrum.Button variant="secondary" onClick={_ => onSignOut()}>
            {React.string(t(SignOutAction))}
          </Spectrum.Button>
          <Spectrum.Button variant="accent" onClick={_ => onClose()}>
            {React.string(t(CancelAction))}
          </Spectrum.Button>
        </div>
      </>
    | (Credentials, None) =>
      <>
        <p className="rn-dialog-message rn-muted"> {React.string(t(AccountIntro))} </p>
        <label className="rn-account-label">
          {React.string(t(UsernameLabel))}
          <input
            className="rn-account-field"
            type_="text"
            autoComplete="username"
            value={username}
            disabled={busy}
            onInput={event => setUsername(_ => fieldValue(event).value->String.toLowerCase)}
          />
        </label>
        <p className="rn-share-note rn-muted"> {React.string(t(UsernameHint))} </p>
        <label className="rn-account-label">
          {React.string(t(PasswordLabel))}
          <input
            className="rn-account-field"
            type_="password"
            autoComplete="current-password"
            value={password}
            disabled={busy}
            onInput={event => setPassword(_ => fieldValue(event).value)}
            onKeyDown={event =>
              if keyOf(event) == "Enter" {
                submitSignIn()
              }}
          />
        </label>
        <p className="rn-share-note rn-muted"> {React.string(t(PasswordHint))} </p>
        {switch error {
        | Some(key) => <p className="rn-error rn-dialog-message"> {React.string(t(key))} </p>
        | None => React.null
        }}
        <div className="rn-dialog-actions">
          <Spectrum.Button variant="secondary" disabled={busy} onClick={_ => onClose()}>
            {React.string(t(CancelAction))}
          </Spectrum.Button>
          <Spectrum.Button variant="secondary" disabled={busy} onClick={_ => submitRegister()}>
            {React.string(t(CreateAccountAction))}
          </Spectrum.Button>
          <Spectrum.Button variant="accent" disabled={busy} onClick={_ => submitSignIn()}>
            {React.string(t(SignInAction))}
          </Spectrum.Button>
        </div>
      </>
    }}
  </dialog>
}
