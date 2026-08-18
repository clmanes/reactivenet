---
appId: segreteria
title: Segreteria
description: "Il cruscotto operativo della segreteria scolastica: pratiche con flusso configurabile, scadenzario degli adempimenti, contatori contrattuali del personale, contratti, acquisti e inventario, report e stampe."
icon: folder-user
lang: it
version: "1.0"
author: ReactiveNET
date: "2026-08-13"
---

::page{title="Avvio" icon="folder-user"}

# Segreteria

Il livello che oggi manca fra il gestionale ministeriale e la memoria
dell'assistente amministrativo: **dove sta una pratica, chi la sta lavorando, che
cosa scade quando, quali contatori sono a saldo.** Quello che vive in fogli di
calcolo condivisi, cartelle di rete e post-it.

## Quello che questa app NON è

Non sostituisce e non replica:

- il **SIDI** e i flussi ministeriali obbligatori;
- il **protocollo informatico a norma** e la conservazione digitale — che
  richiedono un conservatore accreditato e non si simulano: qui c'è un campo per il
  numero di protocollo *vero*, assegnato altrove, e nient'altro;
- il registro elettronico e lo scrutinio;
- la contabilità di bilancio, i mandati e la firma digitale qualificata.

Dove servirebbe uno di questi, questa app tiene un **riferimento** e un export, non
una finta implementazione.

## Che cosa fa

| Fa | Non fa |
| --- | --- |
| Pratiche con tipi, termini e checklist **configurabili dall'interfaccia** | Non protocolla: registra il numero che il protocollo ha assegnato |
| Vista kanban per stato e tabella ad alta densità | Non manda notifiche: nessuna mail parte da qui |
| Scadenzario degli adempimenti ricorrenti, con lo storico | Non conosce il calendario regionale: le date si scrivono |
| Contatori contrattuali per unità e per anno, con i limiti | Non liquida nulla e non calcola stipendi |
| Contratti e decreti a termine con il preavviso di scadenza | Non trasmette al SIDI |
| Acquisti, CIG, DURC e carico in inventario | Non è contabilità: gli importi sono per sapere, non per rendicontare |
| Modulistica con segnaposto e stampa massiva | Non firma digitalmente |

## Dati sanitari: non ce ne sono

Delle assenze si registrano **il tipo secondo la codifica contrattuale e i giorni**.
Mai una diagnosi, mai la patologia, mai la condizione del familiare. Del certificato
medico si registra l'estremo — numero e data — e non il certificato.

Il conteggio dei permessi previsti dalla legge 104 è **un numero di giorni**: quel
numero serve per il contatore, e nulla di quello che vi sta dietro entra qui.

## Chi possiede che cosa

| Padrone | Collezioni |
| --- | --- |
| Tu, con un modulo | `personale-aggiunto`, `tipi-aggiunti`, `adempimenti-aggiunti`, `pratiche`, `assenze`, `contratti`, `fornitori`, `acquisti`, `inventario` |
| Un blocco | `personale`, `tipi-pratica`, `adempimenti`, `contatori`, `allarmi`, `tempi` |

## Semina l'istituto di esempio

L'IC «Ada Lovelace»: personale, tipi di pratica e adempimenti tipici di un anno.
Premi i tre pulsanti.

::python{data="personale-aggiunto" writes="personale" manual}
```python
# Personale inventato. Part-time, contratti al 30/06 e supplenze brevi ci sono
# perché sono la norma, non il caso difficile.
righe = [
    ("M001", "Alberti", "Franca", "docente", "tempo indeterminato", "A022", "centrale", "2011-09-01", "", "100"),
    ("M002", "Belli", "Ruggero", "docente", "tempo indeterminato", "A028", "centrale", "2015-09-01", "", "100"),
    ("M003", "Carra", "Ilaria", "docente", "determinato al 31/08", "A022", "succursale", "2026-09-01", "2027-08-31", "100"),
    ("M004", "Dessì", "Piero", "docente", "determinato al 30/06", "AD00", "centrale", "2026-09-01", "2027-06-30", "100"),
    ("M005", "Esposito", "Nadia", "docente", "tempo indeterminato", "A001", "centrale", "2008-09-01", "", "50"),
    ("M006", "Fontana", "Guido", "docente", "supplenza breve", "A022", "succursale", "2027-01-12", "2027-02-06", "100"),
    ("M007", "Gatti", "Serena", "assistente amministrativo", "tempo indeterminato", "AA", "centrale", "2013-01-07", "", "100"),
    ("M008", "Husu", "Andrei", "assistente amministrativo", "determinato al 31/08", "AA", "centrale", "2026-09-01", "2027-08-31", "100"),
    ("M009", "Izzo", "Carmela", "assistente tecnico", "tempo indeterminato", "AR02", "succursale", "2017-09-01", "", "100"),
    ("M010", "Lo Bianco", "Vito", "collaboratore scolastico", "tempo indeterminato", "CS", "centrale", "2005-09-01", "", "100"),
    ("M011", "Manca", "Rosa", "collaboratore scolastico", "tempo indeterminato", "CS", "succursale", "2019-09-01", "", "75"),
    ("M012", "Nifosì", "Elio", "collaboratore scolastico", "determinato al 30/06", "CS", "centrale", "2026-09-01", "2027-06-30", "100"),
    ("M013", "Orru", "Bruna", "DSGA", "tempo indeterminato", "DSGA", "centrale", "2016-09-01", "", "100"),
]

result = []
for r in righe:
    result.append({
        "id": r[0].lower(), "matricola": r[0], "cognome": r[1], "nome": r[2],
        "profilo": r[3], "contratto": r[4], "area": r[5], "sede": r[6],
        "assunzione": r[7], "fineContratto": r[8], "partTime": r[9],
        "stato": "in servizio",
    })

campi = ["matricola", "cognome", "nome", "profilo", "contratto", "area", "sede",
         "assunzione", "fineContratto", "partTime", "stato"]
for riga in data["personale-aggiunto"]:
    nuova = {"id": riga.get("id", "")}
    for campo in campi:
        nuova[campo] = riga.get(campo, "")
    result.append(nuova)

print("%d unità di personale." % len(result))
print("Di cui a termine: %d." % sum(1 for r in result if r.get("fineContratto")))
```
::/python

