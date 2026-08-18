# Reactive Data — warehouse open data

Layer dati lato server di Reactive: un warehouse **DuckDB** di dati open
italiani, che il servizio HTTP (in arrivo) esporrà alle app tramite le
direttive `od-*` — query SQL read-only e ricerca semantica sul catalogo.

La prima fonte ingerita è **schema.gov.it** (NDC — Catalogo Nazionale della
semantica dei dati): i ~200 vocabolari controllati delle PA (comuni,
province, regioni, ATECO, titoli di studio, professioni, …) diventano le
tabelle-dimensione canoniche su cui agganciare le fonti di fatti che
arriveranno dopo. La seconda è **dati.normattiva.it**: i metadati di tutti
gli atti normativi statali dal 1861 (tabella `lex_atti`, con ricerca
semantica per riga sulla legislazione della Repubblica). Poi i **carburanti**
del MIMIT (`carb_impianti`/`carb_prezzi`, la fonte più viva: si aggiorna ogni
mattina) e i **CIG di ANAC** (`anac_cig`, le gare pubbliche, con ricerca
semantica sui lotti di importo maggiore).

Tutte le tabelle di fatti si agganciano ai vocabolari tramite il **codice
ISTAT del comune** — è la spina dorsale del warehouse.

## Struttura

```
data/
  server.mjs        servizio HTTP: /datasets, /query (SELECT-only), /search
  etl/
    schema.mjs      ingestione vocabolari controllati di schema.gov.it
    normattiva.mjs  ingestione atti normativi (dati.normattiva.it) + embeddings per riga
    carburanti.mjs  ingestione impianti e prezzi carburanti (MIMIT Osservaprezzi)
    anac.mjs        ingestione CIG / gare pubbliche (ANAC) + embeddings per riga
    embed.mjs       embeddings del catalogo (Qwen3-Embedding via Ollama)
  raw/              cache dei download (gitignored)
  warehouse.duckdb  il database (gitignored)
```

## Uso

```sh
bun install
bun run etl        # tutti i vocabolari (~200)
bun run embed      # embeddings del catalogo (serve Ollama + qwen3-embedding:0.6b)
bun run server     # servizio su :8788 (PORT/OLLAMA_URL/EMBED_MODEL via env)

bun etl/schema.mjs --only istat/cities   # un solo vocabolario
bun etl/schema.mjs --max 5               # i primi N (debug)
bun etl/schema.mjs --refresh             # ignora la cache in raw/

bun etl/normattiva.mjs                   # tutti gli atti (cache per anno; serve Ollama)
bun etl/normattiva.mjs --from 2024       # solo gli anni recenti
bun etl/normattiva.mjs --skip-embed      # senza embeddings

bun run etl:carburanti                   # impianti + prezzi (snapshot del giorno)
bun etl/carburanti.mjs --refresh         # riscarica ignorando la cache

bun run etl:anac                         # CIG degli ultimi 2 anni + embeddings di TUTTI
                                         # i lotti (serve Ollama; ~25h, ripartibile)
bun etl/anac.mjs --from 2019 --to 2025   # più storico (~5,3M righe)
bun etl/anac.mjs --skip-embed            # solo caricamento, niente embeddings
bun etl/anac.mjs --embed-min 1000000     # perimetro ridotto (~44k righe/anno, ~30 min)

bun run etl:popolazione                  # bilancio demografico per comune (denominatore pro capite)
bun run etl:indicepa                     # anagrafica delle PA (ponte alle gare via CF)
bun run etl:confini                      # confini ISTAT: comuni + province + regioni (GeoJSON)
bun etl/istat-confini.mjs --year 2025    # forza l'annata (deve combaciare col resto del warehouse)

bun run etl:opencoesione                 # progetti coesione: caricamento + embed ≥ 150.000 €
bun etl/opencoesione.mjs --embed-min 0   # embed di TUTTI i progetti (ore; ripartibile come anac)
bun etl/opencoesione.mjs --skip-embed    # solo caricamento, niente embeddings

bun run etl:opencup                      # tutti i progetti CUP: caricamento (niente embed, ~5 min)
bun etl/opencup.mjs --refresh            # ignora la cache in raw/opencup/ e riscarica (~2,6 GB)

bun run etl:aci-veicoli                  # parco veicolare per comune + alimentazione per provincia
bun run etl:giustizia-durata             # durata procedimenti civili (SICID + SIECIC) per ufficio
bun run etl:dispersione                  # dispersione scolastica: serie nazionale + dettaglio regionale (da PDF)
bun run etl:iscrizioni                   # alunni iscritti per comune/grado/anno (10 anni)
bun run etl:edilizia-scolastica          # edifici scolastici: epoca di costruzione, rischio sismico
bun run etl:personale-scuola             # docenti e ATA titolari per provincia (10 anni)
bun run etl:invalsi-regionale            # risultati INVALSI campionari per regione (11 anni)
```

Un run lungo conviene staccarlo dalla sessione e seguirlo dal log:

```sh
setsid nohup bun etl/anac.mjs > anac-embed.log 2>&1 &
tail -f anac-embed.log
```

## Aggiornamento periodico (`etl/refresh-all.mjs`)

L'orchestratore aggiorna il warehouse lanciando ogni sorgente secondo la sua
**cadenza** (registro `SOURCES` in testa al file: carburanti daily; camera,
senato, giustizia, consulta, normattiva, indicepa weekly; ANAC, INAIL,
farmacie, vocabolari monthly; le fonti annuali ISTAT/MEF/INVALSI/ISPRA
quarterly), poi la coda fissa semantica → embed → export-site. Lo stato vive
in `etl-state.json` (una sorgente fallita ritenta al run successivo); le
sorgenti dovute girano con `--refresh`, e quelle con embeddings ricevono
`--skip-embed` se Ollama non è raggiungibile (il debito resta annotato nello
stato e si recupera al primo run con Ollama attivo).

```sh
bun run refresh                          # aggiorna ciò che è scaduto
bun etl/refresh-all.mjs --list           # registro, ultimo run, cosa è dovuto
bun etl/refresh-all.mjs --only camera --force   # forza una sorgente
bun etl/refresh-all.mjs --seed           # marca tutto come fresco (una tantum)
bun etl/refresh-all.mjs --deploy         # a run pulito: ./deploy.sh --data-only
```

Da cron (ogni notte alle 4; `flock` evita run sovrapposti):

```cron
0 4 * * * cd <repo>/data && flock -n /tmp/reactive-etl.lock bun etl/refresh-all.mjs >> etl.log 2>&1
```

Prima di partire verifica di poter aprire il warehouse **in scrittura**: un
server dati attivo sul file (anche READ_ONLY) blocca lo scrittore — il run
esce con messaggio chiaro invece di corrompere o restare appeso. In
produzione non è un problema: l'ETL gira sul client e `deploy.sh --data-only`
fa rsync + restart sul server dati.

Il servizio apre il database READ_ONLY e **senza accesso esterno** (niente
read_csv/httpfs dalle query, che sono SQL arbitrario di chiunque); `/query`
accetta **solo SELECT singole** (validate con `json_serialize_sql`, il parser
di DuckDB), con LIMIT forzato (default 1000, max 10000), timeout 10s via
`interrupt()` e parametri preparati.

⚠️ **La sequenza di avvio è delicata, non riordinarla.**
`enable_external_access=false` messo nella CONFIG impedisce anche di
**caricare le estensioni** ("Loading external extensions is disabled through
configuration") — e senza `vss` l'indice HNSW non verrebbe usato, con
`/search` che tornerebbe a scansionare milioni di vettori. Il server apre
quindi **senza** il flag, carica `vss` e **richiude la porta a runtime**: il
`SET` è **globale** all'istanza (verificato: le connessioni successive nascono
già con read_csv/httpfs/glob bloccati) e l'indice continua a funzionare. Se il
`SET` fallisce il servizio **non parte**. `/search` embedda la domanda col **motore ONNX
integrato** (Transformers.js su CPU, stesso modello e opzioni del RAG
in-app: Qwen3-Embedding-0.6B q8, pooling last_token; ~600 MB scaricati al
primo avvio in `model-cache/`) e fa cosine sul catalogo — se c'è un Ollama
locale viene usato come acceleratore, ma **non è richiesto**. `/search`
accetta anche un vettore già pronto (`{"vector": FLOAT[1024]}`, embeddato
dal client col prefisso-query del RAG) e, con `{"table": "lex_atti"}`,
cerca tra le **righe** di una tabella abilitata (whitelist `ROW_SEARCH` in
`server.mjs`, proiezione fissa per tabella) invece che tra i dataset.
L'ETL scrive sul file: va eseguito **a servizio fermo** (o su una copia,
poi swap). NB: `bun run embed` (catalogo) e gli embeddings di
`normattiva.mjs` usano Ollama — girano dove fai l'ETL, non sul server.

## Come funziona

1. elenco degli asset da `/api/semantic-assets` (filtro `CONTROLLED_VOCABULARY`);
2. per ogni vocabolario i dettagli `by-iri` danno ente, concetto e
   distribuzioni; i dati si prendono **dalla distribuzione CSV ufficiale su
   GitHub** (`italia/dati-semantic-assets`, derivata dall'URL del Turtle) —
   l'API piatta dell'NDC (`/api/vocabularies/<ente>/<concetto>`) è solo un
   ripiego perché per alcuni vocabolari è tronca (es. `istat/cities` vi
   espone 21 comuni su ~8000, contro le ~38500 righe del CSV con lo storico);
3. ogni vocabolario diventa una tabella `voc_<ente>_<concetto>` (colonne
   del CSV così come sono, `all_varchar`; le date sono stringhe
   `dd-mm-yyyy`, fine validità `31-12-9999` = tuttora valido). Il parse CSV
   è a tentativi: rigoroso, poi `null_padding`/`strict_mode=false` per i
   file "ragged", poi `ignore_errors` — e si ritenta se lo sniffer non
   riconosce il `;` (sintomo: un'unica colonna con `;` nel nome);
4. la tabella **`catalog`** descrive ogni tabella (titolo e descrizione
   ufficiali, URL della distribuzione, colonne in JSON) più una colonna
   `embedding FLOAT[1024]` (Qwen3-Embedding-0.6B, popolata da un passo
   separato, in arrivo) per la ricerca semantica.

## Normattiva (`etl/normattiva.mjs`)

Metadati (mai i testi) di **tutti gli atti normativi statali** pubblicati in
Gazzetta Ufficiale dal 1861: `POST /ricerca/avanzata` dell'API Open Data del
Poligrafico, paginata **per anno di pubblicazione** (200 atti/pagina, cache
`raw/normattiva/<anno>.ndjson`, l'anno corrente si riscarica sempre). Il WAF
esige header da browser (`Origin: https://dati.normattiva.it`) e ogni tanto
chiude il socket: i retry hanno backoff generoso e il run è ripartibile.
Ogni riga di `lex_atti` porta due link costruiti deterministicamente:
`url_normattiva` (URN NIR `urn:nir:stato:<slug>:<data>;<numero>` → testo
vigente) e `url_gu` (pagina ELI della GU da data + codice redazionale).
Gli **embeddings per riga** coprono la legislazione primaria della
Repubblica (≥1946: leggi, decreti-legge, decreti legislativi, leggi
costituzionali — ~24k atti) e vengono riportati tra i run per codice
redazionale: i run successivi embeddano solo il nuovo.

## Carburanti (`etl/carburanti.mjs`)

I due CSV dell'**Osservaprezzi MIMIT** (`anagrafica_impianti_attivi.csv`,
`prezzo_alle_8.csv`, licenza IODL 2.0, nessun WAF): ~24k impianti e ~93k
prezzi. È la fonte più viva del warehouse — il MIMIT ripubblica ogni mattina
— ma i file sono **snapshot senza storico**: ogni run sostituisce le tabelle,
la serie storica esisterebbe solo archiviando i run.

Due cose da sapere prima di toccarlo:

- **il CSV degli impianti non è parsabile**: "Nome Impianto" contiene a volte
  un `|` non quotato (`STOIL SIMPLE | gestori.prezzibenzina.it`), quindi ~100
  righe su 24k hanno 11-12 campi invece di 10 e lo sniffer di DuckDB fallisce
  del tutto. `null_padding` non serve (pareggia i campi mancanti, non quelli
  in più) e `ignore_errors` butterebbe le righe. Si legge riga per riga e si
  spacchetta **posizionalmente**: primi 4 campi e ultimi 5 fissi, il resto è
  il nome. L'assunzione è ricontrollata a ogni run (provincia sempre di 2
  lettere, id sempre numerico) e l'ETL si ferma se salta;
- **il codice ISTAT non c'è**: si ricava agganciando nome comune + sigla
  provincia a `voc_istat_cities` (solo comuni validi, e **DISTINCT**: il
  vocabolario ha 8229 righe per 7896 codici, un join ingenuo moltiplica gli
  impianti). Copertura 99,7%; i mancanti sono comuni fusi/soppressi che il
  MIMIT non ha aggiornato (CORIGLIANO CALABRO e ROSSANO → Corigliano-Rossano,
  POPOLI → Popoli Terme, …).

## ANAC — gare pubbliche (`etl/anac.mjs`)

I **CIG** (Codici Identificativi di Gara) dal CKAN di ANAC: una riga per
LOTTO con oggetto, importi, amministrazione appaltante, comune di esecuzione
e categoria CPV. ~1,45M righe per anno; il default sono gli ultimi 2 anni
(`--from 2019` scende a ~5,3M righe, ~0,9 GB scaricati).

- **licenza CC-BY-SA 4.0** — l'unica *share-alike* del warehouse: si propaga
  ai derivati pubblicati. Non è uniforme nemmeno dentro ANAC (il pacchetto
  OCDS è CC-BY 4.0);
- **il CKAN non è su `/api/3/` ma su `/opendata/api/3/`**;
- **WAF F5**: rifiuta in base alla plausibilità dello User-Agent — `Mozilla/5.0`
  viene respinto, serve uno UA Chrome completo (a differenza di Normattiva
  non servono `Origin`/`Referer`);
- il campo `size` del CKAN è la dimensione **non compressa** (~92 MB contro i
  ~20 MB dello zip) e va in **overflow negativo** sopra i 2 GB: inutilizzabile
  per stimare i download;
- di ogni anno si prendono solo le 12 risorse **CSV**: gli stessi dati in TTL
  pesano 10 volte tanto;
- **buco dell'anno in corso**: i pacchetti per anno sono snapshot annuali e
  `cig-<anno corrente>` non esiste. I dati recenti passano solo dal pacchetto
  `cig` ("aggiornamenti delta"), con ~4 mesi di retention — un delta non
  scaricato in tempo è perso. Questo ETL copre solo i pacchetti per anno.

Gli **embeddings per riga** coprono di default **tutti** i lotti
(`--embed-min 0`): `oggetto_gara` è un ottimo corpus (108 caratteri di media,
mai vuoto). Il calcolo è lungo — ~1800 vettori/min su GPU locale, cioè **~25
ore per 2,7M righe** — ma è **ripartibile**: i vettori vivono in `anac_emb`,
tabella laterale append-only che sopravvive ai run e alle interruzioni.
`--embed-min 1000000` restringe a ~44k righe/anno se serve un run breve.

Due scelte di progetto da non disfare:

- **niente `UPDATE` per riga.** Gli embeddings si accumulano in `anac_emb` e la
  tabella finale nasce con una `LEFT JOIN`. Un `UPDATE` per riga su milioni di
  righe riscrive interi row group: in una versione precedente il file cresceva
  di **380 MB per soli 14k vettori**;
- **retry con backoff su Ollama.** Un run di ore non può morire per un
  singhiozzo (è già successo: `ConnectionRefused` a 28k/82k). Otto tentativi,
  backoff fino a 60s; e comunque il lavoro fatto è già in `anac_emb`.

Nota sui dati: gli importi contengono **errori della fonte** (nel 2025 un
"servizio di formazione del personale camerale" da 12,6 miliardi di euro).
Non sono corretti dall'ETL — chi li usa per classifiche se ne accorga.

## Confini amministrativi ISTAT (`etl/istat-confini.mjs`)

Tre tabelle dai confini generalizzati ISTAT: `istat_confini_comuni` (7896),
`istat_confini_province` (107) e `istat_confini_regioni` (20). Ogni riga porta
il **poligono** del confine come `geojson` (GeoJSON `[lon, lat]`, RFC 7946, già
semplificato e pronto per Leaflet), il **centroide** (`lon`/`lat`, mappabile a
punti anche con `:::map`) e la **superficie** (`superficie_kmq`). È il
moltiplicatore geografico: `istat_confini_comuni.codice_istat` si aggancia a
`istat_popolazione`/`indicepa`/`anac_cig`, così qualunque numero per comune
diventa una mappa coropletica (densità = popolazione / superficie).

Trappole:

- lo shapefile è in **UTM 32N (EPSG:32632, metri)** → riproiezione a EPSG:4326
  con `always_xy := true` **obbligatorio**, o il GeoJSON esce con lon/lat
  scambiate e tutte le mappe saltano;
- **l'annata conta.** I confini di gennaio applicano subito le
  riorganizzazioni comunali dell'anno (la riforma delle province sarde del 2026
  rinumera i comuni: Alghero `090003` → `112001`), mentre popolazione/IndicePA
  seguono con ~un anno di ritardo. L'ETL parte quindi da `THIS_YEAR-1` e stampa
  la **% di aggancio a `istat_popolazione`** come guardia: sotto il 99% l'annata
  non combacia, si forza con `--year`.

