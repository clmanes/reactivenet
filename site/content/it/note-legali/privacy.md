---
title: "Informativa sul trattamento dei dati personali"
translationKey: "legal-privacy"
description: "Chi tratta i tuoi dati quando usi ReactiveNET, quali dati, per quanto tempo e con quali diritti. La risposta breve: quasi nessuno, perché le app girano nel tuo browser."
version: "1.6"
updated: "2026-08-18"
weight: 10
---

<!-- GENERATO da site/scripts/sync-legal.mjs — non modificare qui.
     La fonte è legal/it/informativa-privacy.md: modifica quella e rilancia lo script. -->

Resa ai sensi degli articoli 13 e 14 del Regolamento (UE) 2016/679 (di seguito
«GDPR») e del D.lgs. 196/2003 come modificato dal D.lgs. 101/2018.

## 1. Titolare del trattamento

**Cosimo Luigi Manes**, persona fisica, che gestisce il progetto ReactiveNET a
titolo personale e non imprenditoriale
Domicilio: Via Gherardo Robertoni, 5 — 73012 Campi Salentina (LE), Italia
Codice fiscale: MNSCML86R23B506P
Email: info@reactivenet.ai

Non è stato designato un Responsabile della protezione dei dati (RPD/DPO):
il trattamento non rientra in nessuno dei casi dell'art. 37 par. 1 GDPR, non
essendovi né attività di monitoraggio regolare e sistematico su larga scala né
trattamento su larga scala di categorie particolari di dati. Per ogni questione
relativa ai dati personali si scrive direttamente al titolare agli indirizzi
sopra indicati.

## 2. Il principio che spiega quasi tutta questa informativa

ReactiveNET è una piattaforma per creare applicazioni che **girano dentro il
browser di chi le usa**. I documenti che descrivono le app e i dati che le app
raccolgono sono salvati nell'archivio locale del browser (IndexedDB) del
dispositivo: **non transitano da noi, non sono copiati sui nostri server e non
vi abbiamo accesso**. L'unica cosa che l'applicazione misura è la visita, in
forma aggregata e tramite Pirsch Analytics (§ 3.2); documenti, righe delle
collezioni e contenuti continuano a non transitare mai dal titolare, e non
esiste codice che lo faccia.

Ne segue che, per l'uso ordinario dell'app, il titolare del trattamento **non
tratta dati personali**. Restano i trattamenti descritti sotto, che riguardano
il sito e alcune funzioni facoltative.

Chi crea un'app con ReactiveNET e la usa per raccogliere dati di altre persone è
titolare autonomo di quel trattamento, e ne risponde: § 3.11.

## 3. Trattamenti, finalità e basi giuridiche

### 3.1 Navigazione del sito reactivenet.ai

Il fornitore di hosting registra, per il funzionamento e la sicurezza del
servizio, i log tecnici delle richieste: indirizzo IP, data e ora, risorsa
richiesta, codice di risposta, user agent, referente.

- **Finalità**: erogare le pagine richieste, diagnosticare malfunzionamenti,
  rilevare e contrastare abusi e attacchi.
- **Base giuridica**: legittimo interesse del titolare alla sicurezza e alla
  continuità del servizio (art. 6 par. 1 lett. f GDPR).
- **Conservazione**: 30 giorni, salvo il tempo
  ulteriore necessario ad accertare un abuso già rilevato.

### 3.2 Statistiche di traffico (Pirsch Analytics)

Il sito reactivenet.ai e l'applicazione app.reactivenet.ai misurano le visite
con **Pirsch Analytics**, servizio di Emvi Software GmbH (Germania), configurato
senza cookie e senza archiviazione di alcun tipo sul dispositivo. Pirsch non
conserva l'indirizzo IP: lo usa, insieme allo user agent, per calcolare un
valore di sintesi non reversibile con un elemento casuale rigenerato ogni
giorno, che serve solo a non contare due volte la stessa visita nella stessa
giornata e che il giorno dopo non è più ricollegabile a nulla. I dati sono
elaborati e conservati su server situati in Germania. Sia sul sito sia
nell'applicazione il browser carica lo script di misurazione da
`api.pirsch.io` e invia lì i conteggi, quindi contatta direttamente quel
dominio: nel farlo il browser espone il proprio indirizzo IP e lo user agent,
che Pirsch usa come descritto sopra e non conserva. Nessun documento e nessun
dato delle app viene trasmesso in questa richiesta. Pirsch agisce quale
responsabile del trattamento.

