/** Markdown (GFM, single newlines as breaks) to HTML, for one message. No
    directives, no math: a message is text somebody sent, not a document that runs.
    The result is NOT yet safe to insert — it must go through [Sanitizer]. */
let toHtml: string => string
