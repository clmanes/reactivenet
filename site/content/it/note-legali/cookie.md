---
title: "Cookie policy"
translationKey: "legal-cookie"
description: "Questo sito non usa cookie. L'app usa l'archivio locale del browser per tenere le tue app, che è dove devono stare. Qui è spiegato cosa c'è dentro e come si cancella."
version: "1.3"
updated: "2026-08-15"
weight: 20
---

<!-- GENERATO da site/scripts/sync-legal.mjs — non modificare qui.
     La fonte è legal/it/cookie-policy.md: modifica quella e rilancia lo script. -->

Resa ai sensi dell'art. 122 del D.lgs. 196/2003 e delle «Linee guida cookie e
altri strumenti di tracciamento» del Garante per la protezione dei dati
personali (provvedimento del 10 giugno 2021, n. 231).

## 1. Cosa disciplina questo documento

La legge non parla soltanto di cookie: parla di **qualunque archiviazione di
informazioni sul dispositivo dell'utente, e di qualunque accesso a informazioni
già archiviate**. Rientrano quindi anche `localStorage`, `sessionStorage`,
IndexedDB, la cache del service worker e le tecniche di identificazione passiva.
Questo documento le tratta tutte, perché la distinzione che conta non è il nome
della tecnologia ma **a cosa serve**: se serve a erogare il servizio che
l'utente ha chiesto è tecnica e non richiede consenso; se serve a seguire una
persona fra siti e nel tempo richiede consenso preventivo.

## 2. Il sito non usa cookie

Le pagine di `reactivenet.ai` **non impostano alcun cookie**, né tecnico né di
terze parti, e non salvano nulla nel `localStorage`. Non c'è nulla da accettare
e per questo non c'è alcun banner: un banner che chiede il consenso a nulla è
un ostacolo, non una tutela.

I caratteri tipografici sono serviti dal nostro stesso dominio: non c'è alcuna
richiesta a servizi esterni di font. Non ci sono video incorporati da terzi,
pulsanti social, pixel pubblicitari o iframe di terze parti.

## 3. Statistiche senza cookie: Pirsch Analytics

Le visite al sito `reactivenet.ai` e all'applicazione `app.reactivenet.ai`
sono contate con **Pirsch Analytics** (Emvi Software GmbH, Germania), scelto
perché è possibile misurare un sito senza inseguire chi lo legge.

- **Non imposta cookie** e non scrive nulla sul dispositivo: né sul sito né
  nell'applicazione Pirsch archivia o legge alcunché sul terminale.
- **Non conserva l'indirizzo IP.** Lo usa insieme allo user agent per calcolare
  un valore di sintesi non reversibile, con un elemento casuale che cambia ogni
  giorno: serve soltanto a non contare due volte la stessa visita nella stessa
  giornata, e il giorno successivo non è più ricollegabile ad alcunché.
- **Non identifica** e non segue la persona fra siti diversi o fra giornate
  diverse: non esiste un identificatore persistente.
- **I dati restano in Germania**, su server dell'Unione europea.

Sono rilevati: pagina visitata, referente, data e ora, paese, tipo di
dispositivo, browser, sistema operativo, lingua del browser. Nient'altro.
Sul sito come nell'applicazione lo script è caricato da `api.pirsch.io` e i
conteggi sono inviati lì: il browser contatta quel dominio direttamente, e nel
farlo espone indirizzo IP e user agent, che Pirsch usa come sopra e non
conserva. È l'unico contatto con un terzo che avviene sempre, e non dipende da
cosa un documento contiene.

Poiché né sul sito né nell'applicazione vi è archiviazione sul terminale o
accesso a informazioni ivi archiviate, **non è richiesto il consenso** ai
sensi dell'art. 122 del D.lgs.
196/2003. Il trattamento dei dati aggregati che ne risulta si fonda sul
legittimo interesse del titolare (art. 6 par. 1 lett. f GDPR), rispetto al quale
è sempre possibile esercitare il diritto di opposizione scrivendo a
info@reactivenet.ai.

