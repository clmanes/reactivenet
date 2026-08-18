---
appId: scuola-in-cifre
title: La scuola in cifre
description: "Dashboard sulla scuola italiana per dirigenti e docenti: iscrizioni con previsione, dispersione, risultati INVALSI, edifici, organico, dove abitano i bambini e dove sono le scuole, il PNRR del comune e i ragazzi che escono per studiare. Dati ufficiali MIUR, INVALSI, ISTAT, ANNCSU e ReGiS."
icon: education
lang: it
version: "4.1"
author: Reactive
date: "2026-08-17"
---

# La scuola in cifre

Nove fonti ufficiali, per chi la scuola la dirige o ci insegna: quanti alunni
avrai (non solo quanti ne hai), dove si disperde il percorso, come vanno le
prove, in che edifici si studia e con che organico — e poi dove abitano
davvero i bambini, dove stanno le scuole sulla mappa, quanto PNRR arriva nel
tuo comune e quanti ragazzi ogni mattina vanno a studiare altrove. I dati si
incrociano da soli tramite il codice ISTAT del comune. Nessun dato tuo lascia
il dispositivo.

::page{title="Il mio comune" icon="location"}
## Il quadro del tuo territorio

Scegli il comune dalla tendina: la scheda si aggiorna da sola. L'elenco
contiene i 6.633 comuni che hanno almeno una scuola statale — gli altri
darebbero una pagina vuota, e non vengono offerti.

::od-query{into="comuniConScuole" sql="SELECT DISTINCT s.codice_istat AS codice, g.comune || ' (' || g.sigla || ')' AS nome FROM scuole s JOIN istat_confini_comuni g USING (codice_istat) ORDER BY 2" limit="7000"}

::choose[comune]{path="comuniConScuole" field="codice" label="nome" legend="Comune" value="037006"}

::od-query{into="kpiAlunni" sql="SELECT a.alunni AS alunni, round(100.0*(a.alunni-b.alunni)/b.alunni,1) AS variazione FROM (SELECT sum(alunni) AS alunni FROM iscrizioni_scolastiche WHERE codice_istat = '{#comune}' AND anno_scolastico=(SELECT max(anno_scolastico) FROM iscrizioni_scolastiche)) a, (SELECT sum(alunni) AS alunni FROM iscrizioni_scolastiche WHERE codice_istat = '{#comune}' AND anno_scolastico=(SELECT min(anno_scolastico) FROM iscrizioni_scolastiche)) b"}

::od-query{into="kpiScuole" sql="SELECT (SELECT count(*) FROM scuole WHERE codice_istat = '{#comune}') AS scuole, (SELECT count(*) FROM edilizia_scolastica WHERE codice_istat = '{#comune}') AS edifici"}

::od-query{into="kpiEdilizia" sql="SELECT round(avg(anno_costruzione)) AS anno_medio, count(*) FILTER (WHERE classificazione_sismica<=2) AS sismica_alta FROM edilizia_scolastica WHERE codice_istat = '{#comune}' AND (anno_costruzione IS NULL OR anno_costruzione BETWEEN 1500 AND 2026)"}

::columns{min="16rem" gap="m"}
::cards{path="kpiAlunni"}
**{alunni}** alunni oggi — variazione in dieci anni **{variazione}%**
::/cards

::cards{path="kpiScuole"}
**{scuole}** scuole statali in **{edifici}** edifici censiti
::/cards

::cards{path="kpiEdilizia"}
Anno medio di costruzione **{anno_medio}** — **{sismica_alta}** edifici in zona sismica 1-2
::/cards
::/columns

## Quanti alunni avrai: la previsione