::python{data="tipi-aggiunti" writes="tipi-pratica" manual}
```python
# I tipi di pratica sono DATI. Aggiungerne uno, con il suo termine e la sua
# checklist, non richiede di toccare il programma: è un modulo nella pagina
# Configurazione.
righe = [
    ("certificato-servizio", "Certificato di servizio", "personale", 15, "Richiesta protocollata|Verifica del fascicolo|Redazione|Firma DS|Consegna", "true"),
    ("nulla-osta-alunno", "Nulla osta al trasferimento alunno", "didattica", 10, "Richiesta della famiglia|Verifica posizione|Nulla osta scuola di destinazione|Firma DS|Comunicazione", "true"),
    ("duplicato-diploma", "Richiesta duplicato diploma", "didattica", 30, "Domanda in bollo|Verifica registro diplomi|Richiesta al MIM|Consegna", "false"),
    ("iscrizione", "Iscrizione", "didattica", 20, "Domanda|Documenti|Verifica obbligo vaccinale|Inserimento", "false"),
    ("infortunio-alunno", "Infortunio alunno", "didattica", 2, "Segnalazione docente|Referto|Denuncia INAIL|Comunicazione assicurazione|Archiviazione", "false"),
    ("istanza-ferie", "Istanza di ferie", "personale", 5, "Domanda|Verifica capienza contatore|Autorizzazione|Registrazione", "false"),
    ("permesso-retribuito", "Permesso retribuito", "personale", 5, "Domanda|Documentazione|Verifica limite|Autorizzazione", "false"),
    ("congedo", "Congedo", "personale", 10, "Domanda|Documentazione|Decreto|Comunicazione", "true"),
    ("accesso-atti", "Richiesta di accesso agli atti", "affari generali", 30, "Istanza|Verifica legittimazione|Notifica controinteressati|Risposta motivata", "true"),
    ("decreto-supplente", "Decreto di assunzione supplente", "personale", 3, "Individuazione|Verifica requisiti|Contratto|Trasmissione", "true"),
    ("ordine-acquisto", "Ordine di acquisto", "acquisti", 15, "Richiesta|Preventivi|Verifica DURC|Autorizzazione|Ordine|Collaudo", "false"),
    ("manutenzione", "Richiesta di manutenzione", "affari generali", 30, "Segnalazione|Sopralluogo|Richiesta all'ente proprietario|Sollecito", "false"),
]

result = []
for r in righe:
    result.append({
        "id": "t-" + r[0], "codice": r[0], "nome": r[1], "area": r[2],
        "termineGiorni": str(r[3]), "checklist": r[4], "firmaDS": r[5],
    })

campi = ["codice", "nome", "area", "termineGiorni", "checklist", "firmaDS"]
for riga in data["tipi-aggiunti"]:
    nuova = {"id": riga.get("id", "")}
    for campo in campi:
        nuova[campo] = riga.get(campo, "")
    result.append(nuova)

print("%d tipi di pratica, su %d aree."
      % (len(result), len(set(r["area"] for r in result))))
```
::/python

::python{data="adempimenti-aggiunti" writes="adempimenti" manual}
```python
# Gli adempimenti ricorrenti di un anno scolastico. Sono DATI: le date cambiano
# ogni anno e con l'ordinanza, e un programma che le portasse dentro sarebbe da
# riscrivere ogni settembre.
righe = [
    ("Organico di diritto", "didattica", "2027-04-15", 30, "DSGA"),
    ("Iscrizioni", "didattica", "2027-01-31", 30, "area didattica"),
    ("Graduatorie interne d'istituto", "personale", "2027-03-15", 21, "area personale"),
    ("Adozioni libri di testo", "didattica", "2027-05-31", 30, "area didattica"),
    ("Aggiornamento PTOF", "affari generali", "2026-12-31", 45, "DS"),
    ("Contrattazione integrativa d'istituto", "affari generali", "2026-11-30", 30, "DSGA"),
    ("Programma annuale", "affari generali", "2026-11-30", 30, "DSGA"),
    ("Conto consuntivo", "affari generali", "2027-04-30", 30, "DSGA"),
    ("Ricognizione inventario", "acquisti", "2027-06-30", 45, "DSGA"),
    ("Prova di evacuazione (prima)", "affari generali", "2026-11-15", 15, "RSPP"),
    ("Prova di evacuazione (seconda)", "affari generali", "2027-03-31", 15, "RSPP"),
    ("Formazione sicurezza nuovi assunti", "personale", "2026-12-15", 30, "RSPP"),
    ("Verifica impianti antincendio", "affari generali", "2027-02-28", 30, "DSGA"),
    ("Rinnovo incarichi ATA", "personale", "2026-09-30", 15, "DSGA"),
    ("Dichiarazione di accessibilità AgID", "affari generali", "2027-09-23", 30, "DS"),
]

result = []
for i, r in enumerate(righe, start=1):
    result.append({
        "id": "ad-%03d" % i, "titolo": r[0], "area": r[1], "scadenza": r[2],
        "preavvisoGiorni": str(r[3]), "responsabile": r[4],
        "ricorrenza": "annuale", "stato": "da fare", "documento": "",
    })

campi = ["titolo", "area", "scadenza", "preavvisoGiorni", "responsabile",
         "ricorrenza", "stato", "documento"]
for riga in data["adempimenti-aggiunti"]:
    nuova = {"id": riga.get("id", "")}
    for campo in campi:
        nuova[campo] = riga.get(campo, "")
    result.append(nuova)

print("%d adempimenti in scadenzario." % len(result))
```
::/python

