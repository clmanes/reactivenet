/***
An href that has been checked against a scheme allowlist.

The point of this signature is that `t` is abstract: `parse` is the only way to build
one, so "unvalidated string used as an href" is not a mistake you can make — it does
not typecheck. Rendering code takes a `t`, never a `string`.
*/

type t

type error =
  | Empty
  | ProtocolRelative
  | DisallowedScheme(string)

let allowedSchemes: array<string>

/** Rejects `javascript:`, `data:`, and anything else outside `allowedSchemes`.
    Control characters are stripped first, so `java\tscript:` cannot slip through. */
let parse: string => result<t, error>

/** The normalised href, safe to hand to an `href`/`src` attribute. */
let toString: t => string

let errorToString: error => string