Il dato che serve per programmare organico e classi: il trend delle
iscrizioni prolungato in avanti. Scegli orizzonte e modello: la tendenza
lineare gira subito, mentre ARIMA e Holt-Winters hanno bisogno del motore
statistico e la prima volta che li scegli aspettano dietro il bottone Esegui —
poi restano in cache e il grafico si rifà da sé. La riga di stato dice quale
modello ha girato davvero e quanto bene segue la storia (l'R²): un modello che
la segue peggio della retta non è il modello giusto per questa serie.

::od-query{into="trendIscrizioni" sql="SELECT substr(anno_scolastico,1,4)::INTEGER AS anno, sum(alunni)::BIGINT AS alunni FROM iscrizioni_scolastiche WHERE codice_istat = '{#comune}' GROUP BY 1 ORDER BY 1"}

::slider[anniPrev]{label="Anni di previsione" min="1" max="5" step="1" value="3"}

::picker[algoPrev]{label="Modello di previsione" value="linear"}
::menu-item{value="linear"}
Trend lineare
::/menu-item
::menu-item{value="sarima"}
ARIMA/SARIMA
::/menu-item
::menu-item{value="holt-winters"}
Holt-Winters (ETS)
::/menu-item
::/picker

::ml-forecast{data="trendIscrizioni" x="anno" y="alunni" horizon="#anniPrev" model="#algoPrev" into="trendPrev"}

::chart-line{data="trendPrev" x="anno" y="alunni,previsione" height="16rem"}

::od-query{into="gradoComune" sql="SELECT grado AS grado, sum(alunni)::BIGINT AS alunni FROM iscrizioni_scolastiche WHERE codice_istat = '{#comune}' AND anno_scolastico=(SELECT max(anno_scolastico) FROM iscrizioni_scolastiche) GROUP BY grado ORDER BY grado"}

::table{path="gradoComune"}
::column{field="grado" label="Grado"}
::column{field="alunni" label="Alunni (ultimo anno)" align="end"}
::/table

## Gli edifici, per epoca di costruzione

::od-query{into="periodiComune" sql="SELECT periodo_costruzione AS periodo, count(*) AS edifici FROM edilizia_scolastica WHERE codice_istat = '{#comune}' AND periodo_costruzione IS NOT NULL GROUP BY 1 ORDER BY min(coalesce(anno_costruzione,2100))" limit="15"}

::chart-bar{data="periodiComune" x="periodo" y="edifici" height="16rem"}

## Dove sono le scuole, e dove sono i bambini

Due strati sulla stessa mappa. I punti sono le scuole, georeferenziate con
l'archivio nazionale dei numeri civici: la precisione è quella della via, non
del portone. Le aree sono le sezioni di censimento colorate per quanti bambini
da 0 a 14 anni ci abitano — è la domanda che nessun conteggio comunale può
rispondere, perché un comune con abbastanza scuole può averle tutte dalla parte
sbagliata.

::od-query{into="bambiniSezioni" sql="SELECT s.sez_id AS sezione, v.P14 + v.P15 + v.P16 AS bambini, s.popolazione AS residenti, s.geojson AS geojson FROM istat_sezioni s JOIN istat_censimento_sezioni v USING (sez_id) WHERE s.codice_istat = '{#comune}' AND v.P14 + v.P15 + v.P16 > 0" limit="2000"}

::map{path="bambiniSezioni" geojson="geojson" fill="bambini" height="24rem"}

::od-query{into="scuolePunti" sql="SELECT s.nome AS nome, s.grado AS grado, round(avg(c.lat),5) AS lat, round(avg(c.lon),5) AS lon FROM scuole s JOIN anncsu_strade st ON st.codice_istat = s.codice_istat AND upper(strip_accents(s.indirizzo)) ILIKE '%' || upper(strip_accents(st.odonimo)) || '%' JOIN anncsu_civici c ON c.codice_istat = st.codice_istat AND c.strada = st.strada AND c.lat IS NOT NULL WHERE s.codice_istat = '{#comune}' GROUP BY 1, 2 ORDER BY 1" limit="400"}

::map{path="scuolePunti" lat="lat" lon="lon" height="24rem"}
**{nome}** — {grado}
::/map

Le scuole senza punto sono quelle il cui indirizzo non combacia con nessuna via
dell'archivio, o che stanno in uno dei 2.402 comuni per cui l'archivio non
riporta coordinate: :count{path="scuolePunti"} georeferenziate su
:count{path="scuoleComune"} istituti.

## Il PNRR nella scuola del tuo comune

::od-query{into="pnrrScuola" sql="SELECT misura_descrizione AS misura, count(*) AS progetti, round(sum(finanziamento_pnrr)) AS euro FROM pnrr_progetti WHERE codice_istat = '{#comune}' AND missione = 'M4' GROUP BY 1 ORDER BY euro DESC" limit="40"}

::if-empty{path="pnrrScuola"}
*Nessun progetto della Missione 4 — Istruzione e ricerca risulta in questo comune.*
::/if-empty

::if-any{path="pnrrScuola"}
:count{path="pnrrScuola"} misure attive, per un totale di
:sum{path="pnrrScuola" field="euro"} euro.

::table{path="pnrrScuola" page-size="8" sort="euro" dir="desc"}
::column{field="misura" label="Misura"}
::column{field="progetti" label="Progetti" align="end"}
::column{field="euro" label="Finanziamento €" align="end"}
::/table
::/if-any

## Chi esce dal comune per studiare

I ragazzi che ogni giorno lasciano il comune per andare a scuola, e dove vanno.
Sono i dati del Censimento 2011 — i più recenti che ISTAT pubblichi come file —
quindi vanno letti per la **struttura** dei legami, non per le quantità di oggi.

::od-query{into="studentiFuori" sql="SELECT g.comune AS verso, sum(p.individui)::BIGINT AS studenti FROM pendolarismo p JOIN istat_confini_comuni g ON g.codice_istat = p.codice_istat_destinazione WHERE p.codice_istat = '{#comune}' AND p.motivo = 'studio' AND p.destinazione = 'altro comune' GROUP BY 1 ORDER BY 2 DESC" limit="20"}

::od-query{into="studentiDentro" sql="SELECT sum(individui)::BIGINT AS restano FROM pendolarismo WHERE codice_istat = '{#comune}' AND motivo = 'studio' AND destinazione = 'stesso comune'"}

::if-any{path="studentiFuori"}
::cards{path="studentiDentro"}
**{restano}** studiano nel proprio comune
::/cards

::chart-bar{data="studentiFuori" x="verso" y="studenti" horizontal height="18rem"}
::/if-any

## Le scuole del comune — :count{path="scuoleComune"} istituti

::od-query{into="scuoleComune" sql="SELECT nome AS nome, grado AS grado, indirizzo AS indirizzo FROM scuole WHERE codice_istat = '{#comune}' ORDER BY grado, nome" limit="300"}

::table{path="scuoleComune" search page-size="10" filters="grado"}
::column{field="nome" label="Scuola"}
::column{field="grado" label="Grado"}
::column{field="indirizzo" label="Indirizzo"}
::/table

Le iscrizioni sono solo scuola statale, infanzia esclusa dalla fonte; la
previsione è un trend, non un oracolo — l'R² nello stato dice quanto il
modello spiega la serie. La classificazione sismica va da 1, rischio più
alto, a 4.
::/page

::page{title="Dispersione" icon="graph-trend"}
## L'abbandono scolastico, anno per anno

La serie storica nazionale dall'a.s. 2013/2014: in calo costante per medie e
passaggio tra cicli, con una ripresa nell'ultimo biennio per le superiori.

::od-query{into="trendNazionale" sql="SELECT anno_frequenza AS anno, max(CASE WHEN grado='I grado' THEN tasso_abbandono_perc END) AS medie, max(CASE WHEN grado='passaggio cicli' THEN tasso_abbandono_perc END) AS passaggio, max(CASE WHEN grado='II grado' THEN tasso_abbandono_perc END) AS superiori FROM dispersione_scolastica WHERE regione = 'ITALIA' GROUP BY anno_frequenza ORDER BY anno_frequenza"}

::chart-line{data="trendNazionale" x="anno" y="medie,passaggio,superiori" height="16rem"}

## Il confronto tra regioni — clicca una barra

Tasso di abbandono alle superiori, ultimo biennio disponibile. Un clic su una
regione filtra il dettaglio storico qui sotto; un secondo clic toglie il
filtro — è il filtro incrociato dei veri strumenti BI.

::od-query{into="rankingRegioni" sql="SELECT regione AS regione, tasso_abbandono_perc AS tasso FROM dispersione_scolastica WHERE grado = 'II grado' AND anno_frequenza = (SELECT max(anno_frequenza) FROM dispersione_scolastica WHERE regione != 'ITALIA' AND grado = 'II grado') AND regione != 'ITALIA' ORDER BY tasso DESC" limit="20"}

::od-query{into="dispDettaglio" sql="SELECT regione AS regione, grado AS grado, periodo AS periodo, tasso_abbandono_perc AS tasso FROM dispersione_scolastica WHERE regione != 'ITALIA' ORDER BY regione, grado, anno_frequenza" limit="300"}

::dashboard{path="rankingRegioni"}
::chart-bar{data="rankingRegioni" x="regione" y="tasso" height="20rem"}

::table{path="dispDettaglio" page-size="9" filters="grado"}
::column{field="regione" label="Regione"}
::column{field="grado" label="Grado"}
::column{field="periodo" label="Biennio"}
::column{field="tasso" label="Tasso %" align="end"}
::/table
::/dashboard

Valle d'Aosta e Trentino-Alto Adige sono assenti dalla fonte ministeriale per
l'intera serie; il dettaglio regionale copre i bienni dal 2015/2016, perché il
Ministero non ripubblica gli anni precedenti a ogni nuova edizione.
::/page

::page{title="INVALSI" icon="graph-bar-vertical"}
## La tua regione, prova per prova

Scrivi una regione — `Lombardia`, `Campania`, `Sicilia`, `Veneto` — e scegli
grado e materia: tutta la pagina segue le tre scelte.

::textfield[regione]{label="Regione" value="Lombardia" placeholder="Nome della regione"}

::od-query{into="regioniTrovate" sql="SELECT DISTINCT territorio AS nome FROM invalsi_regionale WHERE livello = 'regione' AND upper(strip_accents(territorio)) LIKE '%' || upper(strip_accents(trim('{#regione}'))) || '%' ORDER BY 1" limit="6"}

::list{path="regioniTrovate" limit="6"}
{nome}
::/list

::columns{min="16rem" gap="m"}
::picker[gradoInv]{label="Grado" value="5ª primaria"}
::menu-item{value="2ª primaria"}
2ª primaria
::/menu-item
::menu-item{value="5ª primaria"}
5ª primaria
::/menu-item
::menu-item{value="3ª secondaria I grado"}
3ª secondaria I grado
::/menu-item
::menu-item{value="2ª secondaria II grado"}
2ª secondaria II grado
::/menu-item
::menu-item{value="5ª secondaria II grado"}
5ª secondaria II grado
::/menu-item
::/picker

::picker[materiaInv]{label="Materia" value="Matematica"}
::menu-item{value="Italiano"}
Italiano
::/menu-item
::menu-item{value="Matematica"}
Matematica
::/menu-item
::menu-item{value="Inglese R"}
Inglese — lettura
::/menu-item
::menu-item{value="Inglese L"}
Inglese — ascolto
::/menu-item
::/picker
::/columns

**Italiano e Matematica nel grado scelto**, anno per anno:

::od-query{into="trendInvalsi" sql="SELECT anno AS anno, max(CASE WHEN materia='Italiano' THEN round(punteggio_medio,1) END) AS italiano, max(CASE WHEN materia='Matematica' THEN round(punteggio_medio,1) END) AS matematica FROM invalsi_regionale WHERE upper(strip_accents(territorio)) = upper(strip_accents(trim('{#regione}'))) AND grado = '{#gradoInv}' GROUP BY anno ORDER BY anno"}

::chart-line{data="trendInvalsi" x="anno" y="italiano,matematica" height="16rem"}

**La materia scelta lungo il percorso** — 5ª primaria, 3ª media, 5ª superiore:

::od-query{into="trendGradi" sql="SELECT anno AS anno, max(CASE WHEN grado='5ª primaria' THEN round(punteggio_medio,1) END) AS primaria, max(CASE WHEN grado='3ª secondaria I grado' THEN round(punteggio_medio,1) END) AS media, max(CASE WHEN grado='5ª secondaria II grado' THEN round(punteggio_medio,1) END) AS superiore FROM invalsi_regionale WHERE upper(strip_accents(territorio)) = upper(strip_accents(trim('{#regione}'))) AND materia = '{#materiaInv}' GROUP BY anno ORDER BY anno"}

::chart-line{data="trendGradi" x="anno" y="primaria,media,superiore" height="16rem"}

## Il confronto tra regioni — clicca una barra

Grado e materia scelti qui sopra, ultimo anno disponibile per quella prova. Un
clic su una regione mostra tutte le sue prove nel dettaglio sotto; con i filtri
della tabella scegli grado e materia.

::od-query{into="rankingInvalsi" sql="SELECT territorio AS regione, round(punteggio_medio,1) AS punteggio FROM invalsi_regionale WHERE livello = 'regione' AND grado = '{#gradoInv}' AND materia = '{#materiaInv}' AND anno = (SELECT max(anno) FROM invalsi_regionale WHERE grado = '{#gradoInv}' AND materia = '{#materiaInv}') ORDER BY punteggio DESC" limit="25"}

::od-query{into="invDettaglio" sql="SELECT territorio AS regione, grado AS grado, materia AS materia, round(punteggio_medio,1) AS punteggio FROM invalsi_regionale WHERE livello = 'regione' AND anno = (SELECT max(anno) FROM invalsi_regionale) ORDER BY territorio, grado, materia" limit="400"}

::dashboard{path="rankingInvalsi"}
::chart-bar{data="rankingInvalsi" x="regione" y="punteggio" height="20rem"}

::table{path="invDettaglio" page-size="10" filters="grado,materia"}
::column{field="regione" label="Regione"}
::column{field="grado" label="Grado"}
::column{field="materia" label="Materia"}
::column{field="punteggio" label="Punteggio" align="end"}
::/table
::/dashboard

Dato campionario — un rilevamento su un campione di scuole — in scala WLE con
media nazionale attorno a 200: serve per confrontare territori e anni, non per
giudicare il singolo istituto. L'a.s. 2019/2020 manca: niente prove, COVID.
::/page

::page{title="Organico" icon="demographic"}
## I docenti della tua provincia

Scrivi una provincia — `Milano`, `Roma`, `Napoli`, `Torino` — e l'elenco qui
sotto conferma il nome esatto.

::textfield[provincia]{label="Provincia" value="Milano" placeholder="Nome della provincia"}

::od-query{into="provinceTrovate" sql="SELECT DISTINCT provincia AS nome, regione AS regione FROM personale_scuola WHERE upper(strip_accents(provincia)) LIKE '%' || upper(strip_accents(trim('{#provincia}'))) || '%' ORDER BY 1" limit="6"}

::list{path="provinceTrovate" limit="6"}
{nome} — {regione}
::/list

::od-query{into="kpiDocenti" sql="SELECT a.docenti AS docenti, round(100.0*(a.docenti-b.docenti)/b.docenti,1) AS variazione FROM (SELECT sum(totale) AS docenti FROM personale_scuola WHERE upper(strip_accents(provincia)) = upper(strip_accents(trim('{#provincia}'))) AND categoria='Docente' AND anno_scolastico=(SELECT max(anno_scolastico) FROM personale_scuola)) a, (SELECT sum(totale) AS docenti FROM personale_scuola WHERE upper(strip_accents(provincia)) = upper(strip_accents(trim('{#provincia}'))) AND categoria='Docente' AND anno_scolastico=(SELECT min(anno_scolastico) FROM personale_scuola)) b"}

::od-query{into="kpiRapporto" sql="SELECT round(a.alunni::DOUBLE / p.docenti, 1) AS rapporto FROM (SELECT sum(alunni) AS alunni FROM iscrizioni_scolastiche WHERE upper(strip_accents(provincia)) = upper(strip_accents(trim('{#provincia}'))) AND anno_scolastico = (SELECT max(anno_scolastico) FROM iscrizioni_scolastiche)) a, (SELECT sum(totale) AS docenti FROM personale_scuola WHERE upper(strip_accents(provincia)) = upper(strip_accents(trim('{#provincia}'))) AND categoria = 'Docente' AND anno_scolastico = (SELECT max(anno_scolastico) FROM personale_scuola)) p"}

::od-query{into="kpiSostegno" sql="SELECT round(100.0*(sum(totale) FILTER (WHERE tipo_posto='Sostegno'))/sum(totale),1) AS perc_sostegno, (SELECT sum(totale) FROM personale_scuola WHERE upper(strip_accents(provincia)) = upper(strip_accents(trim('{#provincia}'))) AND categoria='ATA' AND anno_scolastico=(SELECT max(anno_scolastico) FROM personale_scuola)) AS ata FROM personale_scuola WHERE upper(strip_accents(provincia)) = upper(strip_accents(trim('{#provincia}'))) AND categoria='Docente' AND anno_scolastico=(SELECT max(anno_scolastico) FROM personale_scuola)"}

::columns{min="16rem" gap="m"}
::cards{path="kpiDocenti"}
**{docenti}** docenti titolari — variazione in dieci anni **{variazione}%**
::/cards

::cards{path="kpiRapporto"}
**{rapporto}** alunni per docente (iscrizioni ÷ titolari, ultimo anno)
::/cards

::cards{path="kpiSostegno"}
**{perc_sostegno}%** posti di sostegno — **{ata}** unità di personale ATA
::/cards
::/columns

## L'organico che avrai: la proiezione

Lo stesso strumento della pagina iscrizioni, applicato ai titolari: il trend
prolungato in avanti, per ragionare su pensionamenti e fabbisogno. Qui i modelli
non lineari cambiano parecchio la risposta, perché la serie ha una curva — il
calo fino al 2020 e la ripresa dopo — che una retta non può descrivere.

::od-query{into="trendDocenti" sql="SELECT substr(anno_scolastico,1,4)::INTEGER AS anno, sum(totale)::BIGINT AS docenti FROM personale_scuola WHERE upper(strip_accents(provincia)) = upper(strip_accents(trim('{#provincia}'))) AND categoria = 'Docente' GROUP BY 1 ORDER BY 1"}

::slider[anniOrg]{label="Anni di proiezione" min="1" max="5" step="1" value="3"}

::picker[algoOrg]{label="Modello di proiezione" value="linear"}
::menu-item{value="linear"}
Trend lineare
::/menu-item
::menu-item{value="sarima"}
ARIMA/SARIMA
::/menu-item
::menu-item{value="holt-winters"}
Holt-Winters (ETS)
::/menu-item
::/picker

::ml-forecast{data="trendDocenti" x="anno" y="docenti" horizon="#anniOrg" model="#algoOrg" into="trendDocPrev"}

::chart-line{data="trendDocPrev" x="anno" y="docenti,previsione" height="16rem"}

::columns{min="20rem" gap="m"}
**Per fascia d'età** — l'onda dei pensionamenti si vede qui:

::od-query{into="etaDocenti" sql="SELECT fascia_eta AS fascia, sum(totale)::BIGINT AS docenti FROM personale_scuola WHERE upper(strip_accents(provincia)) = upper(strip_accents(trim('{#provincia}'))) AND categoria = 'Docente' AND anno_scolastico = (SELECT max(anno_scolastico) FROM personale_scuola) GROUP BY fascia_eta ORDER BY min(CASE fascia_eta WHEN 'Fino a 34' THEN 1 WHEN 'Tra 35 e 44' THEN 2 WHEN 'Tra 45 e 54' THEN 3 ELSE 4 END)"}

::chart-bar{data="etaDocenti" x="fascia" y="docenti" height="15rem"}

**Per grado di scuola**:

::od-query{into="gradoDocenti" sql="SELECT grado AS grado, sum(totale)::BIGINT AS docenti FROM personale_scuola WHERE upper(strip_accents(provincia)) = upper(strip_accents(trim('{#provincia}'))) AND categoria = 'Docente' AND anno_scolastico = (SELECT max(anno_scolastico) FROM personale_scuola) GROUP BY grado ORDER BY grado"}

::chart-bar{data="gradoDocenti" x="grado" y="docenti" height="15rem"}
::/columns

Solo personale di ruolo: il precariato non è nella fonte. Il rapporto
alunni/docente incrocia due dataset — iscrizioni statali senza infanzia ÷
titolari con infanzia — ed è un indicatore di tendenza, non un dato di
organico ufficiale.
::/page

::page{title="La mappa" icon="globe"}
## L'Italia della scuola, colorata dai dati

**Matematica in 5ª primaria**, punteggio INVALSI dell'ultimo anno — tocca una
regione per il valore:

::od-query{into="mappaInvalsi" sql="SELECT r.regione AS regione, r.geojson AS geojson, round(i.punteggio_medio) AS punteggio FROM istat_confini_regioni r JOIN invalsi_regionale i ON i.regione = r.regione WHERE i.grado='5ª primaria' AND i.materia='Matematica' AND i.anno=(SELECT max(anno) FROM invalsi_regionale)" limit="30"}

::map{path="mappaInvalsi" geojson="geojson" fill="punteggio" height="26rem"}
**{regione}** — punteggio {punteggio}
::/map

**Abbandono alle superiori**, tasso % dell'ultimo biennio — qui il colore
scuro è il problema:

::od-query{into="mappaDispersione" sql="SELECT r.regione AS regione, r.geojson AS geojson, d.tasso_abbandono_perc AS tasso FROM istat_confini_regioni r JOIN dispersione_scolastica d ON d.regione = r.regione WHERE d.grado='II grado' AND d.anno_frequenza=(SELECT max(anno_frequenza) FROM dispersione_scolastica WHERE regione != 'ITALIA' AND grado='II grado')" limit="30"}

::map{path="mappaDispersione" geojson="geojson" fill="tasso" height="26rem"}
**{regione}** — abbandono {tasso}%
::/map

Le regioni senza colore non hanno il dato nella fonte: Valle d'Aosta e
Trentino-Alto Adige per la dispersione, e il Trentino-Alto Adige INVALSI è
pubblicato come due province autonome, non come regione.
::/page

::page{title="Esplora" icon="search"}
## Il pivot: fai le tue domande trascinando

Le iscrizioni per regione, grado e anno — :count{path="pivotIscrizioni"}
combinazioni. Trascina le colonne per raggruppare, cambia tipo di grafico,
filtra: è una tabella pivot, e funziona anche in modalità Uso.

::od-query{into="pivotIscrizioni" sql="SELECT regione AS regione, grado AS grado, substr(anno_scolastico,1,4)::INTEGER AS anno, sum(alunni)::BIGINT AS alunni FROM iscrizioni_scolastiche WHERE regione IS NOT NULL AND codice_istat IS NOT NULL GROUP BY 1,2,3 ORDER BY 1,2,3" limit="1000"}

::explore{path="pivotIscrizioni" view="bar" group-by="regione" columns="alunni" height="30rem"}

Le stesse righe restano leggibili anche senza rete: la collection scaricata è
la copia locale, e quando il servizio non risponde le viste mostrano l'ultima
buona con lo stato "stale".
::/page

---

I dati sono ufficiali e aperti: **iscrizioni, edilizia scolastica e
personale** del MIUR — Portale Unico dei Dati della Scuola, Open Data IODL
2.0; **dispersione scolastica** del MIM — Ufficio di Statistica, riuso libero
con citazione; **risultati INVALSI regionali** di INVALSI — Servizio
Statistico, CC BY 4.0 IT; **confini** ISTAT. Si agganciano da soli tramite
comune, regione o provincia. Nessun dato tuo lascia il dispositivo.