## Sezioni di censimento ISTAT (`etl/istat-sezioni.mjs`)

Tre tabelle dalle **Basi Territoriali 2021**, ed è l'unico livello del warehouse
*sotto* il comune: `istat_sezioni` (~400k, una riga per sezione di censimento —
poligono, centroide, superficie, tipo di località, e i quattro totali censuari
popolazione/famiglie/abitazioni/edifici), `istat_censimento_sezioni` (le **127
variabili censuarie 2023**, in forma larga: una colonna per variabile) e
`istat_censimento_variabili` (il dizionario, codice → definizione ISTAT).

Con questa una coropletica smette di colorare 7896 comuni e ne colora
quattrocentomila, e domande come «in quali isolati di questo comune la quota di
stranieri supera il 20%» diventano una `SELECT`.

```sh
bun run etl:sezioni                       # 950 MB di download, ~400k sezioni
bun etl/istat-sezioni.mjs --only R14      # una regione sola, per provare
bun etl/istat-sezioni.mjs --no-geometry   # solo i numeri, tabella ~4× più piccola
```

Trappole:

- **`SEZ21_ID` non ha lunghezza fissa**: 11 caratteri dove `PRO_COM` ha 4 cifre
  (Valle d'Aosta, `70010000001`), 12 dove ne ha 5 (Molise, Roma, Milano,
  `700010000001`). Un `lpad` a 11 troncherebbe metà del Paese. Si casta a
  VARCHAR e basta — le due fonti concordano già sulle cifre — e la percentuale
  di aggancio stampata a fine ETL è la guardia se un giorno smettessero;
- **le due annate non coincidono, ed è corretto così.** La geometria è del 2021,
  le variabili del 2023, che ISTAT pubblica *sopra* le basi 2021. Quindi
  `istat_sezioni.popolazione` e `istat_censimento_sezioni.P1` sono la stessa
  grandezza a due anni di distanza e **non saranno mai uguali** (Valle d'Aosta:
  123.360 contro 122.877). Chi le confronta senza saperlo apre una segnalazione
  di bug su un dato giusto. `--anno-var 2021` allinea le annate;
- **circa il 45% delle sezioni non ha variabili censuarie**: sono quelle non
  residenziali (aree industriali, parchi, acque). Non è un buco, è la forma del
  dato — per questo le due tabelle sono separate e si uniscono con una LEFT JOIN
  invece di portare 127 colonne NULL su 180k righe;
- **forma larga e non lunga**: 400k sezioni × 127 variabili sono 50,8 milioni di
  righe in forma lunga, quattro volte `opencup`. DuckDB è colonnare, quindi una
  query che chiede tre variabili ne legge tre;
- stesse due trappole geometriche dei confini: **UTM 32N** da riproiettare con
  `always_xy := true`, e i **sidecar** (`.shx`/`.dbf`/`.prj`) da estrarre accanto
  all'`.shp`. Lo zip regionale contiene anche un `TAB/SEZ_R<nn>_21.csv` con gli
  stessi attributi, ma è in **UTF-16**: si legge lo shapefile;
- `read_xlsx` con `all_varchar = true` e `TRY_CAST` a valle: l'inferenza di tipo
  su colonne con celle vuote dà VARCHAR per alcune regioni e BIGINT per altre, e
  l'INSERT fallirebbe a metà del Paese;
- **i comuni fusi fra le due annate lasciano sezioni senza nome**, ed è corretto.
  Nel run nazionale sono 105 sezioni di 6 comuni (`012095`, `012009`, `012018` →
  `012144`; `005110`, `005079` → `005122`; `018002` → `018026`): esistevano nel
  2021, sono stati assorbiti prima del 2023, quindi il loro codice non compare
  più né nell'xlsx delle variabili né in `istat_confini_comuni`. Le variabili ce
  le hanno, ma sotto il codice del comune che li ha assorbiti — perciò per quelle
  sezioni `istat_sezioni.codice_istat` (2021) e
  `istat_censimento_sezioni.codice_istat` (2023) **non coincidono**, mentre
  `sez_id` sì. Non si inventa un nome: quel comune non esiste;
- **il dizionario non riporta i denominatori** delle percentuali, e non è una
  dimenticanza: la base di `P86`-`P90` (titolo di studio) è `P83`, la popolazione
  di 9 anni e più, non `P1`. Un registro sbagliato produce percentuali plausibili,
  che è il modo peggiore di sbagliare. Va costruito verificando sui dati che la
  somma delle parti faccia il totale.

**Costo.** La geometria è ~73% dell'ingombro (1759 byte a sezione, misurati):
sulle 20 regioni l'ordine di grandezza è **0,7-1 GB** su un warehouse che ne pesa
già 9,1 e su una macchina di produzione da 15 GB di RAM — cioè va deciso, non
subìto. Le leve sono due: `--tol 0.0002` dimezza il GeoJSON (a queste scale la
differenza non si vede), `--no-geometry` lo toglie del tutto e lascia i numeri.

## Pendolarismo (`etl/pendolarismo.mjs`)

Due tabelle dalla matrice ISTAT: `pendolarismo` (988.625 flussi, **28.871.447
persone**, di cui 11,3 milioni verso un altro comune) e `pendolarismo_mezzo`
(1.182.803 righe, gli stessi spostamenti spezzati per treno, auto, bici, a piedi…).

**È la prima tabella di flussi del warehouse.** Tutto il resto descrive un luogo;
questa descrive un *legame* fra due luoghi — quali paesi si svuotano la mattina, chi
gravita su chi. Milano riceve 368.473 pendolari per lavoro, Roma 238.494, Torino
134.976.

**L'annata è il 2011, e non è una scelta.** La matrice del Censimento 2021 esiste ed è
stata pubblicata nell'ottobre 2025, ma è consultabile solo da IstatData, e il suo
dataflow `DF_BULK_PEND_LAV_2021_1` risponde:

```
Dataflow ... doesn't contain a mapping set
```

cioè è dichiarato nel catalogo e scollegato dal motore dei dati — **lo stesso guasto
che `turismo.mjs` documenta** per il dataflow comunale del movimento turistico. Sul
portale ISTAT i dataflow «BULK» sono spesso vetrine senza niente dietro. Come file
sono pubblicati solo 1991, 2001 e 2011.

Quindici anni comprendono la diffusione del lavoro da remoto: questi numeri
descrivono l'Italia che andava in ufficio tutti i giorni, e servono per la
**struttura** dei legami molto più che per le quantità. Sta scritto nella descrizione
di catalogo.

Trappole:

- **è a larghezza fissa, e il tracciato sta in un `.doc` dentro lo zip.** Le posizioni
  sono lette da lì, non dedotte dalle prime righe: una colonna spostata di un
  carattere produce codici comune plausibili e sbagliati. La prova che il parsing è
  giusto al carattere è il totale — **28.871.447 persone, esattamente il numero che il
  documento dichiara**;
- **due tipi di record nello stesso file, e sommarli conta tutto due volte.** I `S`
  (988.625) sono i totali per strato, i `L` (3.887.617) spezzano gli stessi flussi per
  mezzo, orario e tempo. Alimentano due tabelle diverse e nessuna contiene l'altra;
- il codice comune è **provincia (3) + comune (3)**: si concatenano, non si sommano;
- i campi non applicabili valgono `+`, non vuoto;
- `destinazione` distingue tre casi che una lettura frettolosa confonde — *stesso
  comune*, *altro comune*, *estero* — e il pendolarismo che attraversa un confine è
  solo il secondo;
- i codici sono al 1° gennaio 2011: **37.994 flussi** non agganciano i confini
  correnti, per via delle fusioni successive.

## Patrimonio immobiliare pubblico (`etl/patrimonio-pa.mjs`)

`patrimonio_pa` (**3.257.044** beni): ogni fabbricato e terreno dichiarato dalle
amministrazioni pubbliche — 9.294 enti, 7.789 comuni — come impone l'art. 2 c. 222
della legge 191/2009. 403 milioni di m² di fabbricati e 35.608 di terreni.

Incrociato con la popolazione: Trento 27,8 m² di edifici pubblici per abitante,
Venezia 21,5, Firenze 15,1.

**Il comune è scritto in codice catastale, non ISTAT** — `A013` è Abriola — ed è la
ragione per cui questa fonte era ferma. Nessuna tabella del warehouse traduceva i due
codici: né `voc_istat_cities` né `istat_confini_comuni` portano il catastale. Ora sì,
perché `anncsu.mjs` emette anche **`comuni_codici`** (7.890 righe): l'ANNCSU ha
entrambi i codici su ogni riga ed è la sola fonte in cui convivono. Aggancio: **99,6%**.
Per nome sarebbe stato possibile e sbagliato — gli omonimi sono decine, e un immobile
finito nel comune sbagliato non lo denuncia nessuno.

Trappole:

- **i file sono in ISO-8859-1**: letti come UTF-8, «proprietà» diventa «propriet&#65533;» e
  ogni accento del Paese con lei. Si convertono con `iconv` in ingresso;
