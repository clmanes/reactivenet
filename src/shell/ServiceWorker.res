// Registered by hand rather than through vite-plugin-pwa's injected script.
//
// That script is a classic <script src> in the document head, so it executes during
// parsing — before the deferred module graph, and therefore before the Trusted Types
// default policy exists. Its register() call then fails with "requires
// 'TrustedScriptURL' assignment" and the app never becomes installable. Doing it here
// puts the registration after TrustedTypes.install().

let register: unit => unit = %raw(`
function () {
  if (!import.meta.env.PROD) return;
  if (!("serviceWorker" in navigator)) return;
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/sw.js", { scope: "/" }).catch(() => {});
  });
}
`)
