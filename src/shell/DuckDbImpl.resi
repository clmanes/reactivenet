/** DuckDB-wasm, statically imported here and nowhere else: reach this module
    only through a dynamic `import()`. The engine downloads from the CDN on
    first use and stays in the browser's cache. */

let run: ({..}, string, array<string>, int) => promise<array<{..}>>