::/page

::page{title="Cruscotto" icon="dashboard"}

# Cruscotto

::if-any{path="pratiche"}
Pratiche aperte: **:count{path="pratiche"}**.

::dashboard{path="pratiche"}
### Per area

::chart-pie{data="pratiche" label="area" value="uno" height="16rem"}

### Per stato

::chart-bar{data="pratiche" x="stato" y="uno" height="16rem"}

### Il dettaglio, filtrato da quello che clicchi qui sopra

::table{path="pratiche" search page-size="10" sort="termine"}
::column{field="oggetto" label="Oggetto"}
::column{field="area" label="Area"}
::column{field="assegnata" label="Assegnata a"}
::column{field="stato" label="Stato"}
::column{field="termine" label="Termine"}
::/table
::/dashboard
::/if-any

::if-empty{path="pratiche"}
Nessuna pratica aperta. Se ne apre una dalla pagina *Pratiche*.
::/if-empty

## Che cosa non va

Il blocco guarda pratiche, contatori, contratti, DURC e scadenzario e mette in fila
solo le cose che richiedono una decisione oggi.

**Va eseguito per ultimo**: legge quello che gli altri blocchi hanno scritto, e al
primo avvio — con i contatori non ancora calcolati — non ha molto da dire.

::python{data="pratiche,tipi-pratica,contatori,contratti,fornitori,adempimenti" writes="allarmi" manual}
```python
import datetime

def intero(v, d=0):
    try:
        return int(float(str(v).strip().replace(",", ".")))
    except (TypeError, ValueError):
        return d

oggi = datetime.date.today().isoformat()

def fra(giorni):
    return (datetime.date.today() + datetime.timedelta(days=giorni)).isoformat()

result = []
def segnala(gravita, ambito, che, quando):
    result.append({
        "id": "al-%03d" % (len(result) + 1),
        "gravita": gravita, "ambito": ambito, "che": che, "quando": quando,
    })

APERTE = ("nuova", "in lavorazione", "in attesa di documenti", "in attesa di firma", "sospesa")

for p in data["pratiche"]:
    if p.get("stato") not in APERTE:
        continue
    termine = p.get("termine", "")
    if not termine:
        continue
    if termine < oggi:
        segnala("scaduta", "pratica",
                "%s (%s)" % (p.get("oggetto", ""), p.get("assegnata", "non assegnata")), termine)
    elif termine <= fra(7):
        segnala("in scadenza", "pratica",
                "%s (%s)" % (p.get("oggetto", ""), p.get("assegnata", "non assegnata")), termine)

for c in data["contratti"]:
    fine = c.get("fine", "")
    if fine and oggi <= fine <= fra(30) and c.get("stato") != "cessato":
        segnala("in scadenza", "contratto",
                "%s — %s" % (c.get("unita", ""), c.get("tipo", "")), fine)

for f in data["fornitori"]:
    durc = f.get("scadenzaDurc", "")
    if durc and durc < oggi:
        segnala("scaduta", "DURC", f.get("ragioneSociale", ""), durc)

for a in data["adempimenti"]:
    if a.get("stato") == "assolto":
        continue
    scadenza = a.get("scadenza", "")
    if not scadenza:
        continue
    preavviso = intero(a.get("preavvisoGiorni"), 30)
    if scadenza < oggi:
        segnala("scaduta", "adempimento",
                "%s (%s)" % (a.get("titolo", ""), a.get("responsabile", "")), scadenza)
    elif scadenza <= fra(preavviso):
        segnala("in scadenza", "adempimento",
                "%s (%s)" % (a.get("titolo", ""), a.get("responsabile", "")), scadenza)

for c in data["contatori"]:
    if c.get("voce") == "Ferie residue" and intero(c.get("valore")) < 0:
        segnala("oltre il limite", "contatore",
                "%s: ferie godute oltre le spettanti" % c.get("unita", ""), oggi)
    if c.get("voce") == "Permessi retribuiti (art. 15) usati" and intero(c.get("valore")) > intero(c.get("limite")):
        segnala("oltre il limite", "contatore",
                "%s: permessi retribuiti oltre il limite" % c.get("unita", ""), oggi)

result.sort(key=lambda r: (0 if r["gravita"] == "scaduta" else 1 if r["gravita"] == "oltre il limite" else 2, r["quando"]))

print("Oggi è il %s." % oggi)
print("%d segnalazioni: %d scadute, %d in scadenza, %d oltre il limite."
      % (len(result),
         sum(1 for r in result if r["gravita"] == "scaduta"),
         sum(1 for r in result if r["gravita"] == "in scadenza"),
         sum(1 for r in result if r["gravita"] == "oltre il limite")))
```
::/python