Molti browser inviano il segnale *Do Not Track* o *Global Privacy Control*:
Pirsch lo rispetta e non conteggia quelle visite.

## 4. L'applicazione: IndexedDB, e perché non è tracciamento

L'applicazione ReactiveNET salva **nel browser dell'utente**, tramite IndexedDB:

| Cosa | Perché |
| --- | --- |
| I documenti delle app installate in quel browser | sono le app: senza di esse non c'è nulla da aprire |
| Le righe delle collezioni (i dati che le app raccolgono) | sono i dati dell'utente, e stanno dove li ha messi |
| La lingua, il tema chiaro/scuro, la palette scelta | perché la scelta non vada rifatta a ogni apertura |
| Le credenziali di sessione degli spazi condivisi, per chi ne usa | per non dover rifare l'accesso a ogni visita |

Sono tutte **finalità tecniche**: erogano esattamente il servizio che l'utente
ha chiesto aprendo l'app, e nessuna di quelle informazioni viene inviata a noi o
a terzi. Non richiedono consenso, e sono descritte qui perché l'utente sappia
che il suo dispositivo contiene i suoi dati e che è lui a poterli cancellare.

Il progetto **non usa `localStorage` né `sessionStorage`**, per scelta
architetturale. Chi ispezionasse gli strumenti per sviluppatori su `localhost`
potrebbe vedere voci scritte da altri progetti sulla stessa porta: non sono
nostre.

## 5. Service worker e funzionamento offline

L'applicazione è una *progressive web app*: un service worker mantiene una copia
locale dei file dell'interfaccia perché le app continuino a funzionare senza
rete e si aprano rapidamente. La cache contiene **codice dell'applicazione**,
non dati personali e non contenuti dell'utente. Si svuota disinstallando l'app o
cancellando i dati del sito dal browser.

## 6. Richieste a terzi che dipendono dal contenuto dell'app

Alcune funzioni, e solo se un documento le usa, fanno partire una richiesta a un
servizio esterno. Non sono strumenti di tracciamento e non archiviano nulla sul
dispositivo, ma il terzo riceve l'indirizzo IP come per qualunque visita a un
sito.

| Servizio | Quando | Cosa riceve |
| --- | --- | --- |
| `tile.openstreetmap.org` (OpenStreetMap Foundation) | il documento usa `::map` | indirizzo IP, user agent, l'area di mappa richiesta |
| `nominatim.openstreetmap.org` (OpenStreetMap Foundation) | il documento cerca un indirizzo **e la ricerca locale non lo ha trovato** (indirizzo estero, o comune senza coordinate nell'ANNCSU) | indirizzo IP, user agent, **il testo cercato** |
| `cdn.jsdelivr.net` (jsDelivr) | un blocco `::python` dichiara `packages` | indirizzo IP, nome del pacchetto |

Un autore che non usi mappe né pacchetti Python pubblica un'app che, oltre alla
misurazione di § 3, non contatta nessuno.

## 7. Come cancellare quanto è archiviato

- **Dall'app**: si elimina una singola app dalla galleria, oppure si esporta e
  poi si cancella; il pannello dati consente il backup e la cancellazione delle
  collezioni.
- **Dal browser**: impostazioni → privacy → dati dei siti → `reactivenet.ai` →
  elimina. Questo rimuove IndexedDB e la cache del service worker.
  **Le app non salvate altrove vanno perse**: sono sul dispositivo e non ne
  esiste copia presso di noi.
- **Navigazione in incognito**: tutto ciò che è stato salvato è cancellato alla
  chiusura della finestra.

## 8. Modifiche

Se un giorno il sito o l'app dovessero usare cookie o strumenti che richiedono
il consenso, questo documento sarà aggiornato **prima** e il consenso sarà
raccolto con un meccanismo conforme, con possibilità di rifiutare senza perdere
l'accesso ai contenuti.

---

Versione 1.2 — 14 agosto 2026. Per il quadro completo dei trattamenti
si veda l'«Informativa sul trattamento dei dati personali». In caso di
divergenza fra la versione italiana e quella inglese prevale la versione
italiana.
