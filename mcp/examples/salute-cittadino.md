---
appId: salute-cittadino
title: "La salute dove vivi"
description: "I dati sanitari pubblici non sono per comune: sono per azienda, e le aziende sono centodieci contro settemilaottocento comuni. Scegli il tuo comune e nove pagine si riempiono da sole — qual è la tua azienda e cosa c'è dentro, chi finisce ricoverato, come vanno a finire le cure, consultori, salute mentale e dipendenze, medici e macchine, quanto si spende, e le cento province una accanto all'altra su mappa. Ventiquattro tabelle da Ministero della Salute, ISTAT, AGENAS e MEF; le analisi girano nel tuo browser."
icon: user
lang: it
version: "3.1"
author: "ReactiveNET"
date: "2026-08-18"
---

::od-query{into="comuniSal" sql="SELECT g.codice_istat AS codice, g.comune || ' (' || g.sigla || ')' AS nome FROM istat_confini_comuni g ORDER BY 2" limit="8000"}

::choose[comune]{path="comuniSal" field="codice" label="nome" legend="Dove vivi" value="063049" help="Tutte le pagine seguono questa scelta."}

::page{title="La mia sanità" icon="user"}

# L'azienda che ti serve, e cosa c'è dentro

Quasi tutto quello che il Servizio Sanitario pubblica è per **azienda sanitaria**,
non per comune: le ASL sono centodieci e i comuni settemilaottocentonovantasei.
Chi cerca «i dati sanitari del mio paese» trova numeri appesi a un'entità di cui
non conosce nemmeno il nome. Questa app comincia da lì.

::od-query{into="miaAzienda" sql="SELECT asl, regione, popolazione_servita FROM sanita_asl_comuni WHERE codice_istat = '{#comune}'"}

::od-query{into="bacinoSal" sql="SELECT count(*) AS comuni, sum(popolazione_servita) AS abitanti FROM sanita_asl_comuni WHERE asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}')"}

::list{path="miaAzienda"}
### {asl}
::/list

Serve **:sum{path="bacinoSal" field="comuni"}** comuni in tutto — questo compreso
— per un bacino di **:sum{path="bacinoSal" field="abitanti"}** abitanti. È il
numero da tenere a mente in tutta l'app: un ospedale non serve il paese in cui
sta, serve il bacino, e dividere i suoi posti letto per gli abitanti del solo
comune che lo ospita dà una cifra lusinghiera e falsa.

## Che cosa hai vicino

::od-query{into="prossimitaSal" sql="SELECT (SELECT count(*) FROM farmacie WHERE codice_istat = '{#comune}') AS farmacie, (SELECT count(*) FROM consultori WHERE codice_istat = '{#comune}') AS consultori, (SELECT count(*) FROM sanita_strutture s JOIN sanita_asl_comuni a USING (codice_istat) WHERE a.asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}')) AS ospedali, (SELECT sum(quante) FROM sanita_apparecchiature WHERE asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}')) AS macchine"}

::columns{min="12rem" gap="m"}

**:sum{path="prossimitaSal" field="farmacie"}** farmacie nel comune

**:sum{path="prossimitaSal" field="consultori"}** consultori nel comune

**:sum{path="prossimitaSal" field="ospedali"}** strutture di ricovero nel bacino

**:sum{path="prossimitaSal" field="macchine"}** grandi apparecchiature

::/columns

I primi due numeri sono **del comune** e gli altri due **del bacino**, ed è una
distinzione che va fatta ogni volta: in farmacia e al consultorio ci si va a
piedi, in ospedale no.

::od-query{into="consultoriSal" sql="SELECT struttura, indirizzo, gestione FROM consultori WHERE codice_istat = '{#comune}' ORDER BY 1" limit="200"}

::if-any{path="consultoriSal"}
::table{path="consultoriSal" search page-size="6"}
::column{field="struttura" label="Consultorio"}
::column{field="indirizzo" label="Indirizzo"}
::column{field="gestione" label="Gestione"}
::/table
::/if-any

::if-empty{path="consultoriSal"}
In questo comune non risultano consultori familiari: in Italia sono 2.164 e
stanno in 1.563 comuni, quindi la maggior parte dei comuni non ne ha uno dentro i
propri confini.
::/if-empty

::/page

::page{title="Chi va in ospedale" icon="graphic"}

# Chi finisce ricoverato, e per che cosa

Questa è la domanda che i posti letto non toccano: la capienza dice quanto si può
accogliere, non chi arriva.