::if-any{path="allarmi"}
::table{path="allarmi" filters="gravita,ambito" page-size="20"}
::column{field="gravita" label="Gravità"}
::column{field="ambito" label="Ambito"}
::column{field="che" label="Che cosa"}
::column{field="quando" label="Quando"}
::/table
::/if-any

::if-empty{path="allarmi"}
Niente in allarme — o il blocco non è ancora stato eseguito.
::/if-empty

::/page

::page{title="Pratiche" icon="task-list"}

# Pratiche

::form{path="pratiche" id="modPratica"}
::input{field="oggetto" legend="Oggetto" required}
::input{field="tipo" type="ref" path="tipi-pratica" label="nome" legend="Tipo di pratica" required}
::input{field="area" legend="Area" required pattern="didattica|personale|affari generali|acquisti" message="didattica, personale, affari generali, acquisti"}
::input{field="richiedente" legend="Richiedente"}
::input{field="riferimento" legend="Soggetto di riferimento" help="Alunno o unità di personale, come lo scriveresti su una cartellina."}
::input{field="apertura" type="date" legend="Data di apertura" required}
::input{field="termine" type="date" legend="Termine previsto" required help="Il tipo di pratica dice quanti giorni; qui si scrive la data."}
::input{field="assegnata" legend="Assegnata a"}
::input{field="stato" legend="Stato" required pattern="nuova|in lavorazione|in attesa di documenti|in attesa di firma|sospesa|evasa|archiviata" message="nuova, in lavorazione, in attesa di documenti, in attesa di firma, sospesa, evasa, archiviata" value="nuova"}
::input{field="priorita" legend="Priorità" pattern="alta|normale|bassa|" message="alta, normale, bassa"}
::input{field="protocollo" legend="Numero di protocollo" help="Quello vero, assegnato dal protocollo informatico. Qui è un riferimento."}
::input{field="note" legend="Note"}
::input{field="uno" type="number" legend="Conta come" value="1" min="1" max="1" help="Serve ai grafici: una pratica è una."}

Scrivi la richiesta a parole e l'assistente riempie la bozza; tu la rivedi e salvi.
Se non c'è un modello configurato, il pulsante lo dice e il modulo funziona lo stesso.

::ai-assist{form="modPratica" placeholder="La famiglia Rossi chiede il nulla osta per il trasferimento, arrivata oggi, urgente"}

::save{label="Apri la pratica"}
::/form

::if-any{path="pratiche"}
## Il flusso

Trascinare una scheda scrive lo stato su quella pratica. Su telefono il trascinamento
non esiste: si usa il pulsante di modifica della scheda.

::board{path="pratiche" group-by="stato" columns="nuova,in lavorazione,in attesa di documenti,in attesa di firma,sospesa,evasa" min="15rem" editform="modPratica" sort="termine"}
**{oggetto}**

{area} · {assegnata}

scade {termine}
::/board

## Tutte le pratiche

::table{path="pratiche" search filters="area,stato,assegnata" sort="termine" page-size="20" deletable editform="modPratica"}
::column{field="oggetto" label="Oggetto"}
::column{field="tipo" label="Tipo"}
::column{field="area" label="Area"}
::column{field="richiedente" label="Richiedente"}
::column{field="assegnata" label="Assegnata a"}
::column{field="stato" label="Stato"}
::column{field="termine" label="Termine"}
::column{field="protocollo" label="Prot."}
::/table

## Instradamento

L'assistente legge l'oggetto e sceglie **una** delle quattro aree. Una risposta fuori
dall'elenco viene scartata, non aggiunta: le aree di una segreteria sono quattro e
restano quattro.

::ai-classify{path="pratiche" field="area" values="didattica,personale,affari generali,acquisti" label="Assegna l'area alle pratiche che non ce l'hanno"}

Una regola scritta a parole, compilata **una volta sola** e poi eseguita senza
modello: da lì in avanti è deterministica, gira a ogni cambiamento dei dati e non
tocca le righe che sono già a posto.

::ai-rule{data="pratiche" when="la priorità è alta e lo stato è nuova" do="scrivi in note 'da smistare subito'" label="Attiva la regola"}

## Chiedi alle pratiche

::ai-query{data="pratiche" into="risposta-pratiche" placeholder="Quante pratiche aperte per area?"}

::if-any{path="risposta-pratiche"}
::table{path="risposta-pratiche"}
::column{field="area" label="Gruppo"}
::column{field="valore" label="Valore" align="end"}
::/table
::/if-any
::/if-any

::if-empty{path="pratiche"}
Nessuna pratica. La prima si apre dal modulo qui sopra.
::/if-empty

::/page

::page{title="Scadenzario" icon="calendar"}

# Scadenzario degli adempimenti

::form{path="adempimenti-aggiunti" id="modAdempimento"}
::input{field="titolo" legend="Adempimento" required}
::input{field="area" legend="Area" required pattern="didattica|personale|affari generali|acquisti" message="didattica, personale, affari generali, acquisti"}
::input{field="scadenza" type="date" legend="Scadenza" required}
::input{field="preavvisoGiorni" type="number" legend="Preavviso in giorni" min="0" max="365" value="30"}
::input{field="responsabile" legend="Responsabile"}
::input{field="ricorrenza" legend="Ricorrenza" pattern="una tantum|annuale|mensile|trimestrale|" message="una tantum, annuale, mensile, trimestrale"}
::input{field="stato" legend="Stato" pattern="da fare|in corso|assolto|" message="da fare, in corso, assolto"}
::input{field="documento" legend="Documento prodotto" help="Il riferimento della prova dell'assolvimento."}
::save{label="Salva l'adempimento"}
::/form

