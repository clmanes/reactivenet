%%raw("import './index.css'")

// Order matters: the Trusted Types policy has to exist before any component builds a
// shadow root, and before the service worker URL is handed to register().
TrustedTypes.install()
ServiceWorker.register()

switch ReactDOM.querySelector("#root") {
| Some(domElement) =>
  ReactDOM.Client.createRoot(domElement)->ReactDOM.Client.Root.render(
    <React.StrictMode>
      <App />
    </React.StrictMode>,
  )
| None => ()
}