::od-query{into="etaRicoveri" sql="SELECT unnest(['0-5','6-12','13-18','19-24','25-34','35-44','45-54','55-64','65-74','75 e oltre']) AS fascia, unnest([sum(eta_0_5), sum(eta_6_12), sum(eta_13_18), sum(eta_19_24), sum(eta_25_34), sum(eta_35_44), sum(eta_45_54), sum(eta_55_64), sum(eta_65_74), sum(eta_75_oltre)]) AS ricoveri FROM sdo_eta WHERE upper(istituto) IN (SELECT DISTINCT upper(s.struttura) FROM sanita_strutture s JOIN sanita_asl_comuni a USING (codice_istat) WHERE a.asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}'))"}

::if-any{path="etaRicoveri"}
::chart-bar{data="etaRicoveri" x="fascia" y="ricoveri" height="300"}

La forma di questo grafico è quasi sempre la stessa in tutta Italia — una gobba
sotto i sei anni e una montagna dopo i sessantacinque — e le due gobbe hanno
cause opposte: la prima è la nascita, la seconda è la vecchiaia. Quello che
cambia da un territorio all'altro è il rapporto fra le due.
::/if-any

::if-empty{path="etaRicoveri"}
Le dimissioni per età non agganciano nessun ospedale di questo bacino: le SDO
numerano gli istituti in un modo diverso dai file delle strutture, e l'aggancio
qui passa per il nome — che non sempre coincide.
::/if-empty

## Come si esce

::od-query{into="esitoRicoveri" sql="SELECT e.istituto, e.decessi, e.a_domicilio, e.ad_altra_struttura, round(e.ad_altra_struttura * 100.0 / nullif(e.decessi + e.a_domicilio + e.ad_altra_struttura, 0), 1) AS trasferiti_pct FROM sdo_esito e WHERE upper(e.istituto) IN (SELECT DISTINCT upper(s.struttura) FROM sanita_strutture s JOIN sanita_asl_comuni a USING (codice_istat) WHERE a.asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}')) ORDER BY e.a_domicilio DESC NULLS LAST" limit="80"}

::table{path="esitoRicoveri" search page-size="8"}
::column{field="istituto" label="Ospedale"}
::column{field="a_domicilio" label="A casa" align="end"}
::column{field="ad_altra_struttura" label="Ad altra struttura" align="end"}
::column{field="trasferiti_pct" label="Trasferiti %" align="end"}
::/table

**Il rapporto fra decessi e dimissioni non è la mortalità di un ospedale**, e non
va calcolato come se lo fosse: un hospice, una lungodegenza e un pronto soccorso
di città trattano pazienti incomparabili, e un reparto che accoglie i casi
terminali avrà sempre la quota più alta *proprio perché* fa quel mestiere. Il
numero confrontabile — aggiustato per quanto erano malati i pazienti — sta nella
pagina degli esiti.

Quello che questa tabella dice bene è un'altra cosa: la quota **trasferita ad
altra struttura**, che misura quanto un ospedale sia un passaggio invece che una
destinazione.

## I traumi

::od-query{into="traumiSal" sql="SELECT anno, ricoveri, trauma_1, trauma_2, trauma_3, trauma_4 FROM sdo_traumi WHERE asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}') ORDER BY anno"}

::if-any{path="traumiSal"}
Nell'anno rilevato l'azienda ha avuto **:sum{path="traumiSal" field="ricoveri"}**
ricoveri per trauma.

Le celle vuote non sono zeri: nella fonte sono `***`, il marcatore con cui il
Ministero oscura i numeri troppo piccoli per non identificare le persone.
::/if-any

::/page

::page{title="Come vanno le cure" icon="alert"}

# L'unica misura di esito che esiste

Tutto il resto di questa app descrive una **dotazione** — letti, personale,
macchine, servizi — e nessuna di quelle cose dice se le persone guariscono.
Questa pagina sì.

::od-query{into="indicatoriSal" sql="SELECT codice_indicatore AS codice, indicatore AS nome FROM pne_esiti WHERE misura = 'mortalità' AND livello = 'struttura' AND valore_aggiustato IS NOT NULL GROUP BY 1,2 HAVING count(*) >= 30 ORDER BY 2" limit="200"}

::choose[esito]{path="indicatoriSal" field="codice" label="nome" legend="Che cosa guardare" value="38"}

::od-query{into="esitiSal" sql="SELECT e.struttura, max(e.casi) FILTER (WHERE e.codice_asl IS NULL) AS casi, round(avg(e.valore_grezzo), 1) AS grezzo, max(e.valore_aggiustato) AS aggiustato FROM pne_esiti e JOIN sanita_asl_comuni a ON a.codice_istat = e.codice_istat WHERE a.asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}') AND e.livello = 'struttura' AND e.codice_indicatore = '{#esito}' GROUP BY 1 HAVING max(e.valore_aggiustato) IS NOT NULL ORDER BY 2 DESC NULLS LAST" limit="80"}

