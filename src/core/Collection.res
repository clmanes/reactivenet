// Pure. A collection is an ordered list of records; a record is an ordered list of
// named fields plus an id.
//
// Ordered rather than a dictionary because the field order an author wrote is what a
// table or list renders, and because a document format should round-trip to exactly
// what went in. The id is explicit rather than positional: deleting record 2 must not
// silently renumber every reference to record 3.

type field = {
  name: string,
  value: string,
}

type record = {
  id: string,
  fields: array<field>,
}

type t = {records: array<record>}

let empty = {records: []}

let field = (record, name) => {
  let needle = name->String.toLowerCase
  record.fields
  ->Array.find(field => field.name->String.toLowerCase == needle)
  ->Option.map(field => field.value)
}

let find = (collection, id) => collection.records->Array.find(record => record.id == id)

// Ids are supplied by the caller rather than generated here: generation needs a clock
// or a random source, and this module has to stay deterministic.
let insert = (collection, record) => {
  records: collection.records->Array.concat([record]),
}

let remove = (collection, id) => {
  records: collection.records->Array.filter(record => record.id != id),
}

// Replaces the named fields and leaves the rest of the record alone, so a form that
// edits two fields does not erase the others.
let update = (collection, id, changes) => {
  records: collection.records->Array.map(record =>
    record.id != id
      ? record
      : {
          id: record.id,
          fields: changes->Array.reduce(record.fields, (fields, change) =>
            fields->Array.some(field =>
              field.name->String.toLowerCase == change.name->String.toLowerCase
            )
              ? fields->Array.map(field =>
                  field.name->String.toLowerCase == change.name->String.toLowerCase
                    ? {name: field.name, value: change.value}
                    : field
                )
              : fields->Array.concat([change])
          ),
        }
  ),
}

let size = collection => collection.records->Array.length

let isEmpty = collection => size(collection) == 0
