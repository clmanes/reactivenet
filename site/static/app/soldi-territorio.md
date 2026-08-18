---
appId: soldi-territorio
title: Conti pubblici del territorio
description: "Dove vanno e da dove arrivano i soldi pubblici del tuo comune: spesa ed entrate per cassa anno per anno e pro capite (SIOPE/OpenBDAP), saldo, autonomia finanziaria e incasso da multe, i progetti finanziati da fondi di coesione e PNRR (OpenCoesione, OpenCUP), le gare d'appalto e chi le vince (ANAC). Con coropletica regionale, previsione, anomalie e comuni dal profilo simile calcolati nel browser. Dati ufficiali MEF-RGS, ANAC, DIPE e Agenzia per la Coesione."
icon: money
lang: it
version: "3.0"
author: Reactive
date: "2026-08-13"
---

# Conti pubblici del territorio

La domanda civica per eccellenza — *dove vanno i soldi pubblici?* — con i dati
ufficiali, comune per comune: quanto paga il tuo comune e per cosa, quanto
incassa e da dove, che progetti sono finanziati da fondi di coesione e PNRR e a
che punto sono, chi vince gli appalti. Scrivi un comune una volta sola: tutte le
pagine seguono quella scelta. Le analisi girano nel browser e nessun dato tuo
lascia il dispositivo.

::page{title="Il mio comune" icon="government"}
## Il quadro del tuo comune

Scrivi il nome del comune. Conta il nome esatto: l'elenco qui sotto mostra i
comuni che corrispondono a quello che hai scritto, con la sigla di provincia
per distinguere gli omonimi.

::textfield[comune]{label="Comune" value="Bologna" placeholder="Nome del comune, es. Bologna"}

::od-query{into="comuniTrovati" sql="SELECT comune || ' (' || sigla || ')' AS nome, regione AS regione FROM istat_confini_comuni WHERE upper(strip_accents(comune)) LIKE '%' || upper(strip_accents(trim('{#comune}'))) || '%' ORDER BY length(comune), comune" limit="6"}

::list{path="comuniTrovati" limit="6"}
{nome} — {regione}
::/list

::od-query{into="kpiSpesa" sql="SELECT round(sum(importo)/1e6,1) AS milioni, round(sum(importo)/max(popolazione)) AS procapite, max(anno) AS anno, max(popolazione) AS abitanti FROM siope_spese WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND mese=12 AND anno=(SELECT max(anno) FROM siope_spese WHERE mese=12 AND codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1)) AND categoria_codice NOT IN ('7.01','7.02','0.00')"}

::od-query{into="kpiVar" sql="SELECT coalesce(round(100.0*(a.tot-b.tot)/nullif(b.tot,0),1)::VARCHAR || '%','n.d.') AS variazione, round(a.inv/1e6,1) AS investimenti FROM (SELECT sum(importo) AS tot, sum(importo) FILTER (WHERE categoria_codice LIKE '2.%') AS inv FROM siope_spese WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND mese=12 AND anno=(SELECT max(anno) FROM siope_spese WHERE mese=12 AND codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1))) a, (SELECT sum(importo) AS tot FROM siope_spese WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND mese=12 AND anno=(SELECT max(anno) FROM siope_spese WHERE mese=12 AND codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1))-1) b"}

::od-query{into="kpiRank" sql="SELECT posizione, totale, centile FROM (SELECT codice_istat, rank() OVER (ORDER BY pc DESC) AS posizione, count(*) OVER () AS totale, round(100*percent_rank() OVER (ORDER BY pc)) AS centile FROM (SELECT codice_istat, sum(importo)/max(popolazione) AS pc FROM siope_spese WHERE cod_reg=(SELECT cod_reg FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND mese=12 AND anno=(SELECT anno FROM siope_spese WHERE mese=12 GROUP BY anno HAVING count(DISTINCT codice_istat)>=6500 ORDER BY anno DESC LIMIT 1) AND popolazione>0 AND categoria_codice NOT IN ('7.01','7.02','0.00') GROUP BY 1)) WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1)"}

::od-query{into="kpiDebito" sql="SELECT round((coalesce(sum(importo) FILTER (WHERE categoria_codice='1.07'),0)+coalesce(sum(importo) FILTER (WHERE categoria_codice LIKE '4.%'),0))/max(popolazione)) AS eur_ab FROM siope_spese WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND mese=12 AND anno=(SELECT max(anno) FROM siope_spese WHERE mese=12 AND codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1))"}

::columns{min="16rem" gap="m" id="scheda"}
::cards{path="kpiSpesa"}
**{milioni} mln €** pagati nel {anno} — **{procapite} €** per abitante, su {abitanti} residenti
::/cards