::if-empty{path="esitiSal"}
Per questo indicatore nessuna struttura del bacino ha abbastanza casi perché
AGENAS ne pubblichi il valore. Non è un dato mancante: è il rifiuto di misurare su
numeri troppo piccoli, che è la cosa giusta da fare.
::/if-empty

::table{path="esitiSal" search page-size="10"}
::column{field="struttura" label="Struttura"}
::column{field="casi" label="Casi" align="end"}
::column{field="grezzo" label="Grezzo %" align="end"}
::column{field="aggiustato" label="Aggiustato %" align="end"}
::/table

**La colonna da guardare è l'ultima, e le due non vanno confuse.** Il valore
grezzo mette insieme pazienti che non sono confrontabili: un centro che prende i
casi più gravi ha una mortalità grezza più alta *proprio perché* fa il suo
mestiere. L'aggiustato tiene conto di quanto erano malati i pazienti arrivati, ed
è quello che AGENAS pubblica per il confronto. Capita spesso che l'aggiustato sia
**più alto** del grezzo, e vuol dire il contrario di quello che sembra.

E prima ancora va guardata la colonna dei **casi**: un indicatore su venti
ricoveri non è confrontabile con niente, e le righe che qui non compaiono sono
quelle, non ospedali che hanno qualcosa da nascondere.

::/page

::page{title="Mente e dipendenze" icon="user"}

# I servizi di cui si parla di più e si trovano meno numeri

::od-query{into="mentaleSal" sql="SELECT classe_eta, sum(accessi) AS persone FROM salute_mentale WHERE asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}') AND anno = (SELECT max(anno) FROM salute_mentale) GROUP BY 1 ORDER BY 1" limit="40"}

::if-any{path="mentaleSal"}
### Salute mentale, per età

::chart-bar{data="mentaleSal" x="classe_eta" y="persone" height="280"}

Sono le persone trattate dai Dipartimenti di Salute Mentale, non le visite. **Un
numero alto non è un cattivo segno**: dice che il servizio intercetta le persone,
e la lettura opposta — poche persone trattate uguale poco disagio — è quasi sempre
sbagliata.
::/if-any

::od-query{into="mentaleSerie" sql="SELECT anno, sum(accessi) AS persone FROM salute_mentale WHERE asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}') GROUP BY 1 ORDER BY 1"}

::if-any{path="mentaleSerie"}
::chart-line{data="mentaleSerie" x="anno" y="persone" height="230"}
::/if-any

## Le dipendenze

::od-query{into="dipendenzeSal" sql="SELECT sostanza, sum(utenti) AS utenti FROM dipendenze WHERE asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}') AND anno = (SELECT max(anno) FROM dipendenze) GROUP BY 1 HAVING sum(utenti) IS NOT NULL ORDER BY 2 DESC" limit="40"}

::if-any{path="dipendenzeSal"}
::chart-bar{data="dipendenzeSal" x="sostanza" y="utenti" horizontal height="280"}

Le persone in carico ai SerD per sostanza d'abuso primaria. **Le sostanze che non
compaiono non valgono zero**: nella fonte sono celle oscurate, perché il numero
era troppo piccolo per pubblicarlo senza rischiare di identificare qualcuno.
Leggerle come «nessun utente» è falso, ed è il motivo per cui qui sono escluse
invece che disegnate a zero.
::/if-any

::if-empty{path="dipendenzeSal"}
Per questa azienda non risultano dati sui servizi per le dipendenze nell'ultimo
anno pubblicato.
::/if-empty

## Chi arriva per la prima volta

::od-query{into="primoContatto" sql="SELECT classe_eta, sum(nuovi_utenti) AS persone FROM dsm_primo_eta WHERE asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}') AND anno = (SELECT max(anno) FROM dsm_primo_eta) GROUP BY 1 HAVING sum(nuovi_utenti) IS NOT NULL ORDER BY 1" limit="40"}

::if-any{path="primoContatto"}
::chart-bar{data="primoContatto" x="classe_eta" y="persone" height="260"}

Sono le persone che nell'anno hanno avuto il **primo** contatto con il servizio,
per fascia d'età. È il numero che dice se un servizio sta intercettando i giovani
o se li vede arrivare tardi.
::/if-any

## Per quale diagnosi

::od-query{into="diagnosiSal" sql="SELECT gruppo, sum(accessi) AS persone FROM dsm_prevalenza WHERE asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}') AND anno = (SELECT max(anno) FROM dsm_prevalenza) GROUP BY 1 HAVING sum(accessi) IS NOT NULL ORDER BY 2 DESC" limit="40"}

