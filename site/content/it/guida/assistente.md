---
title: "L'assistente dentro l'app"
description: "Le quindici direttive ai-*: riassumere, chiedere, compilare un modulo, lavorare una collezione, cercare per significato — con la regola che le rende sicure."
weight: 24
translationKey: "assistente"
---

Queste direttive mettono al lavoro il modello **dentro** l'app, non accanto.
Usano tutte l'unico modello configurato una volta sola nelle impostazioni
dell'assistente: un modello su questa macchina (Ollama), oppure un endpoint
compatibile OpenAI con la sua chiave.

**Dove vanno i dati è una proprietà dell'endpoint, non della direttiva.** Con un
modello locale non esce niente dal computer. Con un fornitore remoto, quello che
la direttiva mette nel prompt viene mandato a lui. È una frase sola e vale per
tutte e quindici; non c'è una direttiva più prudente di un'altra, c'è
un'impostazione.

Se non c'è nessun modello configurato, **ognuna disegna una riga che lo dice** e
l'app continua a funzionare. Un documento scritto per un modello non deve
diventare una pagina di controlli rotti su un browser che non ne ha uno.

## La regola che le rende sicure

Sono direttive che si trovano dentro documenti scritti da altri, quindi la
domanda giusta non è cosa sanno fare ma cosa non possono fare. La risposta è
una:

> **Il modello non produce mai niente che venga eseguito.**

Produce una parola presa da una lista chiusa che ha scritto il documento, oppure
un oggetto le cui chiavi ha dichiarato il documento, oppure un **piano di
interrogazione** in cui ogni nome di campo è stato verificato contro quelli che
la collezione ha davvero — e quel piano viene poi eseguito qui, sulle righe che
questo dispositivo ha già. Tutto il resto viene rifiutato prima di poter
diventare una riga.

È lo stesso argomento di `::python` e `::sql`: i dati viaggiano in un canale
loro e non vengono mai incollati dentro del codice.

## Leggere e chiedere

```markdown
::ai-summary{data="spese"}
Riassumi le spese: quanto, in che cosa, e che cosa è cambiato.
::/ai-summary

::ai-chat{data="allenamenti"}
Sei l'allenatore. Rispondi corto e in italiano.
::/ai-chat

::ai-query{data="spese" into="risposta" placeholder="Quanto ho speso in trasporti a giugno?"}
```

**`::ai-summary`** scrive un riassunto e **lo riscrive quando le righe
cambiano**. Il corpo — o `prompt=` — dice che cosa guardare. Viaggia solo un
campione delle righe, mai la collezione intera. Prende anche `rag=`.

**`::ai-chat`** risponde a partire dalle collezioni in `data=`, e **dice quando
lì dentro la risposta non c'è** invece di inventarla. Il corpo è la persona (o
`persona=`), `placeholder` è cosa dice la casella vuota. La conversazione resta
su questo dispositivo.

**`::ai-query`** è la più interessante. La domanda diventa un **piano** —
filtri, un `group-by`, un'aggregazione — e il widget mostra **il piano oltre
alla risposta**, perché chi non vede che cosa è stato chiesto non può
distinguere una risposta giusta da una plausibile. Il numero singolo compare nel
widget; la scomposizione finisce in `into=`, pronta per una `::table` o un
`::chart-bar`.

| | `data` | `into` | `placeholder` | corpo |
| --- | --- | --- | --- | --- |
| `::ai-summary` | la collezione | — | — | che cosa dirne |
| `::ai-chat` | le collezioni leggibili | — | ✓ | la persona |
| `::ai-query` | la collezione | la scomposizione | ✓ | — |

## Compilare un modulo

```markdown
::form{path="spese" id="f1"}
::input{field="voce" legend="Voce"}
::input{field="importo" type="number" legend="Importo"}
::input{field="categoria" legend="Categoria"}

::ai-assist{form="f1" placeholder="Pizza con Mario, giovedì, 24 euro"}
::ai-field{form="f1" field="categoria" values="cibo,casa,trasporti"}
::ai-suggest{form="f1" path="spese" fields="voce,importo:number"}
::save{label="Salva"}
::/form
```

**Nessuna di queste scrive una riga.** Riempiono la **bozza** del modulo, e a
salvare è la persona premendo il pulsante del modulo. È la stessa distinzione
dell'agente più sotto, ed è deliberata: un modello che scrive righe da solo è un
modello di cui bisogna ricontrollare tutto il lavoro.

