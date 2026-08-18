# legal/

I documenti normativi di ReactiveNET. L'italiano è il testo di riferimento;
l'inglese è una traduzione fedele e, in caso di divergenza, prevale l'italiano
(ogni documento lo dice al proprio interno).

```
legal/
  it/  informativa-privacy · cookie-policy · termini-di-servizio
       dichiarazione-accessibilita · licenze-e-attribuzioni
       politica-di-sicurezza · nomina-responsabile-art28
  en/  le stesse sette, tradotte
```

## I segnaposto: ne resta uno solo, ed è un modello

I documenti pubblicati sono **compilati**. Gli unici segnaposto rimasti — il
valore fra doppie graffe — sono quelli dell'atto di nomina ex art. 28
(`it/nomina-responsabile-art28.md` e
`en/data-processing-agreement.md`), che non è una pagina web ma un **modello di
contratto**: denominazione, sede, codice fiscale ed email del cliente, data e
oggetto del contratto, categorie di dati e di interessati, luogo del
trattamento. Si compilano volta per volta, alla firma, e devono restare
segnaposto nel repository. Verifica:

```sh
grep -rn "{{" legal/ | grep -v art28 | grep -v data-processing-agreement
```

I dati compilati, identici nelle due lingue:

| Voce | Valore |
| --- | --- |
| Titolare e fornitore | Cosimo Luigi Manes, persona fisica, a titolo personale e non imprenditoriale |
| Domicilio | Via Gherardo Robertoni, 5 — 73012 Campi Salentina (LE), Italia |
| Codice fiscale | MNSCML86R23B506P |
| Email | info@reactivenet.ai (contatti, privacy, accessibilità) |
| Segnalazioni di sicurezza | security@reactivenet.ai — nessuna chiave PGP |
| Foro competente | Lecce, fatto salvo il foro inderogabile del consumatore |
| Hosting (sito, app, PocketBase, server MCP, servizio dati) | Aruba S.p.A., Italia — un solo fornitore, una sola voce |
| Posta elettronica | Aruba S.p.A., Italia |
| Licenza del software | proprietario, tutti i diritti riservati (© Cosimo Luigi Manes) |
| Licenza dei contenuti editoriali | CC BY 4.0 |
| Conservazione | log hosting 30 giorni · log servizio dati 30 giorni · statistiche Pirsch 24 mesi |
| Prima pubblicazione | 13 agosto 2026 |

Due assenze da non reintrodurre. **Non esiste un recapito di posta elettronica
certificata**: dove i documenti ne indicavano uno — comprese le comunicazioni
contrattuali — il canale è l'email di contatto, e il riferimento è stato
tolto, non lasciato vuoto. E **la normativa non parla di formazione**:
l'attività non è un servizio della piattaforma, quindi nessun documento nomina
corsi, iscrizioni, attestati o l'ente che li organizza. È la scelta che ha reso
gratuita la rimozione della sezione Formazione dal sito, il 17 agosto 2026:
c'era da togliere delle pagine, e non una riga di questi documenti. Se un giorno
l'attività torna, torna come marketing e non come normativa — la regola resta
questa.

Resta da scrivere un file `LICENSE` alla radice del repository, coerente con
`licenze-e-attribuzioni`: è là che si va a cercare la licenza.

## Come vanno pubblicati

Devono essere raggiungibili da una pagina del sito (il footer è il posto
consueto) e da un link nell'app. Il sito Hugo è bilingue con `contentDir`
separati, quindi ogni documento va copiato — o simlinkato — sotto
`site/content/it/…` e `site/content/en/…` con la stessa `translationKey`, che
è già nella frontmatter di ciascun file. Gli URL suggeriti, coerenti con la
convenzione del sito (path italiano anche in inglese):

| Documento | URL |
| --- | --- |
| Informativa privacy | `/note-legali/privacy/` |
| Cookie policy | `/note-legali/cookie/` |
| Termini di servizio | `/note-legali/termini/` |
| Dichiarazione di accessibilità | `/note-legali/accessibilita/` |
| Licenze e attribuzioni | `/note-legali/licenze/` |
| Politica di sicurezza | `/note-legali/sicurezza/` |

