---
title: "Il server MCP"
seotitle: "Server MCP: scrivere app con un modello"
description: "Collegare un modello a ReactiveNET: otto strumenti per scrivere un'app, verificarla e consegnarla, con la garanzia che a rispondere è la grammatica vera."
weight: 50
translationKey: "mcp"
---

Le pagine precedenti sono il riferimento di chi scrive le direttive a mano.
Questa è per chi vuole che a scriverle sia un modello — il proprio, in un client
qualunque che parli **MCP**.

Il server dà al modello quello che gli manca per fare un lavoro utile qui:
la documentazione, il catalogo delle direttive con gli attributi tipizzati, le
app di esempio, il catalogo open data, un **validatore**, un **analizzatore del
flusso dei dati** e il costruttore del link di consegna.

## L'indirizzo

```
https://mcp.reactivenet.ai/mcp
```

Trasporto **Streamable HTTP**, nessuna autenticazione. Un client MCP si
configura di solito con un oggetto come questo:

```json
{
  "mcpServers": {
    "reactivenet": {
      "type": "http",
      "url": "https://mcp.reactivenet.ai/mcp"
    }
  }
}
```

In locale, con il repository a disposizione: `bun run mcp`, e l'indirizzo
diventa `http://localhost:8789/mcp`.

> L'assistente **dentro l'app** usa lo stesso server, raggiunto come `/mcp`
> sulla propria origine. Non è una comodità: l'endpoint del modello è
> configurabile e quello degli strumenti no, quindi nessuna impostazione e
> nessun documento possono puntarlo altrove.

## Perché non chiede una password

Perché non c'è niente da proteggere. Il server **non tocca i dati di nessuno**,
non apre nessun canale verso un browser, non scrive niente su disco. È un server
di **funzioni pure** — guida, catalogo, validazione, analisi, codifica — più una
sola lettura verso l'esterno, il catalogo open data.

Quello che resta da difendere è la disponibilità del servizio, e per quella c'è
un limite di frequenza per indirizzo (`MCP_RATE`, 120 richieste al minuto).
`MCP_TOKEN` accende l'autenticazione bearer per chi la vuole.

## La garanzia che conta

**Ogni risposta grammaticale viene dal nucleo compilato dell'app.** Il catalogo
delle direttive è lo stesso `DirectiveRegistry` che il renderer legge; lo
scanner è lo stesso `DirectiveScan` che gira nella pipeline Markdown e
nell'editor a blocchi; il parser degli attributi è lo stesso, virgolette
comprese, quindi il `{5}` di un'espressione regolare non chiude la lista degli
attributi né qui né là; il link è quello che l'app stessa produce, byte per
byte.

Se questo server dicesse «ok» di un documento che l'app legge in un altro modo,
l'intero strumento non servirebbe a niente. Importare il nucleo compilato è
quello che rende quel disaccordo impossibile.

## Gli otto strumenti

| Strumento | Che cosa risponde |
| --- | --- |
| `reactive_guide` | La documentazione, una sezione per volta. Senza argomenti dà l'indice |
| `reactive_directives` | Il catalogo delle direttive con la forma (inline, leaf, container) e gli attributi tipizzati |
| `reactive_examples` | App complete da cui partire: `welcome` e `starter` in sette lingue, più le ricette per casi reali |
| `reactive_od_catalog` | I dataset del servizio open data: tabelle, colonne e tipi |
| `reactive_od_query` | **Esegue** la SELECT invece di leggerne lo schema: il catalogo dice che esiste la colonna `regione`, solo l'esecuzione dice che contiene `'Puglia'` e non `'PUGLIA'` |
| `reactive_validate` | Controlla il documento con la grammatica vera e riporta ogni problema **col numero di riga** |
| `reactive_analyze` | Il flusso dei dati: chi scrive ogni collezione e chi la legge, e che cosa non si incontra |
| `reactive_app_link` | Valida e costruisce il link che apre l'app nella galleria di chi lo riceve |

Sono **tutti in sola lettura**. `reactive_validate` e `reactive_analyze`
restituiscono anche `structuredContent` accanto al testo, per chi preferisce
leggere un oggetto invece di una relazione.

