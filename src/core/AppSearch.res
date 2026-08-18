// Pure. Which apps a query keeps.
//
// Matching is over the fields the gallery already shows — title, id, description,
// author — because a search that finds something the card does not mention reads as
// a bug. It is case-insensitive and matches anywhere in the field rather than only at
// the start: an id like `registro-voti` should be findable by typing `voti`.
//
// Every space-separated word must match somewhere. That is the behaviour people
// expect from a search box, and it is the one that narrows as you keep typing.

let haystack = (app: AppDocument.summary) =>
  [app.title, app.id, app.description, app.author]->Array.join(" ")->String.toLowerCase

let words = query =>
  query->String.trim->String.toLowerCase->String.split(" ")->Array.filter(word => word != "")

let matches = (app, query) => {
  let text = haystack(app)
  words(query)->Array.every(word => text->String.includes(word))
}

let filter = (apps, query) =>
  words(query)->Array.length == 0 ? apps : apps->Array.filter(app => matches(app, query))
