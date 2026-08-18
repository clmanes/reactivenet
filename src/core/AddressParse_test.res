open BunTest

describe("AddressParse", () => {
  let parti = testo =>
    switch AddressParse.parse(testo) {
    | None => "—"
    | Some(a) => `${a.odonimo}|${a.civico}|${a.esponente}|${a.comune}`
    }

  test("la forma comune: via, numero, comune", () => {
    expect(parti("Via Lucana 53, Matera"))->toBe("Via Lucana|53||Matera")
    expect(parti("Piazza del Plebiscito 1, Napoli"))->toBe("Piazza del Plebiscito|1||Napoli")
  })

  // Il CAP davanti e la sigla in coda sono l'ornamento più frequente di un indirizzo
  // copiato da una lettera, e nessuno dei due è il nome del comune.
  test("il comune si spoglia di CAP e sigla di provincia", () => {
    expect(parti("Via Roma 1, 75100 Matera"))->toBe("Via Roma|1||Matera")
    expect(parti("Via Roma 1, Matera (MT)"))->toBe("Via Roma|1||Matera")
    expect(parti("Via Roma 1, 75100 Matera (MT)"))->toBe("Via Roma|1||Matera")
    expect(parti("Via Roma 1, Matera - MT"))->toBe("Via Roma|1||Matera")
  })

  test("l'esponente sta attaccato o dopo una barra", () => {
    expect(parti("Via Roma 12/A, Torino"))->toBe("Via Roma|12|A|Torino")
    expect(parti("Via Roma 12A, Torino"))->toBe("Via Roma|12|A|Torino")
    expect(parti("Via Roma 12 / a, Torino"))->toBe("Via Roma|12|A|Torino")
  })

  // "Via Lucana, 53, Matera" è come lo scrive mezza Italia: il numero è un pezzo suo.
  test("il numero può essere il pezzo di mezzo", () => {
    expect(parti("Via Lucana, 53, Matera"))->toBe("Via Lucana|53||Matera")
    expect(parti("Via Lucana, 53/B, Matera"))->toBe("Via Lucana|53|B|Matera")
  })

  // Una via senza numero resta una ricerca sensata: si trova la strada.
  test("il civico può mancare", () => {
    expect(parti("Via Lucana, Matera"))->toBe("Via Lucana|||Matera")
  })

  // Il caso che conta: senza strada o senza comune NON si cerca. Cercare a metà
  // trova un punto, e un punto sbagliato su una mappa non si distingue da uno giusto.
  test("un indirizzo a metà non si cerca", () => {
    expect(parti("Matera"))->toBe("—")
    expect(parti(""))->toBe("—")
    expect(parti("   "))->toBe("—")
    expect(parti(", , "))->toBe("—")
    expect(parti("Via Lucana 53, 75100"))->toBe("—")
  })

  // Un numero nel nome della via non è un civico, e il civico si stacca solo se sta
  // in CODA: "Via 4 Novembre" resta intera, "Via 4 Novembre 12" perde il 12.
  test("un numero dentro il nome resta nel nome", () => {
    expect(parti("Via 4 Novembre, Roma"))->toBe("Via 4 Novembre|||Roma")
    expect(parti("Via 4 Novembre 12, Roma"))->toBe("Via 4 Novembre|12||Roma")
    expect(parti("Via XXV Aprile 3, Milano"))->toBe("Via XXV Aprile|3||Milano")
  })
})
