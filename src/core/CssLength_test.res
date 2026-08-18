open BunTest

describe("CssLength.normalise", () => {
  // Il motivo per cui il modulo esiste. `height="520"` è quello che chiunque
  // scrive, e `setProperty("height", "520")` viene rifiutato dal parser CSS senza
  // eccezione e senza avviso: la mappa restava all'altezza di default e
  // l'attributo sembrava non fare niente.
  test("un numero nudo sono pixel", () => {
    expect(CssLength.normalise("520"))->toEqual(Some("520px"))
    expect(CssLength.normalise("0"))->toEqual(Some("0px"))
    expect(CssLength.normalise("32.5"))->toEqual(Some("32.5px"))
    expect(CssLength.normalise("  300  "))->toEqual(Some("300px"))
  })

  test("una lunghezza già scritta passa com'è", () => {
    expect(CssLength.normalise("520px"))->toEqual(Some("520px"))
    expect(CssLength.normalise("18rem"))->toEqual(Some("18rem"))
    expect(CssLength.normalise("50vh"))->toEqual(Some("50vh"))
    expect(CssLength.normalise("100%"))->toEqual(Some("100%"))
    expect(CssLength.normalise("calc(100% - 2rem)"))->toEqual(Some("calc(100% - 2rem)"))
  })

  test("niente non è una lunghezza", () => {
    expect(CssLength.normalise(""))->toEqual(None)
    expect(CssLength.normalise("   "))->toEqual(None)
  })

  // Quello che non è una lunghezza passa lo stesso, e deve: giudicarlo tocca al
  // parser CSS, che rifiuta l'intero valore in blocco. Questo modulo non è una
  // difesa e non deve sembrarlo — chi lo prendesse per tale smetterebbe di
  // passare da `setProperty`, che è la difesa vera.
  test("non giudica: quello che non è una lunghezza lo rifiuta il CSS", () => {
    expect(CssLength.normalise("rosso"))->toEqual(Some("rosso"))
    expect(CssLength.normalise("18rem; background: url(x)"))->toEqual(
      Some("18rem; background: url(x)"),
    )
  })

  test("un numero con l'unità attaccata non viene toccato due volte", () => {
    expect(CssLength.normalise("1e3"))->toEqual(Some("1e3"))
    expect(CssLength.normalise("-40"))->toEqual(Some("-40"))
  })
})
