/** Spectrum's generated components, each carrying the global attributes the
    manifests omit. Every consumer — renderer, block specs, editor completions —
    reads this, not the generated file directly. */
let all: array<SpectrumRegistry.component>

/** Attributes every element accepts, absent from the manifests because they are
    HTML's rather than Spectrum's. */
let global: array<SpectrumRegistry.attribute>

/** ReactiveNET's own directives — pages, forms, lists, aggregations — described in
    the same shape so every consumer reads one list. */
let reactive: array<SpectrumRegistry.component>

let find: string => option<SpectrumRegistry.component>
