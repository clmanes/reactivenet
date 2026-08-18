---
appId: come-si-vive
title: "Come si vive qui"
description: "Il ritratto del tuo comune in un posto solo: quanti siamo e quanto si guadagna, quanto è sicura la strada e chi si muove, che sanità c'è intorno — ospedali, esiti delle cure, consultori, medici — quanto suolo è stato costruito e quanto si differenzia. Sempre accanto al numero della provincia e dell'Italia, con previsioni e correlazioni calcolate nel tuo browser."
icon: home
lang: it
version: "2.0"
author: "ReactiveNET"
date: "2026-08-17"
---

::od-query{into="comuniVita" sql="SELECT g.codice_istat AS codice, g.comune || ' (' || g.sigla || ')' AS nome FROM istat_confini_comuni g ORDER BY 2" limit="8000"}

::choose[comune]{path="comuniVita" field="codice" label="nome" legend="Dove vivi" value="063049" help="Tutte le pagine seguono questa scelta."}

::page{title="Il ritratto" icon="home"}

# Com'è, questo posto

Sei numeri, presi da sei fonti diverse, che insieme dicono più di qualunque
classifica: quanti siamo, quanto si guadagna, quanto è pericolosa la strada,
quanta salute c'è a portata di mano, quanto del territorio è stato costruito, e
quanto trema.

::od-query{into="ritratto" sql="SELECT (SELECT popolazione FROM istat_popolazione WHERE codice_istat = '{#comune}') AS abitanti, (SELECT round(reddito_medio, 0) FROM mef_redditi WHERE codice_istat = '{#comune}' AND anno = (SELECT max(anno) FROM mef_redditi)) AS reddito, (SELECT round(i.incidenti * 10000.0 / nullif(p.popolazione, 0), 1) FROM incidenti_stradali i JOIN istat_popolazione p USING (codice_istat) WHERE i.codice_istat = '{#comune}' AND i.anno = (SELECT max(anno) FROM incidenti_stradali)) AS incidenti_per_10mila, (SELECT round(count(*) * 10000.0 / nullif((SELECT popolazione FROM istat_popolazione WHERE codice_istat = '{#comune}'), 0), 1) FROM farmacie WHERE codice_istat = '{#comune}') AS farmacie_per_10mila, (SELECT round(suolo_consumato_pct, 1) FROM consumo_suolo WHERE codice_istat = '{#comune}' AND anno = (SELECT max(anno) FROM consumo_suolo)) AS suolo_costruito_pct, (SELECT zona FROM zone_sismiche WHERE codice_istat = '{#comune}') AS zona_sismica"}

::columns{min="11rem" gap="m"}

**:sum{path="ritratto" field="abitanti"}** abitanti

**:sum{path="ritratto" field="reddito"} €** di reddito medio

**:sum{path="ritratto" field="incidenti_per_10mila" decimals="1"}** incidenti ogni 10.000

**:sum{path="ritratto" field="farmacie_per_10mila" decimals="1"}** farmacie ogni 10.000

**:sum{path="ritratto" field="suolo_costruito_pct" decimals="1"}%** di suolo costruito

zona sismica **:sum{path="ritratto" field="zona_sismica"}**

::/columns

La **zona sismica** va da 1 a 4 e più è bassa più il terreno è pericoloso: la 1 è
dove i terremoti forti sono attesi, la 4 dove non lo sono. È l'unico numero di
questa pagina che non dipende da come è amministrato il posto — dipende da dove
è.

## Rispetto a chi ci sta intorno

Un numero da solo non dice niente: 28 incidenti ogni diecimila abitanti sono
tanti o pochi solo accanto a quelli di qualcun altro.

