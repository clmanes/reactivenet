---
title: "Politica di sicurezza"
translationKey: "legal-security"
description: "Come è protetta la piattaforma, cosa il fornitore non è in grado di leggere, e come segnalare una vulnerabilità senza rischiare conseguenze."
version: "1.0"
updated: "2026-08-13"
---

# Politica di sicurezza

Documento reso ai sensi dell'art. 32 GDPR quanto alle misure tecniche e
organizzative, e valevole come **politica di divulgazione coordinata delle
vulnerabilità**.

## 1. La misura di sicurezza principale è un'assenza

I dati delle app restano nel browser di chi le usa. Non c'è un archivio centrale
dei documenti, non c'è un archivio centrale delle righe, non c'è telemetria.
Il rischio di una violazione massiva dei dati degli utenti è ridotto per
costruzione, non per configurazione: **non è possibile esfiltrare un archivio
che non esiste**.

Ciò che sta sui nostri sistemi è poco e cifrato: i documenti dei link brevi e le
modifiche degli spazi condivisi, cifrati dal browser prima dell'invio, con le
chiavi che non ci raggiungono mai.

## 2. Misure tecniche

**Cifratura end-to-end.** Gli spazi condivisi cifrano i contenuti sul
dispositivo; il server conserva testo cifrato e i metadati necessari a
distribuirlo. La revoca di un accesso ruota la chiave di epoca, così che il
revocato non possa leggere ciò che viene scritto dopo: quanto ha già letto non
può essere richiamato indietro, e questo è un limite della crittografia, non una
scelta.

**Link brevi cifrati.** Il documento è sigillato con AES-GCM; la chiave viaggia
nel frammento dell'indirizzo, che il browser non invia ad alcun server. Un
tentativo di manomissione del blob fallisce l'autenticazione e non viene
importato.

**Difesa contro il cross-site scripting.** È il modello di minaccia principale,
perché la funzione stessa della piattaforma è trasformare testo scritto da
qualcuno in HTML. Le difese sono stratificate perché nessuna sia decisiva da
sola: gli indirizzi non sicuri non sono rappresentabili nel sistema di tipi;
l'HTML generato passa obbligatoriamente da DOMPurify prima di raggiungere il
documento; i valori salvati dalle app sono inseriti come **testo**, mai come
markup; una Content Security Policy senza `unsafe-inline` e senza `unsafe-eval`
sugli script, con Trusted Types, chiude la strada a ciò che dovesse sfuggire ai
livelli precedenti; le espressioni nei documenti sono valutate da un parser
scritto per lo scopo, non da `eval`.

**Isolamento dell'esecuzione di Python.** Il codice Python dei documenti è
eseguito da CPython compilato in WebAssembly, in un *worker* separato, con un
limite di tempo oltre il quale il worker è terminato: un ciclo infinito scritto
per errore non blocca l'applicazione.

**Trasporto e intestazioni.** Tutto il traffico è su HTTPS con HSTS. Sono
attive `X-Content-Type-Options`, `X-Frame-Options: DENY`, `frame-ancestors 'none'`,
`Referrer-Policy: no-referrer`, isolamento cross-origin e una `Permissions-Policy`
che disattiva fotocamera, microfono, geolocalizzazione e gli altri permessi non
usati.

**Controllo degli accessi lato server.** Le regole delle collezioni e i *hook*
del servizio verificano il ruolo di chi scrive: un partecipante con ruolo di sola
lettura non può scrivere, e il rifiuto avviene sul server, non nell'interfaccia.

**Autenticazione.** Le password sono conservate come hash. L'account è pseudonimo
e non esiste un elenco degli utenti consultabile.

## 3. Misure organizzative

L'accesso ai sistemi è riservato al titolare, con autenticazione a più fattori
dove il fornitore la rende disponibile. Le dipendenze sono aggiornate
periodicamente e in via straordinaria quando è pubblicata una vulnerabilità che
riguarda una componente in uso. Le modifiche al codice passano da un controllo
del *diff*, e le regole di sicurezza descritte sopra sono coperte da test
automatici che fanno fallire la compilazione — fra questi, la verifica che la
policy servita agli host statici coincida con quella dichiarata nella
configurazione, perché una divergenza lì sarebbe invisibile a ogni prova locale.

