open BunTest

describe("AiSettings.normalize", () => {
  test("an empty model or endpoint falls back to the default", () => {
    let normalized = AiSettings.normalize({key: " sk-abc ", model: "  ", baseUrl: ""})
    expect(normalized.key)->toBe("sk-abc")
    expect(normalized.model)->toBe(AiSettings.defaultModel)
    expect(normalized.baseUrl)->toBe(AiSettings.hostedBaseUrl)
  })

  // Everybody pastes the trailing slash, and the endpoint is built by concatenation.
  test("trailing slashes come off the endpoint", () => {
    let normalized = AiSettings.normalize({
      key: "k",
      model: "gpt-4.1",
      baseUrl: "https://example.test/v1//",
    })
    expect(normalized.baseUrl)->toBe("https://example.test/v1")
  })
})

describe("AiSettings.check", () => {
  test("a remote provider without a key cannot be called", () => {
    expect(AiSettings.check({...AiSettings.blank, key: "   "}))->toEqual(Some(AiSettings.NoKey))
  })

  // The grant in connect-src is bounded to the loopback host, which is the one place
  // a browser will not carry the request off the machine. Another address on the
  // network is somebody else's computer and is refused here, in the form where it was
  // typed, rather than by the policy — which would block it with no explanation.
  test("http elsewhere is refused here rather than by the policy", () => {
    expect(
      AiSettings.check({key: "k", model: "m", baseUrl: "http://192.168.1.4:11434/v1"}),
    )->toEqual(Some(AiSettings.NotHttps))
  })

  test("a model on this machine needs no key: there is no secret to ask for", () => {
    expect(AiSettings.isReady(AiSettings.onOllama))->toBe(true)
    expect(AiSettings.isLocal(AiSettings.onOllama))->toBe(true)
    // Every spelling of the loopback host, on any port.
    expect(AiSettings.isLocal({...AiSettings.blank, baseUrl: "http://127.0.0.1:1234/v1"}))->toBe(
      true,
    )
    // Not accepted, deliberately: CSP's host grammar cannot write an IPv6 literal,
    // so this would be an endpoint the form allows and the policy blocks.
    expect(AiSettings.isLocal({...AiSettings.blank, baseUrl: "http://[::1]:8080/v1"}))->toBe(false)
    // Not the loopback host: `localhost.example.com` is somebody's domain.
    expect(
      AiSettings.isLocal({...AiSettings.blank, baseUrl: "http://localhost.example.com/v1"}),
    )->toBe(false)
  })

  test("a key and an https endpoint are ready", () => {
    expect(AiSettings.isReady({...AiSettings.blank, key: "sk-abc"}))->toBe(true)
    expect(AiSettings.isLocal({...AiSettings.blank, key: "sk-abc"}))->toBe(false)
  })
})

describe("AiSettings.completionsUrl", () => {
  test("is the endpoint plus the chat completions path", () => {
    expect(
      AiSettings.completionsUrl({key: "k", model: "m", baseUrl: "https://example.test/v1/"}),
    )->toBe("https://example.test/v1/chat/completions")
  })

  test("the same concatenation builds the local one", () => {
    expect(AiSettings.completionsUrl(AiSettings.onOllama))->toBe(
      "http://localhost:11434/v1/chat/completions",
    )
  })

  // The native endpoint sits beside /v1, not under it: the benched, more reliable
  // wire for a local model. An endpoint without the /v1 suffix must still work.
  test("the native chat endpoint drops the /v1 layer", () => {
    expect(AiSettings.nativeChatUrl(AiSettings.onOllama))->toBe("http://localhost:11434/api/chat")
    expect(
      AiSettings.nativeChatUrl({...AiSettings.onOllama, baseUrl: "http://127.0.0.1:11434"}),
    )->toBe("http://127.0.0.1:11434/api/chat")
  })
})