::cards{path="kpiVar"}
**{variazione}** rispetto all'anno prima — **{investimenti} mln €** di investimenti
::/cards

::cards{path="kpiRank"}
**{posizione}° su {totale}** comuni della regione per spesa per abitante — {centile}° percentile
::/cards

::cards{path="kpiDebito"}
Il debito costa **{eur_ab} €** per abitante l'anno (interessi più rimborso prestiti)
::/cards
::/columns

::print{target="scheda" label="Stampa la scheda"}

## La regione, comune per comune

La coropletica della regione del comune scelto: spesa totale per abitante
nell'ultimo anno a copertura piena. Blu più intenso, spesa più alta. Tocca un
comune per il valore.

::od-query{into="mappaSpesa" sql="SELECT c.comune AS comune, c.geojson AS geojson, round(sum(s.importo) FILTER (WHERE s.categoria_codice NOT IN ('7.01','7.02','0.00'))/max(s.popolazione)) AS procapite, round(coalesce(sum(s.importo) FILTER (WHERE s.categoria_codice LIKE '2.%'),0)/max(s.popolazione)) AS investimenti FROM siope_spese s JOIN istat_confini_comuni c ON c.codice_istat=s.codice_istat WHERE s.cod_reg=(SELECT cod_reg FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND s.mese=12 AND s.anno=(SELECT anno FROM siope_spese WHERE mese=12 GROUP BY anno HAVING count(DISTINCT codice_istat)>=6500 ORDER BY anno DESC LIMIT 1) AND s.popolazione>0 GROUP BY 1,2" limit="1600"}

::map{path="mappaSpesa" geojson="geojson" fill="procapite" height="26rem"}
**{comune}** — {procapite} € per abitante, di cui {investimenti} € di investimenti
::/map

Sono pagamenti di **cassa**: quanto è uscito davvero nell'anno, non quanto è
stato impegnato in bilancio. Sono esclusi i giri contabili e le partite di giro.
I numeri della scheda vengono dall'ultimo anno che il comune ha chiuso; la mappa
e i confronti regionali dall'ultimo anno in cui quasi tutti i comuni hanno
trasmesso, che di solito è quello prima. Un comune molto piccolo con una sola
opera in cantiere può comparire in cima alla mappa: il pro capite di poche
centinaia di abitanti si muove per pochi euro.
::/page

::page{title="La spesa" icon="graph-bar-vertical"}
## Per cosa spende — clicca una barra per filtrare

Le due serie sono il **tuo comune** contro la **media dei comuni della
regione**, in euro per abitante. Un clic su una barra restringe la tabella a
quella voce; un secondo clic toglie il filtro.

::od-query{into="spesaCategorie" sql="WITH pc AS (SELECT codice_istat, categoria_codice, categoria, sum(importo) AS imp, max(popolazione) AS pop FROM siope_spese WHERE cod_reg=(SELECT cod_reg FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND mese=12 AND anno=(SELECT anno FROM siope_spese WHERE mese=12 GROUP BY anno HAVING count(DISTINCT codice_istat)>=6500 ORDER BY anno DESC LIMIT 1) AND popolazione>0 AND categoria_codice NOT IN ('7.01','7.02','0.00') GROUP BY 1,2,3), poptot AS (SELECT sum(pop) AS pop FROM (SELECT codice_istat, max(pop) AS pop FROM pc GROUP BY 1)) SELECT CASE categoria_codice WHEN '1.01' THEN 'Personale' WHEN '1.02' THEN 'Imposte' WHEN '1.03' THEN 'Beni e servizi' WHEN '1.04' THEN 'Trasferimenti' WHEN '1.05' THEN 'Trasf. tributi' WHEN '1.07' THEN 'Interessi' WHEN '1.09' THEN 'Rimborsi entrate' WHEN '1.10' THEN 'Altre correnti' WHEN '2.02' THEN 'Investimenti' WHEN '2.03' THEN 'Contributi invest.' WHEN '2.05' THEN 'Altre c. capitale' WHEN '4.03' THEN 'Rimborso mutui' WHEN '5.01' THEN 'Anticipazioni' ELSE min(categoria) END AS voce, min(categoria) AS categoria, round(sum(imp) FILTER (WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1))/1e3) AS migliaia, round(sum(imp) FILTER (WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1))/nullif(max(pop) FILTER (WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1)),0)) AS procapite, round(sum(imp)/(SELECT pop FROM poptot)) AS media FROM pc GROUP BY categoria_codice ORDER BY migliaia DESC NULLS LAST" limit="30"}

::dashboard{path="spesaCategorie"}
::chart-bar{data="spesaCategorie" x="voce" y="procapite,media" height="18rem"}