::od-query{into="confrontoVita" sql="WITH s AS (SELECT sigla, regione FROM istat_confini_comuni WHERE codice_istat = '{#comune}'), b AS (SELECT g.codice_istat, g.sigla, g.regione, i.incidenti, p.popolazione FROM istat_confini_comuni g JOIN istat_popolazione p USING (codice_istat) JOIN incidenti_stradali i ON i.codice_istat = g.codice_istat AND i.anno = (SELECT max(anno) FROM incidenti_stradali)) SELECT amb.ambito, round(CASE amb.ambito WHEN 'Qui' THEN (SELECT sum(incidenti) * 10000.0 / nullif(sum(popolazione), 0) FROM b WHERE codice_istat = '{#comune}') WHEN 'Provincia' THEN (SELECT sum(incidenti) * 10000.0 / nullif(sum(popolazione), 0) FROM b WHERE sigla = (SELECT sigla FROM s)) WHEN 'Regione' THEN (SELECT sum(incidenti) * 10000.0 / nullif(sum(popolazione), 0) FROM b WHERE regione = (SELECT regione FROM s)) ELSE (SELECT sum(incidenti) * 10000.0 / nullif(sum(popolazione), 0) FROM b) END, 1) AS incidenti_per_10mila FROM (SELECT unnest(['Qui','Provincia','Regione','Italia']) AS ambito) amb"}

::chart-bar{data="confrontoVita" x="ambito" y="incidenti_per_10mila" height="250"}

::/page

::page{title="La strada" icon="alert"}

# Quanto è sicura la strada

::od-query{into="serieVita" sql="SELECT anno, incidenti, morti FROM incidenti_stradali WHERE codice_istat = '{#comune}' ORDER BY anno" limit="40"}

::chart-line{data="serieVita" x="anno" y="incidenti" height="280"}

Ventiquattro anni. Se la linea sta a terra non è un buco nei dati: circa
milleseicento comuni l'anno hanno **zero** incidenti, ed è la risposta migliore
possibile.

## E i prossimi anni

::slider[orizzonte]{min="1" max="10" step="1" value="5" label="Anni da proiettare"}

::ml-forecast{data="serieVita" x="anno" y="incidenti" horizon="#orizzonte" into="previsioneIncidenti"}

::chart-line{data="previsioneIncidenti" x="anno" y="incidenti,previsione" height="300"}

**Questa è una retta tirata avanti, non una profezia.** Il modello guarda solo la
serie passata e non sa niente di rotatorie costruite, limiti abbassati o strade
chiuse: dice dove si finirebbe se non cambiasse nulla, che è esattamente
l'informazione utile a decidere di cambiare qualcosa. Su una serie che ha una
svolta — e quasi tutte ce l'hanno — la retta la ignora per costruzione.

## Che cosa circola

::od-query{into="parcoEuro" sql="SELECT unnest(['Euro 0-3','Euro 4','Euro 5','Euro 6']) AS classe, unnest([euro_0+euro_1+euro_2+euro_3, euro_4, euro_5+euro_5b, euro_6+euro_6a+euro_6b+euro_6c+euro_6d+euro_6e]) AS veicoli FROM aci_veicoli_euro WHERE codice_istat = '{#comune}' AND anno = (SELECT max(anno) FROM aci_veicoli_euro)"}

::chart-doughnut{data="parcoEuro" label="classe" value="veicoli" height="280"}

La quota **Euro 0-3** è quella immatricolata prima del 2006, ed è la misura di chi
resta fuori il giorno che una città chiude il centro alle auto più inquinanti.
Attenzione però: il dato è il Pubblico Registro Automobilistico, cioè dove il
veicolo è *registrato* — i grandi noleggiatori iscrivono flotte intere su pochi
indirizzi, e il comune di Trento risulta con più auto di Napoli.

::/page

::page{title="Chi si muove" icon="train"}

# Chi entra e chi esce

::od-query{into="saldoVita" sql="SELECT (SELECT sum(individui) FROM pendolarismo WHERE codice_istat = '{#comune}' AND destinazione = 'altro comune') AS escono, (SELECT sum(individui) FROM pendolarismo WHERE codice_istat_destinazione = '{#comune}' AND destinazione = 'altro comune') AS entrano"}

Ogni giorno **:sum{path="saldoVita" field="escono"}** persone escono da questo
comune e **:sum{path="saldoVita" field="entrano"}** ci arrivano da fuori. Quale
delle due è la più grande dice quasi tutto: un posto dove si viene a lavorare, o
un posto da cui si parte la mattina.

