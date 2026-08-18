/***
Turns raw HTML into markup that is safe to insert.

`trustedHtml` is abstract on purpose: the only way to obtain one is `toTrustedHtml`,
which runs DOMPurify inside the "markdown" Trusted Types policy. Assigning an
unsanitised string to innerHTML is therefore not something this module lets you do.
*/

type trustedHtml

let toTrustedHtml: string => trustedHtml

/** Assigns sanitised markup to an element. Takes [trustedHtml], never a string. */
let setInnerHtml: (Dom.element, trustedHtml) => unit

/** Sanitises to a plain string. For [TrustedTypes], which wraps the result itself. */
let sanitizeToString: string => string