L'atto di nomina ex art. 28 non è una pagina web: è un **modello di contratto**
da allegare all'offerta quando il cliente è una pubblica amministrazione o
comunque un titolare che ci affida un trattamento.

La politica di sicurezza chiede anche un file statico
`site/static/.well-known/security.txt`: il contenuto pronto è in fondo al
documento.

## Cose che i documenti affermano e che il codice deve continuare a rendere vere

Non sono formule: sono descrizioni verificabili dell'architettura. Se una di
queste cambia, il documento va cambiato nello stesso commit.

- **Nessuna telemetria sui contenuti.** L'app invia a Pirsch solo la visita in
  forma aggregata (§ 3.2 dell'informativa); documenti e dati non lasciano il
  dispositivo, e non esiste codice che lo faccia.
- **I dati stanno su IndexedDB, e nient'altro.** Regola già scritta in
  `CLAUDE.md`; l'informativa la trasforma in una promessa verso l'esterno.
- **I link brevi sono cifrati lato client** e il server conserva un blob che non
  può leggere, con cancellazione dopo 120 giorni (`pb/pb_hooks/shares.pb.js`).
  Se cambia il periodo, cambia il numero in due documenti.
- **Gli spazi condivisi sono end-to-end**: il server vede cifrato, ruoli e
  metadati. È l'unica affermazione forte dell'informativa e regge solo finché
  regge `doc/rbac.md`.
- **I terzi contattati dall'app** sono **Pirsch** (sempre, per la misurazione:
  vedi sotto), **OpenStreetMap** (tile e geocodifica Nominatim, solo per i
  documenti che usano `::map`) e **jsDelivr** (solo per i documenti che
  dichiarano `packages` in un blocco `::python`). Aggiungerne un altro significa
  aggiornare informativa e cookie policy.

## Analytics: Pirsch, e una conseguenza tecnica

I documenti descrivono **Pirsch Analytics** (Emvi Software GmbH, Germania) come
statistica senza cookie, con IP non conservato e dati in UE — che è ciò che
rende difendibile l'assenza di banner. Perché resti vero va configurato così.
È usato **sul sito Hugo e sull'app**.

Nell'app lo script è caricato **direttamente da `api.pirsch.io`**, e la CSP lo
concede: `script-src 'self' 'wasm-unsafe-eval' https://api.pirsch.io`, in
`vite.config.js` e in `public/_headers`, che `SecurityPolicy_test` tiene
allineati. È l'unica origine di terze parti in `script-src`, ed è una scelta
deliberata con un costo che va detto: `script-src` è la direttiva che decide se
del markup iniettato può eseguire, e quella decisione ora è anche di Pirsch. In
cambio si usa lo snippet che Pirsch pubblica, senza modificarlo.

La conseguenza per i documenti è che il browser contatta quell'host da sé, e
questo va scritto dove prima era scritto il contrario: **informativa § 3.2** e
**cookie policy § 3** lo dicono, e la frase «il browser non contatta alcun host
terzo» non deve tornare finché la CSP resta questa.

La strada del ritorno esiste ed è cablata: il **proxy same-origin** `/pa/*`
(in `vite.config.js`, `public/_redirects` e `Caddyfile`, lo stesso trattamento
di `/pb` e `/od`). Riscrivere lo snippet come `src="/pa/pa.js"` con
`data-hit-endpoint="/pa/hit"`, `data-event-endpoint="/pa/event"` e
`data-session-endpoint="/pa/session"` rimette tutto sull'origine dell'app e
consente di togliere il token dalla CSP — e di rimettere quella frase.

## Versioni

Ogni documento porta in frontmatter `version` e `updated`. Una modifica
sostanziale — nuovo trattamento, nuovo destinatario, nuova clausola onerosa —
alza la versione e va comunicata agli utenti registrati; una correzione di
refuso no.