## 4. Segnalare una vulnerabilità

Le segnalazioni sono benvenute e trattate con serietà.

**Dove**: security@reactivenet.ai
**Chiave pubblica per messaggi cifrati**: non disponibile

**Cosa scrivere**: la componente interessata, i passi per riprodurre il problema,
l'impatto che si ritiene abbia e, se possibile, una prova di concetto minima.
La lingua può essere l'italiano o l'inglese.

**Tempi**: presa in carico entro **5 giorni lavorativi**; valutazione e piano di
correzione entro **30 giorni**; divulgazione pubblica concordata, in via
ordinaria non oltre **90 giorni** dalla segnalazione o alla disponibilità della
correzione, se anteriore. Chi segnala è citato nel ringraziamento pubblico, se
lo desidera.

**Nessun compenso**: non è previsto un programma di ricompense. Non è un modo
per svalutare il lavoro di chi segnala; è per non prometterlo e non mantenerlo.

### 4.1 Ambito

**Nel perimetro**: `reactivenet.ai` e i sottodomini del fornitore,
l'applicazione ReactiveNET, i servizi di condivisione e sincronizzazione, il
servizio open data, il server MCP, il codice sorgente pubblicato.

**Fuori perimetro**: i servizi di terzi (fornitore di hosting, piattaforma di
videoconferenza, OpenStreetMap, jsDelivr), le app scritte dagli utenti e i loro
contenuti, gli attacchi di ingegneria sociale verso il fornitore o i suoi
clienti, gli attacchi fisici, la saturazione delle risorse (denial of service),
e le segnalazioni prodotte da uno scanner automatico senza dimostrazione di un
impatto concreto — comprese le consuete rilevazioni su intestazioni mancanti,
versioni dichiarate o cifrari accettati.

### 4.2 Impegno verso chi segnala

A chi conduce ricerca in buona fede nel perimetro sopra indicato, rispettando le
regole che seguono, il fornitore **non promuove azioni legali** e non segnala
l'attività alle autorità, considerandola autorizzata:

- accedere solo ai dati strettamente necessari a dimostrare la vulnerabilità, e
  fermarsi appena la dimostrazione è raggiunta;
- non accedere, copiare, modificare o cancellare dati di altri utenti — se
  accade incidentalmente, interrompere e dirlo nella segnalazione;
- non degradare il servizio, non eseguire test di carico o di saturazione;
- non divulgare la vulnerabilità prima del termine concordato;
- usare esclusivamente dati di prova propri.

Questo impegno riguarda le sole azioni del fornitore e non può estendersi a
diritti di terzi né alle valutazioni dell'autorità giudiziaria.

## 5. Violazioni dei dati personali

In caso di violazione che comporti un rischio per i diritti e le libertà delle
persone, il fornitore la notifica al **Garante per la protezione dei dati
personali entro 72 ore** dal momento in cui ne viene a conoscenza (art. 33
GDPR) e, quando il rischio è elevato, ne dà comunicazione senza ingiustificato
ritardo agli interessati (art. 34 GDPR). Ogni violazione, anche non notificabile,
è registrata con le circostanze, gli effetti e i provvedimenti adottati.

Quando il fornitore agisce come **responsabile del trattamento** per conto di un
cliente, informa il titolare **senza ingiustificato ritardo e comunque entro 24
ore** dalla conoscenza dell'evento, con gli elementi necessari perché il titolare
possa a sua volta adempiere.

## 6. `security.txt`

Il file seguente va pubblicato in `site/static/.well-known/security.txt` e
aggiornato alla scadenza:

```
Contact: mailto:security@reactivenet.ai
Expires: 2027-08-13T00:00:00.000Z
Preferred-Languages: it, en
Canonical: https://reactivenet.ai/.well-known/security.txt
Policy: https://reactivenet.ai/note-legali/sicurezza/
```

---

Versione 1.0 — 13 agosto 2026. In caso di divergenza fra la versione
italiana e quella inglese prevale la versione italiana.
