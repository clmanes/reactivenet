---
title: "L'app diventa uno strumento BI: dashboard, SQL nel browser e domande in linguaggio naturale"
description: "Otto novità trasformano ogni app Reactive in un piccolo strumento di business intelligence: filtro incrociato tra grafici e tabelle, un motore SQL completo (DuckDB) che gira nel browser, l'AI che traduce le domande in query, connettori per le API pubbliche mondiali, geocoding degli indirizzi, previsioni su serie temporali e il benchmarking con rank e percentile. Tutto client-side, tutto in Markdown."
date: 2026-07-21
author: "Cosimo Luigi Manes"
translationKey: "bi-in-the-browser"
cover: "/img/blog/bi-in-the-browser.jpg"
coverAlt: "Google Analytics"
coverAuthor: "Negative Space"
coverAuthorUrl: "https://stocksnap.io/author/4440"
coverSource: "https://stocksnap.io/photo/google-analytics-89AZTB8E5H"
coverLicense: "CC0"
coverLicenseUrl: "https://creativecommons.org/publicdomain/zero/1.0/"
---

Un’app Reactive sapeva già raccogliere dati, mostrarli in viste e grafici,
mapparli, farci machine learning e interrogarci sopra un’AI. Quello che
mancava era il gesto tipico dei veri strumenti di business intelligence:
**cliccare su un grafico e vedere tutto il resto filtrarsi da solo**. E, per
chi vuole spingersi oltre, un vero motore di query. Da oggi ci sono entrambi —
più sei altre novità che completano il quadro. Come sempre: nessun server,
nessun account, i dati restano sul dispositivo.

## Il filtro incrociato: `::dashboard`

Basta racchiudere grafici e viste nella stessa collezione dentro un
contenitore:

```markdown
::dashboard{path="vendite"}
::chart-bar{data="vendite" x="regione" y="importo"}

::table{path="vendite" headers="Regione,Canale,Importo"}
{regione} | {canale} | {importo}
::/table
::/dashboard
```

Clic su una barra: la tabella si restringe a quella regione, un chip in testa
mostra il filtro attivo, il grafico **evidenzia** la selezione spegnendo il
resto — senza filtrarsi da solo, perché il contesto deve restare visibile (è
la stessa scelta di Tableau e Power BI). Secondo clic: filtro tolto. Funziona
con tabelle, liste, schede, viste derivate e mappe, e ogni grafico del
dashboard è un filtro diverso: uno per regione, uno per canale.

## SQL vero, nel browser: `::sql`

Per le analisi che il Markdown non esprime c’è ora un motore SQL **completo**
— DuckDB compilato in WebAssembly — che gira interamente nel browser. Le
collezioni dell’app diventano tabelle, e si scrive SQL:

```markdown
::sql{data="clienti,ordini" into="fatturato"}
```sql
SELECT c.nome, sum(o.importo) AS totale
FROM ordini o JOIN clienti c ON c.nome = o.cliente
GROUP BY 1 ORDER BY 2 DESC
```
::/sql

::chart-bar{data="fatturato" x="nome" y="totale"}
```

**JOIN tra collezioni**, GROUP BY, window functions: il risultato è una
collezione come le altre, quindi finisce dritto in una tabella, un grafico,
una mappa. I segnaposto `{#chiave}` sono parametri reattivi — uno slider che
riesegue la query — e `read_parquet('https://…')` legge i file remoti sul
posto: i dati open mondiali pubblicati in Parquet o CSV entrano nell’app
senza alcun servizio intermedio. Perfino gli allegati caricati con `::file`
si interrogano con `read_csv('vendite.csv')`. Il motore (~10 MB) si scarica
una volta sola, al primo clic su Esegui.

## Chiedi ai tuoi dati: `::ai-query`

La funzione più richiesta della BI moderna, con una riga:

```markdown
::ai-query{data="spese" into="risposta"}
```

“Quanto ho speso in trasporti a giugno?”, “top 5 clienti per fatturato”: il
modello — nel browser, su Ollama o via API — non vede l’intera collezione né
scrive codice libero. Produce un **piano di interrogazione vincolato** (i
campi ammessi sono un elenco chiuso: non può inventare colonne) eseguito in
locale. E se l’app usa anche `::sql`, si potenzia da solo: la domanda
diventa una vera SELECT DuckDB — join, date, espressioni — mostrata nel
widget per trasparenza, con ripiego automatico sul piano se qualcosa va
storto.

## I dati open oltre l’Italia: `::api-query`

Il servizio dati di Reactive copre l’Italia; il nuovo connettore REST copre
il resto del mondo. Tassi di cambio, meteo, borsa, Eurostat — qualunque API
JSON pubblica entra in una collezione:

```markdown
::input[base]{value="EUR"}
::api-query{url="https://api.frankfurter.dev/v1/latest?base={#base}" into="cambi" pick="rates" as="pairs"}

::chart-bar{data="cambi" x="key" y="value"}
```

Cambi la valuta base e la chiamata si riesegue da sola. `pick` scende nel
JSON, e le forme comuni diventano righe senza colla: perfino il formato
colonnare di Open-Meteo si “zippa” da solo in una serie temporale pronta per
un grafico.

## Dagli indirizzi alla mappa: `::geocode`

I dati aziendali — clienti, sedi, punti vendita — hanno l’indirizzo, non il
GPS. Ora basta un pulsante:

```markdown
::geocode{path="clienti" from="indirizzo" to="coords"}

::map{path="clienti" coords="coords"}
**{nome}** — {indirizzo}
::/map
```

Geocodifica solo le righe che non hanno ancora coordinate (un secondo clic
riprende da dove era rimasto), rispetta la policy di Nominatim — una
richiesta al secondo, mai in automatico — e con `url=` punta a un’istanza
self-hosted, coerente con l’impostazione privacy-first.

## Previsioni, classifiche e percentili

Tre mattoni che completano il lato analitico:

- **`::ml-forecast`** — la previsione su serie temporali che mancava accanto
  a `ml-predict`: trend sui redditi per anno, sulla popolazione, sui prezzi
  accumulati. Scrive lo storico con il fit e le righe future, così
  `::chart-line{y="valore,previsione"}` mostra la serie e il suo
  prolungamento insieme.
- **`:rank`** e **`:percentile`** — il benchmarking in una riga: “questo
  comune è al 12° percentile per reddito”, “3° su 42”. Reattivi due volte:
  sui dati del gruppo e sul valore confrontato.

## Tutto si compone

La forza non è nelle otto novità prese una per una, ma nel fatto che parlano
tutte la stessa lingua: una collezione. `api-query` scarica i cambi, `::sql`
li incrocia con gli ordini, il risultato finisce in un `::dashboard` dove un
clic filtra la tabella, e `::ai-query` risponde alle domande — mentre
`:rank` dice dove ti collochi. Ogni pezzo è una riga di Markdown, e l’intera
app resta un file di testo che si condivide con un link.

Prova subito: [apri l’app](https://app.reactivenet.ai) o sfoglia il
[catalogo](/app/) — le app open data si stanno già aggiornando con dashboard,
benchmark e previsioni.
