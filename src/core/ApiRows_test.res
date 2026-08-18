open BunTest

let json = text => JSON.parseExn(text)

let names = fields => fields->Array.map(field => field.Collection.name)->Array.join(",")
let value = (fields, name) =>
  fields
  ->Array.find(field => field.Collection.name == name)
  ->Option.map(field => field.Collection.value)

describe("ApiRows.picked", () => {
  test("walks names and indices", () => {
    let found = ApiRows.picked(json(`{"results":[{"series":[1,2]}]}`), "results.0.series")
    expect(found->Option.map(JSON.stringify(_)))->toEqual(Some("[1,2]"))
  })

  test("a path off the document is nothing", () => {
    expect(ApiRows.picked(json(`{"a":1}`), "b.c")->Option.isNone)->toBe(true)
  })

  test("an empty pick is the root", () => {
    expect(ApiRows.picked(json(`{"a":1}`), "")->Option.isNone)->toBe(false)
  })
})

describe("ApiRows.rows", () => {
  test("an array of objects is rows already", () => {
    let rows = ApiRows.rows(json(`[{"a":1,"b":"x"},{"a":2,"b":"y"}]`), ~pairs=false)->Option.getExn
    expect(rows->Array.length)->toBe(2)
    expect(rows->Array.getUnsafe(0)->value("a"))->toEqual(Some("1"))
    expect(rows->Array.getUnsafe(1)->value("b"))->toEqual(Some("y"))
  })

  // Open-Meteo's shape: {"time": [...], "temp": [...]}.
  test("an object of arrays zips by index", () => {
    let rows =
      ApiRows.rows(json(`{"time":["h1","h2","h3"],"temp":[20,21]}`), ~pairs=false)->Option.getExn
    expect(rows->Array.length)->toBe(3)
    expect(rows->Array.getUnsafe(0)->names)->toBe("time,temp")
    expect(rows->Array.getUnsafe(1)->value("temp"))->toEqual(Some("21"))
    // The shorter column pads with the empty string.
    expect(rows->Array.getUnsafe(2)->value("temp"))->toEqual(Some(""))
  })

  test("an object of scalars is one row, or pairs when asked", () => {
    let one = ApiRows.rows(json(`{"USD":1.08,"GBP":0.85}`), ~pairs=false)->Option.getExn
    expect(one->Array.length)->toBe(1)
    let pairs = ApiRows.rows(json(`{"USD":1.08,"GBP":0.85}`), ~pairs=true)->Option.getExn
    expect(pairs->Array.length)->toBe(2)
    expect(pairs->Array.getUnsafe(0)->value("key"))->toEqual(Some("USD"))
    expect(pairs->Array.getUnsafe(0)->value("value"))->toEqual(Some("1.08"))
  })

  test("a bare scalar is no rows: the key form reads those", () => {
    expect(ApiRows.rows(json(`42`), ~pairs=false)->Option.isNone)->toBe(true)
    expect(ApiRows.scalar(json(`42`)))->toEqual(Some("42"))
    expect(ApiRows.scalar(json(`{"a":1}`))->Option.isNone)->toBe(true)
  })

  test("nested structures flatten to their JSON", () => {
    let rows = ApiRows.rows(json(`[{"a":{"b":1}}]`), ~pairs=false)->Option.getExn
    expect(rows->Array.getUnsafe(0)->value("a"))->toEqual(Some(`{"b":1}`))
  })
})