::table{path="spesaCategorie" page-size="12"}
::column{field="categoria" label="Voce di spesa"}
::column{field="migliaia" label="Migliaia €" align="end"}
::column{field="procapite" label="€/ab. qui" align="end"}
::column{field="media" label="€/ab. media regione" align="end"}
::/table
::/dashboard

## Dove si colloca il tuo comune

La distribuzione della spesa per abitante fra tutti i comuni della regione, in
fasce da 500 €: confronta la posizione della scheda con la forma della campana.

::od-query{into="fasceRegione" sql="SELECT CASE WHEN b>=8 THEN '4000 e oltre' ELSE (b*500)::BIGINT::VARCHAR || '–' || ((b+1)*500)::BIGINT::VARCHAR END AS fascia, count(*) AS comuni FROM (SELECT least(floor(sum(importo)/max(popolazione)/500),8) AS b FROM siope_spese WHERE cod_reg=(SELECT cod_reg FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND mese=12 AND anno=(SELECT anno FROM siope_spese WHERE mese=12 GROUP BY anno HAVING count(DISTINCT codice_istat)>=6500 ORDER BY anno DESC LIMIT 1) AND popolazione>0 AND categoria_codice NOT IN ('7.01','7.02','0.00') GROUP BY codice_istat) GROUP BY b ORDER BY b" limit="20"}

::chart-bar{data="fasceRegione" x="fascia" y="comuni" height="16rem"}

## Il trend: correnti e investimenti anno per anno

Il grafico è in **euro per abitante** — la versione onesta, perché un comune che
cresce di popolazione sembrerebbe spendere di più; la tabella è in milioni.

::od-query{into="trendSpesa" sql="SELECT anno AS anno, round(sum(importo) FILTER (WHERE categoria_codice LIKE '1.%')/1e6,2) AS correnti, round(sum(importo) FILTER (WHERE categoria_codice LIKE '2.%')/1e6,2) AS investimenti, round(sum(importo) FILTER (WHERE categoria_codice LIKE '1.%')/max(popolazione)) AS correnti_ab, round(sum(importo) FILTER (WHERE categoria_codice LIKE '2.%')/max(popolazione)) AS investimenti_ab, max(mese) AS mesi FROM siope_spese WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) GROUP BY 1 ORDER BY 1" limit="20"}

::chart-line{data="trendSpesa" x="anno" y="correnti_ab,investimenti_ab" height="16rem"}

::table{path="trendSpesa"}
::column{field="anno" label="Anno"}
::column{field="correnti" label="Correnti (mln)" align="end"}
::column{field="investimenti" label="Investimenti (mln)" align="end"}
::column{field="mesi" label="Mesi cumulati" align="end"}
::/table

Le voci sono il livello II del piano dei conti armonizzato (D.Lgs 118/2011),
una venticinquina di categorie leggibili. L'ultima riga della tabella ha spesso
meno di dodici mesi: è l'anno in corso, cumulato all'ultimo mese pubblicato, e
nel grafico va letto come parziale, non come un crollo. Il confronto con la
media regionale è una media pesata sulla popolazione, non la media delle medie
dei comuni.
::/page

::page{title="Le entrate" icon="credit-card"}
## Quanto incassa il tuo comune

L'altra metà del bilancio: da dove arrivano i soldi — tributi propri,
trasferimenti da Stato e Regione, tariffe e sanzioni.

::od-query{into="kpiEntrate" sql="SELECT round(sum(importo)/1e6,1) AS milioni, round(sum(importo)/max(popolazione)) AS procapite, max(anno) AS anno FROM siope_entrate WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND mese=12 AND anno=(SELECT max(anno) FROM siope_entrate WHERE mese=12 AND codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1)) AND categoria_codice NOT IN ('9.01','9.02','0.00')"}

::od-query{into="kpiAutonomia" sql="SELECT round(100.0*sum(importo) FILTER (WHERE categoria_codice LIKE '1.%' OR categoria_codice LIKE '3.%')/nullif(sum(importo) FILTER (WHERE categoria_codice LIKE '1.%' OR categoria_codice LIKE '2.%' OR categoria_codice LIKE '3.%'),0),1) AS autonomia, round(coalesce(sum(importo) FILTER (WHERE categoria_codice='3.02'),0)/max(popolazione)) AS multe_ab, round(coalesce(sum(importo) FILTER (WHERE categoria_codice='3.02'),0)/1e3) AS multe_migliaia FROM siope_entrate WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND mese=12 AND anno=(SELECT max(anno) FROM siope_entrate WHERE mese=12 AND codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1))"}

::columns{min="16rem" gap="m"}
::cards{path="kpiEntrate"}
**{milioni} mln €** incassati nel {anno} — **{procapite} €** per abitante
::/cards