::if-any{path="adempimenti"}
::calendar{path="adempimenti" field="scadenza" by="area" view="agenda" tooltip="{titolo} — {responsabile}"}
**{titolo}** {responsabile}
::/calendar

::table{path="adempimenti" search filters="area,stato,responsabile" sort="scadenza" page-size="20"}
::column{field="scadenza" label="Scadenza"}
::column{field="titolo" label="Adempimento"}
::column{field="area" label="Area"}
::column{field="responsabile" label="Responsabile"}
::column{field="stato" label="Stato"}
::column{field="documento" label="Prova"}
::/table
::/if-any

::if-any{path="adempimenti-aggiunti"}
### I tuoi adempimenti

::table{path="adempimenti-aggiunti" deletable editform="modAdempimento" sort="scadenza"}
::column{field="scadenza" label="Scadenza"}
::column{field="titolo" label="Adempimento"}
::column{field="stato" label="Stato"}
::/table
::/if-any

::/page

::page{title="Personale" icon="user-group"}

# Personale e contatori

::form{path="personale-aggiunto" id="modUnita"}
::input{field="matricola" legend="Matricola" required}
::input{field="cognome" legend="Cognome" required}
::input{field="nome" legend="Nome" required}
::input{field="profilo" legend="Profilo" required help="docente, DSGA, assistente amministrativo, assistente tecnico, collaboratore scolastico"}
::input{field="contratto" legend="Tipologia di contratto" required help="tempo indeterminato, determinato al 31/08, determinato al 30/06, supplenza breve"}
::input{field="area" legend="Classe di concorso o area"}
::input{field="sede" legend="Sede di servizio"}
::input{field="assunzione" type="date" legend="Assunzione"}
::input{field="fineContratto" type="date" legend="Fine contratto"}
::input{field="partTime" type="number" legend="Percentuale di servizio" min="1" max="100" value="100"}
::input{field="stato" legend="Stato" pattern="in servizio|sospeso|cessato|" message="in servizio, sospeso, cessato"}
::save{label="Salva"}
::/form

::table{path="personale" search filters="profilo,contratto,sede" sort="cognome" page-size="20"}
::column{field="matricola" label="Matr."}
::column{field="cognome" label="Cognome"}
::column{field="nome" label="Nome"}
::column{field="profilo" label="Profilo"}
::column{field="contratto" label="Contratto"}
::column{field="partTime" label="%" align="end"}
::column{field="fineContratto" label="Fine"}
::/table

## Assenze

Si registra il **tipo secondo la codifica contrattuale** e i giorni. Del certificato
medico si registra l'estremo, non il certificato. Non c'è un campo diagnosi, e non
ci sarà.

::form{path="assenze" id="modAssenza"}
::input{field="unita" type="ref" path="personale" label="cognome" legend="Unità di personale" required}
::input{field="tipo" legend="Tipo di assenza" required pattern="ferie|festività soppresse|permesso retribuito|permesso breve|malattia|legge 104|congedo|sciopero|altro" message="ferie, festività soppresse, permesso retribuito, permesso breve, malattia, legge 104, congedo, sciopero, altro"}
::input{field="dal" type="date" legend="Dal" required}
::input{field="al" type="date" legend="Al" required}
::input{field="giorni" type="number" legend="Giorni" min="0" max="365" required}
::input{field="ore" type="number" legend="Ore (per i permessi brevi)" min="0" max="24"}
::input{field="anno" legend="Anno scolastico" required value="2026/2027"}
::input{field="estremoCertificato" legend="Estremo del certificato" help="Numero e data. Non il certificato."}
::input{field="note" legend="Note di servizio"}
::save{label="Registra l'assenza"}
::/form

::if-any{path="assenze"}
::table{path="assenze" search filters="tipo,anno" sort="dal" dir="desc" deletable editform="modAssenza" page-size="15"}
::column{field="unita" label="Unità"}
::column{field="tipo" label="Tipo"}
::column{field="dal" label="Dal"}
::column{field="al" label="Al"}
::column{field="giorni" label="Giorni" align="end"}
::/table

::calendar{path="assenze" field="dal" end="al" by="tipo" tooltip="{unita} — {tipo}"}
{unita} {tipo}
::/calendar
::/if-any

## I contatori

