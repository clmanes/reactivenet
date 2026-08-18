/** The path the catalogue answers on, on this app's own origin. */
let prefix: string

/** The document of one catalogue app. `missing` distinguishes "the catalogue does
    not have it" from "the catalogue did not answer", which need different words. */
let fetchDocument: string => promise<{"text": option<string>, "missing": bool}>

/** What the catalogue holds, or an empty list when it cannot be reached. The version
    is what `CatalogUpdate` compares against an installed app's own. */
let fetchIndex: unit => promise<
  array<{"id": string, "title": string, "description": string, "version": string}>,
>
