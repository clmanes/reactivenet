---
title: "Dichiarazione di accessibilità"
translationKey: "legal-accessibility"
description: "Stato di conformità di reactivenet.ai e dell'applicazione rispetto alle WCAG 2.2 livello AA: cosa è conforme, cosa non lo è e perché, e come segnalare una barriera."
version: "1.0"
updated: "2026-08-13"
weight: 40
---

<!-- GENERATO da site/scripts/sync-legal.mjs — non modificare qui.
     La fonte è legal/it/dichiarazione-accessibilita.md: modifica quella e rilancia lo script. -->

Dichiarazione **volontaria**, resa da Cosimo Luigi Manes, persona fisica che
gestisce il progetto ReactiveNET a titolo personale e non imprenditoriale, in
relazione al sito `reactivenet.ai` e all'applicazione ReactiveNET.

Va detto subito da dove nasce: il fornitore non rientra fra i soggetti obbligati
alla dichiarazione ai sensi della legge 9 gennaio 2004, n. 4 e delle relative
linee guida AgID. La dichiarazione è resa lo stesso, nella forma prevista per i
soggetti obbligati, perché la piattaforma si rivolge in larga parte alla
pubblica amministrazione: un ente che pubblichi un servizio realizzato con
questi strumenti deve poter sapere **su cosa può contare e su cosa no**, e una
dichiarazione volontaria che dice la verità è più utile di un obbligo che non
c'è.

## 1. Stato di conformità

Il sito `reactivenet.ai` e l'applicazione ReactiveNET sono **parzialmente
conformi** ai requisiti delle **WCAG 2.2 livello AA** (e alla norma EN 301 549),
a causa dei casi di non conformità elencati al § 2.

L'obiettivo dichiarato del progetto è il livello AA delle WCAG 2.2 — una
versione più recente di quella richiesta dalla normativa vigente, che si ferma
alle WCAG 2.1 AA.

## 2. Contenuti non accessibili

### 2.1 Non conformi

**I due editor di testo** — l'editor Markdown e l'editor a blocchi — sono
componenti di terze parti (CodeMirror e BlockNote) incorporati nella piattaforma.
La loro conformità non è nella disponibilità del fornitore e non è stata
verificata come conforme. Sono superfici di **redazione**, usate da chi scrive
un'app, e non compaiono in ciò che i lettori dell'app vedono: le pagine
pubblicate e le app in esecuzione non li contengono. Sotto la larghezza di
schermo di un telefono gli editor non sono proposti affatto.

**Alternativa disponibile**: un'app è un file di testo Markdown. Può essere
scritta con qualunque editor accessibile di propria scelta e importata; può
essere esportata, modificata altrove e reimportata. La creazione e la modifica
non passano necessariamente dagli editor incorporati.

**Le app create dagli utenti** possono contenere barriere che il fornitore non
controlla: un'immagine senza testo alternativo, un colore scelto male, un'etichetta
mancante sono decisioni di chi scrive il documento. La piattaforma fornisce
elementi accessibili e li compone correttamente — etichette associate ai campi,
messaggi di aiuto legati con `aria-describedby`, tabelle con intestazioni,
regioni con nome, contrasto verificato per le palette offerte — ma non può
imporre all'autore di usarli bene. **La conformità di un'app pubblicata è
responsabilità del suo autore**, e per un ente pubblico è un obbligo di legge:
la sezione «accessibilità» della documentazione indica cosa controllare.

### 2.2 Onere sproporzionato

Nessun requisito è escluso per onere sproporzionato.

### 2.3 Non rientranti nella normativa applicabile

Diagrammi generati da Mermaid, formule matematiche rese da KaTeX e output
prodotti dai blocchi Python riflettono il contenuto scritto dall'autore del
documento: la loro comprensibilità dipende da un'alternativa testuale che spetta
all'autore fornire.

## 3. Cosa è stato fatto, e come è verificato

