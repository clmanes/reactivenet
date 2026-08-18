---
appId: mobilita-comune
title: "Mobilità del comune"
description: "Come ci si muove in ogni comune italiano e come va a finire: incidenti stradali dal 2001, parco veicolare per classe Euro, chi entra e chi esce per lavoro e con quale mezzo, e — dove esiste — i monopattini in condivisione in tempo reale. Dati ufficiali ISTAT, ACI e GBFS."
icon: car
lang: it
version: "1.0"
author: "ReactiveNET"
date: "2026-08-17"
---

::od-query{into="comuniMob" sql="SELECT g.codice_istat AS codice, g.comune || ' (' || g.sigla || ')' AS nome FROM istat_confini_comuni g ORDER BY 2" limit="8000"}

::choose[comune]{path="comuniMob" field="codice" label="nome" legend="Comune" value="063049" help="Tutte le pagine seguono questa scelta."}

::page{title="Sicurezza stradale" icon="alert"}

# Come va a finire

Di tutto quello che si può misurare sugli spostamenti, questa è l'unica cosa che
è un **esito** e non una dotazione: quante auto ci sono, dove passano le strade e
chi va a lavorare dove sono tre domande sulla struttura, e nessuna dice come va a
finire. Questa sì, per ogni comune italiano e per ventiquattro anni di fila.

::od-query{into="ultimoAnno" sql="SELECT comune, anno, incidenti, morti, feriti FROM incidenti_stradali WHERE codice_istat = '{#comune}' AND anno = (SELECT max(anno) FROM incidenti_stradali)"}

::columns{min="12rem" gap="m"}

**:sum{path="ultimoAnno" field="incidenti"}** incidenti con feriti

**:sum{path="ultimoAnno" field="morti"}** morti

**:sum{path="ultimoAnno" field="feriti"}** feriti

nell'anno :sum{path="ultimoAnno" field="anno"}

::/columns

::if-empty{path="ultimoAnno"}
Nessun dato per questo comune. Può succedere ai comuni nati da una fusione
recente: la serie storica li conosce con i codici che avevano prima.
::/if-empty

## Ventiquattro anni

Uno **zero è un dato**, e circa milleseicento comuni l'anno hanno esattamente
zero incidenti. Se la linea qui sotto sta a terra non è un buco: è la risposta
migliore possibile.

::od-query{into="serieIncidenti" sql="SELECT anno, incidenti, feriti FROM incidenti_stradali WHERE codice_istat = '{#comune}' ORDER BY anno" limit="40"}

::chart-line{data="serieIncidenti" x="anno" y="incidenti,feriti" height="300"}

I morti stanno su una scala completamente diversa — decine contro migliaia — e
messi nello stesso grafico diventerebbero una riga appiattita sull'asse. Hanno il
loro.

::od-query{into="serieMorti" sql="SELECT anno, morti FROM incidenti_stradali WHERE codice_istat = '{#comune}' ORDER BY anno" limit="40"}

::chart-line{data="serieMorti" x="anno" y="morti" height="240"}

## Rispetto a dove sta

Il numero da solo non dice niente: un comune grande ha più incidenti di uno
piccolo perché ha più gente. Questo è il tasso ogni **diecimila abitanti**,
confrontato con la provincia, la regione e l'Italia.

::od-query{into="confronto" sql="WITH a AS (SELECT max(anno) y FROM incidenti_stradali), s AS (SELECT sigla, regione FROM istat_confini_comuni WHERE codice_istat = '{#comune}'), b AS (SELECT i.codice_istat, i.sigla, i.regione, i.incidenti, p.popolazione FROM incidenti_stradali i JOIN istat_popolazione p USING (codice_istat), a WHERE i.anno = a.y) SELECT amb.ambito, round(CASE amb.ambito WHEN 'Comune' THEN (SELECT sum(incidenti)*10000.0/nullif(sum(popolazione),0) FROM b WHERE codice_istat = '{#comune}') WHEN 'Provincia' THEN (SELECT sum(incidenti)*10000.0/nullif(sum(popolazione),0) FROM b WHERE sigla = (SELECT sigla FROM s)) WHEN 'Regione' THEN (SELECT sum(incidenti)*10000.0/nullif(sum(popolazione),0) FROM b WHERE regione = (SELECT regione FROM s)) ELSE (SELECT sum(incidenti)*10000.0/nullif(sum(popolazione),0) FROM b) END, 1) AS per_10k FROM (SELECT unnest(['Comune','Provincia','Regione','Italia']) AS ambito) amb"}

::chart-bar{data="confronto" x="ambito" y="per_10k" height="260"}

