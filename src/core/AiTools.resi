/** Pure. Which tools this browser answers itself, and what they look like on the
    wire.

    Everything grammatical — guide, catalogue, validation, analysis, share link — is
    the MCP server's, because that server answers those questions by importing this
    app's own compiled core; a second implementation here could disagree with the app
    about what a directive means. What the MCP server cannot answer is anything about
    *this* browser, so the four tools that read and write the stored apps are
    answered locally. [isLocal] is the only place that split is written down. */

let listApps: string
let readApp: string
let createApp: string
let editApp: string

let local: array<string>

let isLocal: string => bool

/** The four local tools as OpenAI function declarations. Their descriptions are in
    English and addressed to the model, exactly as the MCP server's are: they are not
    interface text and are not translated. */
let declarations: array<JSON.t>
