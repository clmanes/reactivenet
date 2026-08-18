open BunTest

// The policy is written once in vite.config.js and repeated TWICE, because a static
// host reads only public/_headers, our own server reads only the Caddyfile, and a
// <meta> tag cannot say everything. A repetition is a thing that drifts: the ::python
// rollout added three tokens to the config and none to the file, and every block died
// on exactly the deploys nobody tests locally — `bun run preview` serves the header
// from the config and reads neither copy. So the sync is a test, and drifting is a
// red build.
//
// The Caddyfile joined this list late, after the copy that actually serves production
// stayed a version behind: the meta tag granted api.pirsch.io and Caddy's header did
// not, and because both are enforced and the INTERSECTION wins, the grant did nothing
// while the console error quoted a policy no file in the repo still contained. A copy
// kept by hand is a copy that drifts; the only fix that holds is to stop keeping it
// by hand.

let readFile: string => string = %raw(`
function (path) { return require("node:fs").readFileSync(path, "utf8"); }
`)

// The directives, from the code lines of the CSP_DIRECTIVES array only: the comments
// inside it quote policy names, and reading those would compare the policy against
// its own documentation.
let configDirectives = () => {
  let source = readFile("vite.config.js")
  let block =
    RegExp.exec(RegExp.fromString("const CSP_DIRECTIVES = \\[([\\s\\S]*?)\\];"), source)
    ->Option.flatMap(result => result->RegExp.Result.matches->Array.at(0))
    ->Option.flatMap(value => value)
    ->Option.getOr("")
  block
  ->String.split("\n")
  ->Array.filter(line => !(line->String.trim->String.startsWith("//")))
  ->Array.map(line => {
    let found = []
    let pattern = RegExp.fromStringWithFlags("\"([^\"]+)\"", ~flags="g")
    let rec walk = () =>
      switch RegExp.exec(pattern, line) {
      | None => ()
      | Some(result) =>
        switch result->RegExp.Result.matches->Array.at(0)->Option.flatMap(v => v) {
        | Some(directive) =>
          found->Array.push(directive)
          walk()
        | None => ()
        }
      }
    walk()
    found
  })
  ->Array.flat
}

let headerPolicy = () => {
  let file = readFile("public/_headers")
  file
  ->String.split("\n")
  ->Array.find(line => line->String.trim->String.startsWith("Content-Security-Policy:"))
  ->Option.map(line =>
    line
    ->String.trim
    ->String.sliceToEnd(~start=String.length("Content-Security-Policy:"))
    ->String.trim
  )
  ->Option.getOr("")
}

// Caddy states the same policy in its own language: `Content-Security-Policy "…"`,
// one quoted value on one line. Read from the quotes rather than by position, so
// reindenting the block does not fail the test for no reason.
//
// The file now carries TWO policies — the showcase site's own (its single copy
// lives in the Caddyfile, there is no build config behind it) and the app's,
// which is the replica this test exists to pin. So every CSP line is collected,
// and the app's is the one carrying `require-trusted-types-for`: that token is
// what the app's whole Trusted Types design hangs on, so it identifies the copy
// no matter where the site's block sits in the file.
let caddyPolicies = () => {
  let file = readFile("Caddyfile")
  file
  ->String.split("\n")
  ->Array.filter(line => line->String.trim->String.startsWith("Content-Security-Policy "))
  ->Array.filterMap(line =>
    RegExp.exec(RegExp.fromString("\"([^\"]+)\""), line)
    ->Option.flatMap(result => result->RegExp.Result.matches->Array.at(0))
    ->Option.flatMap(value => value)
  )
}

let caddyPolicy = () =>
  caddyPolicies()
  ->Array.find(policy => policy->String.includes("require-trusted-types-for"))
  ->Option.getOr("")

describe("the three copies of the security policy", () => {
  test("public/_headers carries exactly the policy vite.config.js defines", () => {
    expect(headerPolicy())->toBe(configDirectives()->Array.join("; "))
  })

  // The copy that serves production. It is the one that went stale, and the failure
  // was invisible to every local check: preview reads the config, not this file.
  test("the Caddyfile carries exactly the policy vite.config.js defines", () => {
    expect(caddyPolicy())->toBe(configDirectives()->Array.join("; "))
  })

  // The showcase site's policy: its only copy is the Caddyfile's, so the pin
  // here is not against drift between copies but against losing the line — a
  // header block edited away would fail no local check at all, like the app's
  // stale CSP before the deploy probe existed.
  test("the Caddyfile also carries the site's own policy, with its two grants", () => {
    let site =
      caddyPolicies()
      ->Array.find(policy => !(policy->String.includes("require-trusted-types-for")))
      ->Option.getOr("")
    // Pirsch loads and reports from its own origin on the site (no /pa proxy
    // there), and the /dati explorer fetches the open-data service directly.
    expect(site->String.includes("script-src 'self' 'unsafe-inline' https://api.pirsch.io"))->toBe(true)
    expect(site->String.includes("https://data.reactivenet.ai"))->toBe(true)
    expect(site->String.includes("frame-ancestors 'none'"))->toBe(true)
  })

  test("the analytics script has an origin to load from in every copy", () => {
    // index.html loads Pirsch's snippet straight from api.pirsch.io. Granted in the
    // meta tag and refused by a server's header, the intersection refuses it — and
    // the error names the meta tag, which is the copy that is right.
    expect(headerPolicy()->String.includes("https://api.pirsch.io"))->toBe(true)
    expect(caddyPolicy()->String.includes("https://api.pirsch.io"))->toBe(true)
  })

  test("the tokens ::python depends on are in both", () => {
    let policy = headerPolicy()
    expect(policy->String.includes("'wasm-unsafe-eval'"))->toBe(true)
    // Pyodide's package CDN rides on the https: grant that ::api-query and the
    // map tiles introduced; the explicit jsdelivr token was folded into it.
    expect(policy->String.includes("connect-src 'self' https:"))->toBe(true)
    expect(policy->String.includes("worker-src 'self' blob:"))->toBe(true)
  })

  // The outward-looking directives each depend on one grant; losing it would
  // break them only on the deploys nobody tests locally, like ::python before.
  test("the grants ::map and ::api-query depend on are in both", () => {
    let policy = headerPolicy()
    expect(policy->String.includes("img-src 'self' data: https:"))->toBe(true)
  })
})