::od-query{into="mezziVita" sql="SELECT mezzo, sum(individui) AS persone FROM pendolarismo_mezzo WHERE codice_istat = '{#comune}' GROUP BY 1 ORDER BY 2 DESC" limit="30"}

::chart-bar{data="mezziVita" x="mezzo" y="persone" horizontal height="340"}

**L'annata è il 2011, e non è una scelta.** La matrice del Censimento 2021 è stata
pubblicata ma il canale con cui si scaricano i dati non la serve. Quindici anni
comprendono la diffusione del lavoro da remoto, quindi questi numeri vanno letti
per la **struttura** dei legami molto più che per le quantità.

::/page

::page{title="La salute" icon="user"}

# La sanità che hai intorno

Quasi tutto quello che il Servizio Sanitario pubblica è per **azienda sanitaria**,
non per comune: le ASL sono centodieci e i comuni settemilaottocentonovantasei.
Ecco la tua, e cosa c'è dentro.

::od-query{into="aslVita" sql="SELECT asl, popolazione_servita FROM sanita_asl_comuni WHERE codice_istat = '{#comune}'"}

::list{path="aslVita"}
### {asl}
::/list

::od-query{into="personaleVita" sql="SELECT anno, ruolo, persone FROM sanita_personale WHERE asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}') ORDER BY anno" limit="40"}

::if-any{path="personaleVita"}
### Chi ci lavora

::chart-bar{data="personaleVita" x="anno" y="persone" height="240"}
::/if-any

::if-empty{path="personaleVita"}
Per questa azienda il Conto Annuale non pubblica il personale: succede per le
aziende ospedaliere e gli IRCCS, che non compaiono nella corrispondenza con i
comuni.
::/if-empty

## Gli ospedali del bacino

::od-query{into="ospedaliVita" sql="SELECT s.struttura, s.comune, s.letti_utilizzati AS letti, s.ricoveri, s.occupazione_pct AS occupazione, s.degenza_media FROM sanita_strutture s JOIN sanita_asl_comuni a USING (codice_istat) WHERE a.asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}') ORDER BY s.letti_utilizzati DESC NULLS LAST" limit="80"}

::if-empty{path="ospedaliVita"}
Nel bacino della tua azienda non risulta nessuna struttura di ricovero: succede a
gran parte dei comuni piccoli, e vuol dire che l'ospedale di riferimento sta in
un'altra azienda.
::/if-empty

::table{path="ospedaliVita" search page-size="8"}
::column{field="struttura" label="Struttura"}
::column{field="comune" label="Comune"}
::column{field="letti" label="Letti" align="end"}
::column{field="occupazione" label="Occupazione %" align="end"}
::column{field="degenza_media" label="Degenza media" align="end"}
::/table

## Come vanno a finire le cure

Tutto quello sopra è una **dotazione** — letti, personale, strutture — e non dice
se le persone guariscono. Questo sì: è il Programma Nazionale Esiti.

::od-query{into="indicatoriVita" sql="SELECT codice_indicatore AS codice, indicatore AS nome FROM pne_esiti WHERE misura = 'mortalità' AND livello = 'struttura' AND valore_aggiustato IS NOT NULL GROUP BY 1,2 HAVING count(*) >= 30 ORDER BY 2" limit="200"}

::choose[esito]{path="indicatoriVita" field="codice" label="nome" legend="Che cosa guardare" value="38"}

::od-query{into="esitiVita" sql="SELECT e.struttura, max(e.casi) FILTER (WHERE e.codice_asl IS NULL) AS casi, round(avg(e.valore_grezzo), 1) AS grezzo, max(e.valore_aggiustato) AS aggiustato FROM pne_esiti e JOIN sanita_asl_comuni a ON a.codice_istat = e.codice_istat WHERE a.asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}') AND e.livello = 'struttura' AND e.codice_indicatore = '{#esito}' GROUP BY 1 HAVING max(e.valore_aggiustato) IS NOT NULL ORDER BY 2 DESC NULLS LAST" limit="80"}

::if-empty{path="esitiVita"}
Per questo indicatore nessuna struttura del bacino ha abbastanza casi perché
AGENAS ne pubblichi il valore. Non è un dato mancante: è il rifiuto di misurare su
numeri troppo piccoli, che è la cosa giusta da fare.
::/if-empty

