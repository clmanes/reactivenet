---
title: "Dati da fuori"
description: "Gli open data, le API pubbliche e un motore SQL nel browser: tre modi di far arrivare righe che nessuno ha digitato — e il workflow che li mette in fila."
weight: 23
translationKey: "dati-esterni"
---

Le direttive dei dati partono dal presupposto che le righe le scriva qualcuno.
Queste no: fanno arrivare righe da un servizio, da un'API pubblica o da una
query, e le mettono in una **collezione ordinaria**.

Quella è la decisione che conta, e vale per tutte e tre. Quello che arriva non è
un tipo speciale: è una collezione come le altre, quindi `::list`, `::table`,
`::chart-bar`, `:sum` e un blocco `::python` la leggono **esattamente** come
leggono le righe salvate a mano, senza sapere da dove vengono. E la collezione è
anche la **copia offline**: quando il servizio non risponde, la vista mostra le
ultime righe ricevute con accanto lo stato che dice che sono vecchie, invece di
un errore sopra dei dati che sembrano vivi.

> Una collezione riempita da una di queste direttive è **derivata**: non viene
> mai spinta in uno spazio condiviso, e un aggiornamento remoto non può
> cancellarla. Un cambio valutario scaricato da questo browser non è un fatto
> condiviso — è una copia, e ogni dispositivo si prende la sua.

## Open data: `::od-query`, `::od-search`, `::od-datasets`

Tre direttive leggono il servizio open data — centinaia di dataset pubblici in
un magazzino solo, raggiunto come `/od` **sulla stessa origine dell'app**. Non
c'è un indirizzo da configurare, e nessun documento può puntare l'app a un host
di sua scelta.

### `::od-query`

Un SELECT dentro una collezione.

```markdown
::textfield[comune]{label="Comune" value="TAORMINA"}

::od-query{into="farmacie" sql="SELECT nome, indirizzo FROM farmacie WHERE comune = '{#comune}' LIMIT 8"}

::list{path="farmacie"}
**{nome}** — {indirizzo}
::/list
```

| Attributo | |
| --- | --- |
| `into` | La collezione dove finiscono le righe |
| `sql` | Il SELECT da eseguire; `{#chiave}` lega una chiave reattiva |
| `limit` | Al massimo tante righe |

I segnaposti `{#chiave}` diventano **parametri preparati**, mai testo incollato
dentro la query. È la differenza fra un'app e una falla: quei valori vengono da
chi legge, e concatenarli sarebbe SQL injection dentro il servizio. La forma fra
apici, `'{#chiave}'`, è accettata e gli apici vengono consumati insieme al
segnaposto.

La query **si rifà da sé**, con un ritardo, quando cambia una chiave che nomina.
Un campo di testo sopra e una query sotto sono un'applicazione completa.

### `::od-search`

Una casella di ricerca sul catalogo in linguaggio naturale — o, con `table=`,
sulle righe di una tabella ricercabile. I risultati finiscono in `into`.

```markdown
::od-search{into="risultati" placeholder="Cerca nei dataset"}

::list{path="risultati"}
**{table_name}** {title_it}
::/list
```

Prende `into`, `placeholder` e `table`.

### `::od-datasets`

Il catalogo stesso — ogni dataset col suo nome di tabella, il conteggio delle
righe e la descrizione — dentro una collezione: `::od-datasets{into="catalogo"}`.
Serve per scrivere il documento: si guarda che colonne ha davvero una tabella
prima di scrivere il SELECT che le nomina.

## `::choose` — una tendina che pilota una query

```markdown
::od-query{into="comuni" sql="SELECT DISTINCT codice_istat, comune FROM istat_sezioni ORDER BY comune"}
::choose[comune]{path="comuni" field="codice_istat" label="comune" legend="Comune"}

::od-query{into="sezioni" sql="SELECT * FROM istat_sezioni WHERE codice_istat = '{#comune}'"}
::map{path="sezioni" geojson="geojson" fill="popolazione"}
::/map
```

Una tendina costruita **dalle righe di una collezione**. Sceglierne una scrive
una **chiave reattiva** — le parentesi quadre la nominano, come su
`::slider[volume]` — quindi tutto ciò che legge `#chiave` la segue, e ogni
`::od-query` che la cita nel suo SQL riparte.