::python{data="personale,assenze" writes="contatori" manual}
```python
def intero(v, d=0):
    try:
        return int(float(str(v).strip().replace(",", ".")))
    except (TypeError, ValueError):
        return d

# I parametri contrattuali stanno QUI, in una tabella, e non sparsi nel codice:
# cambiano a ogni rinnovo, e questa è la riga da correggere quando succede.
SPETTANZE = {
    "docente":                   {"ferie": 32, "festivita": 4, "permessi15": 3},
    "DSGA":                      {"ferie": 32, "festivita": 4, "permessi15": 3},
    "assistente amministrativo": {"ferie": 32, "festivita": 4, "permessi15": 3},
    "assistente tecnico":        {"ferie": 32, "festivita": 4, "permessi15": 3},
    "collaboratore scolastico":  {"ferie": 32, "festivita": 4, "permessi15": 3},
}
DEFAULT = {"ferie": 32, "festivita": 4, "permessi15": 3}

per_unita = {}
for a in data["assenze"]:
    per_unita.setdefault(a.get("unita", ""), []).append(a)

result = []
def voce(unita, nome, valore, limite, misura):
    result.append({
        "id": "ct-%04d" % (len(result) + 1),
        "unita": unita, "voce": nome, "valore": str(valore),
        "limite": str(limite), "misura": misura,
    })

for p in data["personale"]:
    assenze = per_unita.get(p["id"], [])
    etichetta = "%s %s" % (p.get("cognome", ""), p.get("nome", ""))
    base = SPETTANZE.get(p.get("profilo", ""), DEFAULT)
    quota = max(1, intero(p.get("partTime"), 100)) / 100.0

    def giorni(tipo):
        return sum(intero(a.get("giorni")) for a in assenze if a.get("tipo") == tipo)

    spettanti = int(round(base["ferie"] * quota))
    godute = giorni("ferie")
    voce(etichetta, "Ferie spettanti", spettanti, spettanti, "giorni")
    voce(etichetta, "Ferie godute", godute, spettanti, "giorni")
    voce(etichetta, "Ferie residue", spettanti - godute, spettanti, "giorni")

    festivita = giorni("festività soppresse")
    voce(etichetta, "Festività soppresse residue",
         int(round(base["festivita"] * quota)) - festivita,
         int(round(base["festivita"] * quota)), "giorni")

    voce(etichetta, "Permessi retribuiti (art. 15) usati",
         giorni("permesso retribuito"), base["permessi15"], "giorni")

    ore_brevi = sum(intero(a.get("ore")) for a in assenze if a.get("tipo") == "permesso breve")
    voce(etichetta, "Permessi brevi da recuperare", ore_brevi, 36, "ore")

    # Il comporto si conta in GIORNI. Che cosa vi stia dietro non entra qui.
    voce(etichetta, "Giorni di malattia registrati", giorni("malattia"), 0, "giorni")
    # Anche questo è solo un conteggio.
    voce(etichetta, "Giorni di permesso legge 104", giorni("legge 104"), 0, "giorni")

fuori = [r for r in result
         if r["voce"] == "Ferie residue" and intero(r["valore"]) < 0]
print("%d contatori per %d unità." % (len(result), len(data["personale"])))
if fuori:
    print("%d unità hanno ferie godute oltre le spettanti." % len(fuori))
else:
    print("Nessun contatore fuori limite.")
```
::/python

::if-any{path="contatori"}
::table{path="contatori" search filters="unita,voce" page-size="20"}
::column{field="unita" label="Unità"}
::column{field="voce" label="Voce"}
::column{field="valore" label="Valore" align="end"}
::column{field="limite" label="Limite" align="end"}
::column{field="misura" label="Misura"}
::/table
::/if-any

::/page

::page{title="Contratti" icon="file-user"}

# Contratti e decreti

::form{path="contratti" id="modContratto"}
::input{field="unita" type="ref" path="personale" label="cognome" legend="Unità di personale" required}
::input{field="numero" legend="Numero progressivo" required}
::input{field="tipo" legend="Tipo" required pattern="contratto a tempo determinato|supplenza breve|decreto di assunzione|proroga|altro" message="contratto a tempo determinato, supplenza breve, decreto di assunzione, proroga, altro"}
::input{field="inizio" type="date" legend="Inizio" required}
::input{field="fine" type="date" legend="Fine"}
::input{field="oreSettimanali" type="number" legend="Ore settimanali" min="0" max="40"}
::input{field="posto" legend="Posto"}
::input{field="sostituisce" legend="Sostituisce"}
::input{field="stato" legend="Stato" pattern="bozza|firmato|trasmesso|cessato|" message="bozza, firmato, trasmesso, cessato"}
::save{label="Registra il contratto"}
::/form

::if-any{path="contratti"}
::table{path="contratti" search filters="tipo,stato" sort="fine" deletable editform="modContratto" page-size="20"}
::column{field="numero" label="N."}
::column{field="unita" label="Unità"}
::column{field="tipo" label="Tipo"}
::column{field="inizio" label="Inizio"}
::column{field="fine" label="Fine"}
::column{field="oreSettimanali" label="Ore" align="end"}
::column{field="stato" label="Stato"}
::/table

::calendar{path="contratti" field="inizio" end="fine" by="tipo" tooltip="{unita} — {tipo}"}
{unita}
::/calendar
::/if-any

::if-empty{path="contratti"}
Nessun contratto registrato.
::/if-empty

::/page

::page{title="Acquisti" icon="shopping-cart"}

# Acquisti e inventario

::form{path="fornitori" id="modFornitore"}
::input{field="ragioneSociale" legend="Ragione sociale" required}
::input{field="partitaIva" legend="Partita IVA" pattern="[0-9]{11}|" message="Undici cifre, oppure vuoto"}
::input{field="codiceUnivoco" legend="Codice univoco"}
::input{field="pec" legend="PEC" type="email"}
::input{field="categoria" legend="Categoria merceologica"}
::input{field="scadenzaDurc" type="date" legend="Scadenza DURC"}
::save{label="Salva il fornitore"}
::/form

::if-any{path="fornitori"}
::table{path="fornitori" search deletable editform="modFornitore" sort="ragioneSociale"}
::column{field="ragioneSociale" label="Fornitore"}
::column{field="partitaIva" label="P. IVA"}
::column{field="categoria" label="Categoria"}
::column{field="scadenzaDurc" label="DURC fino al"}
::/table
::/if-any

## Acquisti