::table{path="esitiVita" search page-size="8"}
::column{field="struttura" label="Struttura"}
::column{field="casi" label="Casi" align="end"}
::column{field="grezzo" label="Grezzo %" align="end"}
::column{field="aggiustato" label="Aggiustato %" align="end"}
::/table

**La colonna da guardare è l'ultima.** Il valore grezzo mette insieme pazienti che
non sono confrontabili: un centro che prende i casi più gravi ha una mortalità
grezza più alta *proprio perché* fa il suo mestiere. L'aggiustato tiene conto di
quanto erano malati i pazienti arrivati. E prima ancora va guardata la colonna dei
**casi**: un indicatore su venti ricoveri non è confrontabile con niente.

## I servizi di prossimità

::od-query{into="consultoriVita" sql="SELECT struttura, indirizzo, gestione FROM consultori WHERE codice_istat = '{#comune}' ORDER BY 1" limit="200"}

::if-any{path="consultoriVita"}
Nel comune ci sono **:count{path="consultoriVita"}** consultori familiari.

::table{path="consultoriVita" search page-size="6"}
::column{field="struttura" label="Consultorio"}
::column{field="indirizzo" label="Indirizzo"}
::column{field="gestione" label="Gestione"}
::/table
::/if-any

::if-empty{path="consultoriVita"}
In questo comune non risultano consultori familiari: sono 2.164 in tutta Italia e
stanno in 1.563 comuni, quindi la maggior parte dei comuni italiani non ne ha uno
dentro i propri confini.
::/if-empty

## Le macchine che fanno diagnosi

::od-query{into="apparecchiVita" sql="SELECT a.struttura, a.apparecchiatura, a.quante, a.lat, a.lon FROM sanita_apparecchiature a WHERE a.asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}') AND a.lat IS NOT NULL AND abs(a.lat - (SELECT median(lat) FROM sanita_apparecchiature x WHERE x.asl_id = a.asl_id AND x.lat IS NOT NULL)) < 1 ORDER BY a.quante DESC" limit="600"}

::map{path="apparecchiVita" lat="lat" lon="lon" height="420px"}
**{struttura}**
{quante} × {apparecchiatura}
::/map

I tipi sono acronimi: **TAC** è la tomografia, **RMN** la risonanza magnetica,
**MMI** i mammografi, **PET** la tomografia a emissione di positroni. Le
coordinate arrivano dal Ministero e qualcuna è sbagliata alla fonte — quelle
troppo lontane dalle altre della stessa azienda sono escluse, perché un punto in
Sicilia in un elenco di Napoli non è un dettaglio: tira la mappa dall'altra parte
del Paese e nasconde tutti gli altri.

::/page

::page{title="L'ambiente" icon="location"}

# Il territorio, e cosa gli succede

::od-query{into="suoloSerie" sql="SELECT periodo, anni, round(incremento_netto_ha, 1) AS ettari FROM consumo_suolo_serie WHERE codice_istat = '{#comune}' ORDER BY anno_da" limit="40"}

::chart-bar{data="suoloSerie" x="periodo" y="ettari" height="260"}

Quanti ettari di suolo sono stati coperti in ogni periodo. **I periodi non hanno
la stessa lunghezza** — il 2006-2012 sono sei anni, gli altri uno o due — quindi
le barre non si confrontano fra loro come se fossero anni.

Il suolo consumato è irreversibile su tempi umani: una volta che sotto c'è
cemento, quel terreno non assorbe più l'acqua quando piove. È la ragione per cui
questo numero sta accanto alla zona sismica e non fra le statistiche economiche.

## La raccolta differenziata

::od-query{into="rifiutiSerie" sql="SELECT anno, round(percentuale_rd, 1) AS differenziata_pct, round(totale_ru / nullif(popolazione, 0), 1) AS kg_per_abitante FROM rifiuti WHERE codice_istat = '{#comune}' ORDER BY anno" limit="40"}

::if-any{path="rifiutiSerie"}
::chart-line{data="rifiutiSerie" x="anno" y="differenziata_pct" height="250"}