| Attributo | |
| --- | --- |
| `path` | La collezione le cui righe sono le opzioni |
| `field` | Il campo il cui valore viene **memorizzato**; omesso, memorizza l'id della riga |
| `label` | Il campo che il lettore **vede**; senza, `field`, poi l'id |
| `legend` | L'etichetta visibile |
| `placeholder` | Il testo della prima opzione vuota, che è una scelta vera |
| `sort` / `dir` | Ordina per un altro campo invece che per quello mostrato |
| `value` | Il valore scelto all'inizio |
| `help` | Una riga di guida sotto il controllo |

È tutta lì la forma: una query riempie la tendina, la tendina scrive la chiave,
la seconda query la rilegge. Prima che questa direttiva esistesse **niente
poteva scrivere una chiave reattiva partendo dai dati**: un documento sui 7.896
comuni doveva fissarne uno nell'SQL, oppure chiedere a chi legge di digitare
`058091` a memoria.

Pilota altrettanto bene una collezione locale, senza nessuna query — la chiave
finisce nel `filter` di una vista:

```markdown
::choose[chi]{path="spese" field="chi" label="chi" legend="Chi"}

::list{path="spese" filter="chi=#chi"}
{cosa} — {importo}
::/list
```

Due cose che fa e che sono decisioni, non incidenti:

- **Memorizza una cosa e ne mostra un'altra**, perché quasi mai sono lo stesso
  campo. Un comune si sceglie per nome e si interroga per codice ISTAT.
- **Ordina le opzioni per quello che si legge**, non per come le righe sono
  arrivate — il contrario di `::list`, che tiene l'ordine di inserimento perché
  una lista è il resoconto di quello che è successo. Una tendina serve a
  *trovare*, e 7.896 comuni nell'ordine di arrivo non si trovano affatto.

> `::choose` non è `::input{type="ref"}` con una bandierina, e la differenza è
> la regola centrale del linguaggio: `::input` riempie la **bozza di un modulo**,
> `::choose` scrive una **chiave reattiva**. Id nudo contro `#ref`, nei due
> controlli che li producono.

## `::api-query` — una qualunque API pubblica

```markdown
::input[base]{value="EUR"}
::api-query{url="https://api.frankfurter.dev/v1/latest?base={#base}" into="cambi" pick="rates" as="pairs"}

::chart-bar{data="cambi" x="key" y="value"}
```

| Attributo | |
| --- | --- |
| `url` | L'indirizzo **https**; i `{#chiave}` sono parametri reattivi, percent-encoded |
| `into` | La collezione dove finiscono le righe |
| `pick` | Il percorso dentro il JSON, per punti e indici: `results.0.series` |
| `as` | `pairs`, per trasformare un oggetto di scalari in righe `{key, value}` |
| `every` | Ripete ogni tanti secondi; il minimo è 60 |

Le forme del JSON sono decise una volta sola: un **array di oggetti** sono le
righe; un **oggetto di array** viene incolonnato in parallelo (è la forma di
Open-Meteo); un **oggetto di scalari** è una riga sola, oppure coppie
`{key, value}` con `as="pairs"`. Con `::api-query[chiave]` e un `pick` che punta
a uno scalare, scrive una chiave reattiva invece di una collezione.

Un pulsante di aggiornamento c'è sempre, anche con `every`. Nell'URL i
segnaposti sono **percent-encoded**, che in un indirizzo *è* la forma corretta
di quoting — la stessa cura che i parametri preparati hanno nell'SQL.

## `::sql` — un motore SQL nel browser

````markdown
::sql{data="clienti,ordini" into="fatturato"}
```sql
SELECT c.nome, sum(o.importo) AS totale
FROM ordini o JOIN clienti c ON c.nome = o.cliente
GROUP BY 1 ORDER BY 2 DESC
```
::/sql
````

Un motore SQL completo — DuckDB — dentro la pagina. Le collezioni nominate in
`data=` diventano **tabelle con lo stesso nome**, coi tipi dedotti (i numeri
sono numeri), e il corpo fenced è **un** SELECT: JOIN, GROUP BY, funzioni
finestra.

| Attributo | |
| --- | --- |
| `data` | Le collezioni che diventano tabelle, separate da virgola |
| `into` | La collezione dove finisce il risultato |
| `limit` | Al massimo tante righe; il tetto è 1000 |

I `{#chiave}` sono gli stessi parametri preparati reattivi di `::od-query`. Un
Parquet o un CSV remoto in https si legge direttamente dall'URL.