::cards{path="kpiAutonomia"}
Autonomia finanziaria **{autonomia}%** — sanzioni e multe **{multe_ab} €** per abitante ({multe_migliaia} mila €)
::/cards
::/columns

Autonomia alta vuol dire che il comune si regge sulle entrate proprie; bassa,
che dipende dai trasferimenti di Stato e Regione.

## Da dove arrivano i soldi — clicca per filtrare

::od-query{into="entrateCategorie" sql="SELECT categoria AS categoria, round(sum(importo)/1e3) AS migliaia, round(sum(importo)/max(popolazione)) AS procapite FROM siope_entrate WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND mese=12 AND anno=(SELECT max(anno) FROM siope_entrate WHERE mese=12 AND codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1)) AND categoria_codice NOT IN ('9.01','9.02','0.00') GROUP BY 1 ORDER BY 2 DESC" limit="30"}

::dashboard{path="entrateCategorie"}
::chart-bar{data="entrateCategorie" x="categoria" y="procapite" height="18rem"}

::table{path="entrateCategorie" page-size="12"}
::column{field="categoria" label="Voce di entrata"}
::column{field="migliaia" label="Migliaia €" align="end"}
::column{field="procapite" label="€ per abitante" align="end"}
::/table
::/dashboard

## Entrate e spese: il saldo di cassa

::od-query{into="saldoCassa" sql="SELECT e.anno AS anno, e.entrate AS entrate, s.spese AS spese, round(e.entrate - s.spese,2) AS saldo, s.mesi AS mesi FROM (SELECT anno, round(sum(importo)/1e6,2) AS entrate FROM siope_entrate WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND categoria_codice NOT IN ('9.01','9.02','0.00') GROUP BY 1) e JOIN (SELECT anno, round(sum(importo)/1e6,2) AS spese, max(mese) AS mesi FROM siope_spese WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND categoria_codice NOT IN ('7.01','7.02','0.00') GROUP BY 1) s USING (anno) ORDER BY e.anno" limit="20"}

::chart-line{data="saldoCassa" x="anno" y="entrate,spese" height="16rem"}

::table{path="saldoCassa"}
::column{field="anno" label="Anno"}
::column{field="entrate" label="Entrate (mln)" align="end"}
::column{field="spese" label="Spese (mln)" align="end"}
::column{field="saldo" label="Saldo (mln)" align="end"}
::column{field="mesi" label="Mesi" align="end"}
::/table

Un saldo negativo dice che in quell'anno è uscito più di quanto è entrato: di
per sé non è un allarme, perché gli investimenti si pagano anche con avanzi
accumulati negli anni prima. Una serie di segni meno consecutivi, quella sì,
racconta qualcosa. L'autonomia finanziaria è (titolo 1 + titolo 3) / (titoli 1 +
2 + 3): i fondi perequativi stanno nel titolo 1 per come è fatto il piano dei
conti, quindi il valore è un po' più generoso di quanto la parola suggerisca.
L'ultimo anno, se ha meno di dodici mesi, non è confrontabile con i precedenti.
::/page

::page{title="PNRR e progetti" icon="project"}
## I progetti finanziati sul territorio

Fondi di coesione, PNRR e investimenti pubblici tracciati dal CUP: cosa è stato
finanziato nel comune scelto, con che soldi e a che punto è.

::od-query{into="kpiCoesione" sql="SELECT count(*) AS progetti, round(sum(finanz_totale_pubblico)/1e6,1) AS milioni, round(100.0*sum(costo_realizzato)/nullif(sum(finanz_totale_pubblico),0),1) AS avanzamento, count(*) FILTER (WHERE stato_progetto ILIKE '%conclus%') AS conclusi, count(*) FILTER (WHERE stato_progetto NOT ILIKE '%conclus%') AS in_corso FROM opencoesione WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1)"}

::columns{min="16rem" gap="m"}
::cards{path="kpiCoesione"}
**{progetti}** progetti per **{milioni} mln €** di finanziamento pubblico
::/cards

::cards{path="kpiCoesione"}
Avanzamento economico medio **{avanzamento}%** — **{conclusi}** conclusi, **{in_corso}** in corso
::/cards
::/columns

## I progetti più grandi, tema per tema

::od-query{into="temiComune" sql="SELECT tema AS tema, round(sum(finanz_totale_pubblico)/1e3) AS migliaia FROM opencoesione WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) GROUP BY 1 ORDER BY 2 DESC" limit="20"}

::od-query{into="progettiComune" sql="SELECT titolo AS titolo, tema AS tema, ciclo AS ciclo, round(finanz_totale_pubblico/1e3) AS migliaia, round(100.0*costo_realizzato/nullif(finanz_totale_pubblico,0)) AS avanzamento, stato_progetto AS stato, beneficiario AS beneficiario FROM opencoesione WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) ORDER BY finanz_totale_pubblico DESC" limit="200"}

