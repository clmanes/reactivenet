// Pure. The two fields every stored row carries.
//
// They are ordinary fields rather than a separate part of the record, so a template
// shows them with `{createdAt}` and an aggregation summarises them with
// `field="updatedAt"` — no machinery beyond a reserved pair of names. The price is
// that the names are reserved: a form field called `createdAt` would be overwritten
// silently, so `apply` drops the author's version rather than letting the two fight.

let created = "createdAt"
let updated = "updatedAt"
let reserved = [created, updated]

let isReserved = name => reserved->Array.some(known => known->String.toLowerCase == name->String.toLowerCase)

let without = fields => fields->Array.filter((field: Collection.field) => !isReserved(field.name))

/** Stamps a row. `~created` is passed when the row is being created; when it is
    absent the existing creation time is kept, because only the modification time
    changes on an edit. */
let apply = (fields, ~now, ~createdAt=?) => {
  let user = without(fields)
  let creation: Collection.field = {
    name: created,
    value: createdAt->Option.getOr(now),
  }
  let modification: Collection.field = {name: updated, value: now}
  user->Array.concat([creation, modification])
}

/** The creation time already on a row, for an edit that must not reset it. */
let createdOf = record => Collection.field(record, created)