Sopra, la quota di rifiuti differenziati anno per anno. Sotto, quanti chili
produce ogni abitante: sono due domande diverse, e la seconda è quella che si
dimentica sempre — differenziare bene una montagna di rifiuti resta peggio che
produrne meno.

::chart-line{data="rifiutiSerie" x="anno" y="kg_per_abitante" height="230"}
::/if-any

::if-empty{path="rifiutiSerie"}
Per questo comune non risultano dati sulla raccolta differenziata.
::/if-empty

::od-query{into="frazioniRifiuti" sql="SELECT unnest(['Umido','Carta','Vetro','Plastica','Metallo','Indifferenziato']) AS frazione, unnest([round(umido/1000,1), round(carta_cartone/1000,1), round(vetro/1000,1), round(plastica/1000,1), round(metallo/1000,1), round(indifferenziato/1000,1)]) AS tonnellate FROM rifiuti WHERE codice_istat = '{#comune}' AND anno = (SELECT max(anno) FROM rifiuti WHERE codice_istat = '{#comune}')"}

::chart-bar{data="frazioniRifiuti" x="frazione" y="tonnellate" horizontal height="260"}

::/page

::page{title="I confronti" icon="graphic"}

# Il tuo comune fra i suoi vicini

Questa pagina non guarda più il tuo comune da solo: prende tutti i comuni della
tua provincia con sette indicatori a testa e lascia che siano i numeri a dire
qualcosa.

::od-query{into="vicinato" sql="SELECT g.comune, p.popolazione AS abitanti, round(i.incidenti * 10000.0 / nullif(p.popolazione, 0), 2) AS incidenti_per_10mila, round(cs.suolo_consumato_pct, 1) AS suolo_costruito_pct, round(r.reddito_medio, 0) AS reddito, round(av.euro_0_3_pct, 1) AS auto_euro0_3_pct, round(ri.percentuale_rd, 1) AS differenziata_pct, round(f.n * 10000.0 / nullif(p.popolazione, 0), 2) AS farmacie_per_10mila FROM istat_confini_comuni g JOIN istat_popolazione p USING (codice_istat) LEFT JOIN incidenti_stradali i ON i.codice_istat = g.codice_istat AND i.anno = (SELECT max(anno) FROM incidenti_stradali) LEFT JOIN consumo_suolo cs ON cs.codice_istat = g.codice_istat AND cs.anno = (SELECT max(anno) FROM consumo_suolo) LEFT JOIN mef_redditi r ON r.codice_istat = g.codice_istat AND r.anno = (SELECT max(anno) FROM mef_redditi) LEFT JOIN aci_veicoli_euro av ON av.codice_istat = g.codice_istat AND av.anno = (SELECT max(anno) FROM aci_veicoli_euro) LEFT JOIN rifiuti ri ON ri.codice_istat = g.codice_istat AND ri.anno = (SELECT max(anno) FROM rifiuti) LEFT JOIN (SELECT codice_istat, count(*) AS n FROM farmacie GROUP BY 1) f ON f.codice_istat = g.codice_istat WHERE g.sigla = (SELECT sigla FROM istat_confini_comuni WHERE codice_istat = '{#comune}') ORDER BY 2 DESC" limit="700"}

::table{path="vicinato" search page-size="10" sort="abitanti" dir="desc"}
::column{field="comune" label="Comune"}
::column{field="abitanti" label="Abitanti" align="end"}
::column{field="reddito" label="Reddito €" align="end"}
::column{field="incidenti_per_10mila" label="Incidenti ogni 10.000" align="end"}
::column{field="suolo_costruito_pct" label="Suolo costruito %" align="end"}
::column{field="differenziata_pct" label="Differenziata %" align="end"}
::/table

## Che cosa si muove insieme

::ml-correlate{data="vicinato" features="abitanti,reddito,incidenti_per_10mila,suolo_costruito_pct,auto_euro0_3_pct,differenziata_pct,farmacie_per_10mila" into="correlazioni"}