::if-any{path="diagnosiSal"}
::chart-bar{data="diagnosiSal" x="gruppo" y="persone" horizontal height="340"}

I gruppi diagnostici delle persone in carico. È la fotografia della **domanda che
arriva al servizio**, non della diffusione dei disturbi nella popolazione: chi non
si è mai rivolto al Dipartimento non è in questi numeri, e in questo scarto sta
quasi tutto quello che le statistiche sulla salute mentale non riescono a dire.
::/if-any

## I servizi per le dipendenze nel tempo

::od-query{into="serdSerie" sql="SELECT anno, sum(nuovi) AS nuovi_utenti, sum(totale) AS in_carico FROM serd_trattamento WHERE asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}') GROUP BY 1 ORDER BY 1" limit="40"}

::if-any{path="serdSerie"}
::chart-line{data="serdSerie" x="anno" y="in_carico,nuovi_utenti" height="260"}

Due linee che vanno lette insieme: quante persone sono **in carico** e quante
sono **nuove**. Se la prima resta alta mentre la seconda scende, il servizio sta
seguendo le stesse persone più a lungo — che può essere una presa in carico
migliore o un'uscita che non arriva.
::/if-any

::/page

::page{title="Con che cosa" icon="data"}

# Le persone e le macchine

::od-query{into="personaleSal" sql="SELECT anno, ruolo, persone FROM sanita_personale WHERE asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}') ORDER BY anno" limit="40"}

::if-any{path="personaleSal"}
::chart-bar{data="personaleSal" x="anno" y="persone" height="250"}

Medici e infermieri dipendenti a tempo indeterminato dell'azienda, anno per anno.
::/if-any

::if-empty{path="personaleSal"}
Per questa azienda il Conto Annuale non pubblica il personale: succede alle
aziende ospedaliere e agli IRCCS, che non compaiono nella corrispondenza fra
aziende e comuni.
::/if-empty

## Dove sono le macchine

::od-query{into="macchineSal" sql="SELECT a.struttura, a.apparecchiatura, a.quante, a.lat, a.lon FROM sanita_apparecchiature a WHERE a.asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}') AND a.lat IS NOT NULL AND abs(a.lat - (SELECT median(lat) FROM sanita_apparecchiature x WHERE x.asl_id = a.asl_id AND x.lat IS NOT NULL)) < 1 ORDER BY a.quante DESC" limit="600"}

::map{path="macchineSal" lat="lat" lon="lon" height="420px"}
**{struttura}**
{quante} × {apparecchiatura}
::/map

Gli acronimi: **TAC** è la tomografia computerizzata, **RMN** la risonanza
magnetica, **MMI** i mammografi, **PET** la tomografia a emissione di positroni.
Sono le macchine che decidono se un esame si fa qui o ci si sposta, ed è per
questo che vale la pena vederle su una mappa invece che in una tabella.

Le coordinate arrivano dal Ministero e diciassette strutture in tutta Italia ne
hanno una sbagliata: quelle troppo lontane dalle altre della stessa azienda sono
escluse, perché un punto dall'altra parte del Paese tira la mappa con sé e
nasconde tutti gli altri.

## I posti letto, per disciplina

::od-query{into="disciplineSal" sql="SELECT disciplina, sum(letti_ordinari) AS letti FROM letti_stabilimento WHERE asl_id = (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}') AND anno = (SELECT max(anno) FROM letti_stabilimento) GROUP BY 1 HAVING sum(letti_ordinari) > 0 ORDER BY 2 DESC" limit="60"}

::if-any{path="disciplineSal"}
::chart-bar{data="disciplineSal" x="disciplina" y="letti" horizontal height="380"}

Quali reparti ci sono davvero, e quanto sono grandi. È la risposta che manca a
chiunque abbia bisogno di sapere se una specialità esiste nel proprio territorio
o se bisogna spostarsi.
::/if-any

## Chi lavora nei servizi territoriali

::od-query{into="personaleTerr" sql="WITH a AS (SELECT asl_id FROM sanita_asl_comuni WHERE codice_istat = '{#comune}'), m AS (SELECT anno, sum(dipendenti) AS persone FROM dsm_personale WHERE asl_id = (SELECT asl_id FROM a) GROUP BY 1), d AS (SELECT anno, sum(dipendenti) AS persone FROM serd_personale WHERE asl_id = (SELECT asl_id FROM a) GROUP BY 1) SELECT coalesce(m.anno, d.anno) AS anno, m.persone AS salute_mentale, d.persone AS dipendenze FROM m FULL OUTER JOIN d ON m.anno = d.anno ORDER BY 1" limit="60"}