::form{path="acquisti" id="modAcquisto"}
::input{field="oggetto" legend="Oggetto" required}
::input{field="fornitore" type="ref" path="fornitori" label="ragioneSociale" legend="Fornitore"}
::input{field="importo" type="number" legend="Importo (€)" min="0" step="0.01" required}
::input{field="capitolo" legend="Attività o progetto di bilancio"}
::input{field="cig" legend="CIG"}
::input{field="dataOrdine" type="date" legend="Data dell'ordine"}
::input{field="stato" legend="Stato" required pattern="richiesta|autorizzato|ordinato|consegnato|collaudato|liquidato" message="richiesta, autorizzato, ordinato, consegnato, collaudato, liquidato" value="richiesta"}
::save{label="Registra l'acquisto"}
::/form

::if-any{path="acquisti"}
::board{path="acquisti" group-by="stato" columns="richiesta,autorizzato,ordinato,consegnato,collaudato,liquidato" min="14rem" editform="modAcquisto"}
**{oggetto}**

{fornitore>fornitori.ragioneSociale}

{importo} €
::/board

Impegnato: **:sum{path="acquisti" field="importo" decimals="2"} €** su
:count{path="acquisti"} acquisti.

::chart-bar{data="acquisti" x="capitolo" y="importo" height="16rem"}
::/if-any

## Inventario

::form{path="inventario" id="modBene"}
::input{field="numero" legend="Numero d'inventario" required}
::input{field="descrizione" legend="Descrizione" required}
::input{field="categoria" legend="Categoria"}
::input{field="ubicazione" legend="Ubicazione"}
::input{field="consegnatario" legend="Consegnatario"}
::input{field="dataCarico" type="date" legend="Data di carico"}
::input{field="valore" type="number" legend="Valore (€)" min="0" step="0.01"}
::input{field="stato" legend="Stato" pattern="in uso|in riparazione|scaricato|" message="in uso, in riparazione, scaricato"}
::input{field="motivoScarico" legend="Motivo dello scarico"}
::save{label="Carica il bene"}
::/form

::if-any{path="inventario"}
::table{path="inventario" search filters="categoria,ubicazione,consegnatario,stato" sort="numero" deletable editform="modBene" page-size="20"}
::column{field="numero" label="N. inv."}
::column{field="descrizione" label="Descrizione"}
::column{field="categoria" label="Categoria"}
::column{field="ubicazione" label="Ubicazione"}
::column{field="consegnatario" label="Consegnatario"}
::column{field="valore" label="Valore €" align="end"}
::column{field="stato" label="Stato"}
::/table

Beni: **:count{path="inventario"}**, per un valore di
**:sum{path="inventario" field="valore" decimals="2"} €**.
::/if-any

::/page

::page{title="Report" icon="graph-bar-vertical"}

# Report

## Tempi di evasione

::python{data="pratiche,tipi-pratica" writes="tempi" manual}
```python
import datetime

def giorno(v):
    try:
        return datetime.date.fromisoformat(str(v)[:10])
    except (TypeError, ValueError):
        return None

tipi = {t["id"]: t for t in data["tipi-pratica"]}
per_tipo = {}

for p in data["pratiche"]:
    if p.get("stato") not in ("evasa", "archiviata"):
        continue
    aperta = giorno(p.get("apertura"))
    chiusa = giorno(p.get("updatedAt"))
    if aperta is None or chiusa is None:
        continue
    nome = tipi.get(p.get("tipo", ""), {}).get("nome", p.get("tipo", "senza tipo"))
    per_tipo.setdefault(nome, []).append((chiusa - aperta).days)

result = []
for nome in sorted(per_tipo):
    giorni = per_tipo[nome]
    result.append({
        "id": "tp-%d" % (len(result) + 1),
        "tipo": nome,
        "evase": str(len(giorni)),
        "medio": "%.1f" % (sum(giorni) / len(giorni)),
        "massimo": str(max(giorni)),
    })

print("%d tipi di pratica con almeno una evasa." % len(result))
if not result:
    print("Nessuna pratica evasa: il tempo medio si misura su quelle chiuse.")
```
::/python

::if-any{path="tempi"}
::table{path="tempi" sort="medio" dir="desc"}
::column{field="tipo" label="Tipo di pratica"}
::column{field="evase" label="Evase" align="end"}
::column{field="medio" label="Giorni medi" align="end"}
::column{field="massimo" label="Peggiore" align="end"}
::/table

::chart-bar{data="tempi" x="tipo" y="medio" horizontal height="18rem"}
::/if-any

## Un riassunto scritto

Un riassunto delle pratiche, riscritto ogni volta che le righe cambiano. Viaggia solo
un campione delle righe, mai tutta la collezione; con un modello locale non esce
niente dal computer.

::ai-summary{data="pratiche"}
Riassumi in cinque righe: quante pratiche aperte, in quali aree si concentrano, quali
sono fuori termine e su chi è il carico maggiore.
::/ai-summary

## Esplora

Trascina le colonne, raggruppa, cambia grafico. È la vista che risponde alle domande
che non erano previste.

::explore{path="pratiche" group-by="area" columns="oggetto,stato,assegnata,termine" height="26rem"}

::/page

::page{title="Stampe" icon="print"}

# Stampe

## Prospetto individuale dei contatori

Matricola dell'unità da stampare — o usa il pulsante che le stampa tutte:

::textfield[unitaSel]{placeholder="M001"}

::columns{min="22rem" id="prospettoContatori"}
### Prospetto dei contatori