| Direttiva | Che cosa fa | Attributi |
| --- | --- | --- |
| `::ai-assist` | Riempie il modulo da **una frase**, leggendo i campi che il modulo ha davvero | `form`, `label`, `placeholder` |
| `::ai-field` | Suggerisce **un** campo dagli altri già compilati, scegliendo da `values` | `form`, `field`, `values`, `label` |
| `::ai-suggest` | Propone la prossima riga plausibile da quello che la collezione già contiene | `form`, `path`, `fields`, `label` |
| `::ai-extract` | Legge un testo libero e riempie la bozza con quello che ci trova | `form`, `fields`, `source`, `label` |
| `::ai-vision` | Descrive l'immagine di un campo `::file` dentro un altro campo | `form`, `field`, `target`, `prompt`, `label` |
| `::ai-translate` | Traduce in `to=` il testo di una chiave o di un campo, **sul posto** | `to`, `form`, `field`, `label` |
| `::ai-rewrite` | Riscrive nello stile chiesto il testo di una chiave o di un campo | `style`, `form`, `field`, `label` |

`fields=` si scrive `nome:tipo` — `text` (il difetto), `number`, `date`,
`boolean` — e **un valore che non è di quel tipo viene lasciato fuori** invece
che memorizzato come prosa. `::ai-field` sceglie da `values=` e da nient'altro:
una risposta fuori dalla lista viene scartata, mai aggiunta alla lista.

`::ai-extract` senza `source` disegna una casella sua; con `source="#dettato"`
legge una chiave reattiva. `::ai-translate[nota]{to="en"}` lavora su una chiave
quando le parentesi ne nominano una, su un campo quando `form`/`field` lo
dicono.

`::ai-vision` ha bisogno di un modello che legga le immagini: Ollama con un
modello multimodale, oppure OpenAI.

## Lavorare una collezione intera

```markdown
::ai-classify{path="spese" field="categoria" values="cibo,casa,trasporti" label="Classifica"}

::ai-rule{data="spese" when="importo sopra 100" do="segna controllo a 'da verificare'"}

::ai-pipeline{data="segnalazioni" fields="ufficio,urgenza,sintesi"}
Classifica la segnalazione per ufficio e urgenza, e scrivi una sintesi di una riga.
::/ai-pipeline
```

**`::ai-classify`** guarda **solo le righe in cui quel campo è ancora vuoto**, a
meno che non si scriva `overwrite`. Attributi: `path`, `field`, `values`,
`overwrite`, `label`.

**`::ai-pipeline`** guarda solo le righe in cui è vuoto il **primo** campo
dichiarato — è quello che qui significa «le righe nuove» — e ne fa al massimo 25
per volta. Attributi: `data`, `fields`, `label`.

**`::ai-rule`** è quella che **smette di aver bisogno del modello**. Viene
compilata **una volta sola** in un piano verificato — un campo, un confronto, un
valore, un campo da scrivere — tenuto in IndexedDB; da lì in poi gira a ogni
cambiamento dei dati **senza nessuna richiesta**. Deterministica, e idempotente
perché tocca solo le righe il cui valore cambierebbe davvero. Attributi: `data`,
`when`, `do`, `label`.

## L'agente

```markdown
::ai-agent{data="prenotazioni,stanze" tools="query,insert"}
Sei l'assistente prenotazioni: verifica la disponibilità con una query prima di
proporre un inserimento.
::/ai-agent
```

Due strumenti e nessun altro. `query` legge le collezioni nominate in `data=`;
`insert` **propone** una riga, che compare con un pulsante di conferma e viene
scritta solo quando qualcuno lo preme. Attributi: `data`, `tools`,
`placeholder`; il corpo è la persona.

Ogni chiamata lascia una riga nel registro visibile, perché **un agente di cui
non si vedono i passi è un agente che nessuno può controllare**.

## Ricerca per significato

```markdown
::ai-search{rag="documenti.allegato,documenti.note" placeholder="Cerca nei documenti"}

::ai-chat{data="documenti" rag="documenti.allegato,documenti.note"}
Rispondi citando i documenti fra parentesi quadre.
::/ai-chat
```

`rag=` nomina i campi come `collezione.campo`. Il loro testo — compreso il
**contenuto** di un allegato `::file`, quando è testo che questo browser sa
leggere da sé — viene tagliato in passaggi, trasformato in vettori e tenuto in
IndexedDB. L'indice **si ricostruisce solo quando il testo da cui è nato è
davvero cambiato**, e non lascia il dispositivo se non come richiesta
all'endpoint configurato. Attributi: `rag`, `placeholder`, `into`.

Il modello per i vettori è **Qwen3-Embedding-0.6B**
(`ollama pull qwen3-embedding:0.6b`, circa 600 MB), e deliberatamente non è
un'impostazione: la scelta ha due risposte oneste e a decidere fra le due è
l'endpoint. Dove l'endpoint è quello di OpenAI si usa `text-embedding-3-small`,
perché è l'unico host che Qwen non lo serve comunque glielo si chieda.

> **I PDF e le scansioni non vengono indicizzati.** Estrarne il testo vuole un
> parser e un OCR. Un file così viene indicizzato **per il suo nome**, e una
> ricerca che indicizzasse di nascosto il nome mostrando l'aria di aver letto il
> file sarebbe peggio che non offrire la cosa: la citazione non potrebbe puntare
> a nient'altro.
