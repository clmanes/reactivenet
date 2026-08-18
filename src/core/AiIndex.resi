/** Pure. The arithmetic of semantic search: how a document is cut into passages, and
    which passages a question is nearest to. Reading the rows, decoding an attachment
    and asking a model for vectors are the binder's; this is the part that has to be
    the same on every device. */

type item = {key: string, label: string, text: string, vector: array<float>}

type hit = {item: item, score: float}

/** A text as the passages it will be searched by: `size` characters each, cut at a
    sentence, overlapping by a fifth. */
let chunks: (string, int) => array<string>

/** A vector of length one — stored this way so a cosine is a dot product. */
let normalise: array<float> => array<float>

/** The cosine of two normalised vectors. Zero for vectors of different lengths:
    those are two different models' work and have no angle between them. */
let cosine: (array<float>, array<float>) => float

/** The nearest passages, best first, at most one per source, dropping everything
    below `floor` — "no match" is a better answer than the least bad one. */
let rank: (array<float>, array<item>, ~many: int, ~floor: float) => array<hit>

/** The passages as a model should receive them: named, so it can cite them. */
let context: array<hit> => string