### La differenza fra validare e analizzare

`reactive_validate` guarda **una direttiva per volta**: il nome esiste, gli
attributi sono quelli giusti, il valore è ammesso, il contenitore è chiuso.
Riporta anche le trappole che validano e tradiscono a runtime — un campo fuori
da un modulo, un `:value` con una chiave nuda, un colore esadecimale letto come
`#riferimento`, e un `::workflow` la cui pianificazione non si legge — `every="10
minuti"` o `at="18"` lascia il workflow **manuale** senza che niente lo dica, e
questa è esattamente la classe di guasto che un validatore esiste per prendere.

`reactive_analyze` guarda se **i pezzi si incontrano**, che è quello che la
grammatica non può vedere da sola: una vista su una collezione che nessuno
scrive resterà vuota per sempre; un `#ref` che nessuna sorgente alimenta non si
aggiornerà mai; un modulo senza `::save` non salverà niente; un `editform` che
nomina un modulo inesistente non aprirà niente. Sono i guasti che non danno
errore — l'app si apre e non fa quello che deve.

## Le risorse e i due prompt

Gli **otto documenti della guida** sono anche risorse MCP, con URI stabili
(`reactive://guide/<nome>`): `language`, `authoring`, `directives`, `storage`,
`security`, `accessibility`, `rbac`, `architecture`. Un client che sa
sfogliarle o appuntarle le trova lì.

Due **prompt** impacchettano i due lavori:

- **`build-app`** — da una richiesta in parole a un'app consegnata, seguendo
  l'ordine per cui gli strumenti sono fatti.
- **`review-app`** — valida e analizza un documento esistente e dice che cosa
  correggere, con i numeri di riga.

## Il flusso di lavoro

È quello che `build-app` detta, e vale la pena conoscerlo anche scrivendo a
mano:

1. `reactive_guide` senza argomenti per l'indice, poi il documento `language` e
   le sezioni che servono.
2. `reactive_examples`: si parte da quella più vicina. **Adattare un esempio che
   funziona è molto più affidabile che montare direttive una per una.**
3. Se l'app legge open data italiani, `reactive_od_catalog` **prima** di
   scrivere il SELECT: si controlla che `provincia` sia davvero una colonna di
   `farmacie` invece di scoprirlo dopo.
4. Si scrive il documento completo, frontmatter compreso.
5. `reactive_validate`, e si corregge finché non risponde `ok`.
6. `reactive_analyze`, e si corregge ogni segnalazione.
7. `reactive_app_link`, e il link si dà alla persona.

I passi 5 e 6 non sono un consiglio: **`reactive_app_link` valida per conto
proprio e rifiuta**. Un documento che non passa non diventa un link, e la
relazione torna indietro al posto del link. Lo stesso vale per gli strumenti che
l'assistente dentro l'app usa per creare e modificare un'app.

Il motivo è stato osservato, non immaginato: i modelli piccoli semplicemente non
validano quando glielo si chiede a parole. La prima app scritta qui è stata
creata *e poi* validata, il che ha messo una `::list` rotta nella galleria di
qualcuno.

## Farlo girare da sé

```sh
bun run res:build   # gli import sono i .res.mjs compilati
bun run mcp         # porta 8789
```

Gira sotto **bun** e non sotto node, perché importa il nucleo compilato
dell'app. Le variabili d'ambiente, coi loro valori di default:

| | |
| --- | --- |
| `MCP_PORT` | `8789` |
| `MCP_APP_URL` | `http://localhost:5173` — l'origine a cui puntano i link |
| `MCP_OD_URL` | `http://127.0.0.1:8788` — il servizio open data che il catalogo legge |
| `MCP_TOKEN` | vuoto; impostato, richiede `Authorization: Bearer <token>` su `/mcp` |
| `MCP_RATE` | `120` richieste al minuto per indirizzo |

Il controllo di salute resta aperto anche con `MCP_TOKEN` impostato: serve a un
supervisore, e non custodisce niente.