::table{path="correlazioni" sort="r" dir="desc" page-size="12"}
::column{field="a" label="Questo…"}
::column{field="b" label="…con questo"}
::column{field="r" label="Quanto vanno insieme" align="end"}
::/table

Ogni riga è quanto due indicatori si muovono insieme fra i comuni della
provincia: **+1** vuol dire che dove cresce uno cresce l'altro, **-1** che dove
cresce uno cala l'altro, **0** che non c'entrano niente. È una tabella e non un
grafico a barre di proposito: una barra porta una sola etichetta, e qui ogni
valore appartiene a una *coppia*.

**E qui va detta la cosa che rende utile questa pagina invece che pericolosa: due
cose che si muovono insieme non sono una la causa dell'altra.** Dove il reddito è
alto le auto vecchie sono poche — ma non è il reddito a rottamarle: è che chi ha
più soldi cambia auto prima. Dove c'è più suolo costruito ci sono più incidenti —
ma è perché c'è più città, non perché il cemento faccia sbandare. La correlazione
dice *dove guardare*, mai *perché*.

## Chi è fuori dal coro

::ml-anomaly{data="vicinato" features="reddito,incidenti_per_10mila,suolo_costruito_pct,differenziata_pct" contamination="0.1" into="anomalie"}

::table{path="anomalie" search page-size="8" sort="anomalia" dir="desc"}
::column{field="comune" label="Comune"}
::column{field="anomalia" label="Quanto è insolito" align="end"}
::column{field="reddito" label="Reddito €" align="end"}
::column{field="differenziata_pct" label="Differenziata %" align="end"}
::/table

Un comune «insolito» non è un comune messo male: è un comune che non somiglia ai
suoi vicini nella combinazione di questi quattro numeri. Può essere il capoluogo,
grande e diverso per definizione; può essere il paese con l'autostrada che gli
passa accanto; può essere un dato sbagliato alla fonte. **Il modello segnala dove
guardare, e chi guarda decide che cosa ha trovato.**

Questa analisi scarica una libreria di calcolo la prima volta che la si esegue, e
succede nel tuo browser: nessuno di questi numeri esce da qui.

::/page

::page{title="Da dove viene" icon="data"}

# Le fonti, e come leggerle

| Cosa | Fonte |
| --- | --- |
| Popolazione | ISTAT — bilancio demografico |
| Reddito medio | MEF — dichiarazioni dei redditi |
| Incidenti stradali | ISTAT — per comune, 2001-2024 |
| Pendolarismo | ISTAT — Censimento 2011 |
| Parco veicolare | ACI — Autoritratto |
| ASL, ospedali, personale, apparecchiature, consultori | Ministero della Salute — IODL 2.0 |
| Esiti delle cure | AGENAS — Programma Nazionale Esiti |
| Farmacie | Ministero della Salute |
| Suolo consumato | ISPRA |
| Raccolta differenziata | ISPRA — catasto rifiuti |
| Zona sismica | Dipartimento della Protezione Civile |

**Quattro avvertenze che valgono più di qualunque numero di questa app.**

Il **reddito medio** è la media delle dichiarazioni, non di quello che la gente
guadagna: chi non dichiara non c'è, e una media si sposta con pochi redditi molto
alti. Serve a confrontare comuni fra loro, non a dire quanto guadagna il vicino.

Il **tasso di incidenti per abitante** mette al denominatore chi *risiede*, mentre
gli incidenti li fanno anche quelli che passano. Per una città è ragionevole; per
un paese piccolo su una statale è ingeneroso.

I **posti letto per abitante** non sono calcolati, ed è deliberato: un ospedale
non serve il paese in cui sta, serve il **bacino** dell'azienda. Dividere i letti
di un grande ospedale per gli abitanti del comune che lo ospita fa risultare quel
comune fortunatissimo e poverissimi tutti i suoi vicini, che in quell'ospedale ci
vanno.

Le **analisi della pagina dei confronti girano nel tuo browser**, sui dati che ha
già scaricato. Non c'è nessun modello addestrato altrove, nessun dato che parte,
nessuna classifica precalcolata da qualcuno: sono conti fatti davanti a te, e per
questo puoi cambiarne i parametri e vedere che cosa succede.

::/page