- **due comuni per riga, e non sono lo stesso**: quello dell'amministrazione che
  dichiara e quello del bene. Il municipio di un comune di montagna può possedere un
  appartamento al mare. Si tiene il comune del **bene**;
- **una coordinata c'è quasi sempre, e non vuol dire che sia un indirizzo.** 3.257.042
  beni su 3.257.044 cadono dentro l'Italia, il che sembra una copertura perfetta; ma
  `precisione_geo` è dichiarata solo per **269.877** di essi, e fra quelli **75.797
  sono precisi "al COMUNE"** — cioè sono il centroide del municipio, non il posto dove
  sta il bene. Solo 92.516 arrivano al civico. Mapparli tutti allo stesso modo impila
  migliaia di puntini sui centri storici: **filtrare per `precisione_geo` è la
  differenza fra una mappa e un artefatto**;
- **l'annata è vecchia, ed è la fonte.** Rilevazione triennale, pubblicazione con due
  anni di ritardo: l'edizione più recente è al 31/12/2023. Accanto a una popolazione
  aggiornata si confrontano due momenti diversi;
- gli anni pubblicati **non sono consecutivi** (2016-2019, poi 2022, 2023): l'annata si
  legge dall'indice, un ciclo all'indietro sbaglierebbe due volte su tre.

## Geocoding: strade e numeri civici (`etl/anncsu.mjs`)

Tre tabelle dall'**ANNCSU**, l'Archivio Nazionale dei Numeri Civici e delle Strade
Urbane (Agenzia delle Entrate + ISTAT): `anncsu_strade` (1.219.990 aree di
circolazione), `anncsu_civici` (**27.405.709** numeri civici, di cui **20.715.787 con
latitudine e longitudine**) e `comuni_codici` (7.890), che è il **crosswalk fra codice
ISTAT e codice catastale**.

Il crosswalk è un regalo di questa fonte e vale quasi quanto il geocoding: mezza
amministrazione italiana scrive i comuni in catastale (`A013` è Abriola) — il
patrimonio del MEF, i codici fiscali, il catasto — e il warehouse non aveva modo di
tradurli. L'ANNCSU porta entrambi i codici su ogni riga ed è la sola fonte in cui
convivono. Costa un `DISTINCT`.

È il geocoding, ed è la prima volta che il warehouse risponde a «dove sta questo
indirizzo» senza chiedere a nessuno. Finora l'unica strada era `::geocode`, che
interroga Nominatim: servizio di terze parti, una richiesta al secondo, un indirizzo
alla volta. Qui sono venti milioni di punti in locale e una JOIN.

```sql
SELECT s.odonimo, c.civico, c.lat, c.lon
FROM anncsu_civici c JOIN anncsu_strade s USING (codice_istat, strada)
WHERE c.codice_istat = '077014' AND s.odonimo ILIKE '%LUCANA%'
```

**La fonte è cambiata di recente**: l'ANNCSU è ora pubblicato come **High Value
Dataset** ai sensi del Reg. UE 2023/138, quindi obbligatoriamente gratuito e in bulk.
Fino a poco fa l'accesso era riservato alle amministrazioni — è la ragione per cui
questo dato risultava fuori portata.

### La copertura, prima di prometterlo a qualcuno

**20,7 milioni di civici su 27,4 hanno le coordinate (75,6%), ma 2.402 comuni su
7.890 non ne hanno nessuna.** Il geocoding funziona in circa cinquemilacinquecento
comuni, non ovunque, e dipende da quali Comuni hanno caricato la georeferenziazione.
Un'app che dà per scontato di trovare un punto mostra una mappa vuota in un comune su
tre: va controllato, non sperato.

`metodo` è l'accuratezza e non un dettaglio burocratico — 1 e 2 rilievo strumentale
sul campo (sotto e sopra i 5 m), 3 e 4 derivazione da base dati territoriale, 5
derivazione tramite il Portale per i Comuni. **8.783.948 civici sono accurati sotto i
cinque metri**, cioè il 42% di quelli georiferiti.

Trappole:

- le coordinate hanno la **virgola decimale** (`13,9961659`): un `TRY_CAST` diretto
  non fallisce, restituisce `NULL` — venti milioni di punti che spariscono senza un
  errore;
- il sistema di riferimento è **ETRF2000 (ETRS89), epoca 2008.0**, non WGS84 alla
  lettera. Alle distanze di una mappa coincidono entro pochi centimetri, quindi **non
  si riproietta**: una trasformazione qui aggiungerebbe errore invece di toglierlo;
- l'odonimo è ripetuto su ogni civico. Tenerlo costerebbe 283 MB invece di 227 — meno
  di quanto sembri, perché DuckDB comprime a dizionario — ma sta già in
  `anncsu_strade`, e una sola copia è una sola verità;
- il CSV grande è di **2,2 GB**: lo legge DuckDB da disco. Farlo passare per lo heap
  di JS non serve e non finirebbe. In `raw/anncsu/` restano 2,5 GB fra zip e csv.

**Costo:** 27,4 milioni di righe stanno in **227 MB** dentro DuckDB, e il file del
warehouse non è cresciuto di un byte — lo spazio libero interno li ha assorbiti. Era
la voce che temevo spostasse i gigabyte, e non li ha spostati.

## Luoghi della cultura (`etl/beni-culturali.mjs`)

`beni_culturali` (58.625): musei, archivi, biblioteche, aree archeologiche e
monumenti, dal grafo della conoscenza del Ministero della Cultura (ArCo /
Cultural-ON) via **SPARQL** — un canale bulk vero, non una ricerca da interrogare
voce per voce. 24.137 hanno coordinate e si disegnano con `::map{lat lon}`.

**L'ontologia va letta, non indovinata.** Tre predicati plausibili qui sono
sbagliati, e sbagliano in silenzio — una `OPTIONAL` che non lega non dà errore, dà
una colonna vuota:

- il nome è `rdfs:label` (61.128 occorrenze), **non** `l0:name` (14.137): con
  quest'ultimo si perdono tre quarti dei luoghi;
- le coordinate sono `clvapit:lat`/`clvapit:long` di OntoPiA CLV, **non**
  `geo:lat`/`geo:long` del vocabolario WGS84 — che pure esiste nel grafo, su un
  sottoinsieme diverso e più piccolo;
- la geometria pende dal **luogo**, l'indirizzo dal **sito**: due rami diversi.

**La paginazione non deve ordinare.** L'istinto è `ORDER BY ?s` per avere pagine
stabili; Virtuoso però rifiuta un TOP ordinato oltre le diecimila righe — *«Sorted
TOP clause specifies more than 15000 rows to sort»* — quindi con `ORDER BY` la
seconda pagina è un 500. Senza, l'OFFSET profondo funziona e le pagine combaciano
esattamente: 58.941 su 58.941 dichiarati, verificato con un `COUNT` chiesto a parte
perché una paginazione che perde pezzi non deve passare per un dato più corto del
vero.

> Prima di arrivarci ho provato a partizionare per iniziale del nome. Non converge:
> i nomi italiani dei luoghi della cultura cominciano quasi tutti per «Chiesa»,
> «Castello», «Biblioteca», quindi nessun prefisso corto spezza i lotti grossi e la
> ricorsione scende fino a mandare l'endpoint in timeout.

**La città non porta un codice ISTAT**, solo il nome. Il codice si ricava in due
modi, nell'ordine: **point-in-polygon** dove ci sono le coordinate (24.083, esatto) e
**nome del comune** dove è univoco in Italia (31.310). Restano 3.232 luoghi senza
comune — nome ambiguo e nessuna coordinata — e lì il campo è `NULL` invece che
indovinato fra due omonimi. Il campo `aggancio` dice quale delle due strade è stata
usata, perché chi mappa ha diritto di saperlo.

Si incrocia con `turismo_capacita` e `istat_popolazione`: Roma 2.685 luoghi e 112
posti letto per luogo, Firenze 2.137 e 30.

## Classi Euro per comune (`etl/aci-veicoli.mjs`, terza tabella)

`aci_veicoli_euro` (7.896): autovetture per comune e classe di emissione, da Euro 0
a Euro 6E, con le classi fino a Euro 3 già sommate (`euro_0_3`, `euro_0_3_pct`) —
che sono quelle che ogni zona a traffico limitato nomina per prime. Il **22,6%**
del parco italiano è Euro 3 o più vecchio.

Questo dato era dato per assente, e la nota in testa all'ETL diceva — correttamente
— che «l'alimentazione è tabulata solo per provincia». Vero per
`Parco_veicolare_<anno>.xlsx`. Ma lo zip ACI contiene **tre** workbook, e
`Circolante_Copert_<anno>.xlsx` — il tabulato costruito per il modello europeo delle
emissioni — ha un foglio intitolato «Autovetture distinte per Provincia, Comune e
EURO». Per un paio d'anni nessuno l'ha aperto.

Il controllo che lo conferma è il totale: **41.777.694 autovetture** da entrambi i
workbook, che sono due tabulati diversi della stessa fonte.

Stessa forma pivot dell'altro foglio (celle unite, forward-fill, righe di totale da
scartare) e stesso aggancio per nome comune + sigla, quindi la tabella editoriale
delle 107 province non è duplicata: l'ETL è uno solo. L'intestazione delle classi si
legge dal foglio invece di fidarsi dell'ordine, perché cambia — `EURO 6E` è comparsa
di recente e prima o poi arriverà `EURO 7`.

## Capacità ricettiva per comune (`etl/turismo-capacita.mjs`)

`turismo_capacita` (47.407 = 7.913 comuni × 6 anni): quanti esercizi ricettivi ha
ogni comune e quanti posti letto offrono, dal 2020.

**Non è un doppione di `turismo`, ed è la distinzione da capire prima di usarli.**
`turismo` è il **movimento** (arrivi e presenze) e si ferma alla **provincia**,
perché ISTAT lo copre con il segreto statistico dove le strutture sono poche; questa
è la **capacità**, cioè un censimento dell'offerta, e per comune c'è. La nota in
testa a `turismo.mjs` sul dataflow comunale «scollegato» riguardava il movimento ed
è ancora vera per quello.

Il rapporto fra posti letto e popolazione residente è la misura di pressione
turistica che questa tabella esiste per rendere calcolabile.

Trappole:

- **rate limit ISTAT**: una sola richiesta per tutto il Paese e tutti gli anni,
  REF_AREA lasciata vuota e i tipi combinati con `+`. Mai un ciclo per comune —
  sarebbero ottomila richieste e un ban di 1-2 giorni;
- **`endPeriod` viene ignorato**: chiedendo 2023-2023 tornano anche gli anni dopo;
- senza filtro REF_AREA la risposta porta anche nazione, ripartizioni, regioni e
  province: i comuni sono i codici a **sei cifre**. La codelist ne dichiara 9.380
  perché conserva i soppressi — 62 righe non si agganciano ai confini correnti;
- per comune ISTAT pubblica **solo il totale**: chiedere anche alberghiero ed
  extra-alberghiero non dà errore, dà zero righe. Quelle colonne sono state tolte
  invece di lasciarle NULL per sempre;
- **il 2025 è una rottura di serie.** Gli esercizi passano da 265.319 a 738.751 e i
  posti letto da 5,5 a 7,7 milioni: non è un boom, è ISTAT che comincia a contare gli
  affitti brevi censiti dalla banca dati nazionale. Si vede dal rapporto fra i due
  salti — gli esercizi quasi triplicano, i letti crescono di un quarto, la firma di
  centinaia di migliaia di unità minuscole. Un confronto 2020-2025 senza questa nota
  misura un cambio di metodo e lo chiama crescita.

## Progetti del PNRR (`etl/pnrr.mjs`)

`pnrr_progetti` (291.398): tutti i progetti finanziati dal PNRR come li registra
ReGiS — missione, componente, misura, titolo e sintesi, importi, soggetto
attuatore, stato e date. **144,01 miliardi** di finanziamento PNRR, 206,88
complessivi. Licenza **CC-BY-4.0**, l'unica dichiarata fra le fonti aggiunte di
recente.

Chiude la catena del denaro pubblico che il warehouse teneva a metà: `anac_cig` →
`anac_aggiudicatari` → `opencoesione` → `opencup` → PNRR.

**Il comune non è nel dataset**, ed è la cosa da sapere prima di tutto. Le 63
colonne di ReGiS descrivono il progetto e il suo finanziamento, non dove sia: la
localizzazione arriva da `opencup` attraverso il CUP. Misurato: il 99,9% dei CUP
del PNRR è in `opencup` e l'**88,3%** ne ricava un codice ISTAT. Il restante 12%
ha un CUP noto e nessun comune — sono gli interventi nazionali e regionali, che
davvero non stanno in un municipio. **Una vista filtrata per comune non vede tutto
il piano, ed è corretto così.**

Per questo l'ETL **dipende da `opencup`** ed è registrato dopo di lui in
`refresh-all.mjs`: invertirli darebbe una tabella senza territorio.

Trappole:

- **HEAD risponde 404 su questo host mentre GET funziona**: sondare l'URL prima di
  scaricarlo fa concludere che il file non esiste;