::dashboard{path="progettiComune"}
::chart-pie{data="temiComune" label="tema" value="migliaia" height="16rem"}

::table{path="progettiComune" search page-size="10" filters="tema,stato"}
::column{field="titolo" label="Progetto"}
::column{field="tema" label="Tema"}
::column{field="migliaia" label="Migliaia €" align="end"}
::column{field="avanzamento" label="Avanz. %" align="end"}
::column{field="stato" label="Stato"}
::/table
::/dashboard

Sono i primi 200 progetti per finanziamento. La ricerca sopra la tabella filtra
per parola — «scuola», «strada», «asilo» — e i due menu per tema e per stato.

## Gli investimenti censiti dal CUP

Ogni investimento pubblico ha un Codice Unico di Progetto, coesione o no: qui
c'è l'universo intero, dal 2003, ordinato per costo.

::od-query{into="cupComune" sql="SELECT descrizione AS descrizione, natura_intervento AS natura, round(costo_progetto/1e3) AS migliaia, anno_decisione AS anno, stato_progetto AS stato, soggetto_titolare AS titolare FROM opencup WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND costo_progetto>0 ORDER BY costo_progetto DESC" limit="150"}

::table{path="cupComune" search page-size="10" filters="stato"}
::column{field="descrizione" label="Intervento"}
::column{field="natura" label="Natura"}
::column{field="migliaia" label="Migliaia €" align="end"}
::column{field="anno" label="Anno" align="end"}
::column{field="stato" label="Stato"}
::/table

Il comune indicato è quello di **realizzazione**, non quello che paga: un'opera
statale o regionale che passa di lì compare qui con tutto il suo costo — la
prima riga di molti capoluoghi è una linea ferroviaria. L'avanzamento di
OpenCoesione è economico, cioè il rendicontato sul finanziato, e non dice a che
punto è il cantiere. I due archivi si sovrappongono: un progetto di coesione ha
un CUP e compare in entrambi, quindi i totali delle due sezioni non si sommano.
::/page

::page{title="Appalti" icon="hammer"}
## Le gare e chi le vince

Le gare pubbliche degli enti che appaltano sul territorio scelto, con l'esito e
il vincitore. Scegli se guardare il solo comune o tutta la sua provincia.

::picker[ambito]{label="Ambito" value="comune"}
::menu-item{value="comune"}
Solo il comune
::/menu-item
::menu-item{value="provincia"}
Tutta la provincia
::/menu-item
::/picker

::od-query{into="gareTerritorio" sql="SELECT g.oggetto_gara AS oggetto, g.amministrazione AS amministrazione, round(g.importo_lotto/1e3) AS migliaia, g.data_pubblicazione AS data, g.tipo_scelta_contraente AS procedura, coalesce(a.vincitore,'—') AS vincitore, coalesce(round(a.ribasso,1),0) AS ribasso FROM anac_cig g LEFT JOIN (SELECT cig, any_value(denominazione) AS vincitore, max(ribasso) AS ribasso FROM anac_aggiudicatari GROUP BY cig) a ON a.cig=g.cig WHERE (g.luogo_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) OR ('{#ambito}'='provincia' AND substr(g.luogo_istat,1,3)=substr((SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1),1,3))) AND g.importo_lotto>0 ORDER BY g.data_pubblicazione DESC" limit="300"}

::table{path="gareTerritorio" search page-size="10" filters="procedura"}
::column{field="oggetto" label="Oggetto"}
::column{field="amministrazione" label="Amministrazione"}
::column{field="migliaia" label="Migliaia €" align="end"}
::column{field="data" label="Pubblicata"}
::column{field="vincitore" label="Vincitore"}
::column{field="ribasso" label="Ribasso %" align="end"}
::/table

## Come si affida, e quanto pesa il PNRR

::od-query{into="procedureGare" sql="SELECT CASE WHEN tipo_scelta_contraente ILIKE 'AFFIDAMENTO DIRETTO%' THEN 'Affidamento diretto' WHEN tipo_scelta_contraente ILIKE 'PROCEDURA APERTA%' THEN 'Procedura aperta' WHEN tipo_scelta_contraente ILIKE 'PROCEDURA RISTRETTA%' THEN 'Procedura ristretta' WHEN tipo_scelta_contraente ILIKE 'PROCEDURA NEGOZIATA%' THEN 'Procedura negoziata' ELSE 'Altre' END AS procedura, count(*) AS gare, round(sum(importo_lotto)/1e6,1) AS milioni FROM anac_cig WHERE (luogo_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) OR ('{#ambito}'='provincia' AND substr(luogo_istat,1,3)=substr((SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1),1,3))) AND importo_lotto>0 GROUP BY 1 ORDER BY 2 DESC" limit="10"}

