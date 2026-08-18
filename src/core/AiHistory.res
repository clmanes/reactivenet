// Pure. What an old conversation weighs when it is sent again.
//
// Every request replays the whole wire history, and the bulk of a building
// conversation is not conversation: it is tool traffic — the starter document, the
// catalogue answers, the validation reports, and above all the complete app
// document inside every delivery call's arguments. All of it mattered in the turn
// that produced it and almost none of it matters afterwards; the model can call the
// tool again if it truly needs the text back. So when a new question starts, the
// past is compacted: tool answers and tool-call arguments are elided beyond a
// ceiling, with a note saying so. The current run is never touched, because the
// loop only compacts what it inherited.
//
// What is deliberately NOT done is dropping messages one by one. The OpenAI format
// requires a tool result to follow the assistant message that called it, and a
// history that violates that is a 400 — so when the conversation grows past
// `maxMessages`, whole exchanges are dropped from the FRONT, cut at a user
// message, which is the one boundary that keeps every pairing intact.
//
// The elision marker stays well under the ceiling, so compacting twice is the same
// as compacting once.

/** Past this many characters, an old tool answer or argument is elided. High
    enough that ordinary answers survive whole — what it catches are documents and
    reports, which are kilobytes. */
let ceiling = 700

/** How much of an elided text is kept: the head, which for a document is the
    frontmatter and for a report is the verdict. */
let kept = 300

/** Past this many messages, whole exchanges are dropped from the front. */
let maxMessages = 60

let compact: array<JSON.t> => array<JSON.t> = %raw(`
function (history) {
  const CEILING = 700, KEPT = 300, MAX = 60;
  const elide = text =>
    typeof text === "string" && text.length > CEILING
      ? text.slice(0, KEPT) +
        "\n… [" + (text.length - KEPT) + " chars of an earlier turn elided — call the tool again if you need the rest]"
      : text;

  const messages = history.map(message => {
    if (!message || typeof message !== "object") return message;
    if (message.role === "tool") return { ...message, content: elide(message.content) };
    if (message.role === "assistant" && Array.isArray(message.tool_calls)) {
      return {
        ...message,
        tool_calls: message.tool_calls.map(call => {
          if (!call || !call.function) return call;
          const fn = call.function;
          // OpenAI carries arguments as a JSON string; Ollama's native shape as an
          // object whose long fields (a delivery's markdown) are the real weight.
          if (typeof fn.arguments === "string")
            return { ...call, function: { ...fn, arguments: elide(fn.arguments) } };
          if (fn.arguments && typeof fn.arguments === "object" && !Array.isArray(fn.arguments)) {
            const slimmed = {};
            for (const key of Object.keys(fn.arguments)) slimmed[key] = elide(fn.arguments[key]);
            return { ...call, function: { ...fn, arguments: slimmed } };
          }
          return call;
        }),
      };
    }
    return message;
  });

  if (messages.length <= MAX) return messages;
  // Drop from the front, but only ever land on a user message: any prefix removed
  // up to one leaves a history that starts a fresh exchange with every
  // call/result pairing intact.
  let start = messages.length - MAX;
  while (start < messages.length && !(messages[start] && messages[start].role === "user")) start++;
  return messages.slice(start);
}
`)