::list{path="personale" filter="matricola=#unitaSel" limit="1"}
**{cognome} {nome}** — matricola {matricola}, {profilo}, {contratto}, sede {sede},
servizio al {partTime}%.
::/list

::table{path="contatori" filter="unita=#unitaSel"}
::column{field="voce" label="Voce"}
::column{field="valore" label="Valore" align="end"}
::column{field="limite" label="Limite" align="end"}
::column{field="misura" label="Misura"}
::/table

Il presente prospetto è un riepilogo di servizio interno e non costituisce
certificazione.
::/columns

::print{target="prospettoContatori" label="Stampa il prospetto"}

::print{target="prospettoContatori" repeat="personale" key="unitaSel" field="matricola" label="Stampa il prospetto di ogni unità"}

## Elenco delle pratiche fuori termine

::columns{min="24rem" id="stampaAllarmi"}
### Segnalazioni

::table{path="allarmi"}
::column{field="gravita" label="Gravità"}
::column{field="ambito" label="Ambito"}
::column{field="che" label="Che cosa"}
::column{field="quando" label="Quando"}
::/table
::/columns

::print{target="stampaAllarmi" landscape label="Stampa le segnalazioni"}

## Registro di inventario

::columns{min="24rem" id="stampaInventario"}
### Registro dei beni

::table{path="inventario" sort="numero"}
::column{field="numero" label="N."}
::column{field="descrizione" label="Descrizione"}
::column{field="categoria" label="Categoria"}
::column{field="ubicazione" label="Ubicazione"}
::column{field="consegnatario" label="Consegnatario"}
::column{field="dataCarico" label="Carico"}
::column{field="valore" label="Valore €" align="end"}
::/table
::/columns

::print{target="stampaInventario" landscape label="Stampa il registro di inventario"}

::/page

::page{title="Configurazione" icon="settings"}

# Tipi di pratica

Un tipo nuovo, con il suo termine e la sua checklist, si crea da qui: non c'è codice
da toccare e non c'è nessuno da chiamare.

::form{path="tipi-aggiunti" id="modTipo"}
::input{field="codice" legend="Codice" required help="Senza spazi: nulla-osta-alunno"}
::input{field="nome" legend="Nome" required}
::input{field="area" legend="Area" required pattern="didattica|personale|affari generali|acquisti" message="didattica, personale, affari generali, acquisti"}
::input{field="termineGiorni" type="number" legend="Termine in giorni" min="1" max="365" required}
::input{field="checklist" legend="Checklist" help="I passaggi, separati da barra verticale: Richiesta|Verifica|Firma DS"}
::input{field="firmaDS" type="checkbox" legend="Richiede la firma del dirigente"}
::save{label="Salva il tipo"}
::/form

::table{path="tipi-pratica" search filters="area" sort="nome" page-size="20"}
::column{field="nome" label="Tipo"}
::column{field="area" label="Area"}
::column{field="termineGiorni" label="Giorni" align="end"}
::column{field="checklist" label="Checklist"}
::column{field="firmaDS" label="Firma DS"}
::/table

::if-any{path="tipi-aggiunti"}
### I tuoi tipi

::table{path="tipi-aggiunti" deletable editform="modTipo" sort="nome"}
::column{field="nome" label="Tipo"}
::column{field="area" label="Area"}
::column{field="termineGiorni" label="Giorni" align="end"}
::/table
::/if-any

# Decisioni prese, e perché

**I parametri contrattuali stanno in una tabella dentro il blocco dei contatori.**
Ferie, festività soppresse e permessi retribuiti sono lì, in cima, in un dizionario:
cambiano a ogni rinnovo, e quella è la riga da correggere quando succede. Le
spettanze sono riproporzionate sulla percentuale di part-time.

**Nessuna diagnosi, in nessun campo.** Delle assenze si registra il tipo secondo la
codifica contrattuale e i giorni; del certificato, l'estremo. Il comporto si conta in
giorni e i permessi della legge 104 sono un numero: quello che vi sta dietro non entra
in questa app.

**Il protocollo non è simulato.** C'è un campo per il numero che il protocollo
informatico ha assegnato. Un numero generato qui sarebbe un numero che non esiste in
nessun registro, e sarebbe peggio del niente.

**Il termine è una data, non un calcolo.** Il tipo di pratica dice quanti giorni, e la
data si scrive: i termini si sospendono, i giorni si contano in modi diversi e le
festività cambiano per regione. Un calcolo automatico sbagliato è peggio di un campo
da compilare.

**Le pratiche si archiviano, non si cancellano.** Lo stato *archiviata* è la fine
normale di una pratica. Il pulsante di eliminazione c'è, ma è per l'errore di
battitura, non per il procedimento.

**Il controllo d'accesso per ruolo non è in questo documento.** Chi apre l'app vede
tutto. Dove i ruoli devono essere separati davvero — l'assistente dell'area didattica
che non vede i dati del personale — la risposta è tenere le due aree in **due app**,
oppure gli spazi condivisi della piattaforma. Non è una decisione che questo file
possa prendere.

**Le direttive AI sono tre e non decidono nulla di irreversibile.** `::ai-assist`
riempie una bozza che una persona rivede e salva; `::ai-classify` sceglie fra le
quattro aree e nient'altro, scartando ogni risposta fuori elenco; `::ai-rule` viene
compilata una volta e poi gira senza modello. Con un fornitore remoto, l'oggetto delle
pratiche viene inviato a quel fornitore: per una segreteria, il modello locale è la
configurazione consigliata.

::/page