::chart-bar{data="procedureGare" x="procedura" y="gare" height="16rem"}

::od-query{into="kpiPnrr" sql="SELECT count(*) FILTER (WHERE flag_pnrr_pnc='1') AS gare_pnrr, round(coalesce(sum(importo_lotto) FILTER (WHERE flag_pnrr_pnc='1'),0)/1e6,1) AS milioni_pnrr, round(100.0*count(*) FILTER (WHERE flag_pnrr_pnc='1')/nullif(count(*),0),1) AS quota FROM anac_cig WHERE (luogo_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) OR ('{#ambito}'='provincia' AND substr(luogo_istat,1,3)=substr((SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1),1,3))) AND importo_lotto>0"}

::cards{path="kpiPnrr"}
**{gare_pnrr}** gare finanziate da PNRR o Piano complementare — **{milioni_pnrr} mln €**, il {quota}% delle gare dell'ambito scelto
::/cards

## Cerca fra le gare di tutta Italia

La ricerca è semantica: descrivi il lavoro, non le parole del bando. Copre
l'archivio nazionale, non solo il territorio scelto sopra.

::od-search{into="gareTrovate" table="anac_cig" placeholder="Es. manutenzione strade, mensa scolastica, illuminazione…"}

::table{path="gareTrovate" page-size="10"}
::column{field="oggetto_gara" label="Oggetto"}
::column{field="amministrazione" label="Amministrazione"}
::column{field="importo_lotto" label="Importo €" align="end"}
::column{field="provincia" label="Provincia"}
::column{field="esito" label="Esito"}
::/table

L'archivio ANAC copre qui il **2024 e il 2025**: non è la storia degli appalti
del comune, è quello che si è mosso in questi due anni. Il luogo è quello di
esecuzione, quindi compaiono anche ASL, università, scuole e società
partecipate, non solo il comune. Gli importi contengono errori della fonte —
sono affidabili riga per riga, molto meno se aggregati alla cieca — e un ribasso
a zero quasi sempre vuol dire che il dato non è stato trasmesso, non che si è
pagato il prezzo pieno.
::/page

::page{title="Analisi" icon="algorithm"}
## Le analisi girano sul tuo dispositivo

scikit-learn e statsmodels via Python nel browser: la prima esecuzione scarica
il motore, qualche decina di megabyte messi poi in cache, e parte dal pulsante
Run. Sono strumenti di lettura statistica, non giudizi.

## Dove andrà la spesa: la previsione

La serie degli anni chiusi prolungata in avanti. L'R² nella riga di stato dice
quanto il modello spiega la serie.

::od-query{into="serieSpesa" sql="SELECT anno AS anno, round(sum(importo)/1e6,2) AS spesa FROM siope_spese WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND mese=12 AND categoria_codice NOT IN ('7.01','7.02','0.00') GROUP BY 1 ORDER BY 1" limit="20"}

::slider[anniPrev]{label="Anni di previsione" min="1" max="4" step="1" value="2"}

::picker[modelPrev]{label="Modello" value="linear"}
::menu-item{value="linear"}
Trend lineare
::/menu-item
::menu-item{value="holt-winters"}
Holt-Winters (ETS)
::/menu-item
::/picker

::ml-forecast{data="serieSpesa" x="anno" y="spesa" horizon="#anniPrev" model="#modelPrev" into="spesaPrevista"}

::chart-line{data="spesaPrevista" x="anno" y="spesa,previsione" height="16rem"}

## Spese fuori norma: le anomalie fra comuni

Il profilo pro capite del tuo comune confrontato con tutti i comuni della
regione — personale, beni e servizi, trasferimenti, investimenti. L'Isolation
Forest segnala i profili che stanno fuori dal gruppo, il tuo compreso se lo è.

::od-query{into="profiliRegione" sql="SELECT comune AS comune, round(sum(importo) FILTER (WHERE categoria_codice='1.01')/max(popolazione)) AS personale, round(sum(importo) FILTER (WHERE categoria_codice='1.03')/max(popolazione)) AS beni_servizi, round(sum(importo) FILTER (WHERE categoria_codice='1.04')/max(popolazione)) AS trasferimenti, round(sum(importo) FILTER (WHERE categoria_codice LIKE '2.%')/max(popolazione)) AS investimenti FROM siope_spese WHERE cod_reg=(SELECT cod_reg FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND mese=12 AND anno=(SELECT anno FROM siope_spese WHERE mese=12 GROUP BY anno HAVING count(DISTINCT codice_istat)>=6500 ORDER BY anno DESC LIMIT 1) AND popolazione>0 GROUP BY 1" limit="1600"}