::if-any{path="personaleTerr"}
::table{path="personaleTerr" search page-size="8" sort="anno" dir="desc"}
::column{field="anno" label="Anno" align="end"}
::column{field="salute_mentale" label="Salute mentale" align="end"}
::column{field="dipendenze" label="Dipendenze" align="end"}
::/table
::/if-any

Sono i dipendenti dei Dipartimenti di Salute Mentale e dei SerD: le due strutture
che questa app segue anno per anno, e le sole di cui il Ministero pubblichi
l'organico separatamente dal resto dell'azienda.

::/page

::page{title="Quanto costa" icon="card"}

# I soldi dell'azienda che ti cura

::od-query{into="spesaVoci" sql="SELECT categoria, round(sum(importo) / 1e6, 1) AS milioni FROM sanita_spesa WHERE movimento = 'spesa' AND tipologia = 'AS' AND codice_istat_sede = '{#comune}' AND mese = 12 AND anno = (SELECT max(anno) FROM sanita_spesa WHERE mese = 12) AND titolo NOT IN ('7','0') GROUP BY 1 ORDER BY 2 DESC" limit="15"}

::if-any{path="spesaVoci"}
::chart-bar{data="spesaVoci" x="categoria" y="milioni" horizontal height="380"}

Le voci di spesa per cassa dell'azienda con sede in questo comune, in milioni di
euro, nell'ultimo anno chiuso. Sono **pagamenti**, non impegni: quello che è
uscito davvero dalla cassa.
::/if-any

::if-empty{path="spesaVoci"}
In questo comune non ha sede nessuna azienda sanitaria: la spesa si vede scegliendo
il comune dove l'azienda ha la propria sede legale, che per la maggior parte dei
territori è il capoluogo.
::/if-empty

::od-query{into="spesaSerie" sql="SELECT anno, round(sum(importo) / 1e6, 1) AS milioni FROM sanita_spesa WHERE movimento = 'spesa' AND tipologia = 'AS' AND codice_istat_sede = '{#comune}' AND mese = 12 AND titolo NOT IN ('7','0') GROUP BY 1 ORDER BY 1"}

::if-any{path="spesaSerie"}
::chart-line{data="spesaSerie" x="anno" y="milioni" height="240"}

Solo gli anni **chiusi**: l'anno in corso è parziale e confrontarlo con gli altri
farebbe sembrare un crollo quello che è solo un calendario a metà.
::/if-any

::/page

::page{title="I confronti" icon="graphic"}

# Le aziende confrontabili, una accanto all'altra

Questa pagina smette di guardare un territorio solo: prende le aziende sanitarie
italiane per cui esistono gli stessi indicatori e lascia che siano i numeri a
dire qualcosa.

Sono **centocinque delle centodieci**. Le cinque che mancano non hanno il
personale nel Conto Annuale o non dichiarano posti letto, e una riga con due
colonne vuote in un confronto non è un confronto in più: è un'azienda che sembra
sguarnita perché di lei non è stato pubblicato niente.

::od-query{into="aziende" sql="WITH bacino AS (SELECT asl_id, max(asl) AS asl, max(regione) AS regione, sum(popolazione_servita) AS abitanti FROM sanita_asl_comuni GROUP BY 1), staff AS (SELECT asl_id, sum(persone) FILTER (WHERE ruolo ILIKE '%MEDIC%') AS medici, sum(persone) FILTER (WHERE ruolo ILIKE '%INFERM%') AS infermieri FROM sanita_personale WHERE anno = (SELECT max(anno) FROM sanita_personale) GROUP BY 1), strutture AS (SELECT a.asl_id, sum(s.letti_utilizzati) AS letti, round(avg(s.occupazione_pct), 1) AS occupazione FROM sanita_strutture s JOIN sanita_asl_comuni a USING (codice_istat) GROUP BY 1), macchine AS (SELECT asl_id, sum(quante) AS apparecchiature FROM sanita_apparecchiature GROUP BY 1) SELECT b.asl, b.regione, b.abitanti, round(st.medici * 10000.0 / nullif(b.abitanti, 0), 1) AS medici_per_10mila, round(st.infermieri * 10000.0 / nullif(b.abitanti, 0), 1) AS infermieri_per_10mila, round(sr.letti * 10000.0 / nullif(b.abitanti, 0), 1) AS letti_per_10mila, sr.occupazione AS occupazione_letti_pct, round(m.apparecchiature * 100000.0 / nullif(b.abitanti, 0), 1) AS macchine_per_100mila FROM bacino b LEFT JOIN staff st USING (asl_id) LEFT JOIN strutture sr USING (asl_id) LEFT JOIN macchine m USING (asl_id) WHERE st.medici IS NOT NULL AND sr.letti IS NOT NULL ORDER BY 3 DESC" limit="300"}

