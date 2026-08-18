/** One line of the published catalogue's index. */
type entry = {id: string, title: string, version: string}

/** An update this browser could take, and everything the question about it needs. */
type offer = {
  id: string,
  installedTitle: string,
  publishedTitle: string,
  installed: string,
  published: string,
}

/** Negative when the first version is older, zero when the two are the same version,
    positive when it is newer. Dotted segments, compared as numbers where both are
    numbers — "1.10" is after "1.9" — and a missing segment is zero. */
let compare: (string, string) => int

/** Whether the catalogue's version is newer than the installed one. Either version
    unwritten answers false: an update announced on a comparison with nothing is a
    fact invented rather than read. */
let isNewer: (~installed: string, ~published: string) => bool

/** The apps this browser has and the catalogue publishes a newer version of. */
let offers: (
  ~installed: array<AppDocument.summary>,
  ~published: array<entry>,
) => array<offer>

/** The offer concerning one app, when there is one. */
let offerFor: (~id: string, ~offers: array<offer>) => option<offer>