Il denominatore è la popolazione residente **di oggi**, che è l'unica annata che
il warehouse tiene: per l'ultimo anno di incidenti è un'approssimazione onesta,
e su una serie lunga non lo sarebbe. È anche il denominatore sbagliato per un
paese di duemila abitanti attraversato da una statale, dove gli incidenti li
fanno persone che lì non abitano — il tasso alto di certi comuni piccoli è
questo, non guida spericolata.

::/page

::page{title="Che cosa circola" icon="car"}

# Il parco veicolare

::od-query{into="parcoTot" sql="SELECT comune, anno, totale, euro_0_3, round(euro_0_3_pct,1) AS quota_vecchi FROM aci_veicoli_euro WHERE codice_istat = '{#comune}' AND anno = (SELECT max(anno) FROM aci_veicoli_euro)"}

Sono **:sum{path="parcoTot" field="totale"}** veicoli, di cui
**:sum{path="parcoTot" field="quota_vecchi" decimals="1"}%** di classe Euro 3 o
più vecchia — cioè immatricolati prima del 2006. È la quota che decide chi resta
fuori quando una città chiude il centro alle auto più inquinanti.

::od-query{into="parcoEuro" sql="SELECT unnest(['Euro 0-3','Euro 4','Euro 5','Euro 6']) AS classe, unnest([euro_0+euro_1+euro_2+euro_3, euro_4, euro_5+euro_5b, euro_6+euro_6a+euro_6b+euro_6c+euro_6d+euro_6e]) AS veicoli FROM aci_veicoli_euro WHERE codice_istat = '{#comune}' AND anno = (SELECT max(anno) FROM aci_veicoli_euro)"}

::chart-doughnut{data="parcoEuro" label="classe" value="veicoli" height="300"}

Un avvertimento che vale per tutta questa pagina: il dato è il **Pubblico
Registro Automobilistico**, cioè dove il veicolo è *registrato*, non dove circola
né dove abita chi lo guida. I grandi noleggiatori registrano flotte intere su
pochi indirizzi, e il comune di Trento risulta con più autovetture di Napoli a
fronte di centodiciottomila abitanti. Non è un errore di questa app: è così nella
fonte.

::/page

::page{title="Chi si muove" icon="train"}

# Chi entra, chi esce

::od-query{into="saldo" sql="SELECT (SELECT sum(individui) FROM pendolarismo WHERE codice_istat = '{#comune}' AND destinazione = 'altro comune') AS escono, (SELECT sum(individui) FROM pendolarismo WHERE codice_istat_destinazione = '{#comune}' AND destinazione = 'altro comune') AS entrano"}

Ogni giorno **:sum{path="saldo" field="escono"}** persone escono da questo comune
e **:sum{path="saldo" field="entrano"}** ci arrivano da fuori. Quale delle due è
la più grande dice quasi tutto: un posto dove si viene a lavorare, o un posto da
cui si parte la mattina.

::od-query{into="uscita" sql="SELECT g.comune AS luogo, sum(p.individui) AS persone FROM pendolarismo p JOIN istat_confini_comuni g ON g.codice_istat = p.codice_istat_destinazione WHERE p.codice_istat = '{#comune}' AND p.destinazione = 'altro comune' GROUP BY 1 ORDER BY 2 DESC LIMIT 10"}

::od-query{into="entrata" sql="SELECT g.comune AS luogo, sum(p.individui) AS persone FROM pendolarismo p JOIN istat_confini_comuni g ON g.codice_istat = p.codice_istat WHERE p.codice_istat_destinazione = '{#comune}' AND p.destinazione = 'altro comune' GROUP BY 1 ORDER BY 2 DESC LIMIT 10"}

### Dove vanno quelli che escono

::chart-bar{data="uscita" x="luogo" y="persone" horizontal height="320"}

### Da dove arrivano quelli che entrano

::chart-bar{data="entrata" x="luogo" y="persone" horizontal height="320"}

I due grafici dicono **con chi** è il legame, non quanto è grosso: ognuno si
ridimensiona sui propri dati, quindi le barre dell'uno non sono confrontabili con
quelle dell'altro nemmeno quando sembrano lunghe uguale — per il quanto ci sono i
due numeri qui sopra. Quello che si legge qui è la forma della rete: pochi legami
spessi verso una città sola, o tanti legami sottili sparsi all'intorno.

## Con che cosa

::od-query{into="mezzi" sql="SELECT mezzo, sum(individui) AS persone FROM pendolarismo_mezzo WHERE codice_istat = '{#comune}' GROUP BY 1 ORDER BY 2 DESC" limit="30"}

::chart-bar{data="mezzi" x="mezzo" y="persone" horizontal height="380"}