::table{path="aziende" search page-size="10" filters="regione" sort="abitanti" dir="desc"}
::column{field="asl" label="Azienda"}
::column{field="abitanti" label="Abitanti" align="end"}
::column{field="medici_per_10mila" label="Medici / 10.000" align="end"}
::column{field="infermieri_per_10mila" label="Infermieri / 10.000" align="end"}
::column{field="letti_per_10mila" label="Letti / 10.000" align="end"}
::column{field="occupazione_letti_pct" label="Occupazione %" align="end"}
::/table

## Che cosa si muove insieme

::ml-correlate{data="aziende" features="abitanti,medici_per_10mila,infermieri_per_10mila,letti_per_10mila,occupazione_letti_pct,macchine_per_100mila" into="correlazioniSan"}

::table{path="correlazioniSan" sort="r" dir="desc" page-size="12"}
::column{field="a" label="Questo…"}
::column{field="b" label="…con questo"}
::column{field="r" label="Quanto vanno insieme" align="end"}
::/table

**+1** vuol dire che dove cresce uno cresce l'altro, **-1** il contrario, **0**
che non c'entrano niente. E due cose che si muovono insieme non sono una la causa
dell'altra: dove ci sono più letti c'è più personale, ma nessuno dei due assume
l'altro — è la dimensione dell'azienda a muovere entrambi.

## Chi è fuori dal coro

::ml-anomaly{data="aziende" features="medici_per_10mila,infermieri_per_10mila,letti_per_10mila,macchine_per_100mila" contamination="0.12" into="anomalieSan"}

::table{path="anomalieSan" search page-size="10" sort="anomalia" dir="desc"}
::column{field="asl" label="Azienda"}
::column{field="regione" label="Regione"}
::column{field="anomalia" label="Quanto è insolita" align="end"}
::column{field="medici_per_10mila" label="Medici / 10.000" align="end"}
::column{field="letti_per_10mila" label="Letti / 10.000" align="end"}
::/table

**Questa tabella è anche una lezione su come si legge un modello, e le due cose
che trova sono tutt'e due false allarmi — di due tipi diversi.**

In cima escono le **ASL romane**: Roma 3 con 203 letti ogni diecimila abitanti,
Roma 1 con 121, contro una trentina delle altre. Nessuna di quelle aziende ha sei
volte i letti delle altre: Roma è divisa fra più ASL, ma i suoi grandi ospedali
servono la città intera e mezza regione, mentre al denominatore c'è solo la fetta
di popolazione assegnata a quell'azienda. È lo **stesso errore che la prima pagina
avverte di non fare sul comune**, che ricompare identico un livello più su.

Poco sotto arrivano le **ATS lombarde**, con meno di un medico ogni diecimila
abitanti: là il numero è basso invece che alto, e la causa è un'altra ancora —
in Lombardia l'ATS compra le prestazioni e il personale sta nelle ASST, che sono
aziende separate. Il modello ha trovato una **differenza di organizzazione**, non
una carenza di medici.

È esattamente per questo che una classifica automatica delle aziende sanitarie non
è in questa app e non ci sarà. Il modello dice dove guardare; chi guarda deve
sapere che cosa sta guardando — e in tutti e due i casi qui sopra quello che c'è
da guardare è il **denominatore**, non la sanità.

## Raggruppare invece di classificare

::slider[gruppi]{min="2" max="8" step="1" value="4" label="Quanti gruppi"}

::ml-cluster{data="aziende" features="abitanti,medici_per_10mila,letti_per_10mila,occupazione_letti_pct" k="#gruppi" into="gruppiSan"}

::table{path="gruppiSan" search page-size="10" sort="cluster"}
::column{field="asl" label="Azienda"}
::column{field="regione" label="Regione"}
::column{field="cluster" label="Gruppo" align="end"}
::column{field="abitanti" label="Abitanti" align="end"}
::column{field="letti_per_10mila" label="Letti / 10.000" align="end"}
::/table

Il raggruppamento non mette nessuno sopra o sotto: dice quali aziende si
somigliano. È il modo giusto di confrontare cose che una classifica
maltratterebbe, perché un'azienda che serve tre milioni di persone e una che ne
serve centomila non sono la stessa cosa fatta meglio o peggio — sono due cose
diverse.

Tutte e tre le analisi girano **nel tuo browser**, sui dati che ha già scaricato:
nessun modello addestrato altrove, nessun numero che parte da qui.

::/page

::page{title="L'Italia a confronto" icon="globe"}

# Dove si vive più a lungo, e di quanto

Le pagine precedenti guardano un territorio. Questa guarda **tutte le cento
province insieme**, con le due misure che riassumono la salute di una popolazione
meglio di qualunque altra: quanto si vive, e quanto si muore a parità di età.

