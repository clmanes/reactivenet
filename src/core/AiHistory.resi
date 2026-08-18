/** Pure. Compacts a conversation's past before it is replayed to the model: old
    tool answers and tool-call arguments — the documents, the reports — are elided
    beyond a ceiling with a note saying how to get them back, and a conversation
    grown past [maxMessages] loses whole exchanges from the front, cut at a user
    message so every tool call keeps its result. Idempotent. */

let ceiling: int

let kept: int

let maxMessages: int

let compact: array<JSON.t> => array<JSON.t>
