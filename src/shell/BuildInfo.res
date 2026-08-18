// The version, from a module the bundler builds out of package.json.
//
// It used to be `@module("../../package.json")`, which is the obvious thing and
// worked until Vite 7: that version refuses to serve package.json to the browser,
// and no setting lifts it. What you get is the worst kind of failure — the request
// 404s, the module graph breaks at that one edge, nothing mounts, and the console
// shows a bare 404 for a file no `<script>` ever asked for. A blank page with
// nothing in it to read.
//
// `define` was the easy answer and the wrong one: it reads the file once, when the
// config loads, so a dev server started before `scripts/version.mjs` bumped the
// number keeps showing the old one — exactly the drift the footer exists to rule
// out. The virtual module in vite.config.js reads it on every load instead.
@module("virtual:reactivenet/version") external version: string = "version"