Alcune scelte sono verificate automaticamente a ogni compilazione, non a occhio:

- **Contrasto**: le formule di luminanza relativa e di rapporto di contrasto
  delle WCAG sono implementate nel codice, e un test verifica ogni palette
  offerta contro le superfici su cui il testo effettivamente appare, in tema
  chiaro e scuro. Un colore sotto 4,5:1 fa fallire la compilazione. Le sei
  palette originali erano state scelte a occhio e nessuna superava il requisito.
- **Ridimensionamento del contenuto (§ 1.4.10)**: verificato riducendo il
  documento a 320 px e misurando l'assenza di scorrimento orizzontale. Le
  tabelle, esenti dall'obbligo di riflusso, sono racchiuse in una regione
  scorrevole raggiungibile da tastiera e dotata di nome accessibile.
- **Focus visibile (§ 2.4.7)**, **nome accessibile su ogni controllo di sola
  icona (§ 4.1.2)**, **dimensione minima dei bersagli 24×24 px (§ 2.5.8)** e
  **assenza di sovrapposizioni sul contenuto messo a fuoco (§ 2.4.11)**:
  verificati nell'applicazione in esecuzione.
- **Etichette che nominano il controllo (§ 2.4.6)**: i pulsanti dichiarano la
  funzione, non il formato; i due riquadri dell'ambiente di lavoro sono regioni
  con nome.

## 4. Metodo di valutazione

Autovalutazione condotta dal fornitore, con test automatici integrati nella
compilazione (contrasto, presenza delle stringhe tradotte), prove manuali con
tastiera, verifica del ridimensionamento e ispezione dell'albero di accessibilità.

**Non è stata condotta una valutazione di terza parte indipendente.** Quando
sarà condotta, questa dichiarazione ne riporterà gli esiti e la data.

## 5. Meccanismo di feedback

Chi incontra una barriera può scriverne a **info@reactivenet.ai**,
indicando la pagina o la funzione, il dispositivo e la tecnologia assistiva in
uso. Il riscontro è dato entro **30 giorni**, con la descrizione di come e quando
la barriera sarà rimossa oppure, se non è rimuovibile, dell'alternativa
disponibile.

Le segnalazioni sono gradite anche quando riguardano un requisito che il
progetto ritiene già soddisfatto: un requisito soddisfatto sulla carta e non
nella pratica è esattamente ciò che le prove interne non riescono a vedere.

## 6. Procedura di attuazione

Nei confronti dei soggetti obbligati per legge, l'interessato che non riceva
riscontro soddisfacente entro trenta giorni può rivolgersi al **Difensore civico
per il digitale** presso l'Agenzia per l'Italia Digitale. Poiché il fornitore
non è un soggetto obbligato, quella procedura non è esperibile nei suoi
confronti: resta il canale di feedback del § 5, e la disponibilità del fornitore
a discutere la questione con il committente pubblico interessato.

## 7. Informazioni per gli enti che pubblicano un'app

Un'amministrazione che realizzi un servizio con ReactiveNET **resta il soggetto
obbligato** per l'accessibilità di quel servizio e per la propria dichiarazione.
Quel che la piattaforma le mette a disposizione è: componenti con ruolo, nome e
stato corretti; contrasto verificato; struttura del documento con intestazioni
reali; tabelle con relazioni preservate; funzionamento da tastiera. Quel che le
resta da fare: testi alternativi, ordine e chiarezza dei contenuti, lingua
dichiarata, verifica del proprio servizio con utenti reali, e — dove usa la
funzione di trascinamento delle schede, che richiede un puntatore — verificare
che l'alternativa da tastiera (la modifica della riga) sia adeguata al proprio
caso d'uso.

---

Dichiarazione redatta il 13 agosto 2026 e riesaminata da ultimo il
13 agosto 2026. Il riesame è effettuato almeno annualmente e a ogni
modifica sostanziale della piattaforma.