::od-query{into="provinceSalute" sql="WITH ult AS (SELECT max(periodo) p FROM istat_mortalita_causa), mort AS (SELECT ref_area, valore FROM istat_mortalita_causa, ult WHERE tipo_dato = 'STMRATE' AND periodo = ult.p), vita AS (SELECT ref_area, valore FROM istat_speranza_vita WHERE tipo_dato = 'LIFEXP' AND AGE = 'Y_UN4' AND SEX = '9' AND coalesce(OBS_STATUS, '') <> 'e' AND periodo = (SELECT max(periodo) FROM istat_speranza_vita WHERE tipo_dato = 'LIFEXP' AND coalesce(OBS_STATUS, '') <> 'e')), inf AS (SELECT ref_area, valore FROM istat_mortalita_infantile WHERE tipo_dato = 'INFMRATE' AND periodo = (SELECT max(periodo) FROM istat_mortalita_infantile WHERE tipo_dato = 'INFMRATE')), letti AS (SELECT g.provincia, sum(l.letti_ordinari) AS letti FROM letti_stabilimento l JOIN istat_confini_comuni g ON g.codice_istat = l.codice_istat WHERE l.anno = (SELECT max(anno) FROM letti_stabilimento) GROUP BY 1), pop AS (SELECT provincia, sum(popolazione) AS ab FROM istat_popolazione JOIN istat_confini_comuni USING (codice_istat) GROUP BY 1) SELECT a.nome AS provincia, a.sigla, round(m.valore, 1) AS mortalita_standardizzata, round(v.valore, 1) AS speranza_vita, round(i.valore, 1) AS mortalita_infantile, round(l.letti * 10000.0 / nullif(pop.ab, 0), 1) AS letti_per_10mila, a.geojson FROM istat_aree a JOIN mort m ON m.ref_area = a.codice LEFT JOIN vita v ON v.ref_area = a.codice LEFT JOIN inf i ON i.ref_area = a.codice LEFT JOIN pop ON pop.provincia = a.nome LEFT JOIN letti l ON l.provincia = a.nome WHERE a.livello = 'provincia' ORDER BY 3 DESC" limit="200"}

## La mortalità, a parità di età

A sinistra la **mortalità standardizzata**: più scuro, si muore di più. A destra
la **speranza di vita alla nascita**: più scuro, si vive di più. Sono la stessa
Italia guardata dai due lati, e le due mappe sono quasi l'una il negativo
dell'altra — il che è il primo modo per accorgersi che nessuna delle due sta
misurando un caso.

::columns{min="20rem" gap="m"}
::map{path="provinceSalute" geojson="geojson" fill="mortalita_standardizzata" height="560px"}
**{provincia}**
Mortalità standardizzata {mortalita_standardizzata} · speranza di vita {speranza_vita} anni
::/map
::map{path="provinceSalute" geojson="geojson" fill="speranza_vita" height="560px"}
**{provincia}**
{speranza_vita} anni di speranza di vita alla nascita
::/map
::/columns

Il colore è il **tasso standardizzato**, e la parola conta più del numero: una
provincia con molti anziani ha più morti di una giovane senza che nessuno stia
peggio, e il tasso grezzo direbbe esattamente quello. La standardizzazione toglie
di mezzo la differenza d'età e lascia quello che resta — che è la domanda vera.

La mappa che ne esce non è un caso: le province in cima sono **Caserta e Napoli**,
seguite dalla Sicilia orientale. Non è una scoperta di questa app, è una delle
cose meglio documentate della sanità italiana; quello che l'app aggiunge è che la
si vede accanto a tutto il resto, invece che in un rapporto a parte.

## Quanto si vive

**Fra la provincia dove si vive di più e quella dove si vive di meno ci sono tre
anni e mezzo.** Treviso è a 85,0, Caserta a 81,5. È il divario che il numero
nazionale — 83,5 anni per l'Italia nel 2024 — nasconde per costruzione, perché
una media nasconde sempre le sue code.

Il dato è quello **definitivo**, non l'ultimo pubblicato: ISTAT diffonde anche
l'anno in corso, marcandolo come stima, e una stima disegnata su una mappa è
indistinguibile da una misura. La query le esclude, e per questo l'anno qui è
uno indietro rispetto a quello che si trova sul sito dell'istituto.

::table{path="provinceSalute" search page-size="10" sort="speranza_vita" dir="desc"}
::column{field="provincia" label="Provincia"}
::column{field="speranza_vita" label="Speranza di vita" align="end"}
::column{field="mortalita_standardizzata" label="Mortalità std." align="end"}
::column{field="mortalita_infantile" label="Mortalità infantile" align="end"}
::column{field="letti_per_10mila" label="Letti / 10.000" align="end"}
::/table