- **Dati**: pagina visitata, referente, data e ora, paese, tipo di dispositivo,
  browser e sistema operativo, lingua; sul sito, la pressione di alcuni pulsanti
  (apertura della piattaforma, apertura o download di un'app del catalogo, copia
  dell'indirizzo MCP, link a GitHub e LinkedIn) è contata come evento anonimo,
  senza alcun dato su chi ha premuto.
- **Finalità**: conoscere in forma aggregata quali contenuti sono letti, per
  decidere cosa scrivere e cosa correggere.
- **Base giuridica**: legittimo interesse del titolare a una misurazione
  aggregata del proprio sito (art. 6 par. 1 lett. f GDPR). Non è richiesto
  consenso ai sensi dell'art. 122 del D.lgs. 196/2003 perché non vi è accesso a
  informazioni archiviate sul terminale né alcun identificatore persistente:
  si veda la cookie policy.
- **Conservazione**: dati aggregati, conservati per 24 mesi.

### 3.3 Uso dell'applicazione

Nessun trattamento da parte del titolare su documenti e dati. Documenti, righe
delle collezioni, preferenze di lingua, tema e palette restano in IndexedDB sul
dispositivo. Si cancellano dall'app stessa o svuotando i dati del sito dal
browser. Fa eccezione la sola statistica aggregata di visita descritta al
§ 3.2.

### 3.4 Link di condivisione

Un'app si può condividere in due modi.

Il **link lungo** contiene l'intero documento nel *frammento* dell'indirizzo
(la parte dopo `#`), che per come funziona il web **non viene mai inviato ad
alcun server**: chi riceve il link riceve l'app, e nessun intermediario ne
registra il contenuto.

Il **link breve** deposita il documento su un nostro server, **cifrato dal
browser prima dell'invio** (AES-GCM): la chiave viaggia nel frammento del link e
non ci raggiunge mai. Sul server resta un blob illeggibile, un identificativo e
la data dell'ultima apertura.

- **Dati**: il contenuto del documento, cifrato e non accessibile al titolare;
  data dell'ultima apertura; log tecnici della richiesta come al § 3.1. Se
  l'autore inserisce dati personali nel documento, quei dati sono nel blob
  cifrato e il titolare non è in grado di leggerli.
- **Finalità**: consentire di condividere un'app con un indirizzo breve.
- **Base giuridica**: esecuzione di un servizio richiesto dall'interessato
  (art. 6 par. 1 lett. b GDPR).
- **Conservazione**: **120 giorni dall'ultima apertura**, poi cancellazione
  automatica. Un link mai riaperto scade 120 giorni dopo la creazione.

### 3.5 Account e spazi condivisi

Chi vuole sincronizzare un'app fra più persone crea un account sul nostro
servizio. L'account è **volutamente pseudonimo**: non chiediamo l'email, non
esiste un elenco degli utenti consultabile, e ciascuno vede solo il proprio
profilo. Ai membri di uno spazio sono visibili il nome scelto e la chiave
pubblica di chi lo condivide con loro.

I contenuti sincronizzati (documento e righe) sono **cifrati end-to-end** dal
browser: il server conserva testo cifrato che non è in grado di decifrare, oltre
ai metadati necessari a farlo funzionare — chi ha scritto una modifica, quando,
in quale spazio, con quale ruolo.

- **Dati**: nome utente scelto, password (conservata come hash), nome
  visualizzato, chiave pubblica, appartenenze e ruoli, modifiche cifrate con la
  relativa data e autore, log tecnici come al § 3.1.
- **Finalità**: erogare la sincronizzazione e il controllo degli accessi.
- **Base giuridica**: esecuzione del contratto con l'interessato (art. 6 par. 1
  lett. b GDPR).
