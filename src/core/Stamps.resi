/** The reserved field names every stored row carries. */
let created: string
let updated: string
let reserved: array<string>

let isReserved: string => bool

/** The author's fields with the reserved names removed. */
let without: array<Collection.field> => array<Collection.field>

/** Fields with both stamps set. Omit `createdAt` to stamp a new row; pass the row's
    existing one to keep it across an edit. */
let apply: (
  array<Collection.field>,
  ~now: string,
  ~createdAt: string=?,
) => array<Collection.field>

let createdOf: Collection.record => option<string>