- **l'URL non va cablato.** La versione corrente sta sotto
  `/content/dam/sogei-ng/opendata/`, le passate sotto `opendata_<mese><anno>/`, e a
  ogni pubblicazione quella corrente diventa un archivio. Un link scritto nel
  codice continuerebbe a funzionare servendo per sempre la versione di oggi — il
  modo peggiore di rompersi: nessun errore, dati fermi. Lo script legge la pagina e
  prende il **primo** CSV, che è la versione corrente;
- CSV `;`, **BOM** in testa e **importi con la virgola decimale**: un `TRY_CAST`
  diretto darebbe NULL su ogni cifra con decimali, cioè sulle più grandi. Date
  `DD/MM/YYYY`, da `strptime`;
- **il CUP non è una chiave**: 291.398 righe per 285.994 CUP, perché un progetto
  può stare sotto più misure. Sommare gli importi raggruppando per CUP li conta più
  volte;
- i codici comunali vengono da OpenCUP, che porta la **storia**: 8.035 codici
  distinti contro i 7.896 comuni di oggi, di cui 142 non si agganciano ai confini
  correnti (comuni fusi, e le province sarde rinumerate nel 2026). Una JOIN semplice
  perde quelle righe in silenzio; l'ETL le conta e lo stampa.

## Consumo di suolo (`etl/consumo-suolo.mjs`)

Due tabelle dalla cartografia ISPRA/SNPA: `consumo_suolo` (7896, una riga per
comune — quanto suolo è coperto artificialmente **oggi**, in ettari e in
percentuale della superficie comunale) e `consumo_suolo_serie` (86.856, una riga
per comune e periodo — quanto se n'è consumato e quanto ripristinato dal 2006).
Il totale nazionale che ne esce, **2.157.460 ettari**, combacia con i ~21.600 km²
che ISPRA pubblica: è il controllo di sanità che questo ETL supera per primo.

Perché due tabelle e non una larga come le variabili censuarie: il foglio ISPRA è
largo — undici periodi × tre misure — ma questa è una **serie storica**, e la
forma che `::chart-line` sa disegnare è quella lunga. Lo stock invece esiste per
un anno solo, e ripeterlo su ogni riga di periodo inviterebbe a sommarlo.

Trappole:

- **i periodi non hanno la stessa durata**: 2006-2012 sono sei anni, gli altri
  uno. Confrontare gli incrementi grezzi mette il primo fuori scala e fa sembrare
  che il consumo sia crollato — la tabella porta `anni` perché la divisione sia
  disponibile invece che da ricordare;
- **netto e lordo non sono la stessa cosa, e nessuno dei due è "il consumo"**: il
  lordo è quanto suolo è stato consumato, il netto è quello meno il ripristino.
  Sommare i netti dà lo stock di oggi meno quello del 2006; sommare i lordi dà
  qualcosa che non è nulla in particolare;
- `PRO_COM` arriva **senza zeri iniziali** (Torino è `1272`): va `lpad` a 6, o il
  join manca in silenzio tutti i comuni delle prime nove province;
- l'URL porta l'anno dell'edizione nel nome del file: lo scan parte dall'anno
  corrente e scende, `--edizione N` lo forza.

## Classificazione sismica (`etl/zone-sismiche.mjs`)

`zone_sismiche` (7896): la zona sismica di ogni comune secondo le classificazioni
regionali raccolte dal Dipartimento della Protezione Civile — 796 comuni in zona
1, 2339 in zona 2, 3049 in zona 3, 1712 in zona 4. Una colonna sola, ma è quella
che manca a chiunque incroci `edilizia_scolastica` (che porta epoca di
costruzione e verifica sismica dell'edificio) con il territorio.

```sh
bun run etl:zone-sismiche
```

Trappole:

- **l'URL non va cablato.** Il file sta sotto `/static/<hash>/…` e l'hash cambia a
  ogni pubblicazione: un link scritto nel codice diventa un 404 silenzioso al
  primo aggiornamento, cioè esattamente quando il dato è cambiato e serve. Lo
  script legge la pagina e prende il link da lì; se la pagina cambia forma si
  ferma dicendolo, che è meglio di servire il dato di tre anni fa;
- il CSV è **separato da punto e virgola, UTF-8 con BOM, fine riga CRLF**: il BOM
  finisce dentro il nome della prima colonna e `REGIONE` diventa una colonna che
  non esiste;
- **il verso è invertito rispetto all'intuizione**: `1` è la zona a pericolosità
  *più alta*, `4` la più bassa. Una scala di colori va invertita rispetto
  all'ordine naturale del numero, e va detto ovunque il dato si mostri;
- alcune regioni usano sottozone (`3A`, `3B`): `zona` conserva il testo pubblicato,
  `zona_sismica` ne prende la cifra, invece di scartare la riga.

## Redditi IRPEF comunali (`etl/mef-redditi.mjs`)

`mef_redditi` sono le dichiarazioni IRPEF delle persone fisiche aggregate per
comune (fonte MEF — Dipartimento delle Finanze, CC BY 3.0), una riga per comune:
numero di contribuenti, reddito complessivo dichiarato, **reddito medio** per
dichiarante, reddito imponibile, imposta netta e la ripartizione per fasce
(`contribuenti_bassi` ≤10.000 €, `contribuenti_alti` >75.000 €). Con
`istat_popolazione` e `istat_confini_comuni` (join per `codice_istat`, 100%)
diventa la **mappa "reddito per comune"**.

Trappole:

- un file per **anno di imposta**, pubblicato con ~due anni di ritardo (il 2024
  esce nel 2026); l'ETL parte dall'anno corrente e scende;
- CSV `;`-separated a 52 colonne; alcune annate (2024) hanno un `;` finale
  nell'header (53 colonne contro 52 nei dati) → `null_padding=true` obbligatorio,
  o lo sniffer di DuckDB si blocca;
- `Codice Istat Comune` a 6 cifre zero-padded e quotato → VARCHAR;
- celle soppresse per privacy nei comuni minori → `TRY_CAST` + guardia sulla
  divisione del reddito medio. Nomi comune puliti da `voc_istat_cities` (il MEF
  rende gli accenti come apostrofi).

## Infortuni sul lavoro INAIL (`etl/inail-infortuni.mjs`)

`inail_infortuni` sono gli infortuni sul lavoro denunciati all'INAIL (Open Data,
CC BY 4.0). La fonte è il **microdato elementare** — una riga per infortunio,
~3 milioni di righe su 20 file regionali — che l'ETL **aggrega** per provincia,
anno, gestione (Industria e servizi / Agricoltura / Conto Stato) e genere: la
tabella finale è compatta (~3200 righe) ma tiene infortuni, casi **mortali**,
casi **con menomazione** permanente e **giorni indennizzati**. Con
`istat_popolazione` dà il **tasso di infortuni per abitante**; si mappa per
provincia via `sigla` su `istat_confini_province`.

Trappole:

- un file ZIP per **regione** (cadenza semestrale, storico ~5 anni): si
  scaricano le **20 regioni** (TrentinoAltoAdige incluso, NON i file provinciali
  di Bolzano/Trento che raddoppierebbero);
- la geografia è `LuogoAccadimento` = codice **provincia a 3 cifre** (`015` =
  Milano), non il comune → si mappa alla `sigla` via
  `voc_istat_cities.CODICE_PROVINCIA`;
- tracciato **codificato** (le colonne rimandano ai `voc_inail_*` già caricati);
  qui serve solo `Gestione` (I/A/S), decodificata con un CASE;
- date `DD/MM/YYYY` → anno = `right(DataAccadimento,4)`; un infortunio è mortale
  se `DataMorte` è valorizzata.

## Farmacie (Ministero della Salute) (`etl/farmacie.mjs`)

`farmacie` è l'elenco delle **farmacie pubbliche attive** in Italia (fonte:
Ministero della Salute — dati.salute.gov.it, Open Data IODL 2.0): ~20.765 righe,
~91% geolocalizzate. È un **layer di punti** — una riga per farmacia con
`lat`/`lon` (WGS84) oltre a `codice_istat`, `comune`, `sigla`, `provincia`,
`regione`, `nome`, `indirizzo`, `cap`, `frazione`, `tipologia` — mappabile
direttamente con `:::map{path="farmacie"}` (marker) e collegabile a
popolazione/confini via `codice_istat` (es. farmacie per 100k abitanti).

Trappole:

- il file contiene **anche le farmacie cessate**: le attive hanno
  `data_fine_validita = '-'` (NON vuoto né 9999) → filtro obbligatorio;
- il nome del CSV porta la **data di pubblicazione** (`FRM_FARMA_5_<YYYYMMDD>.csv`)
  → l'URL si risolve leggendo il link dalla pagina del dataset, non si
  hard-codifica;
- le coordinate usano la **virgola decimale** e quelle mancanti sono `-` →
  conversione e range-check per riga;
- `cod_comune` è il codice ISTAT a **6 cifre** e i nomi dei comuni sono
  MAIUSCOLI → l'etichetta pulita arriva da `voc_istat_cities`.

## Scuole statali (MIUR) (`etl/scuole.mjs`)

`scuole` è l'anagrafica delle **scuole statali italiane** (fonte: MIUR —
dati.istruzione.it, IODL 2.0): ~50.273 scuole, una riga per scuola con
`codice_istat`, `comune`, `sigla`, `provincia`, `regione`, `codice_scuola`,
`nome`, `grado` (dell'infanzia / primaria / secondaria di I e II grado / licei /
istituti tecnici e professionali), `istituto`, `indirizzo`, `cap`, `sito`. **Non
ha coordinate**: è un dataset **per comune** (scuole per comune / pro capite,
mappa coropletica), collegabile a popolazione/confini via `codice_istat`.

Trappole:

- il CSV dell'anno scolastico corrente si risolve leggendo il link dalla pagina
  del dataset, non si hard-codifica;
- **il codice comune della fonte è il codice CATASTALE (Belfiore), non l'ISTAT**:
  `codice_istat` si ricava **per NOME** — la coppia (comune, regione) è univoca
  nei confini, con ripiego sul nome comune univoco a livello nazionale
  (copertura ~99,9%). CHECKPOINT finale.

## Indicatori socio-demografici (ISTAT) (`etl/istat-indicatori.mjs`)

`istat_indicatori` sono indicatori socio-demografici **per comune** (fonte:
ISTAT — demo.istat.it, CC BY 4.0): 7896 comuni, una riga ciascuno, riferimento
1° gennaio dell'ultimo anno disponibile. Colonne: `codice_istat`, `comune`,
`sigla`, `regione`, `anno`, `popolazione`, `eta_media`, `perc_0_14`,
`perc_65_piu`, `indice_vecchiaia`, `stranieri`, `perc_stranieri`. Tutti gli
indicatori sono mappabili coropleticamente su `istat_confini_comuni` via
`codice_istat`. Derivati **aggregando** due file di demo.istat.it: POSAS
(popolazione per età/sesso/stato civile → struttura per età) e STRASA
(popolazione straniera residente).

Trappole:

- riga di **titolo** in testa (`skip=1`) e riga finale "Nota:" da ignorare
  (`ignore_errors`);
- una **riga TOTALE per comune con Età=999** va esclusa: si tengono solo le età
  0–100 ("100 e più" → 100);
- cast a **BIGINT** sui conteggi.

## Aggiudicatari ANAC (`etl/anac-aggiudicatari.mjs`)

