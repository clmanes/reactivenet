// Which models the local daemon actually has.
//
// This exists so the settings form can offer a list instead of a text field, and the
// difference is not cosmetic: a model name typed from memory is the single most
// common way this ends in a 404, and the names are long, versioned and unguessable
// (`qwen3.5:4b`, not `qwen`). A hosted provider gets a text field, because there the
// list is a catalogue of hundreds that changes weekly and the account decides which
// of them answer.
//
// Ollama publishes `capabilities` per model, and `tools` is the one that matters
// here: a model that cannot call a tool cannot read the directive catalogue, and an
// assistant that cannot read the catalogue invents directives — which render as
// their own source text. So the incapable ones are marked rather than silently
// offered as equals.
//
// The endpoint is derived from the one already configured, not written twice:
// `…:11434/v1` for the chat, `…:11434/api/tags` for this. A daemon that answers
// neither is simply not there, which is an empty list and not an error.

type model = {name: string, tools: bool}

let installed: (~baseUrl: string) => promise<array<model>> = %raw(`
async function (baseUrl) {
  // Ollama's own API sits beside its OpenAI-compatible one, not under it.
  const root = String(baseUrl).replace(/\/v1$/, "");
  try {
    const response = await fetch(root + "/api/tags");
    if (!response.ok) return [];
    const answer = await response.json();
    if (!answer || !Array.isArray(answer.models)) return [];
    return answer.models
      .map(model => ({
        name: String(model.name || model.model || ""),
        // Absent on older daemons, where "we do not know" has to read as yes: marking
        // every model incapable would leave the list empty and unusable.
        tools: !Array.isArray(model.capabilities) || model.capabilities.includes("tools"),
      }))
      .filter(model => model.name !== "");
  } catch (error) {
    return [];
  }
}
`)