::slider[sensibilita]{label="Quota attesa di anomalie" min="0.01" max="0.2" step="0.01" value="0.05"}

::ml-anomaly{data="profiliRegione" features="personale,beni_servizi,trasferimenti,investimenti" contamination="#sensibilita" into="comuniAnomali"}

::table{path="comuniAnomali" filter="flag=1" search page-size="10" sort="anomalia" dir="desc"}
::column{field="comune" label="Comune"}
::column{field="personale" label="Personale €/ab" align="end"}
::column{field="beni_servizi" label="Beni e servizi" align="end"}
::column{field="trasferimenti" label="Trasferimenti" align="end"}
::column{field="investimenti" label="Investimenti" align="end"}
::column{field="anomalia" label="Punteggio" align="end"}
::/table

## Comuni che spendono come il tuo

Il k-means raggruppa i comuni della regione per profilo di spesa pro capite:
cerca il tuo nella tabella e guarda in che famiglia è finito.

::slider[kCluster]{label="Numero di gruppi" min="2" max="8" step="1" value="5"}

::ml-cluster{data="profiliRegione" features="personale,beni_servizi,trasferimenti,investimenti" k="#kCluster" into="famiglieComuni"}

::table{path="famiglieComuni" search page-size="10" filters="cluster"}
::column{field="comune" label="Comune"}
::column{field="cluster" label="Gruppo" align="end"}
::column{field="personale" label="Personale" align="end"}
::column{field="beni_servizi" label="Beni e servizi" align="end"}
::column{field="investimenti" label="Investimenti" align="end"}
::/table

## Spesa e reddito: cosa si muove insieme

La correlazione fra le voci pro capite e il reddito medio dichiarato nei comuni
della regione. Un r vicino a ±1 è un legame forte, e resta correlazione, non
causa.

::od-query{into="spesaReddito" sql="SELECT s.comune AS comune, round(sum(s.importo) FILTER (WHERE s.categoria_codice='1.01')/max(s.popolazione)) AS personale, round(sum(s.importo) FILTER (WHERE s.categoria_codice='1.03')/max(s.popolazione)) AS beni_servizi, round(sum(s.importo) FILTER (WHERE s.categoria_codice LIKE '2.%')/max(s.popolazione)) AS investimenti, max(r.reddito_medio) AS reddito FROM siope_spese s JOIN mef_redditi r ON r.codice_istat=s.codice_istat WHERE s.cod_reg=(SELECT cod_reg FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND s.mese=12 AND s.anno=(SELECT anno FROM siope_spese WHERE mese=12 GROUP BY anno HAVING count(DISTINCT codice_istat)>=6500 ORDER BY anno DESC LIMIT 1) AND s.popolazione>0 GROUP BY 1" limit="1600"}

::ml-correlate{data="spesaReddito" features="personale,beni_servizi,investimenti,reddito" into="correlazioni"}

::table{path="correlazioni" sort="r" dir="desc"}
::column{field="a" label="Variabile A"}
::column{field="b" label="Variabile B"}
::column{field="r" label="r" align="end"}
::/table

## Ribassi anomali negli appalti della provincia

Combinazioni insolite di importo e ribasso rispetto al resto della provincia: un
punto da cui partire per chi vuole guardarci dentro, non una lista di colpevoli.

::od-query{into="ribassiProvincia" sql="SELECT g.oggetto_gara AS oggetto, g.amministrazione AS amministrazione, round(g.importo_lotto/1e3) AS migliaia, round(a.ribasso,1) AS ribasso, a.offerte_ammesse AS offerte FROM anac_cig g JOIN anac_aggiudicatari a ON a.cig=g.cig WHERE substr(g.luogo_istat,1,3)=substr((SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1),1,3) AND a.ribasso IS NOT NULL AND a.ribasso BETWEEN 0.1 AND 99 AND g.importo_lotto>10000" limit="1000"}

::ml-anomaly{data="ribassiProvincia" features="migliaia,ribasso" contamination="0.04" into="gareAnomale"}

::table{path="gareAnomale" filter="flag=1" search page-size="10" sort="anomalia" dir="desc"}
::column{field="oggetto" label="Oggetto"}
::column{field="amministrazione" label="Amministrazione"}
::column{field="migliaia" label="Migliaia €" align="end"}
::column{field="ribasso" label="Ribasso %" align="end"}
::column{field="offerte" label="Offerte" align="end"}
::/table

