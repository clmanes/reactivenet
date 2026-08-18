---
title: "Mappe e coordinate"
description: "La collezione disegnata su una mappa, i punti raccolti da chi compila e gli indirizzi risolti in coordinate."
weight: 22
translationKey: "mappe"
---

Una mappa è **una vista su una collezione**, come una lista o una tabella: una
riga è un punto, e il corpo della direttiva è il modello del fumetto. Quello che
cambia rispetto alle altre viste è come una riga dice dov'è.

Il motore della mappa è un pezzo caricato solo se il documento ne ha una.

## `::map` … `::/map`

```markdown
::map{path="segnalazioni" coords="posizione" height="26rem"}
**{tipo}** — {via}
{note}
::/map
```

| Attributo | |
| --- | --- |
| `path` | La collezione |
| `coords` | Il campo che tiene **le due coordinate in una stringa**, `"45.46, 9.18"` — il formato che `::geo` scrive |
| `lat` / `lon` | I due campi, quando le coordinate stanno in due colonne (per difetto `lat` e `lon`) |
| `geojson` | Il campo che tiene una geometria GeoJSON: ogni riga diventa un'**area** invece che un punto |
| `fill` | Con `geojson`, il campo numerico che colora le aree a quantili di blu |
| `center` | Il centro iniziale, `"lat, lon"` |
| `zoom` | Lo zoom iniziale, da 0 (il mondo) a 19 (la via) |
| `height` | Un'altezza CSS; senza, `24rem` |
| `tiles` | Un'altra base cartografica: un URL https con i segnaposti `{z}/{x}/{y}` |
| `attribution` | La riga di credito che quel fornitore di tasselli richiede |

Il fumetto è un **modello di riga** come quello di `::list`: `{campo}` viene
sostituito col valore, e il valore arriva come **testo, mai come marcatura** —
una riga che contiene `<script>` mostra quei caratteri.

Una riga senza coordinate valide semplicemente non ha un punto. Non è un errore
e non interrompe niente: in una collezione appena importata la metà degli
indirizzi non è ancora stata risolta, ed è normale.

### La vista segue i punti, finché non la muovi

Senza `center`, la mappa si inquadra da sé sui punti che ha. Continua a farlo
mentre le righe cambiano — si aggiunge una segnalazione e la mappa si allarga —
**fino al primo gesto del lettore**. Da quel momento la vista è sua e non gliela
si sposta più sotto le mani, che è la cosa che rende insopportabili le mappe che
si riposizionano da sole.

### Le aree, e la coropletica

```markdown
::od-query{into="sezioni" sql="SELECT * FROM istat_sezioni WHERE codice_istat = '{#comune}'"}

::map{path="sezioni" geojson="geojson" fill="popolazione"}
**{sezione}** — {popolazione} abitanti
::/map
```

Con `geojson` ogni riga è un poligono invece di un punto, e `fill` lo colora
secondo un campo numerico: la scala è a **quantili**, non lineare, così una
distribuzione con una coda lunga — che è come sono fatti quasi tutti i dati
territoriali — non produce una mappa di un colore solo con tre eccezioni.

### I tasselli

Per difetto sono quelli di OpenStreetMap, con il credito che la loro licenza
richiede. Sono l'unica ragione per cui la politica di sicurezza dell'app
concede `img-src https:`. Un `tiles=` diverso è accettato **solo** se è https e
contiene `{z}/{x}/{y}`; altrimenti si torna a OpenStreetMap. Con un tema scuro i
tasselli vengono ritinti via CSS, perché una mappa chiarissima dentro
un'interfaccia scura è l'unica cosa che si vede nella stanza.

## `::geo` — il punto di chi compila

```markdown
::form{path="segnalazioni"}
::input{field="tipo" legend="Tipo di segnalazione"}
::geo{field="posizione" legend="Dove"}
::save{label="Segnala"}
::/form
```

È **un campo di modulo** con accanto un pulsante: premuto, chiede al dispositivo
la sua posizione e la scrive nel campo come `"lat, lon"` — esattamente il
formato che `::map{coords}` legge. Prende `field`, `legend` e `form` (quando il
campo sta fuori dal modulo che lo possiede), come ogni altro campo.

La posizione si chiede **su un gesto**, mai da sola all'apertura della pagina.

## `::geocode` — dagli indirizzi alle coordinate

```markdown
::geocode{path="fornitori" from="indirizzo" to="coords" label="Trova sulla mappa"}
```

Un pulsante che risolve in coordinate gli indirizzi già scritti nelle righe.

| Attributo | |
| --- | --- |
| `path` | La collezione |
| `from` | Il campo che tiene l'indirizzo |
| `to` | Il campo dove finiscono le coordinate; senza, `coords` |
| `value` | Forma a indirizzo singolo: l'indirizzo, o un `#key` che lo tiene |
| `url` | Un endpoint Nominatim `/search` proprio, invece di quello pubblico |
| `label` | Che cosa dice il pulsante |

Tre cose lo rendono usabile su una collezione vera:

- Guarda **solo** le righe che hanno l'indirizzo e non hanno ancora le
  coordinate. Premerlo due volte non rifà il lavoro: riprende da dove era.
- Ne fa al massimo **50 per clic**, una richiesta al secondo, e scrive riga per
  riga — così una corsa interrotta a metà tiene le risposte che ha già avuto.
- Parte **su un gesto**, sempre.

La forma a indirizzo singolo scrive una chiave reattiva invece che una riga:

```markdown
::textfield[indirizzo]{label="Indirizzo"}
::geocode[punto]{value="#indirizzo" label="Trova"}
::map{path="poi" center="#punto" zoom="16"}
::/map
```

### Due risolutori, prima quello locale

Un indirizzo italiano viene cercato in **ANNCSU**, l'archivio nazionale dei
numeri civici — venti milioni, con le coordinate — tenuto dal servizio open data
sulla stessa origine dell'app. Quella risposta è immediata, non ha limiti di
frequenza e **non dice a nessuno che cosa è stato cercato**. Solo se lì non si
trova niente la richiesta esce verso Nominatim, con la sua politica di una
richiesta al secondo.

Ricade fuori per due ragioni oneste, e vale la pena saperle entrambe: ANNCSU è
**solo Italia**, e **2.402 comuni su 7.890** non hanno coordinate lì dentro. Un
indirizzo all'estero, o in uno di quei comuni, si risolve lo stesso — ma non da
qui. Dove il servizio open data non c'è, tutti gli indirizzi vanno a Nominatim
come prima.

Quale dei due abbia risposto si vede nel pannello di rete e in nessun altro
posto, deliberatamente: chi chiede «dov'è questo indirizzo» deve ricevere la
stessa risposta in entrambi i casi.