`anac_aggiudicatari` è **chi VINCE** le gare pubbliche (fonte: ANAC, CC
BY-SA 4.0): ~2.434.297 righe, una per aggiudicatario. Deriva dal join del
dataset `aggiudicatari` (gli operatori vincitori) con `aggiudicazioni`
(l'esito) su `id_aggiudicazione`, filtrato ai CIG già presenti in `anac_cig`
(perimetro 2024–2025). Colonne: `cig`, `cf_aggiudicatario`, `denominazione`,
`ruolo` (mandataria/mandante negli RTI), `tipo_soggetto`,
`importo_aggiudicazione`, `data_aggiudicazione`, `esito`, `criterio`,
`ribasso`, `offerte_ammesse`. Si unisce ad `anac_cig` via `cig` (oggetto,
amministrazione, luogo), chiudendo il cerchio amministrazione → gara →
vincitore.

Trappole:

- riusa il pattern CKAN di ANAC (`anac.mjs`); i due zip CSV di storia completa
  (~800 MB di CSV ciascuno) vengono filtrati al perimetro di `anac_cig`;
- **`id_aggiudicazione` NON è univoco** in `aggiudicazioni`: va deduplicato
  prima del join (`QUALIFY row_number`) o il join **moltiplica le righe**;
- gli importi portano gli **stessi errori della fonte** di `anac_cig`:
  affidabili per riga, non se aggregati alla cieca. CHECKPOINT finale.

## Progetti coesione — OpenCoesione (`etl/opencoesione.mjs`)

`opencoesione` sono i progetti finanziati con **fondi di coesione** (UE
FESR/FSE/FEASR/FEAMP + Fondo Sviluppo e Coesione nazionale) — fonte
opencoesione.gov.it, CC BY 4.0: **1.855.230 righe**, una per progetto. È il
complemento lato SPESA di `anac_cig` (che dice chi VINCE gli appalti):
titolo e sintesi in chiaro, tema, comune di realizzazione, importi
finanziati/rendicontati, beneficiario, stato di avanzamento.

Il dataset nazionale è un **Parquet unico** già tipizzato (niente CSV con la
virgola decimale da convertire), ~260 MB, letto direttamente via HTTP da
DuckDB. Gli **embeddings per riga** (`OC_TITOLO_PROGETTO` + sintesi) coprono
di default i progetti **≥ 150.000 €** (~169k righe): stesso vincolo di RAM
di `anac_cig` (indice HNSW memory-resident), stesso pattern di cache
laterale ripartibile (`opencoesione-emb.duckdb`, locale, mai deployata).

Trappole:

- un progetto può interessare **più comuni** (`COD_COMUNE`/`DEN_COMUNE`
  liste separate da `":::"`): si tiene solo il primo, il luogo principale;
- `COD_COMUNE` porta un **prefisso** (codice regione) davanti ai 6 cifre
  del codice ISTAT vero: si prendono gli ultimi 6 caratteri (copertura
  99,9%);
- esistono decine di export ridondanti per regione/fondo/tema: si usa solo
  il file nazionale unico, gli altri causerebbero doppioni;
- ~0,8% dei titoli porta un "¿" al posto di un apostrofo/accento: è già così
  nel Parquet ufficiale, non un bug di lettura — non corretto in silenzio.

## Progetti d'investimento pubblico — OpenCUP (`etl/opencup.mjs`)

`opencup` è l'intero universo dei progetti d'investimento pubblico italiani
dal 2003, tracciati dal **CUP** (Codice Unico di Progetto) — fonte
opencup.gov.it (DIPE), CC BY: **11.861.554 righe**, una per CUP. A differenza
di `opencoesione` (solo fondi di coesione) copre QUALUNQUE fonte di
finanziamento: lavori pubblici, incentivi alle imprese, contributi, servizi.
Verificato: `opencoesione.cup` è coperto al 99,5% da `opencup.cup` — quasi
tutto ciò che c'è in opencoesione c'è anche qui, più il resto dell'universo.

Quattro dataset nazionali (zip di CSV `;`-delimited): Progetti (anagrafica,
~2,2 GB zip — split in 7 CSV da ~2 GB perché il sistema sorgente ha un tetto
di dimensione per export), Localizzazione (CUP→comune, relazione 1:N),
Fonti di Copertura (CUP→tipo di finanziamento, relazione 1:N) e Soggetti
(registro dei ~28.700 enti titolari, non per-progetto). Uniti in un'unica
riga per CUP: la localizzazione preferisce un comune reale a un "-1"
(TUTTI/nessun comune specifico) quando un progetto ne ha più di uno; le
coperture finanziarie diventano una lista aggregata; i soggetti si
aggangano via CF/PIVA del titolare.

NIENTE EMBEDDINGS (a differenza di anac_cig/opencoesione): la scala — più
del doppio di anac_cig — renderebbe un terzo indice HNSW memory-resident un
rischio per il budget di RAM di produzione, e il CUP aggancia già
opencoesione (che la ricerca semantica ce l'ha) per il testo libero. Il
valore di opencup sta nella copertura geografica e nel volume.

Trappole:

- il dataset Progetti è FISICAMENTE diviso in più CSV (osservato: 7 file,
  "OpenCup_ProgettiN.csv") ciascuno col proprio header — non un CSV unico
  rinominato: si processa un file alla volta;
- decomprimere l'intero zip di Progetti IN MEMORIA in un colpo solo (tutti
  i CSV insieme, ~13,8 GB scompattati) rischia di saturare la RAM — si
  decomprime UN CSV alla volta (fflate `filter` per nome esatto) e si
  scrive su disco vero, mai su un filesystem RAM-backed come un `/tmp`
  tmpfs con quote strette;
- `CODICE_COMUNE` vale "-1" (con `COMUNE`="TUTTI") per i progetti senza un
  comune specifico (interventi provinciali/regionali/nazionali): un NULL
  semantico, non un codice da recuperare;
- ~0,3% dei codici comune storici non trova riscontro in
  `istat_confini_comuni` (fusioni/ridenominazioni successive alla
  registrazione del CUP, spesso in Sardegna per le sue riforme provinciali
  ricorrenti): stessa natura degli scarti già visti altrove, non corretta
  in silenzio;
- `PIVA_CF_BENEFICIARIO`/`DENOMINAZIONE_BENEFICIARIO` portano il valore
  letterale "**********" (10 asterischi) quando il dato è oscurato per
  privacy: NULLIF, non un valore reale;
- `Soggetti.csv` non ha una colonna CUP: è il registro dei titolari,
  agganciato via CF/PIVA, con duplicati per ente (indirizzi diversi nel
  tempo) aggregati con `any_value`;
- la scheda Metadati del portale documenta anche campi (es.
  `LINK_OPENCOESIONE`) che NON esistono nell'export Progetti reale: non
  fare affidamento sulla lista dei metadati per il parsing, verificare
  l'header vero.

## Parco veicolare — ACI Autoritratto (`etl/aci-veicoli.mjs`)

Due tabelle a granularità DIVERSA, perché è quello che la fonte offre
davvero (fonte ACI — Autoritratto, CC BY 4.0, uno zip annuale con tre
Excel): `aci_veicoli` (una riga per COMUNE, 7896 righe: veicoli circolanti
per categoria — autovetture, motocicli, autocarri, …) e
`aci_veicoli_alimentazione` (una riga per PROVINCIA, 107 righe: autovetture
per alimentazione — benzina/gasolio/altre, dove "altre" somma GPL, metano,
ibride ed elettriche perché la fonte non le scorpora a livello
provinciale). Nessun incrocio comune×alimentazione: la fonte non lo dà.

Trappole:

- il file è un **workbook Excel a 46 fogli pivot** con celle unite
  (Area/Regione/Provincia compaiono solo sulla prima riga del gruppo): serve
  un forward-fill in JS (libreria `xlsx`/SheetJS — DuckDB non legge xlsx),
  DuckDB entra in gioco solo dopo, su un CSV intermedio;
- nessun codice ISTAT nel file: comune e provincia sono solo NOME in
  maiuscolo. La provincia si mappa alla sigla con una tabella **editoriale**
  (107 voci, verificate contro `istat_confini_province`: i nomi variano,
  "REGGIO CALABRIA" vs "Reggio di Calabria", "FORLI'-CESENA" con apostrofo
  per l'accento — niente join fuzzy sul nome provincia); il comune si
  aggancia poi per (nome normalizzato, sigla). Copertura ~99% per comune,
  100% per provincia — il residuo sono nomi abbreviati dalla fonte ("S." per
  San/Santa, tagli tipo "STRADA DEL VINO") lasciati con `codice_istat NULL`;
- la colonna del totale nei fogli per provincia va letta dall'**intestazione**
  ("Totale "), non dall'ultima cella della riga: almeno un foglio ha una
  colonna vuota in più dopo il totale che farebbe leggere `NULL`;
- il dato è la **PRA** (dove il veicolo è registrato), non dove risiede il
  proprietario: i grandi noleggiatori/leasing registrano flotte intere su
  indirizzi concentrati — il comune di **Trento** risulta con ~544k
  autovetture (più di Napoli) a fronte di ~118k abitanti. Non è un bug
  dell'ETL: è già così nella fonte, stesso disclaimer degli importi ANAC.

## Incidenti stradali per comune (`etl/incidenti-stradali.mjs`)

`incidenti_stradali` (192.741 righe, 8578 comuni, **2001-2024**) dal dataflow
ISTAT `41_983_DF_DCIS_INCIDMORFER_COM_1`: quanti incidenti con lesioni alle
persone, quanti morti e quanti feriti, per comune e per anno.

**È la prima misura di esito della mobilità nel warehouse.** Tutto il resto che
riguarda gli spostamenti descrive una dotazione o una struttura — `aci_veicoli`
quante auto ci sono, `anncsu_strade` dove passano le strade, `pendolarismo` chi
gravita su chi — e nessuna dice come va a finire. Questa sì, per **ogni** comune
e per ventiquattro anni di fila, il che la rende anche l'unica serie di mobilità
abbastanza lunga da mostrare una tendenza invece di una fotografia.

Costa **una sola richiesta**: 45 MB in una ventina di secondi, tutti i comuni e
tutti gli anni insieme. Il ciclo per comune, oltre che vietato dal rate limit
ISTAT, sarebbe pure inutile.

Trappole:

- **le tre misure arrivano come tre RIGHE, non tre colonne**, distinte da due
  dimensioni che vanno lette insieme: `ROADACC × 9` è il numero di incidenti —
  l'esito «9» vale *totale* e non è una terza categoria di persone — mentre
  `KILLINJ × M` e `KILLINJ × F` sono i morti e i feriti. Sommare tutto quello
  che condivide comune e anno mette insieme sinistri e persone, che sono unità
  diverse;
- **l'ultimo anno omette gli zeri, e senza accorgersene si disegnano mappe
  false.** Dal 2001 al 2023 ISTAT pubblica una riga anche per il comune che non
  ha avuto nessun incidente — circa 1.700 l'anno, e lo `0` scritto è un dato. Nel
  2024 quelle righe non ci sono: i comuni presenti sono 6.339 invece di 7.896.
  Che i 1.557 mancanti siano zeri e non dati soppressi lo dimostra il totale
  nazionale, che **torna esatto senza di loro**: se fossero ignoti, la somma dei
  comuni non farebbe 3.030 morti. L'ETL li completa a zero contro i confini
  correnti, e lo fa solo se l'anno non ne contiene già — la regola è legata
  all'asimmetria osservata e non a un anno scritto a mano, così si sposterà da
  sola quando ISTAT consoliderà il 2024;
- **la prova che il parsing è giusto è il totale nazionale**, ed è verificata a
  ogni esecuzione: il 2024 fa 173.364 incidenti, 3.030 morti e 233.853 feriti,
  esattamente le cifre che ISTAT pubblica a parte. Se il controllo smette di
  tornare, è cambiata la forma della risposta, non l'incidentalità;
- i comuni distinti sono **8.578 contro i 7.896 di oggi**: la differenza sono i
  soppressi per fusione, che la serie storica conserva perché nel 2001
  esistevano;
- **il tasso per abitante non è precalcolato.** La popolazione sta in
  `istat_popolazione` con lo stesso `codice_istat` e il rapporto si fa nella
  query, perché per un comune di duemila abitanti attraversato da una strada di
  grande traffico la sua popolazione è il denominatore sbagliato — e quale sia
  quello giusto dipende dalla domanda, non dalla tabella.

## Sistemi di sharing in tempo reale — GBFS (`etl/gbfs-sistemi.mjs`)

`gbfs_sistemi` (36 sistemi, 26 comuni) dal catalogo ufficiale **MobilityData**
(CC0), l'elenco che i gestori stessi aggiornano via pull request: quali sistemi
di bike e scooter sharing esistono in Italia, in che comune, e a quale indirizzo
pubblicano lo stato dei loro veicoli.

**Qui dentro non c'è niente in tempo reale, ed è deliberato.** Un monopattino si
sposta ogni minuto e il warehouse si aggiorna a cadenza di giorni: una fotografia
delle posizioni salvata qui sarebbe un dato vecchio che *sembra* vivo, cioè
l'inganno peggiore che un dato possa fare — lo stesso del SELECT che torna vuoto
senza errore. Quello che è statico — quali sistemi esistono, dove, e a quale
indirizzo rispondono — è metadato di catalogo e sta bene qui; le posizioni si
leggono **dal browser** con `::api-query{every="60"}` sull'`url_stato`, che è il
posto giusto perché è l'unico che le guarda nel momento in cui qualcuno le sta
guardando. La CSP non va toccata: `connect-src https:` è già concesso e i feed
mandano `Access-Control-Allow-Origin: *`.

GBFS è lo standard che rende la tabella possibile: otto operatori diversi
rispondono tutti con la stessa forma, senza chiave. È il motivo per cui la
micromobilità è l'unico pezzo di mobilità italiana in tempo reale alla portata di
chiunque — e il NAP, che dovrebbe dare gli orari del trasporto pubblico, è giù
(vedi «Fonti valutate e NON integrate»).

Trappole:

- **i nomi di città sono esonimi inglesi** — Naples, Florence, Milan, Rome,
  Turin, Padua — più qualche variante locale (Lido di Jesolo, Mazara per Mazara
  del Vallo, Reggio Emilia per Reggio nell'Emilia). Il join per nome fallirebbe
  su un terzo delle righe, quindi c'è una mappa **editoriale** di 26 voci —
  stesso precedente delle province in `aci-veicoli.mjs` — e l'ETL **elenca** le
  città che non ha saputo agganciare invece di lasciarle cadere;
- **GBFS 2.x annida i feed per lingua (`data.it.feeds`), la 3.0 no
  (`data.feeds`).** Trattare la 3.0 come la 2.x prende il primo valore di `data`
  — che è già l'array — e poi ne cerca `.feeds`, che non esiste: i tre sistemi
  Cooltra risultavano «senza feed» pur essendo perfettamente vivi. Il conteggio
  passa da 28 a 31 feed vivi solo per questa riga;
- **ogni feed viene interrogato davvero**, e si tiene quanti veicoli ha
  risposto. Un sistema può stare nel catalogo ed essere spento — l'operatore che
  lascia una città non manda una pull request — e infatti **5 su 36 non
  rispondono** (Amicarnapoli, Dott Catania, Dott Lecco, Lime Bari e Lime Napoli:
  404 e un 403). `veicoli_alla_verifica` non è un dato di traffico, è la prova
  che il feed rispondeva; `errore` dice perché uno non l'ha fatto;
- **elencati e vivi sono due cifre diverse: 26 comuni contro 23.** È la seconda
  quella su cui si può disegnare qualcosa, e si ottiene con `errore IS NULL`;
- due nomi per la stessa cosa — `free_bike_status` (2.x) è diventato
  `vehicle_status` (3.0) — e i sistemi a stazione (BikeMi, nextbike, Verona Bike)
  non hanno né l'uno né l'altro ma `station_status`. La colonna `tipo` distingue
  i due mondi perché si disegnano in modo diverso: mezzi sparsi o stazioni fisse.

## Strutture del Servizio Sanitario Nazionale (`etl/sanita-strutture.mjs`)

Tre tabelle dal **Ministero della Salute** (dati.salute.gov.it, Open Data **IODL
2.0** — dichiarata in pagina, che non è scontato):

- `sanita_posti_letto` (26.315 righe, 1.372 strutture in 723 comuni, **2010-2023**):
  posti letto per struttura e disciplina, con il **codice ISTAT del comune** e
  l'indirizzo. 212.768 letti nell'ultimo anno;
- `sanita_asl_comuni` (7.898 comuni, **110 aziende**): quale ASL serve ogni comune
  e con quanta popolazione;
- `sanita_strutture` (993): ospedali pubblici e case di cura accreditate con
  personale, ricoveri, giornate di degenza — da cui occupazione dei letti e
  degenza media.

**`sanita_asl_comuni` è la chiave di volta e vale più di quanto sembri.** Quasi
tutto quello che il SSN pubblica è per AZIENDA, non per comune: le ASL sono 110 e
i comuni 7.896, e senza questa corrispondenza ogni dato sanitario resta appeso a
un'entità che nessun cittadino sa nominare. Il Ministero la pubblica con il codice
ISTAT già dentro, quindi non c'è nessun aggancio per nome da indovinare.

**Il controllo indipendente è la popolazione**, ed è stampato a ogni run: la somma
di quella servita dalle ASL fa 58.943.464 contro i 58.942.828 residenti che il
warehouse già conosce da ISTAT — **scarto 0,0%**. Due fonti diverse che arrivano
allo stesso numero sono la prova che entrambe sono state lette bene.

Trappole:

- **il codice ASL è unico solo DENTRO la regione, e contarlo da solo mente.** Il
  codice `201` esiste in dieci regioni, il `202` in otto: contando i codici
  distinti le aziende risultano **52** invece delle **110** vere. Non è un errore
  di bordo — è un numero plausibile, sbagliato di più del doppio, del tipo che
  finisce in una slide. La tabella porta perciò `asl_id` = codice regione + codice
  azienda, e la descrizione di catalogo lo dice a chi scriverà la query;
- **gli URL dei file non sono costruiti a mano.** Il portale è un Drupal e i file
  stanno sotto `/sites/default/files/<anno-mese>/…`: quel segmento cambia a ogni
  ripubblicazione, e un percorso indovinato oggi è un 404 domani. Ogni file è
  preso leggendo la *pagina* del dataset — la disciplina di `zone-sismiche.mjs`;
- **i file sono in ISO-8859-1** e vanno convertiti con `iconv`, come in
  `patrimonio-pa.mjs`;
- **il punto è il separatore delle MIGLIAIA**, non dei decimali: `7.035` ricoveri
  sono settemilatrentacinque, e letti come decimale diventano sette. Colpisce
  esattamente le colonne più grandi — ricoveri e giornate di degenza — cioè quelle
  in cui l'errore è più grosso e meno visibile;
- ogni campo di testo è **riempito di spazi a destra** (i file nascono da tracciati
  a larghezza fissa): senza `trim` il nome del comune non aggancia niente;
- la serie dei posti letto sta in **cinque file** (2010-2019 più un file per anno):
  l'ETL **verifica che le cinque intestazioni coincidano** invece di fidarsi, perché
  un tracciato cambiato in silenzio è il modo in cui una colonna finisce sotto il
  nome di un'altra;
- `sanita_strutture` unisce due file — ospedali pubblici e case di cura accreditate
  — che hanno lo stesso tracciato ma intestazioni scritte diversamente, quindi sono
  letti **per posizione**. La colonna `natura` dice da quale viene una riga, e
  sommare senza guardarla mescola pubblico e privato accreditato;
- in quei due file il comune è un **nome in maiuscolo senza codice**, e agganciarlo
  richiede due normalizzazioni che da sole valgono trentadue righe su
  novecentonovantatré. I confini ISTAT portano il nome **bilingue** dei comuni
  altoatesini — «Bolzano/Bozen», «Merano/Meran» — mentre il Ministero scrive solo
  l'italiano: senza confrontare anche la parte prima della barra, **tutti** gli
  ospedali dell'Alto Adige risultavano inesistenti, e la pagina di un lettore di
  Bolzano diceva che nel suo bacino non c'è nessuna struttura. E il Ministero usa
  l'**apostrofo al posto dell'accento** finale (`FORLI'` per `Forlì`), la stessa
  trappola delle province in `aci-veicoli.mjs`. Tolto l'apostrofo da una parte e
  l'accento dall'altra, e confrontata anche la parte italiana del nome bilingue, i
  senza-comune scendono da 37 a **5**: sono comuni **rinominati** dopo la
  rilevazione (Negrar è diventato «Negrar di Valpolicella», Godiasco «Godiasco
  Salice Terme»), e restano tali invece di inaugurare una seconda tabella
  editoriale per cinque righe.

## Esiti delle cure — PNE (`etl/pne-esiti.mjs`)

`pne_esiti` (223.149 righe, 218 indicatori, 1.079 strutture, 121 aziende) e
`pne_indicatori` (838) dal **Programma Nazionale Esiti** di AGENAS: come vanno a
finire le cure, ospedale per ospedale — mortalità a trenta giorni dopo un infarto,
femori operati entro due giorni, cesarei, riammissioni.

**È il dato sanitario più utile che esista, e questo ETL nasce da un errore
mio.** Nella ricognizione del giorno prima avevo scritto — qui e sul sito — che
gli esiti «si consultano struttura per struttura da un'interfaccia, non si
scaricano». Falso: il portale è una pagina singola che parla con una **API REST
aperta**, dichiarata nella sua stessa configurazione (`assets/config.json`,
campo `apiUrl`), senza chiave. Guardare quali richieste fa il sito invece di
guardare il sito è la differenza fra le due conclusioni — la stessa disciplina
con cui il Punto di Accesso Nazionale della mobilità è stato trovato, e trovato
spento.

Trappole, e sono le più insidiose di tutto il warehouse perché ognuna produce un
numero *plausibile*:

- **666 non è un valore: è la sentinella di «aggiustamento non calcolato».**
  Compare 7.886 volte, **solo** nella colonna aggiustata — nel grezzo mai — e
  sempre su righe con poche decine di casi. Lasciata dentro scrive «666% di
  mortalità» accanto al nome di un ospedale, cioè diffama un reparto con un dato
  ufficiale. Diventa NULL, e **da quella colonna soltanto**: `casi` = 666 esiste
  ed è vero, sono le 666 PTCA del Gemelli;
- **il 36% delle righe erano duplicati esatti.** L'API restituisce la stessa
  misura più volte per la stessa coppia (indicatore, struttura): 349.738 righe
  scendono a 223.149 deduplicando sul JSON del valore. Senza, ogni media e ogni
  classifica contano due volte alcuni ospedali — il Gaetano Pini compariva due
  volte identico nella graduatoria del femore;
- **la stessa colonna porta unità diverse**, ed è il motivo per cui non si chiama
  «percentuale»: per gli indicatori di VOLUME i numeri sono conteggi (il Federico
  II ha 3046 per il volume dei parti), per mortalità e proporzioni sono
  percentuali. La colonna `misura` dice quale, da una mappa **editoriale** dei
  sette tipi che l'API dichiara — l'endpoint che li nominerebbe risponde 403;
- **`valore_aggiustato` è la colonna che conta.** Il grezzo mette insieme
  pazienti non confrontabili: un centro che prende i casi più gravi ha una
  mortalità grezza più alta *proprio perché* fa il suo mestiere. Capita che
  l'aggiustato sia più alto del grezzo — il Cardarelli fa 8% grezzo e 11,98%
  aggiustato sull'infarto — e vuol dire il contrario di quello che sembra;
- fra le «strutture» ce ne sono due che ospedali non sono: il codice `00000001` è
  l'**Italia**, l'aggregato nazionale, e `00000000` è «Altre Strutture». La
  colonna `livello` le distingue, o l'Italia finisce in una classifica di
  ospedali;
- **le edizioni sono quattro e tre sono OFFLINE**: si prende solo quella corrente,
  scelta leggendo lo stato e non scrivendo un anno a mano. Ripubblicare
  un'edizione ritirata rimetterebbe in circolo numeri che AGENAS ha tolto;
- si pagina, tetto 2000, `paged=false` ignorato: l'edizione corrente sono 175
  richieste da un secondo. Tutte e quattro sarebbero 1,36 milioni di valori, ed è
  esattamente ciò che non va scaricato;
- i codici struttura del PNE hanno **otto** caratteri, quelli del Ministero
  **sei**: due numerazioni diverse. Le due sanità si incontrano per comune, e
  agganciarle per codice unirebbe righe a caso.

## Personale e apparecchiature del SSN (`etl/sanita-personale.mjs`)

`sanita_personale` (1191 righe, 205 aziende, **2020-2022**) e
`sanita_apparecchiature` (6771 righe, 2332 strutture, **con le coordinate**).
Al 2022: **106.960 medici e 272.119 infermieri** dipendenti — gli ordini di
grandezza noti del SSN, verificati a ogni run.

Trappole:

- **il personale è in XLSX e il foglio non dichiara le sue dimensioni.** Senza
  `<dimension>` DuckDB deduce la larghezza dalla PRIMA riga, che è il titolo del
  modello: una cella, quindi una colonna, quindi un file che sembra vuoto. Serve
  un `range` esplicito;
- **l'intestazione non è la prima riga** e si CERCA (quella che contiene «CODICE
  REGIONE») invece di contarla, o un'annata con una nota in più sposta ogni
  colonna di uno in silenzio. Il foglio giusto è il secondo, «MED E INF», scelto
  per nome perché porta l'anno attaccato;
- i totali si chiamano **`PERS. ANNO RIF. U/D`**, non «TOTALE»;
- **`dotazione_organica` c'è e vale sempre ZERO**, su tutte le 1191 righe: una
  colonna vuota con un nome promettente è peggio di una assente, perché qualcuno
  ci calcolerà sopra la scopertura degli organici e otterrà il 100% ovunque;
- il **2019 è in `.xls`** e l'estensione Excel di DuckDB legge solo `.xlsx`: si
  parte dal 2020, detto invece di lasciarlo sembrare un buco;
- i tipi di apparecchiatura sono **nove ACRONIMI** — TAC, RMN, MMI, PET — non
  parole: cercare «RISONANZA» non trova niente;
- **diciassette strutture hanno coordinate fuori dall'Italia**, errori della
  fonte. Un punto sbagliato tira l'inquadratura dall'altra parte del Paese e
  nasconde tutti gli altri, quindi chi cade fuori dal rettangolo nazionale resta
  senza coordinate invece di essere disegnato dove non è;
- le due colonne di conteggio coincidono in 6438 righe su 6771 e altrove
  differiscono in **entrambe** le direzioni: la lettura ovvia «installate contro
  funzionanti» è esclusa dai dati, e non viene raccontata.

## Spesa delle aziende sanitarie (`etl/sanita-spesa.mjs`)

`sanita_spesa` (93.750 righe, 260 enti, **2021-2026**): quanto paga e incassa per
cassa ogni azienda sanitaria, per anno e categoria del piano dei conti.

**Non scarica niente**, e questo è il punto: rilegge i file che `siope.mjs` ha già
in `raw/siope/`, che contengono TUTTI gli enti mentre quell'ETL tiene solo i
comuni. La spesa sanitaria per azienda era sul disco da mesi, mentre altrove si
scriveva che «esiste per regione e a scendere si ferma». Il modo più economico di
aggiungere una fonte è accorgersi di averla già.

Trappole, tutte trovate dal controllo sull'ordine di grandezza a fine ETL:

- **l'importo è un decimale con il PUNTO** — «8113577.85» — non un numero
  all'italiana: trattare i punti come separatori di migliaia lo moltiplica per
  cento, e il totale nazionale usciva a **8641 miliardi** contro gli 86 veri;
- il campo del periodo è **`2021/09`, con la barra**: letto a posizione fissa il
  mese diventa «/0», cioè NULL, e il join sul mese più alto **svuota la tabella
  intera** senza un errore — zero righe, e sembra che la fonte non abbia sanità;
- il **codice comune è a tre cifre**, dentro la provincia: il codice ISTAT a sei
  si compone con quello della provincia, o tutte le righe restano senza sede;
- **quattro tipologie sanitarie** (AS le ASL, AG le gestioni, RS le regioni, AR le
  agenzie) e sommarle alla cieca mette insieme l'azienda che gestisce gli ospedali
  e la contabilità accentrata di una Regione;
- SIOPE **non porta il codice dell'azienda**, solo il nome: con
  `sanita_asl_comuni` non si aggancia, e per nome non si tenta. Quello che c'è è
  il comune della SEDE.

## Sanità territoriale (`etl/sanita-territorio.mjs`)

`consultori` (2164 in **1563 comuni**, con il codice ISTAT), `salute_mentale`
(5876 righe, 3,3 milioni di accessi nel 2024) e `dipendenze` (16.169 righe,
131.328 utenti). È la sanità che si incontra **senza essere ricoverati**, e nel
warehouse non c'era niente di tutto questo.

Trappole:

- **le intestazioni cambiano fra annate della stessa fonte, per uno SPAZIO**: il
  2024 scrive «Descrizione Regione » e il 2022 «Descrizione Regione». Con
  `UNION ALL BY NAME` diventano due colonne distinte e qualunque nome si scelga
  fallisce per metà degli anni. Le colonne di ogni file si LEGGONO (`DESCRIBE`) e
  si mappano su un nome canonico ignorando spazi e maiuscole;
- **nel file dei SerD la colonna degli utenti è spesso vuota** — 945 celle: sono
  i numeri troppo piccoli perché il Ministero li pubblichi senza rischiare di
  identificare le persone. Restano NULL e non diventano zero, perché uno zero
  direbbe «nessun utente», che è una cosa diversa e più grave;
- i consultori scendono al COMUNE, salute mentale e dipendenze si fermano
  all'AZIENDA: è il livello a cui quei servizi sono organizzati, non una mancanza.

## Dimissioni ospedaliere — SDO (`etl/sdo-dimissioni.mjs`)

`sdo_eta` (2726 righe, 1353 istituti), `sdo_esito` (1357) e `sdo_traumi` (219):
per che cosa la gente finisce in ospedale, chi è, e come ne esce — **7.645.914
dimissioni**, la scala nota del SSN.

Questi file hanno più trappole di qualunque altra fonte del warehouse:

- **ogni riga è un unico campo quotato** che *contiene* i punti e virgola, con le
  virgolette interne raddoppiate. Non è un CSV con campi quotati: è un CSV di una
  colonna. Si legge una riga per volta e si spacchetta a mano;
- il **punto separa le migliaia** — «10.487» dimissioni, non dieci;
- **`***` è il marcatore di dato oscurato**, non un valore;
- **e da quel NULL discendono due errori peggiori.** Sommare le dieci colonne
  dell'età con `+` fa sparire l'ospedale intero, perché in SQL `x + NULL` è NULL:
  1712 righe su 2726 hanno una classe oscurata, il Bambino Gesù con 55.543
  ricoveri esce dal totale per una cella, e il totale nazionale scende a 5,1
  milioni contro i 7,6 veri. Un livello più su è **peggio**: se una sola delle due
  righe di un ospedale (maschi, femmine) ha una cella oscurata, `sum()` la salta e
  l'ospedale compare con **metà** dei ricoveri — le Molinette a 17.174 invece di
  39.870, un numero plausibile e dimezzato, che è peggio di un numero assente. Il
  totale per ospedale si prende da `sdo_esito`;
- **la terza volta il NULL è finito dentro il controllo stesso**: `nullif` sul
  denominatore rende NULL il confronto, e `NULL < 1` non è vero, quindi sedici
  ospedali che non divergevano affatto risultavano divergenti. Corretto: i due
  file si accordano entro l'1% su **tutti i 389** ospedali senza celle oscurate,
  scarto massimo 0,63%. È il controllo che prova che il parsing è giusto.

## Servizi territoriali del SSN (`etl/sanita-servizi.mjs`)

**Dodici tabelle, 246.834 righe** da 61 file: salute mentale (prestazioni,
personale, strutture convenzionate, centri diurni, residenziali, primo contatto
per età e per diagnosi, prevalenza per diagnosi), dipendenze (personale, utenti
per trattamento) e posti letto per regione e per stabilimento, 2010-2025.

**È un ETL solo con un REGISTRO, non dodici ETL.** Le famiglie condividono la
stessa forma — anno, regione, azienda, servizio, una dimensione, una misura — e
scriverle una per una significherebbe dodici copie della stessa lettura, che
divergono al primo file che cambia. La differenza fra una famiglia e l'altra è una
voce di `FAMIGLIE`.

Trappole:

- **le intestazioni cambiano fra annate della stessa famiglia**, e non di poco:
  «Codice Asl» diventa «CODICE AZIENDA», «DESCRIZIONE REGIONE» diventa
  «DENOMINAZIONE REGIONE», e in una c'è «DECRIZIONE REGIONE» con il refuso. Su 116
  file ci sono **46 tracciati distinti**. Le colonne di ogni file si leggono con
  `DESCRIBE` e si mappano su un nome canonico ignorando spazi, accenti e
  maiuscole, con le alternative dichiarate;
- **dal 2021 diversi file mettono una riga di TITOLO sopra l'intestazione**, o una
  riga di soli punti e virgola. Letta come intestazione produce colonne senza nome
  e zero righe utili, **senza un errore**: il personale dei SerD risultava fermo
  al 2020 con quattro annate scaricate e buttate. Si cerca la prima riga che
  contiene una chiave attesa;
- **sedici dataset del portale non hanno alcun file scaricabile**: tutta la spesa
  per dispositivi medici dal 2013 al 2021, l'elenco nazionale dei direttori, il
  personale universitario, la spesa per medicinali regionale. La pagina esiste, il
  link no. Sono elencati in `SENZA_FILE` perché la ricerca non venga rifatta.

## Durata dei procedimenti civili (`etl/giustizia-durata.mjs`)

`giustizia_durata` è la durata media dei procedimenti civili per **ufficio
giudiziario** (fonte DGSTAT — Ministero della Giustizia, CC BY 4.0):
**18.540 righe**, una per (ufficio, materia, anno), 140 uffici (tribunali +
corti d'appello), anni 2014–2025. Completa `giustizia_amministrativa` (TAR)
e `corte_costituzionale` con la giustizia ORDINARIA — il dato più citato
sulla lentezza della giustizia civile italiana. Due registri uniti in una
tabella: **SICID** (cognizione ordinaria — civile ordinario, lavoro,
previdenza, procedimenti speciali, volontaria giurisdizione; tribunali e
corti d'appello) e **SIECIC** (esecuzioni mobiliari/immobiliari,
liquidazione giudiziale ex fallimenti; solo tribunali).

**Solo civile**: la pagina gemella sul penale non ha alcun export
bulk/CSV/xlsx, solo una dashboard interattiva senza download — non si è
inventato un URL, la tabella copre onestamente solo ciò che la fonte
pubblica.

Trappole:

- i due file mischiano più **livelli di aggregazione** nella stessa colonna
  (Circondariale/Distrettuale/Nazionale): si tiene solo il livello per
  singolo ufficio (Circondariale per i Tribunali; per le Corti d'appello è
  la riga Distrettuale, che essendo un unico ufficio per distretto NON va
  ulteriormente scartata) o i Tribunali di un distretto si sommerebbero;
- nessun codice ISTAT/provincia: il `Distretto` (circoscrizione della corte
  d'appello, 29 sedi) si mappa alla regione con una tabella editoriale
  (stesso pattern di `giustizia-amministrativa.mjs` per i TAR — i distretti
  non sono 1:1 con le regioni, la Sicilia ne ha 4).

## Dispersione scolastica (`etl/dispersione.mjs`)

`dispersione_scolastica` è il tasso di abbandono scolastico complessivo (%),
fonte MIM — Ufficio di Statistica, Anagrafe Nazionale degli Studenti (riuso
libero con citazione): **267 righe**, serie storica NAZIONALE
(`regione='ITALIA'`) dall'a.s. 2013/2014 al 2020/2021 per i tre gradi (I
grado, passaggio tra cicli, II grado), più il dettaglio REGIONALE per 6
bienni consecutivi 2015/2016-2020/2021 (18 regioni).

Il ministero **non pubblica un export CSV/XLSX** per questo fenomeno, solo
una serie di PDF "Focus" biennali. Le tabelle e i grafici in quei PDF hanno
però etichette numeriche VERE nel layer di testo del PDF (non immagini
raster): l'ETL scarica 4 edizioni (uniche, coperture non sovrapposte —
2015/16-16/17, 16/17-17/18, 17/18-18/19+18/19-19/20, 19/20-20/21+20/21-21/22)
e ricostruisce le coppie (etichetta, valore) per **prossimità di coordinate
x/y** con `pdfjs-dist` (la stessa libreria del RAG PDF, vedi `RagIndex.js`) —
mai un modello vision che "legge" un grafico: qui il numero è testo esatto
del ministero, zero rischio di allucinazione.

Trappole:

- il grafico regionale copre 18 regioni + ITALIA: Valle d'Aosta e
  Trentino-Alto Adige sono ASSENTI dalla fonte per l'intera serie di
  edizioni (a differenza di INVALSI, che include le province autonome) — non
  un buco dell'estrattore;
- il grafico "passaggio tra cicli scolastici" non ha in ogni edizione il
  dettaglio regionale completo: si prende quello che c'è (solo 2 dei 6
  bienni ne dispongono);
- le etichette hanno spazi spuri interni per un font TrueType con lo spazio
  rotto ("Lomba rdia" invece di "Lombardia"): il match dei nomi regione è
  per confronto normalizzato (solo lettere, maiuscolo, accenti rimossi);
- copertura regionale parziale per costruzione (243/288 celle attese, ~84%):
  una barra senza etichetta abbastanza vicina in x si scarta piuttosto che
  rischiare un accoppiamento sbagliato;
- il valore ITALIA letto dai grafici regionali è ridondante con la serie
  storica nazionale (la copre per intero) e viene scartato: le righe
  `regione='ITALIA'` vengono SOLO dalla serie storica.

## Alunni iscritti (`etl/iscrizioni.mjs`)

`iscrizioni_scolastiche` è il numero di alunni per comune, grado (primaria,
secondaria I/II grado) e anno scolastico: **113.536 righe**, 10 anni
(2015/16-2024/25), fonte MIUR — Portale Unico dei Dati della Scuola (IODL
2.0). Un file per anno, aggregato dall'anagrafe per-scuola sommando su anno
di corso e fascia d'età; il comune deriva dal join con `scuole.codice_scuola`
(che risolve già il codice catastale → ISTAT). Solo statale, scuola
dell'infanzia esclusa dalla fonte (dataset separato, non integrato). Il
quadro numerico che completa `scuole` (anagrafica) e si incrocia con
`dispersione_scolastica`/`invalsi` sullo stesso grado.

## Edilizia scolastica (`etl/edilizia-scolastica.mjs`)

`edilizia_scolastica` è l'Anagrafe Nazionale dell'Edilizia Scolastica:
**60.054 edifici**, comune (codice ISTAT DIRETTO, non catastale — a
differenza di `scuole`), epoca di costruzione, classificazione sismica
nazionale (1-4) e vincoli (idrogeologico, paesaggistico, tutela). Tre file
uniti su (CODICESCUOLA, CODICEEDIFICIO): anagrafica + vincoli + età
origine, ultimo anno scolastico (un edificio non ha una serie storica
interessante). Nessun importo di investimento nella fonte: per i
finanziamenti si incrocia con `opencoesione` (tema "Istruzione e
formazione"). Curiosità onesta: una manciata di edifici hanno
`anno_costruzione` con datazione al secolo (1000, 1200, 1300…) — non un
errore, sono ex conventi/palazzi storici riconvertiti a scuola.

## Personale scolastico (`etl/personale-scuola.mjs`)

`personale_scuola` è il personale di RUOLO (titolare) per provincia:
**36.918 righe**, 10 anni, docenti (per grado, tipo posto normale/sostegno,
fascia d'età, genere) e ATA (fascia d'età, genere), fonte MIUR (IODL 2.0).
Granularità provincia (la fonte non pubblica un livello più fine). Solo
titolari: il precariato (supplenti) è una famiglia di dataset separata e
discontinua a metà serie storica (cambio schema nel 2023/24), non integrata
per tenere la serie comparabile su tutti gli anni. Il lato "chi insegna" che
completa `iscrizioni_scolastiche` (chi studia): rapporto alunni/docenti per
territorio.

## Risultati INVALSI per regione (`etl/invalsi-regionale.mjs`)

`invalsi_regionale` completa `invalsi` (censuario, per comune, solo l'ultimo
anno) con la dimensione che a quello manca: **2.644 righe**, serie storica
2012/13-2022/23 (11 anni, 2019/20 assente per il COVID) per regione, le 5
aree geografiche e Italia — fonte INVALSI, pagina "Open Data" (CC BY 4.0,
nessuna registrazione, distinta dall'archivio microdati). Punteggio medio
(scala WLE), errore standard, percentili, per grado e materia. CAMPIONARIO,
non censuario: i due dataset INVALSI si affiancano, non si sommano. Nessuna
rottura per indirizzo di studio nella fonte open data verificata (solo nei
microdati a registrazione, non integrati).

## Fonti valutate e NON integrate

Fonti candidate rivelatesi non percorribili con lo stesso pattern "bulk
download pubblico, nessuna chiave" del resto del warehouse — annotato qui
per non riaprire la ricerca da zero:

- **OMI (quotazioni immobiliari, Agenzia delle Entrate)**: nessun bulk
  nazionale open. Le "Forniture dati OMI" richiedono autenticazione
  Entratel/SPID/CIE nell'area riservata. L'unica eccezione è un CSV aperto
  del solo Comune di Milano (ripubblicato dal comune stesso), non
  generalizzabile all'Italia;
- **GSE Atlaimpianti** (impianti da fonti rinnovabili geolocalizzati): al
  momento della ricerca (lug 2026) il portale è offline ("in fase di
  aggiornamento"); anche da vivo è un WebGIS senza vera API/bulk — solo un
  export XLS manuale dai filtri interattivi, non scriptabile in modo
  affidabile. L'alternativa più vicina (Rapporto Statistico GSE annuale) è
  aggregata per regione/provincia, senza coordinate: non un layer di punti,
  troppo debole rispetto all'obiettivo. Da riconsiderare se/quando
  Atlaimpianti torna online con un vero export;
- **OCSE-PISA** (risultati scolastici comparati internazionalmente): INVALSI
  (centro nazionale PISA) pubblica solo a livello di MACROAREA (5 aree, non
  regione), in formato SPSS `.sav`, dietro registrazione gratuita — non un
  bulk CSV/XLSX aperto. L'OCSE stesso non pubblica un aggregato regionale
  ufficiale per l'Italia (esiste solo in letteratura accademica, ricavato
  dai microdati). Scartato: sforzo (parsing SPSS + registrazione) sproporzionato
  al guadagno informativo rispetto a `invalsi_regionale`, che copre già le 5
  aree geografiche con dati aperti e serie storica più lunga.

### Il dato pubblico che vive dietro un'interfaccia

Tre fonti sono aperte per legge, gratuite, e non hanno un canale bulk: si
consultano una voce alla volta. Prenderle vorrebbe dire pilotare un'interfaccia
di ricerca non pensata per quello — la stessa cosa che la skill `cruscotto-cli`
vieta esplicitamente sul proprio server, e per le stesse ragioni. Sono annotate
qui perché la ricerca non vada rifatta, non perché siano da fare:

- **RUNTS** (Registro Unico Nazionale del Terzo Settore, Ministero del Lavoro):
  nessun export, nessuna API documentata, nessun dataset nazionale su
  dati.gov.it — solo frammenti regionali (Lombardia, Puglia) e comunali. La
  consultazione è una ricerca ente per ente su `servizi.lavoro.gov.it/runts`;
- **AGCOM Broadband Map** (copertura banda larga e FTTH): il link «open data» su
  `geo.agcom.it/opendata` reindirizza a `geo3.agcom.it/opendata`, che è
  un'applicazione Leaflet a pagina singola. I download tabellari a livello
  comunale esistono e sono annunciati, ma passano dall'interfaccia della mappa:
  nessun link a file, nessuna API pubblicata, nessun dataset su dati.gov.it;
- **ISPRA — misure di qualità dell'aria dal 2013**: il registro delle 755
  stazioni si scarica (EEA, `PanEuropean_metadata.csv`, 26,9 MB, con coordinate
  e tipo di stazione), ma le misure recenti no. L'API EEA risponde con zero file
  per Italia, Austria, Germania, Francia e Spagna — è il servizio, non l'Italia —
  e ISPRA non pubblica un bulk nazionale: i 365 risultati per «qualità aria» su
  dati.gov.it sono venti portali ARPA con venti formati. **Da risondare**: un
  guasto che colpisce cinque paesi ha l'aria del temporaneo.

### Dichiarati e vuoti: i dataflow «BULK» di ISTAT

Due cose diverse sono bloccate dallo **stesso** guasto, e conviene saperlo perché
si sbloccheranno insieme. Su IstatData certi dataflow sono elencati nel catalogo
e scollegati dal motore dei dati; interrogarli risponde:

```
Dataflow ... doesn't contain a mapping set
```

Riguarda `DF_BULK_PEND_LAV_2021_1` (la **matrice del pendolarismo 2021**, per cui
`pendolarismo.mjs` ripiega sul Censimento 2011) e `DF_BULK_DCSC_OCCUPCOLLE` (il
**movimento turistico comunale**, per cui `turismo.mjs` si ferma alla provincia).
Vale la pena risondarli ogni tanto: sono due ETL da cambiare di poco, non da
riscrivere.

### Mobilità: il canale ufficiale è fuori servizio, e il tempo reale non va qui

Cercando gli orari del trasporto pubblico si arriva al **NAP — Punto di Accesso
Nazionale** (`nap.mit.gov.it`), che l'Europa impone come aggregatore unico dei
dati di mobilità (Reg. delegato 2017/1926) ed è dove stanno i GTFS degli
operatori italiani. Oggi non serve niente a nessuno:

```
/nap-api/stats/datasets   → 500     (i due endpoint che l'app stessa chiama)
/nap-api/groups           → 500
/catalog/api/3/action/…   → 503 Service Unavailable
```

Sotto c'è un CKAN, quindi l'API sarebbe quella documentata e completa; è il CKAN
a essere giù, e il servizio davanti risponde 500 perché sta proxando quello. Gli
endpoint non sono indovinati: sono letti dalle richieste che il sito fa da solo
(`assets/configuration/configuration.json` dichiara `API_BASE_URL_PROD`). **Da
risondare** — a differenza dei casi qui sopra non è un dato che manca, è un
servizio spento. Gli altri due cataloghi GTFS non aiutano: **Mobility Database**
richiede login Google IAP, **TransitFeeds** risponde 403 ed è dismesso.

**La micromobilità in tempo reale c'è, e sta deliberatamente fuori dal
warehouse.** Il catalogo **GBFS** elenca 36 sistemi italiani (Dott, Bird, Lime,
Zeus, Cooltra, BikeMi, nextbike…), formato standard, nessuna chiave, e — la
cosa che decide tutto — `Access-Control-Allow-Origin: *`. Provati dal vivo: Dott
Milano 3.740 veicoli, Roma 6.253, Torino 2.615. Il posto giusto per leggerli è
`::api-query{every="60"}` **dal browser**, non un ETL: il warehouse si aggiorna a
cadenza di giorni e un monopattino si sposta ogni minuto, quindi una fotografia
salvata qui produrrebbe dati vecchi che *sembrano* vivi — lo stesso inganno del
SELECT che torna vuoto senza errore. La CSP non va toccata: `connect-src https:`
è già concesso.

Va detto per intero, perché è il limite della cosa: quei 36 sistemi stanno in una
trentina di comuni. Una dashboard **nazionale** e **in tempo reale per ogni
comune** non è scrivibile — il tempo reale in Italia esiste dove c'è lo sharing e
finisce lì. Quello che si può fare, ed è quello che si fa, è una dashboard
nazionale su 7.896 comuni che *dove esiste* si accende anche in tempo reale.

Infine, **la mobilità urbana ISTAT non è nazionale**: i dataflow
`609_1_DF_DCCV_URBANENV_*` (TPL, mobilità sostenibile, veicoli circolanti) sono
100.922 righe su **127 aree** — i capoluoghi. Buoni per un confronto fra città,
inutili per una mappa dei comuni, ed è il motivo per cui non sono qui.

## Layer semantico (`etl/semantica.mjs`)

Tre tabelle di metadati che rendono il warehouse **auto-descrittivo**:
`catalog_keys` (le chiavi concettuali — codice ISTAT, CF, CIG, sigla, regione,
id impianto — con l'URI **OntoPiA** dove esiste: CLV per i luoghi, COV per il
codice fiscale), `catalog_relations` (le relazioni formali tabella→tabella con
cardinalità e **copertura misurata**: ogni relazione dichiarata viene verificata
col join a ogni run e la percentuale finisce nella riga — la documentazione si
autoverifica) e `catalog_columns` (ogni colonna di ogni tabella, generata dal
catalog, col concetto chiave quando ne porta uno). Sono tabelle normali,
interrogabili via `od-query`: l'esploratore del sito ci costruisce il grafo
delle relazioni (con fallback alle euristiche sui nomi di colonna quando
mancano) e l'assistente può rispondere «come si uniscono X e Y?» con una
SELECT su `catalog_relations`.

Trappole:

- gli URI ontologici sono SOLO quelli certi di OntoPiA; dove non esiste un
  concetto standard (CIG, id impianto) l'URI resta NULL con la descrizione —
  meglio onesti che inventati;
- va rieseguito DOPO gli altri ETL (legge il `catalog` e misura i join sul
  dato reale): una copertura che crolla segnala una regressione in un ETL a
  monte.

## Ricerca semantica: l'indice ANN (HNSW)

La ricerca per riga era una **scansione completa** con cosine su ogni vettore:
sostenibile a 24k atti, impossibile a milioni di gare. Le tabelle con
embeddings portano quindi un indice **HNSW** (estensione `vss` di DuckDB),
creato in coda a `normattiva.mjs` e `anac.mjs`. Misurato su **2,67M vettori
veri** (l'intero `anac_cig`): **25 ms contro 3,3 secondi** di forza bruta
(132×), recall@10 100%; su query reali via Ollama, 11-58 ms.

⚠️ **La build vuole un tetto di memoria, o va in OOM.** vss costruisce il grafo
**fuori** dalla memoria tracciata da DuckDB: senza `SET memory_limit` il
processo veniva **ucciso** a 2,67M vettori (il log si tronca senza riga di
errore — firma del kill). Con `memory_limit = '40GB'` + spill su disco la build
è passata in ~5 minuti, toccando ~43 GB di RAM su 60 fisici. Gli ETL lo
impostano da soli; il valore va **tarato sulla RAM della macchina** (vedi
"Produzione" sotto).

Cinque cose da sapere, tutte verificate sul campo:

1. **L'indice appartiene alla tabella**: gli ETL fanno DROP/RENAME per
   ricostruirla, e questo porta via l'indice. Va ricreato **dopo** lo swap —
   è l'ultimo passo, non il primo.
2. **La forma della query decide se l'indice si usa**: solo
   `ORDER BY array_cosine_distance(...) LIMIT n` (crescente). Con
   `array_cosine_similarity ... DESC` il planner fa una scansione completa
   **senza dirlo**. In `server.mjs` lo score resta la similarità (`1 -
   distanza`) per non cambiare l'API. Il filtro `WHERE embedding IS NOT NULL`
   non disturba l'indice (verificato con EXPLAIN).
3. **`enable_external_access=false` nella config blocca il `LOAD`** delle
   estensioni: vedi la nota sulla sequenza di avvio più sopra.
4. **La persistenza dell'indice è sperimentale** (`SET
   hnsw_enable_experimental_persistence = true`, obbligatorio per crearlo su un
   database su file).

5. **L'indice è memory-resident quando lo si interroga.** Alla PRIMA query
   DuckDB carica l'intero grafo HNSW in RAM (misurato: 9,2s e RSS a 23,7 GB su
   2,67M vettori), poi ogni query è ~10-50 ms. È il fatto che detta il
   perimetro in produzione (sotto).

Il `catalog` (203 righe) **non ha indice**: a quella scala la scansione è
sotto il millisecondo e un indice aggiungerebbe solo superficie di rischio.

### Produzione: perché il perimetro ANAC è ≥ 140.000 €

La macchina di produzione (`185.58.193.49`) ha **15 GB di RAM**. L'indice HNSW
è memory-resident (punto 5): l'RSS scala col numero di vettori, e la misura è
**2,67M vettori → ~23 GB residenti** — fuori portata, finirebbe in swap e la
traversata del grafo (accesso casuale, il caso peggiore per lo swap)
riporterebbe le query a secondi, oltre il timeout di 10s del servizio.

Il default `--embed-min 140000` (soglia UE per forniture/servizi) tiene nel
warehouse **~304k vettori → ~2,7 GB residenti**, comodi in 15 GB. Solo le righe
del perimetro finiscono nella colonna `embedding` (le altre restano `NULL`),
quindi anche il **file si sgonfia** — da 44 GB (tutto indicizzato) a ~7-8 GB,
il che rende sano l'rsync di `deploy.sh`. Le gare sotto soglia restano
interrogabili con `::od-query`; solo la ricerca semantica non le copre.

La cache **`anac-emb.duckdb`** (locale, ~18 GB, gitignored, **mai deployata**)
conserva TUTTI i 2,67M vettori: se un domani il server cresce, basta rifare
l'ETL con `--embed-min 40000` (o 0) — l'indice si allarga **senza riembeddare**
(il calcolo è 12 ore, la ricostruzione dell'indice pochi minuti). Corrispondenze
misurate: ≥140k€ = 304k vettori (~2,7 GB), ≥40k€ = 758k (~6,7 GB), tutti = 2,67M
(~23 GB).

Nota infrastrutturale: la **build** dell'indice (che chiede ~40 GB, punto ⚠️)
gira dove si fa l'ETL, **non sul server** — il server riceve il warehouse già
indicizzato via rsync e lo carica in RAM. Sono due requisiti di memoria
diversi: molta per costruire (locale), poca-ma-sufficiente per servire (il
perimetro deve starci).