La serie di spesa comunale è corta — cinque anni chiusi, uno per anno — e su
cinque punti una previsione è un'estrapolazione, non un piano: alzare
l'orizzonte a quattro anni allarga l'errore molto più di quanto il grafico
lasci vedere. Le anomalie e i gruppi si calcolano su un solo anno e su quattro
voci, quindi un comune montano con poche centinaia di abitanti risulta anomalo
per aritmetica prima che per gestione. Sui ribassi valgono gli avvisi della
pagina Appalti: gli importi ANAC hanno errori di fonte e i valori fuori scala
sono già stati esclusi qui sopra.
::/page

::page{title="Esplora" icon="pivot"}
## Il pivot: le tue domande, trascinando

Tutta la spesa del comune scelto — anno per anno e voce per voce. Trascina le
colonne per raggruppare, cambia tipo di grafico, filtra. Funziona anche in
modalità Uso, senza aprire l'editor.

::od-query{into="pivotSpesa" sql="SELECT anno AS anno, mese AS mese, titolo AS titolo, categoria AS categoria, round(importo) AS importo FROM siope_spese WHERE codice_istat=(SELECT codice_istat FROM istat_confini_comuni WHERE upper(strip_accents(comune))=upper(strip_accents(trim('{#comune}'))) ORDER BY codice_istat LIMIT 1) AND categoria_codice NOT IN ('7.01','7.02','0.00') ORDER BY anno, categoria" limit="1000"}

::explore{path="pivotSpesa" view="bar" group-by="categoria" columns="importo" height="30rem"}

Ci sono dentro anche gli anni parziali, riconoscibili dalla colonna dei mesi:
raggruppando per anno senza escluderli, l'ultima barra è più bassa perché
l'anno non è finito, non perché la spesa sia calata. Le righe scaricate restano
leggibili anche senza rete — la collection è la copia locale, e quando il
servizio non risponde le viste mostrano l'ultima buona con lo stato «stale».
::/page

::page{title="Fonti" icon="book"}
## Da dove vengono i dati

Tutte le fonti sono dati aperti ufficiali, aggiornati periodicamente dal
servizio dati e interrogati al volo. Questa app non conserva niente su nessun
server: le righe scaricate restano nel browser.

| Dato | Fonte | Licenza | Aggiornamento |
|---|---|---|---|
| Spesa ed entrate per cassa dei comuni | [OpenBDAP — MEF, Ragioneria Generale dello Stato](https://bdap-opendata.rgs.mef.gov.it/catalog/RND_SPE_SIO) (flussi SIOPE) | CC BY | mensile |
| Progetti di coesione e PNRR | [OpenCoesione](https://opencoesione.gov.it/it/opendata/) | CC BY 4.0 | bimestrale |
| Investimenti pubblici (CUP) | [OpenCUP — DIPE, Presidenza del Consiglio](https://www.opencup.gov.it/portale/web/opencup/accesso-agli-open-data) | CC BY | mensile |
| Gare d'appalto e aggiudicatari | [ANAC — dati.anticorruzione.it](https://dati.anticorruzione.it/opendata) | CC BY-SA 4.0 | mensile |
| Redditi IRPEF per comune | [MEF — Dipartimento delle Finanze](https://www.finanze.gov.it/it/statistiche-fiscali/open-data-comunale-principali-variabili-irpef/) | CC BY 3.0 | annuale |
| Popolazione e confini comunali | [ISTAT](https://www.istat.it/notizia/confini-delle-unita-amministrative-a-fini-statistici/) | CC BY | annuale |
| Mappa di sfondo | © OpenStreetMap contributors | ODbL | — |

## Note metodologiche

- **Cassa, non competenza.** Gli importi SIOPE sono i pagamenti e gli incassi
  effettuati nell'anno, non gli impegni e gli accertamenti di bilancio. Un
  investimento deciso quest'anno può essere pagato nei prossimi; il confronto
  fra comuni resta valido perché la metrica è la stessa per tutti.
- **Partite di giro escluse.** Dai totali sono tolti i giri contabili — spese
  7.01 e 7.02, entrate 9.01 e 9.02 — e i movimenti da regolarizzare (0.00):
  non sono spesa né entrata vera.
- **Anno chiuso e anno pieno sono due cose diverse.** La scheda del comune usa
  l'ultimo anno che *quel* comune ha chiuso a dodici mesi; i confronti
  regionali e la mappa usano l'ultimo anno in cui almeno 6.500 comuni hanno
  trasmesso il dicembre, perché una classifica su una regione mezza vuota non
  è una classifica.
- **Il comune si risolve per nome.** La scelta è un nome scritto a mano: fra
  due comuni omonimi la app prende quello con il codice ISTAT più basso.
  L'elenco sotto la casella mostra la sigla di provincia, che è il modo per
  accorgersene.
- **Machine learning.** Previsioni, anomalie e gruppi sono calcolati sul
  dispositivo e sono letture statistiche: scostamenti, non giudizi.
::/page