## Che cosa si muove insieme

::ml-correlate{data="provinceSalute" features="mortalita_standardizzata,speranza_vita,mortalita_infantile,letti_per_10mila" into="corrProvince"}

::table{path="corrProvince" sort="r" dir="desc" page-size="8"}
::column{field="a" label="Questo…"}
::column{field="b" label="…con questo"}
::column{field="r" label="Quanto vanno insieme" align="end"}
::/table

**Qui il modello dice una cosa che vale la pena leggere due volte.** Mortalità e
speranza di vita si muovono in direzioni opposte con forza — ed è ovvio, sono due
modi di misurare la stessa cosa. Ma i **posti letto** non si muovono quasi con
nessuna delle due: dove ci sono più letti non si vive più a lungo.

Non vuol dire che gli ospedali non servano. Vuol dire che la salute di una
popolazione si decide molto prima dell'ospedale — nel reddito, nel lavoro,
nell'istruzione, nell'aria — e che contare i letti misura la *risposta* alla
malattia, non la sua *assenza*. È il motivo per cui questa app tiene separate le
dotazioni dagli esiti, e non fa una classifica che le mescoli.

## Le province fuori dal coro

::ml-anomaly{data="provinceSalute" features="mortalita_standardizzata,speranza_vita,mortalita_infantile,letti_per_10mila" contamination="0.1" into="anomalieProvince"}

::table{path="anomalieProvince" search page-size="10" sort="anomalia" dir="desc"}
::column{field="provincia" label="Provincia"}
::column{field="anomalia" label="Quanto è insolita" align="end"}
::column{field="speranza_vita" label="Speranza di vita" align="end"}
::column{field="mortalita_infantile" label="Mortalità infantile" align="end"}
::column{field="letti_per_10mila" label="Letti / 10.000" align="end"}
::/table

Una provincia «insolita» qui può esserlo in due modi opposti, e la tabella non li
distingue: può stare male su tutto, oppure avere una combinazione strana — molti
letti e vita corta, o pochi letti e vita lunga. **Chi guarda deve aprire la riga
e vedere quale dei due**, perché il modello misura la distanza dagli altri e non
sa in che direzione.

La **mortalità infantile** è la colonna da trattare con più cautela: è un numero
piccolo su denominatori piccoli, e in una provincia con poche nascite basta un
caso in più per farla saltare in cima. Non è rumore da ignorare — è un segnale
che va letto sapendo quanti bambini ci sono sotto.

::/page

::page{title="Da dove viene" icon="data"}

# Le fonti, e le cinque cose da sapere

| Cosa | Fonte |
| --- | --- |
| Quale azienda serve ogni comune | Ministero della Salute — IODL 2.0 |
| Ospedali, posti letto, ricoveri, degenza | Ministero della Salute |
| Medici e infermieri per azienda | Ministero della Salute — Conto Annuale |
| Apparecchiature, con le coordinate | Ministero della Salute |
| Consultori familiari | Ministero della Salute |
| Salute mentale e dipendenze (undici tabelle) | Ministero della Salute |
| Posti letto per disciplina e stabilimento | Ministero della Salute |
| Dimissioni ospedaliere (SDO) | Ministero della Salute |
| Esiti delle cure | AGENAS — Programma Nazionale Esiti |
| Farmacie | Ministero della Salute |
| Spesa delle aziende | MEF — flussi SIOPE |
| Mortalità standardizzata e speranza di vita per provincia | ISTAT (SDMX) |
| Mortalità infantile per provincia | ISTAT (SDMX) |

**Uno.** I **posti letto per abitante** vanno calcolati sul bacino dell'azienda e
mai sul comune: un ospedale non serve il paese in cui sta.

**Due.** Il rapporto fra **decessi e dimissioni non è la mortalità** di un
ospedale. L'unico numero confrontabile è quello aggiustato per il rischio, nella
pagina degli esiti.

**Tre.** Le **celle vuote non sono zeri**. Nelle dimissioni, nelle dipendenze e
nei traumi il Ministero oscura i numeri troppo piccoli per non identificare le
persone: qui restano vuoti, e leggerli come «nessun caso» è falso.

**Quattro.** Il rapporto fra **medici e abitanti non è confrontabile fra regioni**
che organizzano il servizio in modo diverso — la Lombardia separa chi compra le
prestazioni da chi le eroga, e ne esce un numero che sembra una catastrofe e non
lo è.

**Cinque.** Un servizio molto usato **non è un servizio che va male**. Per la
salute mentale e le dipendenze vale il contrario di quello che l'istinto
suggerisce: molte persone in carico vuol dire che il servizio le intercetta.
::/page