- **Conservazione**: per la durata dell'account. La cancellazione dell'account
  o dello spazio si richiede al titolare e comporta l'eliminazione dei relativi
  dati entro 30 giorni.
- **Avvertenza**: la password è l'unica chiave dei contenuti cifrati. Chi la
  perde senza il codice di recupero perde l'accesso agli spazi condivisi.
  Non esiste una procedura di reimpostazione che non sia una porta di servizio
  sulla cifratura, e per questo non esiste.

### 3.6 Servizio open data

Le direttive `::od-*` interrogano un nostro servizio che espone dataset pubblici
italiani in sola lettura. Le richieste contengono la query (parametrizzata) e
nessun dato dell'app: **le righe salvate sul dispositivo non vengono inviate**.
Il servizio registra log tecnici come al § 3.1, per capacità e sicurezza.

- **Base giuridica**: legittimo interesse alla sicurezza e alla continuità del
  servizio; esecuzione della richiesta dell'interessato per la query stessa.
- **Conservazione**: 30 giorni.

### 3.7 Mappe e ricerca di indirizzi

Un documento che usa la direttiva `::map` scarica le mattonelle cartografiche da
`tile.openstreetmap.org`, servizio della **OpenStreetMap Foundation** (Regno
Unito): il loro server riceve l'indirizzo IP del dispositivo e lo user agent.

**La geocodifica — trasformare un indirizzo in coordinate — cerca prima
localmente.** Le coordinate dei numeri civici italiani provengono dall'Archivio
Nazionale dei Numeri Civici e delle Strade Urbane (ANNCSU), che è ospitato sul
nostro stesso servizio dati: per un indirizzo italiano in un comune coperto
dall'archivio **il testo cercato non lascia questa infrastruttura e nessun terzo
lo riceve**.

Solo quando la ricerca locale non trova nulla — un indirizzo all'estero, oppure
in uno dei comuni per i quali l'ANNCSU non riporta coordinate — la richiesta
prosegue verso `nominatim.openstreetmap.org`, e in quel caso il loro server
riceve l'indirizzo IP, lo user agent e **il testo dell'indirizzo cercato**.
Questo avviene solo per i documenti che usano quella funzione, e il titolare non
riceve copia di quelle richieste. Si applicano l'informativa e la usage policy
della OpenStreetMap Foundation.

### 3.8 Pacchetti Python

Un blocco `::python` che dichiara `packages` scarica i pacchetti richiesti da
`cdn.jsdelivr.net` (jsDelivr). L'interprete Python è servito dal nostro sito; i
pacchetti aggiuntivi no, perché pesano quanto l'intera applicazione. Il CDN
riceve l'indirizzo IP del dispositivo e il nome del pacchetto richiesto. Nessun
codice e nessun dato dell'app lasciano il dispositivo: il codice Python è
eseguito localmente, in una WebAssembly nel browser.

### 3.9 Server MCP

Il server MCP consente a un assistente AI di scrivere e verificare un'app. È un
servizio di sole funzioni pure: riceve il testo del documento da validare e
restituisce il risultato, **senza memorizzare nulla** e senza accesso ad alcun
browser. Restano i log tecnici come al § 3.1.

### 3.10 Assistente AI dentro l'applicazione

L'applicazione contiene un assistente che scrive le app su richiesta. È
**disattivato finché non lo si configura**, e come lo si configura decide se
qualcosa esce dal dispositivo:

- **Modello sul proprio computer** (per esempio Ollama, in ascolto su
  `localhost`): la conversazione non lascia la macchina. Non c'è alcun
  fornitore, non c'è alcuna chiave, e il titolare non riceve nulla.
- **Fornitore remoto** (`https://api.openai.com` per impostazione predefinita, o
  qualunque altro indirizzo si indichi): il browser dell'utente parla
  **direttamente** con quel fornitore. Il titolare non è nel mezzo, non riceve
  copia delle conversazioni e non ne conserva traccia.

Con un fornitore remoto vanno a quel fornitore: la domanda scritta, l'intera
conversazione precedente, e — quando l'assistente li consulta per rispondere —
**l'elenco delle app presenti nel browser e il testo completo del documento
dell'app aperta**. Chi tiene dati personali dentro il *documento* di un'app
tenga presente che chiedere all'assistente di modificarla significa inviarne il
testo a quel fornitore.

