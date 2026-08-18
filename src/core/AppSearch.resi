/** True when every word of the query appears in the app's title, id, description or
    author. An empty query matches everything. */
let matches: (AppDocument.summary, string) => bool

/** The apps a query keeps, in the order they were given. */
let filter: (array<AppDocument.summary>, string) => array<AppDocument.summary>
