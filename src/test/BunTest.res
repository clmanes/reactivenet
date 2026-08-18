// Bindings to bun's built-in test runner. Only test modules import this, so it never
// reaches the app bundle.

type expectation

@module("bun:test") external describe: (string, unit => unit) => unit = "describe"
@module("bun:test") external test: (string, unit => unit) => unit = "test"
@module("bun:test") external expect: 'a => expectation = "expect"

@send external toBe: (expectation, 'a) => unit = "toBe"
@send external toEqual: (expectation, 'a) => unit = "toEqual"