**Le direttive `ai-*` dentro un'app usano lo stesso modello, e con un fornitore
remoto inviano anche le righe.** Sono le direttive con cui un'app può riassumere
una collezione, rispondere a domande sui propri dati, riempire un modulo da una
frase, classificare righe, riformulare un testo o cercare per significato. Che
cosa viaggia dipende dalla direttiva, e in ogni caso è **un campione delle
righe** e non l'intera collezione:

- il testo del campo o della riga su cui la direttiva sta lavorando;
- un campione delle righe delle collezioni che la direttiva dichiara di leggere;
- per la ricerca semantica, il testo delle righe e **il contenuto testuale degli
  allegati** indicati, inviato una volta per costruire l'indice e poi conservato
  solo su quel dispositivo;
- per la descrizione di un'immagine, l'immagine stessa.

Con un **modello sul proprio computer** nulla di tutto questo lascia la
macchina. Per le app che trattano dati personali — e a maggior ragione categorie
particolari di dati — quella è la sola configurazione che il titolare
raccomanda, ed è il motivo per cui il modello locale è offerto come scelta di
pari dignità e non come curiosità.

Un'app che non contiene direttive `ai-*` non invia **nessuna** riga: fuori da
quelle direttive l'assistente non legge le righe salvate (§ 3.11).

La chiave API è dell'utente e resta **in IndexedDB su quel dispositivo**: non è
mai inviata al titolare, che non la vede e non potrebbe recuperarla. Va trattata
come una credenziale sul proprio dispositivo — chi condivide il computer, o
importa nel proprio browser app di terzi contenenti codice (`::python`), scelga
il modello locale, che di chiavi non ne ha.

Quel trattamento è disciplinato dall'informativa del fornitore scelto e il
titolare non ne è parte. Le richieste dell'assistente al server MCP (§ 3.9)
contengono il testo del documento da controllare e nulla di più.

### 3.11 Dati raccolti dalle app create dagli utenti

Chi crea un'app con ReactiveNET e la usa per raccogliere dati di altre persone —
un modulo di iscrizione, un registro, un elenco di contatti — è **titolare
autonomo** di quel trattamento: sceglie finalità e mezzi, e su di sé ricadono
informativa, base giuridica, tempi di conservazione e risposta ai diritti degli
interessati. Il titolare della piattaforma non ha accesso a quei dati e non è
in grado di intervenire su di essi. Se quell'app è sincronizzata in uno spazio
condiviso, il titolare della piattaforma agisce quale **responsabile del
trattamento** per la sola conservazione del dato cifrato: il rapporto si
disciplina con l'atto di nomina di cui all'art. 28 GDPR, disponibile su
richiesta.

### 3.12 Richieste di contatto

Chi scrive al titolare — per informazioni, segnalazioni, esercizio dei diritti —
conferisce i dati contenuti nel messaggio.

- **Finalità**: rispondere e, se del caso, dare seguito alla richiesta.
- **Base giuridica**: legittimo interesse a dare riscontro alle richieste
  ricevute; misure precontrattuali su richiesta dell'interessato quando il
  messaggio riguarda un'offerta.
- **Conservazione**: due anni dall'ultimo scambio, salvo che la corrispondenza
  documenti un rapporto contrattuale.

## 4. Natura del conferimento

Nessun dato deve essere conferito per leggere il sito o per usare
l'applicazione. È necessario conferire i dati indicati come obbligatori al § 3.5
per creare un account: senza di essi il servizio non può essere erogato.

## 5. Destinatari e responsabili del trattamento

I dati non sono ceduti né venduti a terzi. Possono essere trattati, per nostro
conto e su nostre istruzioni documentate, dai fornitori indispensabili
all'erogazione dei servizi, nominati responsabili ai sensi dell'art. 28 GDPR:

| Fornitore | Ruolo | Dove |
| --- | --- | --- |
| Aruba S.p.A. | hosting del sito, dell'applicazione e dei servizi di condivisione, sincronizzazione e open data, log tecnici, posta elettronica | Italia |
| Emvi Software GmbH (Pirsch Analytics) | statistiche di traffico del sito e dell'applicazione | Germania |

I dati possono inoltre essere comunicati alle autorità pubbliche quando la
comunicazione è imposta da una norma o richiesta nelle forme di legge.

L'elenco aggiornato dei responsabili è disponibile su richiesta scritta al
titolare.

## 6. Trasferimenti fuori dall'Unione europea

I servizi sono ospitati nell'Unione europea e i responsabili indicati sopra vi
sono stabiliti: il titolare non effettua trasferimenti di dati personali verso
paesi terzi. Se un trasferimento dovesse rendersi necessario, avverrebbe sulla
base di una decisione di adeguatezza della Commissione europea, ove applicabile,
o delle clausole contrattuali tipo di cui alla decisione di esecuzione (UE)
2021/914, accompagnate dalle misure supplementari valutate caso per caso, e
questa informativa sarebbe aggiornata prima che il trasferimento abbia luogo.
Copia delle garanzie si ottiene scrivendo al titolare.

Le richieste a OpenStreetMap (§ 3.7) e a jsDelivr (§ 3.8) non sono
trasferimenti operati dal titolare: sono richieste che il browser dell'utente
rivolge direttamente a quei servizi quando il documento aperto le richiede.

Lo stesso vale, e in modo più marcato, per il fornitore di intelligenza
artificiale scelto nell'assistente (§ 3.10): è l'utente a indicare l'indirizzo,
è il suo browser a inviare la conversazione con la propria chiave, e il titolare
non è parte di quel trattamento né in grado di osservarlo. Chi non vuole alcun
trasferimento usi un modello sul proprio computer, come descritto in quel
paragrafo.

## 7. Processi decisionali automatizzati e profilazione

Non ne esistono. Nessun dato è usato per costruire profili, per profilazione
pubblicitaria o per decisioni automatizzate che producano effetti giuridici o
incidano in modo analogamente significativo sulle persone.

## 8. Minori

I servizi non sono destinati a minori di quattordici anni e non ne sollecitano
i dati. Un genitore o tutore che ritenga che un minore abbia conferito dati può
scrivere al titolare: i dati saranno cancellati senza indugio.

## 9. Sicurezza

Le misure tecniche e organizzative adottate ai sensi dell'art. 32 GDPR sono
descritte nella «Politica di sicurezza», che è parte integrante di questa
informativa: cifratura end-to-end dei contenuti sincronizzati, cifratura in
transito, sanitizzazione dell'output e Content Security Policy con Trusted
Types, minimizzazione strutturale (i dati restano sul dispositivo), accesso ai
sistemi limitato al titolare.

## 10. Diritti dell'interessato

Sono riconosciuti i diritti di accesso (art. 15), rettifica (art. 16),
cancellazione (art. 17), limitazione (art. 18), portabilità (art. 20) e
opposizione (art. 21), quest'ultimo in particolare rispetto ai trattamenti
fondati sul legittimo interesse.

Si esercitano scrivendo a info@reactivenet.ai. Il riscontro è dato
senza ingiustificato ritardo e comunque entro un mese, prorogabile di due mesi
per richieste complesse, con informativa sulla proroga.

Un limite va detto con chiarezza: **sui contenuti cifrati end-to-end e sui
link brevi il titolare non può leggere né rettificare alcunché**, perché non
possiede le chiavi. Può cancellarli, e lo fa su richiesta.

Resta il diritto di proporre **reclamo al Garante per la protezione dei dati
personali** (Piazza Venezia 11, 00187 Roma — garante@gpdp.it) o di adire
l'autorità giudiziaria.

## 11. Modifiche

Questa informativa può essere aggiornata quando cambiano i servizi o i
fornitori. La versione e la data in testa al documento dicono a cosa si sta
guardando; le modifiche sostanziali sono comunicate agli utenti registrati
prima che abbiano effetto.

---

Versione 1.4 — 14 agosto 2026. In caso di divergenza fra la versione
italiana e quella inglese di questo documento prevale la versione italiana.
