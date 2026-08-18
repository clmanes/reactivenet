---
title: "Licenze e attribuzioni"
translationKey: "legal-licences"
description: "A chi appartiene cosa: il software di ReactiveNET, le componenti di terze parti che lo compongono, e le fonti open data con le licenze che impongono di citarle."
version: "1.2"
updated: "2026-08-18"
---

# Licenze e attribuzioni

## 1. Il software ReactiveNET

ReactiveNET è opera di **Cosimo Luigi Manes**, persona fisica, che ne è
l'autore e il titolare del diritto d'autore: **© Cosimo Luigi Manes**. Ciò vale
per il codice sorgente, per la documentazione e per i contenuti editoriali del
progetto, salvo le componenti di terzi elencate al § 3.

Il codice sorgente di ReactiveNET è **software libero**, rilasciato con licenza
**Apache License 2.0**: chiunque può usarlo, copiarlo, modificarlo e
ridistribuirlo, anche a fini commerciali, alle condizioni della licenza —
conservare gli avvisi di copyright e il file NOTICE, e indicare le modifiche
apportate. La licenza include una concessione esplicita sui brevetti e non
concede alcun diritto sui marchi (§ 2). Il testo integrale è nel file `LICENSE`
del repository pubblico.

La documentazione, le guide, gli esempi, gli articoli e gli altri contenuti
editoriali pubblicati su `reactivenet.ai` sono invece rilasciati con licenza
**Creative Commons Attribuzione 4.0 Internazionale (CC BY 4.0)**: si possono
riprodurre, adattare e riusare, anche per fini commerciali, citando l'autore.

## 2. Marchi e segni distintivi

I nomi **«ReactiveNET»** e **«Reactive»**, il logo e gli elementi grafici
identificativi appartengono a Cosimo Luigi Manes. Una licenza sul software, ove
concessa, **non è una licenza sul marchio**: non autorizza a presentare un
prodotto derivato come se fosse ReactiveNET, né a usarne il nome o il logo per
promuovere altro. È consentito l'uso descrittivo — dire che un servizio è
realizzato con ReactiveNET — purché non ingeneri confusione sull'origine.

## 3. Componenti di terze parti

L'applicazione incorpora software libero di terzi, ciascuno con la propria
licenza e i propri avvisi di copyright, che restano dei rispettivi titolari.
Le principali:

| Componente | Licenza | Ruolo |
| --- | --- | --- |
| React, React DOM | MIT | interfaccia |
| ReScript | LGPL-3.0-or-later AND MIT | compilatore e libreria standard |
| Adobe Spectrum Web Components | Apache-2.0 | componenti e icone dell'interfaccia |
| CodeMirror | MIT | editor Markdown |
| BlockNote | MPL-2.0 | editor a blocchi |
| Automerge | MIT | sincronizzazione degli spazi condivisi |
| DOMPurify | MPL-2.0 OR Apache-2.0 | sanitizzazione dell'HTML generato |
| marked | MIT | interpretazione del Markdown |
| KaTeX | MIT | formule matematiche |
| Mermaid | MIT | diagrammi |
| Leaflet | BSD-2-Clause | mappe |
| Chart.js | MIT | grafici |
| Pyodide (CPython su WebAssembly) | MPL-2.0 | esecuzione di Python nel browser |
| scikit-learn, statsmodels (via Pyodide) | BSD-3-Clause | direttive di machine learning |
| Perspective (FINOS) | Apache-2.0 | vista esplorativa `::explore` |
| DuckDB WASM e DuckDB | MIT | servizio open data |
| SheetJS (xlsx) | Apache-2.0 | lettura e scrittura di fogli di calcolo |
| Tailwind CSS, Vite | MIT | stile e compilazione |
| PocketBase | MIT | servizio di condivisione e sincronizzazione |
| Space Grotesk | SIL Open Font License 1.1 | carattere tipografico del sito |

L'elenco completo, con le versioni esatte, è nel file `package.json` del
repository e nei rispettivi pacchetti; i testi integrali delle licenze
accompagnano ciascun pacchetto in `node_modules`. Le licenze MPL-2.0 e LGPL
riguardano i file dei rispettivi progetti e restano tali: nulla di quanto qui
dichiarato le modifica.

## 4. Mappe

Le mappe usano le mattonelle cartografiche e il servizio di geocodifica della
**OpenStreetMap Foundation**. I dati di OpenStreetMap sono rilasciati con
licenza **Open Data Commons Open Database License (ODbL) 1.0**, la cartografia
con licenza CC BY-SA 2.0.

L'attribuzione è **obbligatoria** ed è resa da ogni mappa dell'applicazione:

> © collaboratori di [OpenStreetMap](https://www.openstreetmap.org/copyright)

Un autore che sostituisca il servizio di mattonelle con un altro deve indicare
l'attribuzione richiesta da quel fornitore tramite l'attributo `attribution`
della direttiva `::map`. All'uso dei servizi pubblici di OpenStreetMap si
applica la loro *Tile Usage Policy*: sono pensati per un traffico modesto, e un
uso intensivo richiede un fornitore di mattonelle proprio.

## 5. Open data: fonti e licenze

Il servizio open data espone **dati pubblici di terzi**, ricaricati
periodicamente e talvolta trasformati (unioni, aggregazioni, normalizzazione dei
codici ISTAT). I titolari restano gli enti che li pubblicano; a ciascuna licenza
si accompagna un obbligo di attribuzione che vale anche per **chi ripubblica
quei dati attraverso un'app costruita con ReactiveNET**.

| Fonte | Licenza |
| --- | --- |
| ISTAT — popolazione, indicatori territoriali, confini amministrativi e basi territoriali, censimento, delitti denunciati, imprese, turismo, rifiuti, incidenti stradali, pendolarismo, mortalità per causa, speranza di vita, mortalità infantile | CC BY 4.0 |
| schema.gov.it — Catalogo Nazionale della semantica dei dati (vocabolari controllati) | licenza del catalogo NDC, riuso libero con citazione |
| Normattiva / dati.normattiva.it — atti normativi statali | riuso libero con citazione della fonte |
| ANAC — contratti pubblici (CIG, aggiudicatari) | **CC BY-SA 4.0** |
| MIMIT — Osservaprezzi carburanti (impianti e prezzi) | IODL 2.0 |
| Ministero dell'Istruzione e del Merito — anagrafe scuole, iscrizioni, personale, edilizia scolastica, dispersione | IODL 2.0 |
| INVALSI — esiti delle prove | CC BY 4.0 IT |
| Ministero della Salute — farmacie e parafarmacie, aziende sanitarie e ambiti comunali, strutture di ricovero e posti letto, personale e apparecchiature sanitarie, consultori familiari, servizi per la salute mentale e per le dipendenze, dimissioni ospedaliere (SDO), attività dei reparti | IODL 2.0 |
| AGENAS — Programma Nazionale Esiti (PNE) | CC BY 4.0 |
| MEF — SIOPE, incassi e pagamenti degli enti pubblici | CC BY 4.0 |
| MEF — Patrimonio della Pubblica Amministrazione | CC BY 4.0 |
| ISPRA — consumo di suolo | CC BY 4.0 |
| Dipartimento della Protezione Civile — classificazione sismica dei comuni | CC BY 4.0 |
| Agenzia delle Entrate — ANNCSU, archivio nazionale dei numeri civici e delle strade urbane | CC BY 4.0 |
| Ministero della Cultura — ArCo, knowledge graph del patrimonio culturale | CC BY 4.0 |
| Operatori di sharing mobility — feed GBFS pubblicati dai singoli servizi | secondo le condizioni pubblicate da ciascun operatore |
| MEF — dichiarazioni dei redditi | CC BY 3.0 IT |
| ACI — parco veicolare (Autoritratto) | CC BY 4.0 |
| INAIL — infortuni denunciati | CC BY 4.0 |
| IndicePA (AgID) — anagrafica delle pubbliche amministrazioni | CC BY 4.0 |
| OpenCoesione, OpenCUP (DIPE) — progetti e investimenti pubblici | CC BY 4.0 |
| Ministero della Giustizia — DGSTAT, durata dei procedimenti | CC BY 4.0 |
| Camera dei deputati, Senato della Repubblica, Corte costituzionale, Giustizia amministrativa — open data istituzionali | riuso libero secondo le condizioni pubblicate dai rispettivi portali |
| Ministero dell'Interno — dati elettorali | riuso libero secondo le condizioni pubblicate |

La provenienza puntuale di ciascuna tabella — URL della fonte, licenza, data
dell'ultimo caricamento — è indicata nel catalogo del servizio dati e
nell'intestazione del rispettivo script di caricamento nel repository.

I dati sanitari nominativi non esistono in nessuna di queste fonti: quelle che
riguardano le persone sono già aggregate all'origine, e le celle che l'ente
titolare ha soppresso per non rendere identificabile nessuno restano vuote —
non vengono stimate né lette come zeri.

**Due obblighi che è facile violare senza accorgersene.**

1. **CC BY-SA (dati ANAC)**: chi ridistribuisce quei dati, anche rielaborati, è
   tenuto a farlo con la *stessa licenza*. Una tabella di gare pubbliche
   ripubblicata dentro un'app resta CC BY-SA 4.0.
2. **Nessun avallo**: l'attribuzione non autorizza a far intendere che l'ente
   titolare approvi, avalli o abbia verificato l'app o le elaborazioni. I dati
   sono rielaborati dal fornitore e gli errori di rielaborazione sono suoi, non
   dell'ente.

Il fornitore non garantisce esattezza, completezza o aggiornamento dei dati:
per un uso ufficiale il dato va verificato presso la fonte.

## 6. Contenuti creati dagli utenti

Le app scritte dagli utenti, i loro dati e i contenuti che vi inseriscono
restano **degli utenti**. Il fornitore non ne acquisisce diritti, non ne dispone
e non ne possiede copia, salvo il blob cifrato che non è in grado di leggere nei
casi descritti dall'informativa privacy.

## 7. Segnalazioni

Chi ritenga che un contenuto pubblicato dal fornitore violi un proprio diritto
può scrivere a info@reactivenet.ai indicando l'opera, il diritto
vantato e l'indirizzo del contenuto: la segnalazione riceve riscontro entro 30
giorni e, se fondata, il contenuto è rimosso o corretto.

---

Versione 1.2 — 18 agosto 2026. In caso di divergenza fra la versione
italiana e quella inglese prevale la versione italiana.