La **primissima esecuzione** scarica il motore — una decina di megabyte, poi
resta in cache — e aspetta dietro un pulsante *Esegui*, che è la regola di ogni
cosa che pesa: nessun documento fa scaricare dieci megabyte a chi lo apre senza
averlo chiesto.


## `::workflow` — mettere in fila i motori

Le direttive di questa pagina, più `::python` e le `ml-*`, sono già una catena:
`::od-query` riempie una collezione, `::sql` la legge e ne scrive un'altra, una
`ml-forecast` legge quella. Quello che manca non è il calcolo — c'è tutto — ma
**un ordine, un momento in cui partire, e una riga sola che dica a che punto è**.

````markdown
::workflow[Aggiornamento serale]{at="18:00" on="save:spese" label="Aggiorna"}

::od-query{into="listino" sql="SELECT codice, prezzo FROM prezzi_medi"}

::sql{data="spese,listino" into="scostamenti"}
```sql
SELECT s.voce, s.importo - l.prezzo AS delta
FROM spese s JOIN listino l ON s.codice = l.codice
```
::/sql

::ml-forecast{data="scostamenti" x="mese" y="delta" into="previsione" horizon="6"}

::/workflow

## Andamento
::chart-line{data="previsione" x="mese" y="delta"}
````

**Dentro ci va quello che produce dati, fuori resta quello che li mostra.** Un
`::sql` o una `::od-query` non disegnano niente: scrivono una collezione, e a
disegnarla è una vista altrove nella pagina, che si aggiorna da sé quando quella
collezione cambia.

**Non c'è nessun linguaggio nuovo da imparare, e nessun collegamento da
scrivere.** I passi sono le direttive di sempre e **i collegamenti sono i nomi
delle collezioni che portano già**: un passo il cui `into=` compare nel `data=`
di un altro viene eseguito prima di quello. L'ordine in cui sono scritti conta
solo a parità di dipendenze, così due passi indipendenti restano dove li ha
messi chi scrive. Un giro chiuso — A che scrive quello che B legge e viceversa —
viene segnalato e non eseguito, invece di girare a vuoto senza che niente sulla
pagina dica perché.

| Attributo | |
| --- | --- |
| `every` | Ogni tanto: `15m`, `2h`, `1d`, `90s` — minimo 60 secondi |
| `at` | Una volta al giorno a quest'ora locale, es. `18:00` |
| `catchup` | Con `at=`, recupera in qualunque momento della giornata invece che solo nell'ora dopo |
| `on` | Cos'altro lo fa partire: `save:collezione`, `change:#chiave`, `open` |
| `label` | Cosa dice il pulsante |
| `show` | Mostra anche il corpo e i controlli di ogni passo, non solo la striscia |
| `quiet` | Esegue senza mostrare niente |

**Si aggiorna mentre l'app è aperta, e la striscia lo dice.** Qui non c'è un
server e non c'è esecuzione in secondo piano: `at="18:00"` significa *la prima
volta che l'app è aperta alle 18:00 o dopo, in un giorno in cui non è ancora
stato eseguito*. La sera saltata si recupera quando qualcuno apre l'app —
subito con `catchup`, entro l'ora senza. Sotto il minuto non si scende, perché
una scheda in secondo piano viene rallentata a circa un timer al minuto e
promettere di più sarebbe promettere quello che il browser non mantiene.

Senza nessuno di questi attributi il workflow è reattivo esattamente come lo
sono le direttive sciolte: riparte quando i dati si muovono, e la firma di ogni
motore rende un passo immutato un'esecuzione che non costa niente.

**Ogni passo riporta quello che riporta già.** La striscia mostra lo stato del
motore — le stesse parole, nella stessa lingua. Quello che il workflow aggiunge
è la riga dopo: tutto ciò che quel passo alimentava viene marcato *saltato* e
non viene eseguito, perché un numero calcolato da un dato che non è mai arrivato
è peggio di nessun numero — sulla pagina i due sono indistinguibili.

Quello che un passo si tiene sono **i suoi controlli**: il pulsante della prima
esecuzione di `::sql` e dei pacchetti `ml-*`, e quello di un `::python{manual}`,
restano dove sono. Un passo fermo in attesa che qualcuno prema è riportato come
in attesa, mai saltato in silenzio. *Ferma* agisce **fra** un passo e l'altro:
una richiesta già partita finisce, e un blocco Python conserva il suo Stop.
