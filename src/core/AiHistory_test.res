open BunTest

// Plain JS builders: the histories under test are wire JSON, and building them
// through a helper keeps each case about what it asserts.
let toolMsg: string => JSON.t = %raw(`
function (content) { return { role: "tool", tool_call_id: "c1", content }; }
`)
let userMsg: string => JSON.t = %raw(`function (text) { return { role: "user", content: text }; }`)
let assistantWithCall: string => JSON.t = %raw(`
function (markdown) {
  return {
    role: "assistant",
    content: "",
    tool_calls: [{ id: "c1", function: { name: "reactive_create_app", arguments: JSON.stringify({ markdown }) } }],
  };
}
`)
let assistantWithNativeCall: string => JSON.t = %raw(`
function (markdown) {
  return {
    role: "assistant",
    content: "",
    tool_calls: [{ id: "c1", function: { name: "reactive_create_app", arguments: { markdown } } }],
  };
}
`)
let contentOf: JSON.t => string = %raw(`function (m) { return m.content; }`)
let argumentsOf: JSON.t => string = %raw(`
function (m) {
  const a = m.tool_calls[0].function.arguments;
  return typeof a === "string" ? a : JSON.stringify(a);
}
`)
let roleOf: JSON.t => string = %raw(`function (m) { return m.role; }`)

let long = "x"->String.repeat(3000)

describe("AiHistory.compact", () => {
  test("a long tool answer is elided with a note saying how to get it back", () => {
    let compacted = AiHistory.compact([toolMsg(long)])
    let content = compacted->Array.getUnsafe(0)->contentOf
    expect(content->String.length < 500)->toBe(true)
    expect(content->String.includes("elided"))->toBe(true)
  })

  test("a short tool answer is left exactly as it was", () => {
    let compacted = AiHistory.compact([toolMsg("ok — the document is valid.")])
    expect(compacted->Array.getUnsafe(0)->contentOf)->toBe("ok — the document is valid.")
  })

  // The delivery call carries the whole app document in its arguments — the single
  // heaviest thing in a building conversation, in both wire shapes.
  test("long tool-call arguments are elided, string and object shape alike", () => {
    let openai = AiHistory.compact([assistantWithCall(long)])
    expect(openai->Array.getUnsafe(0)->argumentsOf->String.length < 600)->toBe(true)
    let native = AiHistory.compact([assistantWithNativeCall(long)])
    expect(native->Array.getUnsafe(0)->argumentsOf->String.length < 600)->toBe(true)
  })

  test("compacting twice is the same as compacting once", () => {
    let once = AiHistory.compact([toolMsg(long), assistantWithCall(long)])
    expect(AiHistory.compact(once))->toEqual(once)
  })

  // Dropping must never orphan a tool result from its call: the cut lands on a
  // user message, which starts a fresh exchange.
  test("an over-long conversation is cut from the front, at a user message", () => {
    let exchange = i => [
      userMsg("question " ++ Int.toString(i)),
      assistantWithCall("doc"),
      toolMsg("answer"),
    ]
    let history = Array.fromInitializer(~length=30, exchange)->Array.flat
    let compacted = AiHistory.compact(history)
    expect(compacted->Array.length <= AiHistory.maxMessages)->toBe(true)
    expect(compacted->Array.getUnsafe(0)->roleOf)->toBe("user")
  })

  test("a short conversation keeps its length", () => {
    let history = [userMsg("ciao"), toolMsg("ok")]
    expect(AiHistory.compact(history)->Array.length)->toBe(2)
  })
})