**L'annata è il 2011, e non è una scelta.** La matrice del Censimento 2021
esiste ma il canale con cui si scaricano i dati non la serve: sul portale ISTAT
è dichiarata e scollegata. Quindici anni comprendono la diffusione del lavoro da
remoto, quindi questi numeri vanno letti per la **struttura** dei legami — chi
gravita su chi — molto più che per le quantità.

::/page

::page{title="In tempo reale" icon="location"}

# I mezzi in condivisione, adesso

Tutto il resto di questa app è una serie storica: qualcuno l'ha raccolta,
pubblicata, e noi la leggiamo mesi dopo. Questa pagina no — chiede a un servizio
dove sono i suoi monopattini nel momento in cui la stai guardando, e si aggiorna
da sola ogni minuto.

**E qui va detto il limite, perché è grosso.** Il tempo reale in Italia esiste
dove c'è lo sharing e finisce lì: su 7.896 comuni, ventitré hanno un sistema che
risponde. Non è una mancanza di questa app — è che il **Punto di Accesso
Nazionale**, l'aggregatore che l'Europa impone per gli orari del trasporto
pubblico, al momento non risponde alle richieste. Quando tornerà su, gli autobus
di mezza Italia potranno stare in questa pagina.

Il selettore qui sotto è diverso da quello in cima: elenca le città della rete
più estesa fra quelle disponibili, e non i comuni italiani, perché offrire una
scelta che per il 99,7% dei casi non porta a niente sarebbe una promessa falsa.

::od-query{into="cittaSharing" sql="SELECT comune AS nome, regexp_extract(url_stato,'/v2/([^/]+)/',1) AS slug FROM gbfs_sistemi WHERE errore IS NULL AND url_stato LIKE '%ridedott%' ORDER BY 1" limit="50"}

::choose[citta]{path="cittaSharing" field="slug" label="nome" legend="Città" value="padua"}

::api-query{url="https://gbfs.api.ridedott.com/public/v2/{#citta}/free_bike_status.json" into="monopattini" pick="data.bikes" every="60"}

In questo momento ci sono **:count{path="monopattini"}** mezzi sulla strada.

::map{path="monopattini" lat="lat" lon="lon" height="520"}
Mezzo `{bike_id}`
::/map

Ogni punto è un veicolo fermo che aspetta qualcuno. La mappa si ridisegna da
sola: lasciala aperta un minuto e qualche punto si sposterà, perché nel
frattempo qualcuno l'ha preso.

## Perché questo non è nel magazzino dati

Le posizioni non sono salvate da nessuna parte: arrivano dal servizio al browser
e restano lì. È una scelta, non una mancanza. Un monopattino si sposta ogni
minuto mentre il magazzino si aggiorna ogni pochi giorni, quindi una fotografia
conservata sarebbe un dato vecchio *che sembra vivo* — e un dato che sembra vivo
e non lo è inganna peggio di un dato assente, perché nessuno lo va a controllare.

Quello che invece è conservato è il **catalogo**: quali sistemi esistono, in che
comune, e a quale indirizzo rispondono. Quello cambia quando un operatore entra o
esce da una città, cioè raramente, ed è esattamente il genere di cosa che un
magazzino dati deve tenere.

::/page

::page{title="Da dove viene" icon="data"}

# Le fonti, e cosa non c'è

| Cosa | Fonte | Annata |
| --- | --- | --- |
| Incidenti, morti, feriti | ISTAT — incidenti stradali per comune | 2001-2024 |
| Parco veicolare per classe Euro | ACI — Autoritratto | l'ultima disponibile |
| Chi entra e chi esce, e con che mezzo | ISTAT — matrice del pendolarismo | 2011 |
| Popolazione residente | ISTAT — bilancio demografico | l'ultima disponibile |
| Mezzi in condivisione | GBFS, i gestori stessi | adesso |

Tre cose che questa app **non** può mostrare, e conviene sapere perché:

- **gli orari e i passaggi del trasporto pubblico.** Esiste un aggregatore
  nazionale che per legge europea dovrebbe pubblicarli tutti; al momento non
  risponde. Non è un dato che manca, è un servizio spento;
- **il traffico.** Nessuno lo pubblica in modo aperto e uniforme per comune: i
  conteggi ci sono, ma dentro applicazioni che si consultano una strada alla
  volta;
- **il pendolarismo di oggi.** La matrice del 2021 è stata pubblicata ma non è
  scaricabile: sul portale ISTAT il canale che dovrebbe servirla è dichiarato e
  vuoto. Il giorno in cui verrà collegato, questa pagina cambierà annata e basta.

Il numero più delicato di tutta l'app è il **tasso per diecimila abitanti**:
mette al denominatore chi *risiede*, mentre gli incidenti li fanno anche quelli
che passano. Per una città è ragionevole; per un paese piccolo su una strada di
grande traffico è ingeneroso, e va letto sapendolo.

::/page
