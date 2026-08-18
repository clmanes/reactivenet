---
appId: orario-scolastico
title: Orario Scolastico
description: "Anagrafiche importabili da foglio di calcolo, cattedre, laboratori, griglia oraria trascinabile, controllo dei vincoli, generazione assistita con blocchi, compresenze e compattazione delle giornate, monitor di fattibilità, qualità, tabellone, stampe, esportazione in Excel e sostituzioni giornaliere per un istituto di II grado."
icon: education
lang: it
version: "3.2"
author: ReactiveNET
date: "2026-08-16"
---

::page{title="Avvio" icon="education"}

# Orario Scolastico

Costruisce e mantiene il **quadro orario settimanale** di un istituto secondario
di II grado. Il software è assistivo: propone una collocazione, la si corregge
trascinando, e il controllo dice subito che cosa si è rotto. Non decide al posto
di chi fa l'orario, e non manda niente a nessuno — tutto resta in questo browser.

## Che cosa fa, e che cosa non fa

| Fa | Non fa |
| --- | --- |
| Anagrafiche di classi, docenti, aule e discipline, con i loro moduli | Non parla col SIDI né con un registro elettronico |
| **Importa** le anagrafiche e le cattedre da un CSV o da un foglio Excel, e **riesporta** ogni tabella nello stesso modo | Non legge il tracciato di nessun applicativo di segreteria: legge le colonne elencate in **Dati** |
| Cattedre con le ore settimanali e i riferimenti alle anagrafiche | Non ricava il quadro orario ministeriale al posto di nessuno |
| **Sceglie l'aula**: la disciplina chiede un tipo, il solver trova quale è libera, capiente e nel plesso giusto | Non conosce le attrezzature della singola aula: distingue i tipi dichiarati in anagrafica |
| **Blocchi di ore consecutive**, che è come si fa laboratorio | Non spezza un blocco per salvare una preferenza: o ci sta intero, o non ci sta |
| **Compresenze in casella**: il sostegno segue la classe, l'ITP affianca il titolare | Non nomina i supplenti e non parla con le graduatorie |
| **Sostituzioni giornaliere**: le ore scoperte, i candidati in ordine, il conto di chi ne ha fatte quante e il foglio del giorno | Non decide chi chiamare, non conosce i contratti e non avvisa nessuno |
| Vincoli del docente: giorni di non disponibilità, massimo e minimo ore al giorno, giorni di servizio, mai in prima ora, spostamenti fra plessi | Non conosce i contratti: quello che sa è quello che c'è scritto in anagrafica |
| **La giornata della classe**: minimo e massimo ore, e le ore buche chiuse dalla compattazione | Non sposta una lezione da un giorno all'altro per riempire una giornata corta |
| **Regole fra materie**: peso didattico, distribuzione settimanale, massimo giornaliero, incompatibili, da tenere distanti | Non le indovina dal nome della materia: si dichiarano una per una, e valgono nei due sensi |
| **Aule condivise**: una palestra divisa a metà tiene due classi nella stessa ora | Non conosce le attrezzature: distingue i tipi e i posti dichiarati |
| Griglia giorno × ora trascinabile: per classe, per docente, per aula, **con le celle chiuse visibili da subito** | Non si trascina col dito: le correzioni da telefono sono le pre-assegnazioni |
| Controllo dei vincoli, con l'elenco delle violazioni e le celle chiuse | Non impedisce di tenere un orario che viola qualcosa |
| Generazione greedy, miglioramento a scambi e spostamenti, compattazione delle giornate | Non garantisce l'ottimo, e può lasciare ore non collocate |
| **Monitor**: dice se l'orario può esistere *prima* di generarlo, e se è pubblicabile dopo | Non decide che cosa sacrificare quando non entra |
| Misura la qualità: saturazione delle aule, ore buche, giorni liberi ottenuti | Non sceglie per te quale orario è il migliore |
| Stampa una pagina per classe, per docente e per aula, il tabellone di tutte le classi e le ore a disposizione | Non produce il tracciato di nessun applicativo di segreteria |

## Come sono fatti i dati, e perché

Un blocco Python **riscrive per intero** la collezione che gli è affidata: se
scrivesse direttamente l'anagrafica, ogni esecuzione cancellerebbe le righe
aggiunte a mano. Perciò ogni collezione qui dentro ha **un padrone solo**, e sono
due i tipi.

| Padrone | Collezioni | Come si cambiano |
| --- | --- | --- |
| Un modulo | le aggiunte alle quattro anagrafiche e alle cattedre, i divieti, le pre-assegnazioni, le assenze e le sostituzioni | si scrivono, si correggono e si cancellano dalle loro tabelle |
| Un blocco | le anagrafiche in uso, le cattedre in uso, l'orario, le violazioni, le misure del monitor e della qualità, il tabellone | si rifanno premendo il loro pulsante |
| Un blocco, da solo | le celle chiuse delle tre griglie, le ore da coprire e il carico delle sostituzioni | si rifanno da sé quando cambia quello che leggono |

Un'anagrafica **in uso** è dunque *costruita*: l'istituto di esempio scritto nel
blocco, più le righe aggiunte a mano. Prima si aggiunge, poi si preme
*Ricostruisci*.

E «aggiunte» non vuol dire per forza scritte una alla volta: le cinque collezioni
`-aggiunte` sono anche quelle in cui si **versa un foglio di calcolo**, che è
come si porta qui dentro una scuola vera. Le colonne che deve avere, e come si
esporta quello che ne esce, stanno in **Dati**.

## Semina l'istituto di esempio

L'app parte con un istituto **inventato** — l'IIS «Ada Lovelace», due indirizzi
su due plessi, sei classi, tredici docenti, undici aule fra cui **tre laboratori
e due palestre**, tredici discipline, sessantasei cattedre — perché un guscio
vuoto non si può provare. Le righe si creano soltanto scrivendo, e il documento
non ha modo di dichiararle: le semina un blocco `::python{manual}`, che parte col
suo pulsante **Esegui** e con nient'altro.

I cinque pulsanti vanno premuti in ordine: le cattedre citano gli id delle altre
quattro.
La prima esecuzione scarica l'interprete (13 MB, poi resta in cache); nessuno di
questi blocchi usa pacchetti.

::python{data="classi-aggiunte" writes="classi" manual}
```python
# Sei classi, due indirizzi, due plessi. L'id è scritto a mano perché le cattedre
# lo citano. "alunni" serve a scartare un laboratorio troppo piccolo.
#
# "minOreGiorno" e "maxOreGiorno" sono il numero di ore che quella classe può
# fare in una giornata, ed è il vincolo che decide la FORMA della settimana: con
# trenta ore su sei giorni e un tetto di sei, una classe che ne fa sei il lunedì
# ne farà quattro un altro giorno, e il minimo impedisce che quel giorno diventi
# di due. Vuoto significa "quello che dice la configurazione", non "nessun
# limite": un orario senza tetto giornaliero non è un orario, è un elenco.
def c(i, nome, anno, sez, alunni, indirizzo, aula, plesso, minore="", maxore=""):
    return {"id": i, "nome": nome, "anno": anno, "sezione": sez, "alunni": alunni,
            "indirizzo": indirizzo, "aulaBase": aula, "plesso": plesso,
            "minOreGiorno": minore, "maxOreGiorno": maxore}

result = [
    c("c-1a", "1A", "1", "A", "26", "Informatica e Telecomunicazioni", "A101", "Centrale"),
    c("c-2a", "2A", "2", "A", "24", "Informatica e Telecomunicazioni", "A102", "Centrale"),
    c("c-3a", "3A", "3", "A", "22", "Informatica e Telecomunicazioni", "A103", "Centrale"),
    c("c-1b", "1B", "1", "B", "27", "Amministrazione, Finanza e Marketing", "B201", "Succursale"),
    c("c-2b", "2B", "2", "B", "25", "Amministrazione, Finanza e Marketing", "B202", "Succursale"),
    # La sola classe che dichiara i propri limiti invece di prendere quelli
    # dell'istituto. Attenzione a che cosa vuol dire questo campo: è il tetto di
    # OGNI giornata, non di una in particolare — un sabato corto non si scrive
    # qui, si scrive come divieto sulla classe, perché riguarda un giorno solo.
    # E un tetto di cinque su trenta ore fa esattamente trenta caselle: entra
    # sulla carta e non entra mai davvero, che è quello che il monitor chiama
    # «al limite».
    c("c-3b", "3B", "3", "B", "21", "Amministrazione, Finanza e Marketing", "B203", "Succursale",
      minore="4", maxore="6"),
]

# Le classi aggiunte a mano, con il loro id: così le cattedre che le citano
# restano valide da una ricostruzione all'altra.
campi = ["nome", "anno", "sezione", "alunni", "indirizzo", "aulaBase", "plesso",
         "minOreGiorno", "maxOreGiorno"]
# Il modulo esige il nome; un foglio importato no, e una riga di coda vuota è la
# cosa più comune che un foglio di calcolo contenga. Una classe senza nome non è
# indirizzabile da nessuna parte — non dalle cattedre, non dalla griglia, non
# dalle stampe — quindi si conta e si lascia fuori.
senza_nome = 0
for riga in data["classi-aggiunte"]:
    if not str(riga.get("nome", "")).strip():
        senza_nome += 1
        continue
    nuova = {"id": riga.get("id", "")}
    for campo in campi:
        nuova[campo] = riga.get(campo, "")
    result.append(nuova)

print("%d classi in anagrafica, di cui %d aggiunte a mano o importate."
      % (len(result), len(data["classi-aggiunte"]) - senza_nome))
if senza_nome:
    print("%d righe senza «nome» sono state saltate." % senza_nome)
```
::/python

::python{data="docenti-aggiunte" writes="docenti" manual}
```python
# Tredici docenti. "oreCattedra" è il monte ore; quello che le cattedre non
# coprono sono ore a disposizione, non un errore.
#
# I vincoli duri vanno usati con parsimonia: "giorniNon" sono i giorni in cui il
# docente non è in servizio (lo spezzone che completa altrove), "maxOreGiorno" il
# tetto giornaliero, "minOreGiorno" il pavimento — nessuno attraversa la città per
# un'ora sola — "maxGiorniServizio" quanti giorni può salire in tutto, e
# "nonPrimaOra" chi non può aprire la giornata. Il giorno libero invece resta una
# PREFERENZA, pesata da uno slider.
#
# "sigla" è il nome corto: in un tabellone di venti classi una casella è larga un
# centimetro, e «De Santis» non ci sta. Vuota, la stampa usa il cognome.
def d(i, cognome, nome, cdc, ore, tipo, libero, plesso, sigla="",
      giorni_non="", max_ore="", min_ore="", max_giorni="", non_prima="false", note=""):
    return {"id": i, "cognome": cognome, "nome": nome, "classeConcorso": cdc,
            "oreCattedra": ore, "tipo": tipo, "giornoLibero": libero,
            "plesso": plesso, "sigla": sigla or cognome[:3].upper(),
            "giorniNon": giorni_non, "maxOreGiorno": max_ore,
            "minOreGiorno": min_ore, "maxGiorniServizio": max_giorni,
            "nonPrimaOra": non_prima, "note": note}

result = [
    d("d-basile",     "Basile",     "Chiara",    "A012", "18", "ordinario",     "sab", "Centrale",
      max_ore="5", note="Non più di cinque ore al giorno"),
    d("d-ferraro",    "Ferraro",    "Michele",   "A012", "18", "ordinario",     "lun", "Succursale"),
    d("d-grimaldi",   "Grimaldi",   "Elena",     "AB24", "18", "ordinario",     "mer", "Centrale"),
    d("d-rinaldi",    "Rinaldi",    "Paolo",     "A026", "18", "ordinario",     "ven", "Centrale",
      max_ore="5"),
    d("d-costantini", "Costantini", "Sara",      "A026", "18", "potenziamento", "mar", "Succursale",
      note="Due ore a disposizione"),
    d("d-vitali",     "Vitali",     "Andrea",    "A041", "18", "ordinario",     "gio", "Centrale"),
    d("d-marchetti",  "Marchetti",  "Luca",      "B016", "18", "ITP",           "mar", "Centrale",
      note="Due ore a disposizione"),
    d("d-lombardi",   "Lombardi",   "Davide",    "B016", "11", "ITP",           "gio", "Centrale",
      giorni_non="lun,mar", min_ore="2",
      note="Spezzone: il lunedì e il martedì è in un altro istituto"),
    d("d-desantis",   "De Santis",  "Giulia",    "A045", "18", "ordinario",     "ven", "Succursale",
      sigla="DES"),
    d("d-palmieri",   "Palmieri",   "Roberto",   "A046", "15", "ordinario",     "mer", "Succursale",
      non_prima="true", note="Spezzone di quindici ore, mai in prima ora"),
    d("d-neri",       "Neri",       "Francesca", "A048", "12", "ordinario",     "lun", "Centrale",
      min_ore="2", max_giorni="4",
      note="Spezzone di dodici ore, concentrato in quattro giorni"),
    d("d-iodice",     "Iodice",     "Marco",     "IRC",  "6",  "religione",     "",    "Centrale"),
    d("d-serra",      "Serra",      "Valentina", "ADSS", "18", "sostegno",      "gio", "Centrale",
      note="Sostegno sulla 2A, in compresenza"),
]

campi = ["cognome", "nome", "classeConcorso", "oreCattedra", "tipo", "giornoLibero",
         "plesso", "sigla", "giorniNon", "maxOreGiorno", "minOreGiorno",
         "maxGiorniServizio", "nonPrimaOra", "note"]
senza_cognome = 0
for riga in data["docenti-aggiunte"]:
    if not str(riga.get("cognome", "")).strip():
        senza_cognome += 1
        continue
    nuovo = {"id": riga.get("id", "")}
    for campo in campi:
        nuovo[campo] = riga.get(campo, "")
    # La sigla come per i tredici di sopra: su un foglio importato non l'ha
    # scritta nessuno, e senza il tabellone stampa il cognome per esteso in una
    # casella larga un centimetro.
    nuovo["sigla"] = str(nuovo["sigla"]).strip() or nuovo["cognome"][:3].upper()
    result.append(nuovo)

print("%d docenti in anagrafica, di cui %d aggiunti a mano o importati."
      % (len(result), len(data["docenti-aggiunte"]) - senza_cognome))
if senza_cognome:
    print("%d righe senza «cognome» sono state saltate." % senza_cognome)
```
::/python

::python{data="aule-aggiunte" writes="aule" manual}
```python
# Undici aule. Il "tipo" è quello che le discipline chiedono: una disciplina dice
# "voglio un laboratorio", non "voglio LAB1". Ogni plesso ha il suo laboratorio e
# la sua palestra, perché una classe che attraversa la città fra un'ora e l'altra
# è un orario che sulla carta funziona e nella realtà no.
#
# Due capienze, e sono due domande diverse. "capienza" è quanti ALUNNI ci stanno,
# e serve a scartare il laboratorio troppo piccolo per la 1B. "classiInsieme" è
# quante CLASSI possono starci nella stessa ora: una palestra divisa a metà ne
# tiene due, un laboratorio con una postazione a testa ne tiene una sola. Senza
# questa seconda colonna la palestra è un collo di bottiglia inventato, e le due
# ore di scienze motorie di sei classi non entrano in una settimana.
def a(i, nome, tipo, capienza, plesso, insieme="1"):
    return {"id": i, "nome": nome, "tipo": tipo, "capienza": capienza,
            "plesso": plesso, "classiInsieme": insieme}

result = [
    a("a-a101", "A101", "aula",        "28", "Centrale"),
    a("a-a102", "A102", "aula",        "28", "Centrale"),
    a("a-a103", "A103", "aula",        "26", "Centrale"),
    a("a-b201", "B201", "aula",        "28", "Succursale"),
    a("a-b202", "B202", "aula",        "27", "Succursale"),
    a("a-b203", "B203", "aula",        "25", "Succursale"),
    a("a-lab1", "LAB1", "laboratorio", "26", "Centrale"),
    a("a-lab2", "LAB2", "laboratorio", "24", "Centrale"),
    a("a-lab3", "LAB3", "laboratorio", "28", "Succursale"),
    a("a-pal",  "PAL",  "palestra",    "60", "Centrale",   "2"),
    a("a-pal2", "PAL2", "palestra",    "50", "Succursale", "2"),
]

campi = ["nome", "tipo", "capienza", "plesso", "classiInsieme"]
senza_nome = 0
for riga in data["aule-aggiunte"]:
    if not str(riga.get("nome", "")).strip():
        senza_nome += 1
        continue
    nuova = {"id": riga.get("id", "")}
    for campo in campi:
        nuova[campo] = riga.get(campo, "")
    result.append(nuova)

print("%d aule in anagrafica, di cui %d aggiunte a mano o importate."
      % (len(result), len(data["aule-aggiunte"]) - senza_nome))
if senza_nome:
    print("%d righe senza «nome» sono state saltate." % senza_nome)
```
::/python

::python{data="discipline-aggiunte" writes="discipline" manual}
```python
# "monteOre" è l'ordine di grandezza settimanale della disciplina; le ore che
# valgono davvero sono quelle scritte sulla singola cattedra, classe per classe.
#
# "aulaRichiesta" è un TIPO di aula, non una stanza: vuoto significa l'aula base
# della classe. "blocco" è quante ore consecutive vanno tenute insieme — due, per
# un laboratorio, perché in cinquanta minuti non si monta niente.
#
# "peso" è il carico da 0 a 10, e ha preso il posto della vecchia bandierina
# "mattino": una bandierina sa dire soltanto «presto», e a un'ora di religione e
# a quattro di matematica serve un ordine fra loro, non un sì e un no. Il costo
# di collocare tardi è proporzionale al peso, quindi le materie pesanti salgono
# in prima e in seconda ora da sole. Le righe scritte prima di questo campo hanno
# ancora "mattino", e sono lette: 8 se vero, 3 se falso.
#
# Gli ultimi tre sono vincoli DURI sulla giornata della classe:
#   - "maxAlGiorno" è quante ore di quella materia una classe può fare in un
#     giorno. A 1 significa «mai due volte lo stesso giorno», che è la regola più
#     comune di tutte e che finora era soltanto una preferenza pesata;
#   - "incompatibili" sono le materie che non stanno nello stesso giorno di
#     questa — le due ore in palestra e le due in laboratorio, per esempio;
#   - "nonConsecutivaCon" quelle che non stanno nel giorno DOPO né in quello
#     prima. Serve a distanziare, non a vietare.
# Si scrivono per nome esteso, separati da virgola, e valgono nei due sensi.
#
# "distribuzione" dice come spezzare il monte ore settimanale in giornate: "2+1+1"
# sono quattro ore in tre giorni, uno dei quali doppio. Vuota, decide "blocco".
def m(i, nome, area, ore, aula, peso, blocco="1", distribuzione="",
      max_giorno="", incompatibili="", non_consecutiva=""):
    return {"id": i, "nome": nome, "area": area, "monteOre": ore,
            "aulaRichiesta": aula, "peso": peso, "blocco": blocco,
            "distribuzione": distribuzione, "maxAlGiorno": max_giorno,
            "incompatibili": incompatibili, "nonConsecutivaCon": non_consecutiva,
            "mattino": "true" if int(peso) >= 6 else "false"}

# Quanti vincoli mettere è una decisione, non una taratura, e questo esempio è
# calibrato: ognuna delle tre regole compare una volta sola, sulla materia in cui
# ha una ragione che si può dire ad alta voce. Metterle su tutte le materie
# «perché sono giuste» è il modo più veloce per rendere l'orario impossibile —
# provato: con quattro maxAlGiorno invece di due restavano cinque ore senza
# casella, e nessuna di quelle quattro regole era stata chiesta da qualcuno.
result = [
    # Quattro ore di italiano non si fanno in due giorni: una al giorno.
    m("m-ita", "Italiano",                   "umanistica",  "4", "",            "9",
      distribuzione="1+1+1+1", max_giorno="1"),
    # Storia e diritto sono la stessa ora di studio a casa: distanti.
    m("m-sto", "Storia",                     "umanistica",  "2", "",            "5",
      non_consecutiva="Diritto ed economia"),
    m("m-ing", "Inglese",                    "umanistica",  "3", "",            "7"),
    # La doppia di matematica è quella in cui si correggono i compiti.
    m("m-mat", "Matematica",                 "scientifica", "4", "",            "10",
      distribuzione="2+1+1", max_giorno="2"),
    m("m-sci", "Scienze integrate",          "scientifica", "3", "",            "6"),
    m("m-dir", "Diritto ed economia",        "giuridica",   "3", "",            "4"),
    # Le due materie di laboratorio non lo stesso giorno: non è didattica, è il
    # laboratorio, che è uno per plesso e in quel giorno sarebbe tutto loro.
    m("m-inf", "Informatica",                "tecnica",     "4", "laboratorio", "8",  "2",
      incompatibili="Sistemi e reti"),
    m("m-sr",  "Sistemi e reti",             "tecnica",     "4", "laboratorio", "6",  "2"),
    m("m-tec", "Tecnologie e progettazione", "tecnica",     "3", "",            "5"),
    m("m-eaz", "Economia aziendale",         "economica",   "5", "",            "8",
      distribuzione="2+1+1+1"),
    m("m-smo", "Scienze motorie",            "motoria",     "2", "palestra",    "2",  "2"),
    m("m-rel", "Religione cattolica",        "religione",   "1", "",            "1"),
    m("m-sos", "Sostegno",                   "sostegno",    "0", "",            "0"),
]

campi = ["nome", "area", "monteOre", "aulaRichiesta", "peso", "blocco", "distribuzione",
         "maxAlGiorno", "incompatibili", "nonConsecutivaCon", "mattino"]
senza_nome = 0
for riga in data["discipline-aggiunte"]:
    if not str(riga.get("nome", "")).strip():
        senza_nome += 1
        continue
    nuova = {"id": riga.get("id", "")}
    for campo in campi:
        nuova[campo] = riga.get(campo, "")
    result.append(nuova)

print("%d discipline in anagrafica, di cui %d aggiunte a mano o importate."
      % (len(result), len(data["discipline-aggiunte"]) - senza_nome))
if senza_nome:
    print("%d righe senza «nome» sono state saltate." % senza_nome)
```
::/python

::python{data="cattedre-aggiunte,classi,discipline,docenti" writes="cattedre" manual}
```python
# Il quadro orario di ogni classe, scritto una volta sola: disciplina, ore
# settimanali, docente titolare. Da qui escono le cattedre, una riga per ogni
# accoppiata classe-disciplina. Trenta ore a classe, sei giorni per sei ore.
#
# L'aula NON è scritta qui: la decide la disciplina chiedendo un tipo, e quale
# stanza di quel tipo la sceglie il generatore. Il campo "aula" resta per il caso
# in cui una classe debba stare in una stanza precisa e in nessun'altra.
quadro = {
    "c-1a": [("m-ita",4,"d-basile"), ("m-sto",2,"d-basile"), ("m-ing",3,"d-grimaldi"),
             ("m-mat",4,"d-rinaldi"), ("m-sci",3,"d-costantini"), ("m-dir",2,"d-palmieri"),
             ("m-inf",4,"d-vitali"), ("m-sr",2,"d-marchetti"), ("m-tec",3,"d-vitali"),
             ("m-smo",2,"d-neri"), ("m-rel",1,"d-iodice")],
    "c-2a": [("m-ita",4,"d-basile"), ("m-sto",2,"d-basile"), ("m-ing",3,"d-grimaldi"),
             ("m-mat",4,"d-rinaldi"), ("m-sci",3,"d-costantini"), ("m-dir",2,"d-palmieri"),
             ("m-inf",4,"d-vitali"), ("m-sr",2,"d-marchetti"), ("m-tec",3,"d-vitali"),
             ("m-smo",2,"d-neri"), ("m-rel",1,"d-iodice")],
    "c-3a": [("m-ita",4,"d-basile"), ("m-sto",2,"d-basile"), ("m-ing",3,"d-grimaldi"),
             ("m-mat",3,"d-rinaldi"), ("m-inf",4,"d-vitali"), ("m-sr",6,"d-marchetti"),
             ("m-tec",3,"d-lombardi"), ("m-eaz",2,"d-desantis"), ("m-smo",2,"d-neri"),
             ("m-rel",1,"d-iodice")],
    "c-1b": [("m-ita",4,"d-ferraro"), ("m-sto",2,"d-ferraro"), ("m-ing",3,"d-grimaldi"),
             ("m-mat",4,"d-rinaldi"), ("m-sci",3,"d-costantini"), ("m-dir",3,"d-palmieri"),
             ("m-eaz",4,"d-desantis"), ("m-inf",2,"d-marchetti"), ("m-tec",2,"d-lombardi"),
             ("m-smo",2,"d-neri"), ("m-rel",1,"d-iodice")],
    "c-2b": [("m-ita",4,"d-ferraro"), ("m-sto",2,"d-ferraro"), ("m-ing",3,"d-grimaldi"),
             ("m-mat",4,"d-costantini"), ("m-sci",3,"d-costantini"), ("m-dir",3,"d-palmieri"),
             ("m-eaz",4,"d-desantis"), ("m-inf",2,"d-marchetti"), ("m-tec",2,"d-lombardi"),
             ("m-smo",2,"d-neri"), ("m-rel",1,"d-iodice")],
    "c-3b": [("m-ita",4,"d-ferraro"), ("m-sto",2,"d-ferraro"), ("m-ing",3,"d-grimaldi"),
             ("m-mat",3,"d-rinaldi"), ("m-eaz",8,"d-desantis"), ("m-dir",5,"d-palmieri"),
             ("m-inf",2,"d-marchetti"), ("m-smo",2,"d-neri"), ("m-rel",1,"d-iodice")],
}

result = []
for classe, righe in quadro.items():
    for disciplina, ore, docente in righe:
        result.append({
            "id": "k-" + classe + "-" + disciplina,
            "classe": classe, "disciplina": disciplina, "docente": docente,
            "aula": "", "ore": str(ore), "blocco": "",
            "compresenza": "false", "affianca": "", "note": "",
        })

# Le due compresenze. Non producono ore proprie: si appoggiano su caselle già
# collocate, e per questo sono sistemate DOPO tutto il resto.
#   - il sostegno segue la classe: nessun "affianca", e prende le sue prime ore;
#   - l'ITP affianca UNA cattedra precisa, che è come si sta in laboratorio.
result.append({
    "id": "k-c-2a-sos", "classe": "c-2a", "disciplina": "m-sos", "docente": "d-serra",
    "aula": "", "ore": "18", "blocco": "", "compresenza": "true", "affianca": "",
    "note": "Segue la 2A: si mette dove è già la classe",
})
result.append({
    "id": "k-c-3a-itp", "classe": "c-3a", "disciplina": "m-inf", "docente": "d-lombardi",
    "aula": "", "ore": "4", "blocco": "", "compresenza": "true", "affianca": "k-c-3a-m-inf",
    "note": "ITP in compresenza sull'Informatica della 3A",
})

# Dentro l'app una cattedra cita le anagrafiche per ID, e deve continuare a farlo:
# rinominare una classe non può rompere sessanta cattedre. Ma l'id lo conosce
# quest'app e non lo conosce il foglio che arriva dalla segreteria, dove c'è
# scritto «3B», «Matematica», «Rinaldi». Quindi si accettano tutti e due, e quello
# che entra in anagrafica è comunque l'id: una riga importata e una scritta a mano
# sono la stessa cosa il minuto dopo.
def indice(righe, chiavi):
    ident = {r.get("id", "") for r in righe if r.get("id", "")}
    nomi = {}
    for r in righe:
        i = r.get("id", "")
        if not i:
            continue
        for k in chiavi(r):
            k = str(k).strip().lower()
            if k:
                nomi.setdefault(k, set()).add(i)
    return ident, nomi

def risolvi(valore, dizionario):
    ident, nomi = dizionario
    v = str(valore).strip()
    if v in ident:
        return v, ""
    trovati = nomi.get(v.lower(), set())
    if len(trovati) == 1:
        # next(iter(...)) e non pop(): quello è l'insieme dentro l'indice, e
        # svuotarlo qui vorrebbe dire che di seicento righe importate si risolve
        # la prima di ogni nome e le altre cinquecentonovantanove no.
        return next(iter(trovati)), ""
    if not trovati:
        return "", "non trovato"
    # Due «Rossi» non si distinguono: per quelli ci vuole «Rossi Anna».
    return "", "ambiguo, ce ne sono %d" % len(trovati)

dizionari = {
    "classe": indice(data["classi"], lambda r: [r.get("nome", "")]),
    "disciplina": indice(data["discipline"], lambda r: [r.get("nome", "")]),
    "docente": indice(data["docenti"], lambda r: [
        r.get("cognome", ""),
        (str(r.get("cognome", "")) + " " + str(r.get("nome", ""))).strip(),
    ]),
}

campi = ["classe", "disciplina", "docente", "aula", "ore", "blocco",
         "compresenza", "affianca", "note"]
scartate = []
for riga in data["cattedre-aggiunte"]:
    nuova = {"id": riga.get("id", "")}
    for campo in campi:
        nuova[campo] = riga.get(campo, "")
    problemi = []
    for campo, dizionario in dizionari.items():
        risolto, perche = risolvi(nuova[campo], dizionario)
        if risolto:
            nuova[campo] = risolto
        else:
            problemi.append("%s «%s»: %s" % (campo, str(nuova[campo]).strip(), perche))
    # Una riga che non si risolve NON entra. Tenerla vorrebbe dire mostrarla fra le
    # cattedre, contarne le ore nel monitor e non collocarne nessuna: un buco di
    # quaranta ore senza niente che lo spieghi. Meglio due righe di stampa.
    if problemi:
        scartate.append("; ".join(problemi))
        continue
    result.append(nuova)

ore = sum(int(r["ore"] or "0") for r in result if r["compresenza"] != "true")
comp = sum(int(r["ore"] or "0") for r in result if r["compresenza"] == "true")
print("%d cattedre: %d ore disciplinari da collocare, %d ore in compresenza."
      % (len(result), ore, comp))
if scartate:
    print("Righe scartate perché i riferimenti non si risolvono: %d." % len(scartate))
    for s in scartate[:3]:
        print("  " + s)
    if len(scartate) > 3:
        print("  … e altre %d." % (len(scartate) - 3))
    print("Su un foglio importato il problema è quasi sempre uno solo ripetuto: un "
          "nome scritto diversamente, o le altre quattro anagrafiche non ancora "
          "ricostruite.")
```
::/python

## E poi

Le quattro anagrafiche stanno in **Anagrafiche**, le cattedre in **Cattedre**.
Se la scuola è già scritta da qualche parte — e lo è quasi sempre — si passa
prima da **Dati** e la si importa, invece di ribatterla.

Poi conviene fare un giro in **Monitor** *prima* di generare: le due misure di
fattibilità si calcolano dalle sole anagrafiche e dicono in dieci secondi se
quello che si sta per chiedere può entrare. Un orario che non si chiude quasi
sempre non si chiudeva già da lì.

La griglia si riempie da **Controlli e generazione**: prima *Genera l'orario*,
poi *Controlla i vincoli*. Quello che esce si conta in **Monitor** e si misura in
**Laboratori e qualità**, si corregge trascinando in **Orario**, e si stampa da
**Stampe**.

Poi c'è **Sostituzioni**, ed è l'unica pagina che si apre a orario finito: le
altre servono tre o quattro volte l'anno, quella lì tutte le mattine.

::/page

::page{title="Dati" icon="import"}

# Importare ed esportare

Una scuola non comincia da un foglio bianco. Le classi, i docenti, le aule e il
quadro orario esistono già — in un foglio di calcolo, nell'estrazione di un
gestionale, nel file che gira per posta da giugno. Ribattere seicento cattedre a
mano è il modo più veloce per non usare quest'app.

## Dove si preme

L'import e l'export non sono di questa pagina né di questa app: sono **del
sistema**, e stanno nel *pannello dati* — l'icona a forma di tabella nella barra
sopra l'app, accanto alla ⓘ. Lì c'è una riga per ogni collezione, con quante
righe contiene e quattro pulsanti:

| Pulsante | Che cosa fa |
| --- | --- |
| `CSV ↓` | scarica la collezione come CSV |
| `CSV ↑` | legge un CSV e lo versa nella collezione |
| `XLSX ↓` | scarica la stessa cosa come vero foglio Excel |
| `XLSX ↑` | legge un `.xlsx` — **il primo foglio del file**, gli altri non li guarda |

Il pannello si apre anche senza aprire l'editor, perché serve a chi *usa* l'app,
non a chi la scrive. Niente di tutto questo passa da un server: il file lo legge
il browser e le righe restano dove sono sempre state.

Una cosa da sapere prima di cercarli: **l'elenco contiene le collezioni che
esistono**, cioè quelle in cui qualcosa è già stato scritto almeno una volta. Su
un'app appena installata nessuna delle cinque `-aggiunte` c'è ancora — ed è
esattamente il momento in cui un foglio serve di più. Per questo sopra l'elenco
c'è **Importa in**: si scrive lì il nome della collezione, e i due pulsanti di
importazione compaiono accanto. Da quel momento in poi la collezione è
nell'elenco come tutte le altre.

Quello che il pannello non può sapere, e che è il mestiere di questa pagina, sono
due cose: **in quale collezione** va versato un foglio, e **quali colonne** deve
avere.

## In quale collezione

La regola dell'app, in una riga: **si importa soltanto in una collezione che ha
un modulo**, cioè in una delle cinque `-aggiunte`. Le anagrafiche *in uso* — `classi`,
`docenti`, `aule`, `discipline`, `cattedre` — appartengono a un blocco, che le
riscrive per intero a ogni *Ricostruisci*: un foglio versato lì sopra sparirebbe
al primo pulsante premuto, e niente lo direbbe. È la stessa ragione per cui non
hanno un modulo.

| Il foglio da caricare | Si importa in | Poi |
| --- | --- | --- |
| Le classi | `classi-aggiunte` | *Ricostruisci* le classi, in **Avvio** |
| I docenti | `docenti-aggiunte` | *Ricostruisci* i docenti |
| Le aule | `aule-aggiunte` | *Ricostruisci* le aule |
| Le discipline | `discipline-aggiunte` | *Ricostruisci* le discipline |
| Le cattedre | `cattedre-aggiunte` | *Ricostruisci* le cattedre, **per ultimo** |

L'ordine dell'ultima colonna non è una cortesia: le cattedre citano le altre
quattro anagrafiche, e ricostruirle prima significa cercare classi che ancora non
esistono.

## Quali colonne

La prima riga del foglio sono i **nomi dei campi, scritti esattamente così** —
maiuscole comprese, `aulaBase` e non `aula base`. Le colonne che non servono si
tolgono; quelle che restano di troppo entrano come campi in più e non danno
fastidio a nessuno. **L'ordine non conta.**

### Classi

| Colonna | Obbligatoria | Che cos'è |
| --- | --- | --- |
| `nome` | sì | Come si scrive sull'orario: `1A`, `3B` |
| `anno` | | Anno di corso, da 1 a 5 |
| `sezione` | | `A`, `B` |
| `alunni` | | Serve a scartare un laboratorio troppo piccolo |
| `indirizzo` | | Indirizzo di studio, per esteso |
| `aulaBase` | | Il **nome** dell'aula, come compare fra le aule |
| `plesso` | | Deve essere scritto come nelle aule |
| `minOreGiorno` `maxOreGiorno` | | Ore al giorno di quella classe; vuoto: quel che dice la configurazione |

### Docenti

| Colonna | Obbligatoria | Che cos'è |
| --- | --- | --- |
| `cognome` | sì | |
| `nome` | | |
| `classeConcorso` | | `A012`, `AB24` |
| `oreCattedra` | | Il monte ore; quello che le cattedre non coprono sono ore a disposizione |
| `tipo` | | `ordinario`, `potenziamento`, `ITP`, `sostegno`, `religione` |
| `sigla` | | Il nome corto per il tabellone; vuota, la ricava dal cognome |
| `giornoLibero` | | Il giorno libero **preferito**: `lun` … `sab` |
| `giorniNon` | | I giorni in cui non è in servizio, separati da virgola — questo è un divieto |
| `maxOreGiorno` `minOreGiorno` | | Tetto e pavimento della giornata |
| `maxGiorniServizio` | | Quanti giorni può salire in tutto |
| `nonPrimaOra` | | `true` per chi non può aprire la giornata |
| `plesso` `note` | | |

### Aule

| Colonna | Obbligatoria | Che cos'è |
| --- | --- | --- |
| `nome` | sì | `A101`, `LAB2` |
| `tipo` | | Quello che le discipline chiedono: `aula`, `laboratorio`, `palestra` |
| `capienza` | | Quanti **alunni** ci stanno |
| `classiInsieme` | | Quante **classi** nella stessa ora: una palestra divisa a metà ne tiene due |
| `plesso` | | |

### Discipline

| Colonna | Obbligatoria | Che cos'è |
| --- | --- | --- |
| `nome` | sì | Per esteso: le cattedre importate la cercano da qui |
| `area` | | `umanistica`, `tecnica`, … |
| `monteOre` | | L'ordine di grandezza settimanale |
| `aulaRichiesta` | | Un **tipo** di aula, non una stanza; vuoto: l'aula base della classe |
| `peso` | | Da 0 a 10: quanto conviene metterla presto |
| `blocco` | | Ore consecutive da tenere insieme |
| `distribuzione` | | Come spezzare il monte ore: `2+1+1` |
| `maxAlGiorno` | | Quante ore di questa materia in un giorno |
| `incompatibili` `nonConsecutivaCon` | | Nomi di materie, separati da virgola, validi nei due sensi |

### Cattedre

| Colonna | Obbligatoria | Che cos'è |
| --- | --- | --- |
| `classe` | sì | Il **nome** della classe (`3B`) oppure il suo id (`c-3b`) |
| `disciplina` | sì | Il **nome** della disciplina (`Matematica`) oppure il suo id |
| `docente` | sì | Il **cognome** (`Rinaldi`), o `Cognome Nome`, oppure l'id |
| `ore` | sì | Ore settimanali |
| `aula` | | Il nome di una stanza obbligata; vuoto: la sceglie il generatore |
| `blocco` | | Vuoto: quello della disciplina |
| `compresenza` | | `true` per una cattedra che si appoggia a caselle già collocate |
| `affianca` | | L'id di un'altra cattedra; vuoto: segue la classe |
| `note` | | |

## Le cattedre si importano per nome

È la sola cosa che l'import ha richiesto di cambiare, e vale la pena dire perché.
Dentro l'app una cattedra cita le anagrafiche per **id**, e deve continuare a
farlo: rinominare una classe non può rompere sessanta cattedre. Ma un id lo
conosce quest'app e non lo conosce il foglio che arriva dalla segreteria, dove
c'è scritto `3B`, `Matematica`, `Rinaldi`.

Quindi il blocco delle cattedre accetta **tutti e due**: se il valore è già un id
lo usa, altrimenti lo cerca per nome — la classe per `nome`, la disciplina per
`nome`, il docente per `cognome` e, quando due cognomi sono uguali, per
`Cognome Nome`. Quello che entra nell'anagrafica è comunque l'id, sempre, così
una riga importata e una scritta a mano sono la stessa cosa il minuto dopo.

Una riga che **non** si risolve non entra: non c'è un modo giusto di indovinare
di quale classe si stia parlando. Il blocco la conta, dice quale campo non ha
trovato e stampa le prime che ha scartato — perché su un foglio di seicento righe
il problema è quasi sempre uno solo, ripetuto seicento volte, e vederne tre
basta.

## L'id, e perché conviene metterlo

Una colonna `id` non è obbligatoria: senza, ogni riga importata ne riceve uno
nuovo appena letta. Il prezzo si paga la seconda volta — **reimportare lo stesso
foglio raddoppia le righe**, perché niente collega le nuove alle vecchie.

Con una colonna `id` — un testo qualunque, purché stabile: `c-1c`, `d-rossi`,
`k-3b-mat` — la seconda importazione *aggiorna* le righe che ha già e aggiunge
solo quelle nuove. È anche il motivo per cui un export si può reimportare: `CSV ↓`
scrive l'id in prima colonna apposta.

Una cosa che sorprende, e che è voluta: **una cella vuota non cancella niente**.
Un campo assente resta com'era, e un foglio con dieci colonne aggiorna quelle
dieci senza toccare le altre. Per svuotare davvero un campo si usa la tabella
dell'app, non il foglio.

## Esportare

Ogni collezione esce con `CSV ↓` o `XLSX ↓`, così com'è: una colonna per campo,
l'id in prima colonna, una riga per riga. Le tre che si esportano davvero sono
queste.

| Collezione | Che foglio è |
| --- | --- |
| `lezioni` | L'orario intero, una riga per casella: classe, giorno, ora, disciplina, docente, aula |
| `tabellone` | Le trentasei caselle in riga e le classi in colonna — si costruisce in **Stampe** |
| `a-disposizione` | Le ore di ciascuno fra cattedra e orario — anche questo si costruisce in **Stampe** |

E poi ce n'è un quarto, che si costruisce qui perché fuori di qui non serve.
`lezioni` è in ordine di collocazione e scrive `lun` e il solo cognome: giusto
per chi ci lavora dentro, scomodo per chi lo riceve. Questo blocco ne fa la
stessa cosa **ordinata come si legge** — classe, giorno, ora — con il giorno per
esteso, il nome completo del docente e la sua classe di concorso accanto.

::python{data="lezioni,docenti" writes="orario-esportabile" manual}
```python
GIORNI = [("lun", "Lunedì"), ("mar", "Martedì"), ("mer", "Mercoledì"),
          ("gio", "Giovedì"), ("ven", "Venerdì"), ("sab", "Sabato")]
ordine = {sigla: i for i, (sigla, _) in enumerate(GIORNI)}
esteso = dict(GIORNI)

def vero(v):
    return str(v).strip().lower() in ("true", "1", "yes", "on", "si", "sì")

def intero(v, d=0):
    try:
        return int(float(str(v).strip().replace(",", ".")))
    except (TypeError, ValueError):
        return d

# Le lezioni portano il cognome, che basta a chi lavora qui dentro e non basta su
# un foglio che esce dalla scuola: accanto a un'ora di lezione una segreteria si
# aspetta di leggere il nome per intero e la classe di concorso.
anagrafica = {d.get("cognome", ""): d for d in data["docenti"]}

righe = []
for l in data["lezioni"]:
    g = l.get("giorno", "")
    d = anagrafica.get(l.get("docente", ""), {})
    intero_nome = (d.get("cognome", "") + " " + d.get("nome", "")).strip()
    righe.append(((l.get("classe", ""), ordine.get(g, 9), intero(l.get("ora", "")),
                   vero(l.get("compresenza", ""))), {
        "id": "x-" + l.get("id", ""),
        "classe": l.get("classe", ""),
        "giorno": esteso.get(g, g),
        "ora": str(l.get("ora", "")),
        "disciplina": l.get("disciplina", ""),
        "docente": intero_nome or l.get("docente", ""),
        "sigla": str(d.get("sigla", "")).strip() or l.get("docente", ""),
        "classeConcorso": d.get("classeConcorso", ""),
        "aula": l.get("aula", ""),
        "plesso": l.get("plesso", ""),
        "compresenza": "sì" if vero(l.get("compresenza", "")) else "",
    }))

# In ordine di lettura, non di collocazione. Un foglio che chi lo riceve deve
# riordinare è un foglio che qualcuno riordinerà a mano.
righe.sort(key=lambda coppia: coppia[0])
result = [riga for _, riga in righe]

classi = len({r["classe"] for r in result})
comp = sum(1 for r in result if r["compresenza"])
print("%d righe, %d classi, %d in compresenza." % (len(result), classi, comp))
if result:
    print("Si scarica con XLSX ↓ accanto a «orario-esportabile», nel pannello dati.")
else:
    print("Non c'è orario da esportare: si genera in «Controlli e generazione».")
```
::/python

::if-any{path="orario-esportabile"}
Le prime righe, per controllare che sia il foglio giusto: qui se ne vede una
pagina, il file le contiene tutte e :count{path="orario-esportabile"}.

::table{path="orario-esportabile" search page-size="12" filters="classe,giorno"}
::column{field="classe" label="Classe"}
::column{field="giorno" label="Giorno"}
::column{field="ora" label="Ora" align="end"}
::column{field="disciplina" label="Disciplina"}
::column{field="docente" label="Docente"}
::column{field="aula" label="Aula"}
::column{field="compresenza" label="Compr."}
::/table
::/if-any

::if-empty{path="orario-esportabile"}
Non ancora costruito: si preme il pulsante qui sopra, a orario generato.
::/if-empty

## Portare via tutto, non un foglio

L'export per collezione serve a mandare qualcosa a qualcuno. Per **spostare
l'orario su un altro computer** ci vuole l'altra cosa, che sta nella stessa barra:
*Salva i dati* scrive un unico file con dentro tutte le collezioni, e *Ripristina*
lo rilegge. Un backup ripristinato torna esattamente com'era; una collezione
reimportata si fonde con quello che trova, che è un'altra operazione e serve a
un'altra cosa.

::/page

::page{title="Anagrafiche" icon="user"}

# Anagrafiche

Le quattro tabelle da cui dipende tutto il resto. Qui si aggiunge e si corregge;
niente di quello che si scrive qui colloca una lezione — le lezioni nascono dalle
cattedre, e le cattedre stanno nella pagina dopo.

Ogni anagrafica ha due tabelle. **Le aggiunte** non le tocca nessun blocco;
**l'anagrafica in uso** è quella che leggono le cattedre, la generazione e le
stampe, ed è rifatta dal pulsante *Ricostruisci* in **Avvio** dopo ogni
aggiunta.

## Classi

Il numero di **alunni** non è un dato di segreteria messo qui per completezza: è
quello che esclude un laboratorio troppo piccolo, ed è l'unico modo che il solver
ha di saperlo.

::form{path="classi-aggiunte" id="formClasse"}
::input{field="nome" legend="Classe" required help="Come si scrive sull'orario: 1A, 3B"}
::input{field="anno" legend="Anno di corso" type="number" min="1" max="5" required}
::input{field="sezione" legend="Sezione"}
::input{field="alunni" legend="Alunni" type="number" min="0" max="40" help="Serve per la capienza delle aule"}
::input{field="indirizzo" legend="Indirizzo di studio"}
::input{field="aulaBase" legend="Aula base" help="Il nome dell'aula, come compare fra le aule"}
::input{field="plesso" legend="Plesso"}
::input{field="minOreGiorno" legend="Ore minime al giorno" type="number" min="1" max="6" help="Vuoto: quello che dice la configurazione"}
::input{field="maxOreGiorno" legend="Ore massime al giorno" type="number" min="1" max="6" help="Il sabato corto di una sola classe si scrive qui"}
::save{label="Aggiungi la classe"}
::/form

::if-any{path="classi-aggiunte"}
**:count{path="classi-aggiunte"}** classi aggiunte, in attesa della prossima
ricostruzione.

::table{path="classi-aggiunte" sort="nome" deletable editform="formClasse"}
::column{field="nome" label="Classe"}
::column{field="anno" label="Anno" align="end"}
::column{field="alunni" label="Alunni" align="end"}
::column{field="indirizzo" label="Indirizzo"}
::column{field="aulaBase" label="Aula base"}
::/table
::/if-any

::if-empty{path="classi"}
L'anagrafica in uso è vuota: si torna in **Avvio** e si preme il primo pulsante.
::/if-empty

::if-any{path="classi"}
**:count{path="classi"}** classi in uso, **:sum{path="classi" field="alunni"}**
alunni in tutto.

::table{path="classi" search sort="nome" filters="indirizzo,plesso"}
::column{field="nome" label="Classe"}
::column{field="anno" label="Anno" align="end"}
::column{field="alunni" label="Alunni" align="end"}
::column{field="indirizzo" label="Indirizzo"}
::column{field="aulaBase" label="Aula base"}
::column{field="plesso" label="Plesso"}
::column{field="minOreGiorno" label="Min/giorno" align="end"}
::column{field="maxOreGiorno" label="Max/giorno" align="end"}
::/table
::/if-any

## Docenti

`oreCattedra` è il monte ore di cattedra. Quello che le cattedre effettive non
coprono sono **ore a disposizione**, e sono una cosa normale: uno spezzone si
completa altrove, un docente di potenziamento tiene qualche ora libera per le
sostituzioni.

Attenzione alla differenza fra le due colonne che sembrano dire la stessa cosa.
Il **giorno libero** è *richiesto*: la generazione ci prova e lo scrive nella
qualità se non ci riesce. I **giorni di non disponibilità** sono un fatto — quel
giorno il docente è altrove — e sono un vincolo duro: nessuna lezione ci finisce
mai. Metterne troppi è il modo più semplice per rendere l'orario impossibile.

::form{path="docenti-aggiunte" id="formDocente"}
::input{field="cognome" legend="Cognome" required}
::input{field="nome" legend="Nome"}
::input{field="classeConcorso" legend="Classe di concorso" help="A012, AB24, B016, ADSS, IRC"}
::input{field="oreCattedra" legend="Ore di cattedra" type="number" min="0" max="24" required}
::input{field="tipo" legend="Tipo" help="ordinario, sostegno, ITP, potenziamento, religione"}
::input{field="giornoLibero" legend="Giorno libero richiesto" pattern="lun|mar|mer|gio|ven|sab|" message="Scrivi lun, mar, mer, gio, ven, sab, oppure lascia vuoto"}
::input{field="giorniNon" legend="Giorni di non disponibilità" help="Vincolo duro, separati da virgola: lun,mar"}
::input{field="maxOreGiorno" legend="Massimo ore al giorno" type="number" min="0" max="6" help="Vuoto: fino a sei"}
::input{field="minOreGiorno" legend="Minimo ore al giorno" type="number" min="0" max="6" help="Nessuno attraversa la città per un'ora sola"}
::input{field="maxGiorniServizio" legend="Massimo giorni di servizio" type="number" min="1" max="6" help="Vuoto: tutti i giorni in cui è disponibile"}
::input{field="nonPrimaOra" legend="Mai in prima ora" type="checkbox"}
::input{field="sigla" legend="Sigla" help="Il nome corto per il tabellone: tre lettere bastano"}
::input{field="plesso" legend="Plesso di servizio"}
::input{field="note" legend="Note"}
::save{label="Aggiungi il docente"}
::/form

::if-any{path="docenti-aggiunte"}
::table{path="docenti-aggiunte" sort="cognome" deletable editform="formDocente"}
::column{field="cognome" label="Cognome"}
::column{field="classeConcorso" label="Classe di concorso"}
::column{field="oreCattedra" label="Ore" align="end"}
::column{field="giornoLibero" label="Giorno libero"}
::/table
::/if-any

::if-any{path="docenti"}
**:count{path="docenti"}** docenti in uso, per
**:sum{path="docenti" field="oreCattedra"}** ore di cattedra dichiarate.

::table{path="docenti" search sort="cognome" filters="tipo,plesso,giornoLibero"}
::column{field="cognome" label="Cognome"}
::column{field="nome" label="Nome"}
::column{field="classeConcorso" label="C.d.C."}
::column{field="oreCattedra" label="Ore" align="end"}
::column{field="tipo" label="Tipo"}
::column{field="giornoLibero" label="G. libero"}
::column{field="giorniNon" label="Non disponibile"}
::column{field="maxOreGiorno" label="Max/giorno" align="end"}
::column{field="minOreGiorno" label="Min/giorno" align="end"}
::column{field="maxGiorniServizio" label="Max giorni" align="end"}
::column{field="sigla" label="Sigla"}
::column{field="plesso" label="Plesso"}
::/table
::/if-any

## Aule

Il **tipo** è la parte che lavora: una disciplina non chiede LAB1, chiede *un
laboratorio*, e quale sia lo decide il generatore fra quelli liberi, abbastanza
capienti e nel plesso della classe. Aggiungere un secondo laboratorio è, in
questa app, il modo di far respirare un orario che non si chiude.

::form{path="aule-aggiunte" id="formAula"}
::input{field="nome" legend="Aula" required help="A101, LAB2, PAL"}
::input{field="tipo" legend="Tipo" required help="aula, laboratorio, palestra — è quello che le discipline chiedono"}
::input{field="capienza" legend="Capienza in alunni" type="number" min="0"}
::input{field="classiInsieme" legend="Classi contemporanee" type="number" min="1" max="6" help="Quante classi ci stanno nella stessa ora: una palestra divisa a metà ne tiene due"}
::input{field="plesso" legend="Plesso"}
::save{label="Aggiungi l'aula"}
::/form

::if-any{path="aule-aggiunte"}
::table{path="aule-aggiunte" sort="nome" deletable editform="formAula"}
::column{field="nome" label="Aula"}
::column{field="tipo" label="Tipo"}
::column{field="capienza" label="Capienza" align="end"}
::column{field="classiInsieme" label="Classi insieme" align="end"}
::/table
::/if-any

::if-any{path="aule"}
**:count{path="aule"}** aule in uso, capienza media
**:avg{path="aule" field="capienza" decimals="0"}** posti.

::table{path="aule" search sort="nome" filters="tipo,plesso"}
::column{field="nome" label="Aula"}
::column{field="tipo" label="Tipo"}
::column{field="capienza" label="Capienza" align="end"}
::column{field="classiInsieme" label="Classi insieme" align="end"}
::column{field="plesso" label="Plesso"}
::/table
::/if-any

## Discipline

`aulaRichiesta` è quello che rende un'aula un vincolo vero, e da questa versione
è **letto davvero**: si scrive il *tipo* di aula — `laboratorio`, `palestra` — e la
disciplina si farà in una stanza di quel tipo. Vuoto significa l'aula base della
classe.

`blocco` dice quante ore consecutive vanno tenute insieme: due per un
laboratorio. Un blocco è indivisibile — o ci sta intero, o quell'ora non si
colloca — ed è la ragione per cui conviene metterlo solo dove serve davvero.

`peso` è il **carico didattico da 0 a 10**, e ha preso il posto della vecchia
bandierina *mattino*. Una bandierina sa dire soltanto «presto», e fra un'ora di
religione e quattro di matematica non serve un sì o un no: serve un ordine. Il
costo di collocare tardi cresce col peso, quindi le materie pesanti salgono in
prima e seconda ora da sole, e quelle leggere scendono a fare loro spazio. Le
righe scritte prima di questo campo hanno ancora `mattino` e sono lette lo
stesso: vale 8 se è spuntata, 3 se non lo è.

`distribuzione` dice **come spezzare le ore settimanali fra le giornate**:
`2+1+1` sono quattro ore in tre giorni, uno dei quali doppio. È l'ordine che un
consiglio di classe decide e che finora questo documento non sapeva dire — senza
di essa quattro ore con blocco 1 diventano quattro giornate qualunque, e con
blocco 2 due doppie. Vuota, decide `blocco`, come prima.

Gli ultimi tre sono **vincoli duri sulla giornata della classe**, e vanno usati
con la stessa parsimonia degli altri:

- `maxAlGiorno` — quante ore di questa materia una classe può fare in un giorno.
  A `1` significa *mai due volte lo stesso giorno*, che è la regola più comune di
  tutte e che fino a ieri qui era soltanto una preferenza pesata.
- `incompatibili` — le materie che non stanno **nello stesso giorno** di questa.
- `nonConsecutivaCon` — quelle che non stanno nel giorno **prima né dopo**.
  Serve a distanziare, non a vietare.

Si scrivono per nome esteso, separate da virgola, e valgono nei due sensi: basta
dichiararle da una parte sola.

::form{path="discipline-aggiunte" id="formDisciplina"}
::input{field="nome" legend="Disciplina" required}
::input{field="area" legend="Area"}
::input{field="monteOre" legend="Monte ore indicativo" type="number" min="0" max="12" help="Le ore che contano sono quelle della cattedra, classe per classe"}
::input{field="aulaRichiesta" legend="Tipo di aula richiesto" help="laboratorio, palestra, oppure vuoto per l'aula base"}
::input{field="blocco" legend="Ore consecutive" type="number" min="1" max="4" help="2 per un laboratorio; vuoto o 1 per un'ora sola"}
::input{field="distribuzione" legend="Distribuzione settimanale" pattern="[0-9]+([+][0-9]+)*|" message="Scrivi le ore di ogni giornata separate da +, per esempio 2+1+1" help="Vuoto: decide il blocco"}
::input{field="peso" legend="Peso didattico" type="number" min="0" max="10" help="0 leggera, 10 pesante: decide quanto presto sta nella giornata"}
::input{field="maxAlGiorno" legend="Massimo ore al giorno" type="number" min="1" max="6" help="1 significa mai due volte nello stesso giorno"}
::input{field="incompatibili" legend="Non nello stesso giorno di" help="Nomi per esteso, separati da virgola"}
::input{field="nonConsecutivaCon" legend="Non in giorni consecutivi con" help="Nomi per esteso, separati da virgola"}
::save{label="Aggiungi la disciplina"}
::/form

::if-any{path="discipline-aggiunte"}
::table{path="discipline-aggiunte" sort="nome" deletable editform="formDisciplina"}
::column{field="nome" label="Disciplina"}
::column{field="area" label="Area"}
::column{field="aulaRichiesta" label="Aula richiesta"}
::column{field="blocco" label="Blocco" align="end"}
::column{field="peso" label="Peso" align="end"}
::/table
::/if-any

::if-any{path="discipline"}
::table{path="discipline" search sort="nome" filters="area,aulaRichiesta"}
::column{field="nome" label="Disciplina"}
::column{field="area" label="Area"}
::column{field="monteOre" label="Monte ore" align="end"}
::column{field="aulaRichiesta" label="Aula richiesta"}
::column{field="blocco" label="Blocco" align="end"}
::column{field="distribuzione" label="Distribuzione"}
::column{field="peso" label="Peso" align="end"}
::column{field="maxAlGiorno" label="Max/giorno" align="end"}
::column{field="incompatibili" label="Non con"}
::/table
::/if-any

::/page

::page{title="Cattedre" icon="table"}

# Cattedre

Una cattedra è una classe, una disciplina, un docente e le ore settimanali. È
l'unica tabella che genera lavoro: ogni ora dichiarata qui è un'ora che il
generatore deve trovare dove mettere.

I riferimenti sono **id**: `c-2a`, `m-mat`, `d-rinaldi`. Si leggono nelle tabelle
delle anagrafiche, e sono fatti così perché rinominare una classe non deve
rompere sessanta cattedre.

Nei tre campi si accetta però anche il **nome** — `3B`, `Matematica`, `Rinaldi`,
o `Rinaldi Paolo` quando due cognomi coincidono — e la ricostruzione lo traduce
nell'id prima di scriverlo in anagrafica. Serve a chi importa un foglio, dove gli
id non ci sono: quello che entra è comunque l'id, sempre. Una riga che non si
risolve resta fuori, e il blocco dice quale campo non ha trovato — il discorso
per intero è in **Dati**.

**L'aula si lascia vuota.** La decide la disciplina chiedendo un tipo, e quale
stanza di quel tipo la sceglie il generatore ora per ora — che è precisamente il
lavoro che ci si aspetta da un applicativo. Il campo resta per il caso in cui una
classe debba stare in una stanza sola e in nessun'altra.

Una cattedra in **compresenza** non produce ore proprie: si appoggia a caselle
già collocate. Senza `affianca` segue la classe — è il sostegno — e con
`affianca` si mette esattamente sulle ore di quella cattedra, che è come si sta
in laboratorio con l'ITP.

::form{path="cattedre-aggiunte" id="formCattedra"}
::input{field="classe" legend="Classe" required help="L'id o il nome: c-2a oppure 3B"}
::input{field="disciplina" legend="Disciplina" required help="L'id o il nome: m-mat oppure Matematica"}
::input{field="docente" legend="Docente" required help="L'id o il cognome: d-rinaldi oppure Rinaldi"}
::input{field="ore" legend="Ore settimanali" type="number" min="1" max="12" required}
::input{field="aula" legend="Aula obbligata" help="Vuoto: la sceglie il generatore dal tipo che chiede la disciplina"}
::input{field="blocco" legend="Ore consecutive" type="number" min="1" max="4" help="Vuoto: quello della disciplina"}
::input{field="compresenza" legend="Compresenza" type="checkbox"}
::input{field="affianca" legend="Affianca la cattedra" help="L'id di un'altra cattedra; vuoto: segue la classe"}
::input{field="note" legend="Note"}
::save{label="Aggiungi la cattedra"}
::/form

::if-any{path="cattedre-aggiunte"}
::table{path="cattedre-aggiunte" sort="classe" deletable editform="formCattedra"}
::column{field="classe" label="Classe"}
::column{field="disciplina" label="Disciplina"}
::column{field="docente" label="Docente"}
::column{field="ore" label="Ore" align="end"}
::/table
::/if-any

::if-empty{path="cattedre"}
Nessuna cattedra in uso: si torna in **Avvio** e si preme il quinto pulsante.
::/if-empty

::if-any{path="cattedre"}
**:count{path="cattedre"}** cattedre in uso, per **:sum{path="cattedre" field="ore"}**
ore dichiarate — comprese quelle in compresenza, che non occupano una casella
propria.

::table{path="cattedre" search sort="classe" filters="compresenza" page-size="20"}
::column{field="classe" label="Classe"}
::column{field="disciplina" label="Disciplina"}
::column{field="docente" label="Docente"}
::column{field="ore" label="Ore" align="end"}
::column{field="blocco" label="Blocco" align="end"}
::column{field="compresenza" label="Compresenza"}
::column{field="affianca" label="Affianca"}
::/table
::/if-any

::/page

::page{title="Orario" icon="calendar"}

# Orario

La stessa griglia, guardata da tre parti: la classe, il docente, l'aula. La
settimana è di sei giorni per sei ore, e trascinare una scheda scrive insieme il
**giorno** e l'**ora** di quella lezione. Una casella con la bandierina viene da
una pre-assegnazione e non si muove.

Il trascinamento è quello del mouse. Da un telefono una lezione si toglie col suo
pulsante e si rimette come pre-assegnazione, in **Controlli e generazione**.

**Le celle chiuse si vedono da subito, e sono quelle di chi stai guardando.**
Prima erano solo quelle scritte dal controllo, che è manuale: finché non lo si
eseguiva la griglia non vietava niente, e una casella grigia arrivava sempre
troppo tardi — dopo aver trascinato, non prima. Adesso ogni griglia ha un blocco
suo che legge i divieti dell'istituto, quelli di quella risorsa e — per il
docente — i suoi giorni di non servizio e la sua prima ora, e li chiude **prima**
che qualcuno provi a metterci qualcosa. Le violazioni del controllo, quando c'è,
si aggiungono a queste.

Il blocco riparte da solo quando cambi il nome nel campo qui sotto, perché quel
nome è un parametro e un parametro fa parte della firma: la chiusura segue chi
stai guardando, che è l'unico modo in cui una casella può dire *Palmieri non fa
la prima ora* invece di un generico «vietato».

Un avvertimento sul trascinamento, ora che esistono i blocchi: la griglia sposta
**una lezione per volta**, quindi trascinare metà di un blocco di due ore lo
spezza. Il controllo non lo segnala — un blocco è una preferenza di generazione,
non un vincolo dell'orario — ma alla prossima generazione tornerà intero.

## Per classe

La classe si scrive come compare in anagrafica: la griglia si restringe a quella.

::textfield[classeSel]{label="Classe da mostrare" value="1A" placeholder="1A"}

::if-any{path="classi"}
Classi disponibili:

::list{path="classi" sort="nome"}
{nome} — {indirizzo}
::/list
::/if-any

::python{data="divieti,violazioni" params="classeSel" writes="chiuse-classe"}
```python
# Le caselle chiuse per la classe che stai guardando: i divieti dell'istituto,
# quelli dichiarati per lei, e le violazioni scritte dal controllo. Le tre cose
# finiscono in una collezione sola perché la griglia ne legge una sola — e perché
# per chi guarda sono la stessa cosa: caselle in cui non si mette niente.
chi = str(params.get("classeSel", "")).strip()
result = []
for v in data["divieti"]:
    ambito = str(v.get("ambito", "")).strip().lower()
    quale = str(v.get("chi", "")).strip()
    if ambito and ambito != "classe":
        continue
    if ambito == "classe" and quale != chi:
        continue
    result.append({
        "id": "cc-%s-%s" % (v.get("giorno", ""), v.get("ora", "")),
        "row": str(v.get("ora", "")), "col": v.get("giorno", ""), "for": "",
        "why": v.get("motivo", "") or ("Indisponibilità della classe" if ambito
                                       else "Indisponibilità dell'istituto"),
    })
# Solo le segnalazioni che parlano di una CASELLA. Il controllo ne scrive
# anche di più larghe — un tetto giornaliero sforato, un giorno libero perso —
# che hanno il giorno ma non l'ora, e infilarle qui aggiungeva righe che non
# chiudono niente e che nella griglia non si vedono: rumore in una collezione
# che si legge per capire perché una casella è grigia.
for v in data["violazioni"]:
    if str(v.get("row", "")).strip() and str(v.get("col", "")).strip():
        result.append({"id": "cv-" + str(v.get("id", "")), "row": v.get("row", ""),
                       "col": v.get("col", ""), "for": v.get("for", ""),
                       "why": v.get("why", "")})
print("%d caselle chiuse per la %s." % (len(result), chi or "classe scelta"))
```
::/python

::timetable{path="lezioni" filter="classe=#classeSel" rows="ora" cols="giorno" row-values="1,2,3,4,5,6" row-labels="1ª,2ª,3ª,4ª,5ª,6ª" col-values="lun,mar,mer,gio,ven,sab" col-labels="Lunedì,Martedì,Mercoledì,Giovedì,Venerdì,Sabato" colour="disciplina" pin="fisso" blocked="chiuse-classe" deletable id="grigliaClasse"}
**{disciplina}**
{docente} · {aula}
::/timetable

::if-empty{path="lezioni"}
La griglia è vuota: l'orario si genera in **Controlli e generazione**.
::/if-empty

## Per docente

La stessa direttiva, filtrata sul cognome: le ore buche e il giorno libero si
leggono qui, non nella griglia della classe. Un docente in compresenza compare
qui con le ore su cui si appoggia — che è il solo posto dove quelle ore si vedono
come sue.

::textfield[docenteSel]{label="Docente da mostrare" value="Basile" placeholder="Basile"}

::python{data="divieti,violazioni,docenti" params="docenteSel" writes="chiuse-docente"}
```python
# Come per la classe, più quello che il docente ha dichiarato in anagrafica: i
# giorni in cui non è in servizio e la prima ora che non fa. Sono vincoli duri
# che finora la griglia non mostrava affatto — si scoprivano trascinando e
# leggendo il controllo dopo.
GIORNI = ["lun", "mar", "mer", "gio", "ven", "sab"]
ORE = ["1", "2", "3", "4", "5", "6"]

chi = str(params.get("docenteSel", "")).strip()
suo = next((d for d in data["docenti"] if d.get("cognome", "") == chi), {})
result = []

def chiudi(ident, ora, giorno, perche, per=""):
    result.append({"id": ident, "row": ora, "col": giorno, "for": per, "why": perche})

for v in data["divieti"]:
    ambito = str(v.get("ambito", "")).strip().lower()
    quale = str(v.get("chi", "")).strip()
    if ambito and ambito != "docente":
        continue
    if ambito == "docente" and quale != chi:
        continue
    chiudi("cd-%s-%s" % (v.get("giorno", ""), v.get("ora", "")),
           str(v.get("ora", "")), v.get("giorno", ""),
           v.get("motivo", "") or ("Non disponibile" if ambito
                                   else "Indisponibilità dell'istituto"))

for giorno in [s.strip() for s in str(suo.get("giorniNon", "")).split(",") if s.strip()]:
    for ora in ORE:
        chiudi("cn-%s-%s" % (giorno, ora), ora, giorno,
               "%s non è in servizio di %s" % (chi, giorno))

if str(suo.get("nonPrimaOra", "")).strip().lower() in ("true", "1", "yes", "on", "si", "sì"):
    for giorno in GIORNI:
        chiudi("cp-%s" % giorno, "1", giorno, "%s non fa la prima ora" % chi)

# Come per la classe: solo le segnalazioni che nominano una casella.
for v in data["violazioni"]:
    if str(v.get("row", "")).strip() and str(v.get("col", "")).strip():
        chiudi("cv-" + str(v.get("id", "")), v.get("row", ""), v.get("col", ""),
               v.get("why", ""), v.get("for", ""))

print("%d caselle chiuse per %s." % (len(result), chi or "il docente scelto"))
```
::/python

::timetable{path="lezioni" filter="docente=#docenteSel" rows="ora" cols="giorno" row-values="1,2,3,4,5,6" row-labels="1ª,2ª,3ª,4ª,5ª,6ª" col-values="lun,mar,mer,gio,ven,sab" col-labels="Lunedì,Martedì,Mercoledì,Giovedì,Venerdì,Sabato" colour="classe" pin="fisso" blocked="chiuse-docente" id="grigliaDocente"}
**{classe}**
{disciplina} · {aula}
::/timetable

## Per aula

È la vista che conta per i laboratori e per le palestre, che sono poche e se le
contendono tutte le classi. La saturazione di ciascuna, in percentuale, sta in
**Laboratori e qualità**.

::textfield[aulaSel]{label="Aula da mostrare" value="LAB1" placeholder="LAB1"}

::python{data="divieti,violazioni" params="aulaSel" writes="chiuse-aula"}
```python
# Per la stanza: i divieti dell'istituto e quelli suoi — la palestra il sabato,
# il laboratorio il pomeriggio in cui c'è manutenzione.
chi = str(params.get("aulaSel", "")).strip()
result = []
for v in data["divieti"]:
    ambito = str(v.get("ambito", "")).strip().lower()
    quale = str(v.get("chi", "")).strip()
    if ambito and ambito != "aula":
        continue
    if ambito == "aula" and quale != chi:
        continue
    result.append({
        "id": "ca-%s-%s" % (v.get("giorno", ""), v.get("ora", "")),
        "row": str(v.get("ora", "")), "col": v.get("giorno", ""), "for": "",
        "why": v.get("motivo", "") or ("Stanza non utilizzabile" if ambito
                                       else "Indisponibilità dell'istituto"),
    })
for v in data["violazioni"]:
    if str(v.get("row", "")).strip() and str(v.get("col", "")).strip():
        result.append({"id": "cv-" + str(v.get("id", "")), "row": v.get("row", ""),
                       "col": v.get("col", ""), "for": v.get("for", ""),
                       "why": v.get("why", "")})
print("%d caselle chiuse per %s." % (len(result), chi or "l'aula scelta"))
```
::/python

::timetable{path="lezioni" filter="aula=#aulaSel" rows="ora" cols="giorno" row-values="1,2,3,4,5,6" row-labels="1ª,2ª,3ª,4ª,5ª,6ª" col-values="lun,mar,mer,gio,ven,sab" col-labels="Lunedì,Martedì,Mercoledì,Giovedì,Venerdì,Sabato" colour="classe" pin="fisso" blocked="chiuse-aula" id="grigliaAula"}
**{classe}**
{disciplina} · {docente}
::/timetable

**Perché la lezione porta i nomi e non gli id.** Le cattedre sono fatte di
riferimenti; la griglia no. Una casella si filtra, si stampa e si legge per come
è scritta — `classe=1A`, `docente=Basile` — e la generazione ci copia dentro i
nomi presi dalle cattedre. Il legame con la cattedra di partenza resta comunque
nel campo `cattedra` di ogni lezione.

::/page

::page{title="Controlli e generazione" icon="gears"}

# Controlli e generazione

Due blocchi, e nessuno dei due parte da solo: girano quando qualcuno preme il
loro pulsante. Il primo propone un orario, il secondo giudica quello che c'è.
Sono **Python puro**, senza pacchetti da scaricare, e mentre girano c'è il
pulsante **Ferma**, che termina l'esecuzione e tiene l'ultimo risultato
pubblicato.

## Divieti

Le ore in cui non si fa lezione. Senza **ambito** valgono per tutti — il plesso
chiuso, il collegio, il rientro che quest'anno non c'è — e diventano celle chiuse
nella griglia dopo il controllo, perché è il controllo a scrivere la collezione
che la griglia legge.

Con un ambito valgono per **una risorsa sola**: il laboratorio fermo per
manutenzione, il docente impegnato in commissione, la classe fuori per l'uscita
didattica. Sono altrettanto duri, ma non chiudono la casella a tutti gli altri, e
per questo la griglia non li disegna: comparirebbero come un divieto generale che
non sono. Il controllo li fa valere lo stesso, segnalando la lezione che ci
finisce dentro.

::form{path="divieti" id="formDivieto"}
::input{field="giorno" legend="Giorno" required pattern="lun|mar|mer|gio|ven|sab" message="Scrivi lun, mar, mer, gio, ven oppure sab"}
::input{field="ora" legend="Ora" type="number" min="1" max="6" required}
::input{field="ambito" legend="Ambito" help="Vuoto per tutti, oppure aula, docente, classe"}
::input{field="chi" legend="Chi" help="Il nome della risorsa: LAB1, Basile, 1A"}
::input{field="motivo" legend="Motivo" required help="Compare nella griglia quando qualcuno prova a rilasciare lì"}
::save{label="Vieta questa casella"}
::/form

::if-any{path="divieti"}
::table{path="divieti" sort="giorno" filters="ambito" deletable editform="formDivieto"}
::column{field="giorno" label="Giorno"}
::column{field="ora" label="Ora" align="end"}
::column{field="ambito" label="Ambito"}
::column{field="chi" label="Chi"}
::column{field="motivo" label="Motivo"}
::/table
::/if-any

## Pre-assegnazioni

Le ore decise prima di tutto il resto: la riunione del venerdì, il laboratorio
che quella classe ha soltanto il martedì, l'ora spostata a mano e da rivedere
uguale al prossimo giro. La generazione le colloca per prime e non le tocca più,
e nella griglia portano la bandierina.

Sono anche il modo di aggiungere una lezione **senza mouse**: si scrive qui e si
rigenera.

Se la cattedra ha un blocco di due ore, l'ora scritta qui è quella di
**inizio**: il blocco resta intero e prende anche quella dopo.

::form{path="preassegnazioni" id="formPreassegnazione"}
::input{field="classe" legend="Classe" required help="Il nome, come in anagrafica: 1A"}
::input{field="disciplina" legend="Disciplina" required help="Il nome per esteso: Matematica"}
::input{field="docente" legend="Docente" required help="Il cognome: Rinaldi"}
::input{field="giorno" legend="Giorno" required pattern="lun|mar|mer|gio|ven|sab" message="Scrivi lun, mar, mer, gio, ven oppure sab"}
::input{field="ora" legend="Ora d'inizio" type="number" min="1" max="6" required}
::save{label="Fissa questa ora"}
::/form

::if-any{path="preassegnazioni"}
**:count{path="preassegnazioni"}** ore pre-assegnate.

::table{path="preassegnazioni" sort="classe" deletable editform="formPreassegnazione"}
::column{field="classe" label="Classe"}
::column{field="disciplina" label="Disciplina"}
::column{field="docente" label="Docente"}
::column{field="giorno" label="Giorno"}
::column{field="ora" label="Ora" align="end"}
::/table
::/if-any

## La configurazione dell'istituto

Le due domande che valgono per tutti e che finora erano scritte dentro il codice:
quante ore al giorno fa una classe, e quante ne fa un docente. Sono un vincolo
**duro**, e sono la ragione per cui una settimana ha una forma invece che
un'altra: trenta ore su sei giorni con un tetto di sei significa che qualche
giornata sarà di quattro, e il minimo dice che non sarà di due.

Una classe o un docente che dichiarano il proprio minimo o massimo in anagrafica
vincono su questi: qui c'è la regola dell'istituto, lì l'eccezione di uno.

::slider[minOreClasse]{label="Ore minime al giorno per una classe" min="1" max="6" value="4"}
Da :value[minOreClasse]{ref="#minOreClasse"} a
:value[maxOreClasse]{ref="#maxOreClasse"} ore al giorno.

::slider[maxOreClasse]{label="Ore massime al giorno per una classe" min="1" max="6" value="6"}

::slider[minOreDocente]{label="Ore minime al giorno per un docente" min="0" max="6" value="0"}
Da :value[minOreDocente]{ref="#minOreDocente"} a
:value[maxOreDocente]{ref="#maxOreDocente"} ore al giorno.

::slider[maxOreDocente]{label="Ore massime al giorno per un docente" min="1" max="6" value="6"}

## I pesi

Cinque pesi e il numero di mosse tentate dopo la prima collocazione. Non
cambiano niente finché non si rigenera: il blocco è manuale apposta, perché una
euristica non deve ripartire perché qualcuno ha corretto un cognome.

::slider[pesoBucheClassi]{label="Ore buche della classe" min="0" max="200" value="150"}
Peso: :value[pesoBucheClassi]{ref="#pesoBucheClassi"}

::slider[pesoBuche]{label="Ore buche del docente" min="0" max="100" value="70"}
Peso: :value[pesoBuche]{ref="#pesoBuche"}

::slider[pesoGiornoLibero]{label="Giorno libero richiesto" min="0" max="100" value="90"}
Peso: :value[pesoGiornoLibero]{ref="#pesoGiornoLibero"}

::slider[pesoMattino]{label="Discipline pesanti nelle prime ore" min="0" max="100" value="40"}
Peso: :value[pesoMattino]{ref="#pesoMattino"}

::slider[pesoRipetizioni]{label="Stessa disciplina due volte nello stesso giorno" min="0" max="100" value="60"}
Peso: :value[pesoRipetizioni]{ref="#pesoRipetizioni"}

::slider[iterazioni]{label="Mosse tentate nel miglioramento" min="0" max="12000" value="6000" step="500"}
Mosse: :value[iterazioni]{ref="#iterazioni"}

Le mosse accolte sono **poche**, ed è giusto così: dopo la collocazione quasi
ogni blocco è già nella casella migliore date le altre, e quello che resta da
guadagnare sta negli scambi, che devono migliorare due orari insieme. Un
miglioramento che accetta metà delle mosse che prova non sta migliorando, sta
misurando male — ed è esattamente il difetto che c'era qui: il costo di dove il
blocco stava era calcolato senza toglierlo prima, quindi risultava più alto del
vero e quasi ogni spostamento sembrava un guadagno.

**L'ora buca della classe ha un peso suo, ed è il più alto di tutti.** Una buca
di un docente è un fastidio; una buca di una classe è un'ora di trenta ragazzi in
corridoio, e in una scuola italiana non è un difetto di qualità — è un orario che
non si può pubblicare. Resta comunque un peso e non un divieto, per una ragione
pratica: durante la costruzione una classe mezza piena ha per forza dei vuoti, e
vietarli mentre si colloca vorrebbe dire non collocare più niente. Alla fine
arriva una **compattazione** che le chiude a mano, e quello che resta lo dice il
monitor.

## Genera l'orario

Prima una **greedy**: le ore più vincolate per prime — un blocco di laboratorio
conteso da tre classi e un docente con poche caselle libere vengono serviti prima
di un'ora di religione — ciascuna nella casella e nell'aula meno costose fra
quelle ammesse. Poi un **miglioramento** che alterna due mosse: lo scambio di due
blocchi della stessa lunghezza, anche di classi diverse, e lo spostamento di un
blocco in una casella libera migliore. Lo scambio fra classi è quello che chiude
le ore buche, perché una buca di un docente si toglie quasi sempre muovendo l'ora
di un'altra classe.

Poi la **compattazione**, che è l'unica parte che guarda una giornata intera
invece di un blocco per volta: le ore di ogni classe scivolano in su fino a
toccarsi, e se anche una sola non ci sta quella giornata resta com'era.

I vincoli duri non si negoziano: una classe una lezione per volta, un docente in
un posto solo, un'aula fino a quante classi ci stanno, la capienza dell'aula, i
giorni di non disponibilità, il tetto e il pavimento giornalieri della classe e
del docente, il tetto sui giorni di servizio, la prima ora di chi non la fa, il
massimo giornaliero di una materia, le materie incompatibili e quelle da tenere
distanti, i divieti — e **nessun docente cambia plesso da un'ora alla
successiva**, che è il vincolo che sulla carta non si vede e nella realtà è il
primo a saltare. Tutto il resto è preferenza pesata, e una preferenza si può
perdere.

**Questo blocco riscrive tutto l'orario.** Quello che deve sopravvivere va messo
fra le pre-assegnazioni qui sopra.

::python{data="cattedre,classi,docenti,discipline,aule,divieti,preassegnazioni" params="pesoBuche,pesoBucheClassi,pesoGiornoLibero,pesoMattino,pesoRipetizioni,iterazioni,minOreClasse,maxOreClasse,minOreDocente,maxOreDocente" writes="lezioni" manual}
```python
import random

GIORNI = ["lun", "mar", "mer", "gio", "ven", "sab"]
ORE = ["1", "2", "3", "4", "5", "6"]
NORE = len(ORE)

def numero(v, d=0.0):
    try:
        return float(str(v).strip().replace(",", "."))
    except (TypeError, ValueError):
        return d

def intero(v, d=0):
    try:
        return int(float(str(v).strip().replace(",", ".")))
    except (TypeError, ValueError):
        return d

def vero(v):
    return str(v).strip().lower() in ("true", "1", "yes", "on", "si", "sì")

P_BUCHE = numero(params.get("pesoBuche"), 70.0) / 10.0
P_BUCHE_CL = numero(params.get("pesoBucheClassi"), 150.0) / 10.0
P_LIBERO = numero(params.get("pesoGiornoLibero"), 90.0) / 10.0
P_MATTINO = numero(params.get("pesoMattino"), 40.0) / 10.0
P_RIP = numero(params.get("pesoRipetizioni"), 60.0) / 10.0
P_FUORI = 500.0            # un'aula fuori dal plesso della classe: quasi un divieto
MOSSE = intero(params.get("iterazioni"), 2000)

# La regola dell'istituto. L'eccezione di una classe o di un docente sta in
# anagrafica e vince su questa, che è il solo ordine sensato fra le due: qui c'è
# quello che vale per tutti, lì quello che vale per uno.
MIN_CL = max(0, min(intero(params.get("minOreClasse"), 4), NORE))
MAX_CL = max(1, min(intero(params.get("maxOreClasse"), 6) or NORE, NORE))
MIN_DOC = max(0, min(intero(params.get("minOreDocente"), 0), NORE))
MAX_DOC = max(1, min(intero(params.get("maxOreDocente"), 6) or NORE, NORE))
if MIN_CL > MAX_CL:
    MIN_CL = MAX_CL

classi = {r["id"]: r for r in data["classi"]}
docenti = {r["id"]: r for r in data["docenti"]}
discipline = {r["id"]: r for r in data["discipline"]}
aule = list(data["aule"])
aula_per_nome = {r.get("nome", ""): r for r in aule}

# Il tetto giornaliero di ogni classe, e quante classi tiene ogni stanza.
max_classe = {}
min_classe = {}
for r in data["classi"]:
    nome = r.get("nome", "")
    max_classe[nome] = min(intero(r.get("maxOreGiorno", ""), 0) or MAX_CL, NORE)
    min_classe[nome] = min(intero(r.get("minOreGiorno", ""), 0) or MIN_CL, max_classe[nome])

posti_aula = {}
for r in aule:
    posti_aula[r.get("nome", "")] = max(1, intero(r.get("classiInsieme", ""), 0) or 1)

# I vincoli fra discipline, letti una volta e simmetrizzati: dichiararli da una
# parte sola deve bastare, altrimenti sono due righe che possono contraddirsi.
nome_disciplina = {r.get("id", ""): r.get("nome", "") for r in data["discipline"]}
incompatibili = {}
non_consecutive = {}


def _lega(mappa, a, b):
    if not a or not b or a == b:
        return
    mappa.setdefault(a, set()).add(b)
    mappa.setdefault(b, set()).add(a)


for r in data["discipline"]:
    mio = r.get("nome", "")
    for altro in str(r.get("incompatibili", "")).split(","):
        _lega(incompatibili, mio, altro.strip())
    for altro in str(r.get("nonConsecutivaCon", "")).split(","):
        _lega(non_consecutive, mio, altro.strip())

max_al_giorno = {}
for r in data["discipline"]:
    quante = intero(r.get("maxAlGiorno", ""), 0)
    if quante > 0:
        max_al_giorno[r.get("nome", "")] = quante

# I divieti. Senza ambito valgono per tutti; con un ambito valgono per una
# risorsa sola, e sono altrettanto duri.
vietate = set()
vietate_per = {"aula": set(), "docente": set(), "classe": set()}
for v in data["divieti"]:
    g, o = v.get("giorno", ""), str(v.get("ora", ""))
    ambito = str(v.get("ambito", "")).strip().lower()
    chi = str(v.get("chi", "")).strip()
    if ambito in vietate_per and chi:
        vietate_per[ambito].add((chi, g, o))
    else:
        vietate.add((g, o))

celle = [(g, i) for g in GIORNI for i in range(NORE) if (g, ORE[i]) not in vietate]

# --- Le unità -------------------------------------------------------------
# Un'unità è un BLOCCO di ore consecutive da collocare insieme: quattro ore di
# informatica con blocco due sono due unità di due, non quattro di una. È la sola
# differenza strutturale con la versione precedente, e da lì viene tutto il resto:
# un blocco è indivisibile, quindi o entra intero o non entra.
#
# Le compresenze con "affianca" NON sono un secondo giro: sono attaccate qui
# all'unità del titolare, così i loro vincoli valgono mentre si sceglie la
# casella. Sistemarle dopo sembrava più semplice e produceva orari in cui l'ITP
# era in laboratorio un giorno in cui non è in servizio — e nessuno lo scopriva
# fino al controllo.
affiancanti = {}
for k in data["cattedre"]:
    if not vero(k.get("compresenza", "")):
        continue
    bersaglio = str(k.get("affianca", "")).strip()
    docente = docenti.get(k.get("docente", ""))
    disciplina = discipline.get(k.get("disciplina", ""))
    if not bersaglio or not docente:
        continue
    affiancanti.setdefault(bersaglio, []).append({
        "cattedra": k.get("id", ""),
        "cognome": docente.get("cognome", ""),
        "disciplina": disciplina.get("nome", "") if disciplina else "",
        "resto": intero(k.get("ore", ""), 0),
        "giorniNon": [s.strip() for s in str(docente.get("giorniNon", "")).split(",") if s.strip()],
        "maxOre": min(intero(docente.get("maxOreGiorno", ""), 0) or MAX_DOC, NORE),
        "maxGiorni": intero(docente.get("maxGiorniServizio", ""), 0) or len(GIORNI),
        "nonPrima": vero(docente.get("nonPrimaOra", "")),
    })

unita = []
senza_aula = []
compresenze_scoperte = []
distribuzioni_ignorate = []
for k in data["cattedre"]:
    if vero(k.get("compresenza", "")):
        continue
    classe = classi.get(k.get("classe", ""))
    disciplina = discipline.get(k.get("disciplina", ""))
    docente = docenti.get(k.get("docente", ""))
    if not classe or not disciplina or not docente:
        continue
    alunni = intero(classe.get("alunni", ""), 0)
    plesso_classe = classe.get("plesso", "")

    # Le aule ammesse. Una stanza obbligata vince su tutto; altrimenti è il TIPO
    # chiesto dalla disciplina a decidere, e fra le stanze di quel tipo restano
    # quelle abbastanza capienti — nel plesso della classe, se ce n'è una.
    obbligata = aula_per_nome.get(str(k.get("aula", "")).strip())
    if obbligata:
        ammesse_aule = [obbligata]
    else:
        tipo = str(disciplina.get("aulaRichiesta", "")).strip().lower()
        if tipo == "":
            base = aula_per_nome.get(classe.get("aulaBase", ""))
            ammesse_aule = [base] if base else []
        else:
            capaci = [a for a in aule
                      if str(a.get("tipo", "")).strip().lower() == tipo
                      and intero(a.get("capienza", ""), 0) >= alunni]
            dentro = [a for a in capaci if a.get("plesso", "") == plesso_classe]
            ammesse_aule = dentro if dentro else capaci

    if not ammesse_aule:
        senza_aula.append("%s %s" % (classe.get("nome", ""), disciplina.get("nome", "")))
        continue

    lung = intero(k.get("blocco", ""), 0) or intero(disciplina.get("blocco", ""), 0) or 1
    lung = max(1, min(lung, NORE))
    resto = intero(k.get("ore", ""), 0)

    # La distribuzione dice come spezzare le ore fra le giornate: "2+1+1" è una
    # doppia e due singole. È una FORMA, non un conto, e questa è la differenza
    # che conta: la stessa disciplina ha quattro ore in una classe e tre in
    # un'altra, e una forma che valesse solo dove i numeri tornano esatti sarebbe
    # da riscrivere classe per classe — cioè non sarebbe una regola.
    #
    # Quindi si adatta, e nel modo in cui lo farebbe una persona: si prendono le
    # giornate dichiarate in ordine finché le ore bastano, l'ultima si accorcia
    # se avanza meno di quanto chiede, e se le ore finiscono dopo la forma si
    # continua a un'ora al giorno. "2+1+1" su tre ore è 2+1; su cinque è 2+1+1+1.
    # Solo una cifra più lunga di una giornata intera è un refuso, e quella si
    # dice: significa che qualcuno ha scritto 12 dove voleva 1+2.
    scritta = str(k.get("distribuzione", "")).strip() or \
        str(disciplina.get("distribuzione", "")).strip()
    pezzi = []
    if scritta:
        parti = [intero(p, 0) for p in scritta.replace(" ", "").split("+")]
        troppo = [p for p in parti if p > NORE]
        parti = [p for p in parti if 0 < p <= NORE]
        if troppo:
            distribuzioni_ignorate.append(
                "%s %s: «%s» chiede una giornata di %d ore e la giornata è di %d"
                % (classe.get("nome", ""), disciplina.get("nome", ""), scritta,
                   max(troppo), NORE))
        avanzo = resto
        for p in parti:
            if avanzo <= 0:
                break
            pezzi.append(min(p, avanzo))
            avanzo -= pezzi[-1]
        while avanzo > 0:
            pezzi.append(1)
            avanzo -= 1
    if not pezzi:
        while resto > 0:
            pezzi.append(min(lung, resto))
            resto -= min(lung, resto)

    for n, L in enumerate(pezzi):
        # Chi affianca copre le ore del titolare in ordine, e solo a blocchi
        # interi: mezzo blocco di compresenza non è una cosa che la griglia sappia
        # scrivere, e fingere che lo sia perderebbe la metà che non ci sta.
        con = []
        for c in affiancanti.get(k.get("id", ""), []):
            if c["resto"] >= L:
                c["resto"] -= L
                con.append(c)
        unita.append({
            "cattedra": k.get("id", ""),
            "classe": classe.get("nome", ""),
            "plessoClasse": plesso_classe,
            "disciplina": disciplina.get("nome", ""),
            "docente": docente.get("cognome", ""),
            "aule": ammesse_aule,
            "nomiAule": {a.get("nome", "") for a in ammesse_aule},
            "compresenti": con,
            "lung": L,
            "n": n,
            # Il carico, da 0 a 10. Una riga scritta prima che questo campo
            # esistesse porta ancora la bandierina, e vale 8 o 3.
            "peso": (intero(disciplina.get("peso", ""), -1)
                     if str(disciplina.get("peso", "")).strip() != ""
                     else (8 if vero(disciplina.get("mattino", "")) else 3)),
            "libero": docente.get("giornoLibero", ""),
            "giorniNon": [s.strip() for s in str(docente.get("giorniNon", "")).split(",") if s.strip()],
            "maxOre": min(intero(docente.get("maxOreGiorno", ""), 0) or MAX_DOC, NORE),
            "maxGiorni": intero(docente.get("maxGiorniServizio", ""), 0) or len(GIORNI),
            "nonPrima": vero(docente.get("nonPrimaOra", "")),
            "giorno": "",
            "i0": -1,
            "aula": None,
        })

# Le ore di chi affianca che non hanno trovato un blocco intero da coprire: o la
# cattedra affiancata non esiste, o le sue ore sono meno di quelle dichiarate.
for lista in affiancanti.values():
    for c in lista:
        if c["resto"] > 0:
            compresenze_scoperte.append("%s (%d ore)" % (c["cognome"], c["resto"]))

if not unita:
    print("Nessuna cattedra collocabile: semina le anagrafiche e le cattedre in Avvio.")
    if senza_aula:
        print("Senza nessuna aula ammessa: %s." % ", ".join(sorted(set(senza_aula))))
    result = []
else:
    occ_classe = {}
    occ_docente = {}      # (docente, giorno, ora) -> plesso dell'aula
    occ_aula = {}         # (aula, giorno, ora) -> quante classi ci sono dentro
    ore_doc = {}          # (docente, giorno) -> set di indici d'ora
    ore_classe = {}       # (classe, giorno) -> set di indici d'ora
    disc_giorno = {}      # (classe, disciplina, giorno) -> quante unità
    disc_ore = {}         # (classe, disciplina, giorno) -> quante ORE
    collocate = []
    fissate = set()

    def hours(u, i0):
        return range(i0, i0 + u["lung"])

    def docente_libero(cog, giorni_non, max_ore, non_prima, g, i0, lung, plesso,
                       max_giorni=None):
        # Le condizioni sono le stesse per il titolare e per chi lo affianca: chi
        # sta in quella casella ci sta, e il fatto che uno dei due sia in
        # compresenza non gli restituisce il giorno in cui non è in servizio.
        if g in giorni_non:
            return False
        if len(ore_doc.get((cog, g), ())) + lung > max_ore:
            return False
        # Il tetto sui GIORNI, non sulle ore: uno spezzone di dodici ore che sale
        # quattro giorni invece di sei è la richiesta più frequente di chi ha una
        # cattedra su due scuole, e senza questa riga si può soltanto chiedere di
        # non salire mai — che è un'altra cosa.
        if max_giorni is not None and not ore_doc.get((cog, g)):
            saliti = sum(1 for gg in GIORNI if ore_doc.get((cog, gg)))
            if saliti + 1 > max_giorni:
                return False
        for i in range(i0, i0 + lung):
            if non_prima and i == 0:
                return False
            if (cog, g, ORE[i]) in occ_docente:
                return False
            if (cog, g, ORE[i]) in vietate_per["docente"]:
                return False
        # Nessuno si sposta di plesso da un'ora alla successiva: si guardano l'ora
        # prima e l'ora dopo il blocco, che sono le sole che confinano.
        for i in (i0 - 1, i0 + lung):
            if 0 <= i < NORE:
                altro = occ_docente.get((cog, g, ORE[i]))
                if altro is not None and altro != plesso:
                    return False
        return True

    def ammessa(u, g, i0, a):
        if i0 < 0 or i0 + u["lung"] > NORE:
            return False
        cls, aul = u["classe"], a.get("nome", "")
        # L'aula deve essere una delle sue: uno scambio muove due blocchi e con
        # loro le stanze, e senza questa riga un'ora di matematica finiva in
        # un'aula che non era mai stata fra quelle ammesse — nel plesso giusto e
        # troppo piccola, che è il modo più discreto di sbagliare.
        if aul not in u["nomiAule"]:
            return False
        for i in hours(u, i0):
            o = ORE[i]
            if (g, o) in vietate:
                return False
            if (cls, g, o) in occ_classe:
                return False
            # Una stanza può tenere più di una classe: la palestra divisa a metà
            # ne tiene due. Si conta, non si guarda se è occupata.
            if occ_aula.get((aul, g, o), 0) + 1 > posti_aula.get(aul, 1):
                return False
            if (aul, g, o) in vietate_per["aula"]:
                return False
            if (cls, g, o) in vietate_per["classe"]:
                return False
        # Il tetto giornaliero della classe. È il vincolo che dà la forma alla
        # settimana, e va guardato prima dei desideri: senza, trenta ore su sei
        # giorni diventano sei il lunedì e due il sabato.
        if len(ore_classe.get((cls, g), ())) + u["lung"] > max_classe.get(cls, MAX_CL):
            return False
        # Le regole fra discipline, tutte e tre sulla giornata della CLASSE.
        mia = u["disciplina"]
        tetto = max_al_giorno.get(mia)
        if tetto is not None and disc_ore.get((cls, mia, g), 0) + u["lung"] > tetto:
            return False
        vietate_oggi = incompatibili.get(mia)
        if vietate_oggi:
            for altra in vietate_oggi:
                if disc_ore.get((cls, altra, g), 0) > 0:
                    return False
        distanti = non_consecutive.get(mia)
        if distanti:
            n = GIORNI.index(g)
            for vicino in (n - 1, n + 1):
                if 0 <= vicino < len(GIORNI):
                    for altra in distanti:
                        if disc_ore.get((cls, altra, GIORNI[vicino]), 0) > 0:
                            return False
        plesso = a.get("plesso", "")
        if not docente_libero(u["docente"], u["giorniNon"], u["maxOre"], u["nonPrima"],
                              g, i0, u["lung"], plesso, u["maxGiorni"]):
            return False
        for c in u["compresenti"]:
            if not docente_libero(c["cognome"], c["giorniNon"], c["maxOre"], c["nonPrima"],
                                  g, i0, u["lung"], plesso, c.get("maxGiorni")):
                return False
        return True

    def piazza(u, g, i0, a):
        cls, aul = u["classe"], a.get("nome", "")
        plesso = a.get("plesso", "")
        for i in hours(u, i0):
            o = ORE[i]
            occ_classe[(cls, g, o)] = u
            occ_aula[(aul, g, o)] = occ_aula.get((aul, g, o), 0) + 1
            ore_classe.setdefault((cls, g), set()).add(i)
            for cog in [u["docente"]] + [c["cognome"] for c in u["compresenti"]]:
                occ_docente[(cog, g, o)] = plesso
                ore_doc.setdefault((cog, g), set()).add(i)
        chiave = (cls, u["disciplina"], g)
        disc_giorno[chiave] = disc_giorno.get(chiave, 0) + 1
        disc_ore[chiave] = disc_ore.get(chiave, 0) + u["lung"]
        u["giorno"], u["i0"], u["aula"] = g, i0, a
        collocate.append(u)

    def togli(u):
        g, i0, a = u["giorno"], u["i0"], u["aula"]
        cls, aul = u["classe"], a.get("nome", "")
        for i in hours(u, i0):
            o = ORE[i]
            occ_classe.pop((cls, g, o), None)
            rimasti = occ_aula.get((aul, g, o), 1) - 1
            if rimasti > 0:
                occ_aula[(aul, g, o)] = rimasti
            else:
                occ_aula.pop((aul, g, o), None)
            ore_classe.get((cls, g), set()).discard(i)
            for cog in [u["docente"]] + [c["cognome"] for c in u["compresenti"]]:
                occ_docente.pop((cog, g, o), None)
                ore_doc.get((cog, g), set()).discard(i)
        chiave = (cls, u["disciplina"], g)
        disc_giorno[chiave] = max(0, disc_giorno.get(chiave, 1) - 1)
        disc_ore[chiave] = max(0, disc_ore.get(chiave, u["lung"]) - u["lung"])
        collocate.remove(u)
        u["giorno"], u["i0"], u["aula"] = "", -1, None

    def buche_di(cls, g):
        # I vuoti fra la prima e l'ultima ora della classe quel giorno. Serve al
        # miglioramento per sapere che cosa lascia dietro di sé, e alla stampa
        # finale per contare quello che è rimasto: una definizione sola, o i due
        # numeri finirebbero per non tornare.
        dentro = ore_classe.get((cls, g), set())
        if len(dentro) < 2:
            return 0
        return (max(dentro) - min(dentro) + 1) - len(dentro)

    def costo(u, g, i0, a):
        # Il costo di TENERE u lì, calcolato quando u non è collocata: il
        # miglioramento toglie sempre prima di misurare, così le due misure sono
        # confrontabili e nessuna conta se stessa.
        c = 0.0
        # Il carico decide QUANTO costa stare tardi, non se. Con la bandierina di
        # prima una materia era del mattino o non lo era, e fra un'ora di
        # religione e quattro di matematica non c'era ordine: adesso la matematica
        # paga dieci volte quello che paga la religione a stare in sesta, e sale
        # da sé senza che nessuno lo chieda.
        if u["peso"] > 0:
            for i in hours(u, i0):
                c += P_MATTINO * i * (u["peso"] / 5.0)
        if u["libero"] and u["libero"] == g:
            c += P_LIBERO * 6.0 * u["lung"]
        c += P_RIP * disc_giorno.get((u["classe"], u["disciplina"], g), 0) * 3.0
        sue = ore_doc.get((u["docente"], g), set())
        if sue:
            tutte = sorted(set(sue) | set(hours(u, i0)))
            c += P_BUCHE * ((tutte[-1] - tutte[0] + 1) - len(tutte)) * 2.0
        # E le buche della CLASSE, che pesano il doppio di quelle di un docente
        # perché sono trenta ragazzi in corridoio. Si misura la giornata intera
        # come sarebbe con u dentro: una buca è un vuoto FRA due lezioni, e una
        # giornata che comincia in seconda ora non ha una buca, ha un ingresso
        # posticipato — che è un'altra cosa e non si conta qui.
        loro = ore_classe.get((u["classe"], g), set())
        insieme = sorted(set(loro) | set(hours(u, i0)))
        if len(insieme) > 1:
            c += P_BUCHE_CL * ((insieme[-1] - insieme[0] + 1) - len(insieme)) * 4.0
        # Una giornata che parte tardi è comunque peggio di una che parte presto:
        # senza questo la compattazione avrebbe due soluzioni ugualmente buone e
        # ne sceglierebbe una a caso, che è come dire che l'orario cambia forma da
        # una generazione all'altra senza che nulla sia cambiato.
        if insieme:
            c += P_BUCHE_CL * insieme[0] * 0.5
        # Una giornata sotto il minimo TIRA. Il tetto giornaliero è un divieto e
        # si fa rispettare rifiutando; il pavimento no — nessuno può rifiutare di
        # non mettere abbastanza ore, si può solo rendere conveniente metterle
        # lì. Senza questo sconto una classe finiva con un martedì di due ore e
        # gli altri giorni pieni: legale sotto ogni tetto, e una mattina che
        # nessuna scuola manda a casa così.
        #
        # Lo sconto è UN quarto di quello che costa un'ora buca (uno contro
        # quattro), e la proporzione non è una taratura: una giornata corta è un
        # difetto della settimana, una buca è un difetto della mattina, e la
        # seconda si sente di più. Messo alla pari, il generatore riempiva il
        # giorno corto spaccando in due quello da cui prendeva le ore — che è
        # scambiare un problema con uno peggiore.
        minimo = min_classe.get(u["classe"], MIN_CL)
        if len(loro) < minimo:
            c -= P_BUCHE_CL * (minimo - len(loro)) * 1.0
        if a.get("plesso", "") != u["plessoClasse"]:
            c += P_FUORI
        # A parità di tutto, la stanza più piccola fra quelle adeguate: tenere
        # libero il laboratorio grande è quello che salva la classe numerosa.
        c += intero(a.get("capienza", ""), 0) * 0.01
        return c

    def migliore(u, prima=None):
        scelte = []
        for (g, i0) in celle:
            for a in u["aule"]:
                if ammessa(u, g, i0, a):
                    scelte.append((costo(u, g, i0, a), GIORNI.index(g), i0,
                                   a.get("nome", ""), g, a))
        if not scelte:
            return None
        scelte.sort(key=lambda s: (s[0], s[1], s[2], s[3]))
        if prima is not None and scelte[0][0] >= prima:
            return None
        return scelte[0]

    def righe():
        fuori = []
        for u in collocate:
            for i in hours(u, u["i0"]):
                comune = {
                    "classe": u["classe"],
                    "aula": u["aula"].get("nome", ""),
                    "plesso": u["aula"].get("plesso", ""),
                    "giorno": u["giorno"],
                    "ora": ORE[i],
                }
                fuori.append(dict(comune, **{
                    "id": "l-%s-%s-%s" % (u["classe"], u["giorno"], ORE[i]),
                    "disciplina": u["disciplina"],
                    "docente": u["docente"],
                    "cattedra": u["cattedra"],
                    "compresenza": "false",
                    "fisso": "true" if id(u) in fissate else "false",
                }))
                for c in u["compresenti"]:
                    fuori.append(dict(comune, **{
                        "id": "l-%s-%s-%s-%s" % (u["classe"], u["giorno"], ORE[i], c["cattedra"]),
                        "disciplina": c["disciplina"] or u["disciplina"],
                        "docente": c["cognome"],
                        "cattedra": c["cattedra"],
                        "compresenza": "true",
                        "fisso": "false",
                    }))
        return fuori

    # Le pre-assegnazioni per prime, e restano dove sono.
    for p in data["preassegnazioni"]:
        g = p.get("giorno", "")
        o = str(p.get("ora", ""))
        if o not in ORE or g not in GIORNI:
            continue
        i0 = ORE.index(o)
        for u in unita:
            if u["giorno"]:
                continue
            if (u["classe"] == p.get("classe", "")
                    and u["disciplina"] == p.get("disciplina", "")
                    and u["docente"] == p.get("docente", "")):
                messa = False
                for a in u["aule"]:
                    if ammessa(u, g, i0, a):
                        piazza(u, g, i0, a)
                        fissate.add(id(u))
                        messa = True
                        break
                if messa:
                    break

    # Greedy: le unità più vincolate per prime. Un blocco lungo vincola più di
    # un'ora sola, un'aula contesa da più classi più di un'aula base, un docente
    # con giorni di non disponibilità più di uno sempre presente.
    contese = {}
    for u in unita:
        for a in u["aule"]:
            contese.setdefault(a.get("nome", ""), set()).add(u["classe"])

    def rigidita(u):
        peso = u["lung"] * 2
        if len(u["aule"]) == 1:
            peso += 1
        if any(len(contese.get(a.get("nome", ""), ())) > 1 for a in u["aule"]):
            peso += 3
        peso += len(u["giorniNon"])
        if u["maxOre"] < NORE:
            peso += 1
        if u["maxGiorni"] < len(GIORNI):
            peso += 2
        if u["libero"]:
            peso += 1
        # Una materia che non può ripetersi nel giorno, o che ne esclude un'altra,
        # ha meno giornate disponibili di quante ne abbia la settimana: se non
        # parte per prima trova occupato quello che le serviva.
        if max_al_giorno.get(u["disciplina"], NORE) <= 1:
            peso += 2
        peso += len(incompatibili.get(u["disciplina"], ())) * 2
        peso += len(non_consecutive.get(u["disciplina"], ()))
        return (-peso, u["classe"], u["disciplina"], u["n"])

    da_fare = [u for u in unita if not u["giorno"]]
    da_fare.sort(key=rigidita)
    totale = max(len(da_fare), 1)
    non_collocate = []

    for i, u in enumerate(da_fare):
        scelta = migliore(u)
        if scelta is None:
            non_collocate.append(u)
        else:
            piazza(u, scelta[4], scelta[2], scelta[5])
        if i % 10 == 0 or i + 1 == totale:
            progress(i + 1, totale, "collocazione: %d blocchi su %d" % (i + 1, totale))
            partial(righe())

    # Miglioramento, con un seme fisso: due esecuzioni sugli stessi dati danno lo
    # stesso orario, che è quello che rende confrontabili due pesi.
    #
    # Due mosse alternate. Lo SPOSTAMENTO porta un blocco nella casella libera
    # migliore; lo SCAMBIO inverte due blocchi della stessa lunghezza, anche di
    # classi diverse — ed è quello che chiude le ore buche, perché la buca di un
    # docente si toglie quasi sempre muovendo l'ora di un'altra classe.
    #
    # Miglioramento e compattazione si alternano, in tre giri, e non è un
    # dettaglio di taratura. Sono due mosse che si sbloccano a vicenda: il
    # miglioramento fa spazio muovendo l'ora di un'altra classe, la compattazione
    # usa quello spazio per chiudere il buco, e il buco chiuso libera la mossa
    # successiva. Fatti una volta sola e in fila le ore buche di classe restavano
    # cinque su centottanta ore e cambiavano numero a ogni seme, che è il modo in
    # cui un risultato dice «ci ho azzeccato» invece di «ho finito».
    sorte = random.Random(20260813)
    mobili = [u for u in collocate if id(u) not in fissate]
    conti = {"accolte": 0, "spostati": 0}
    GIRI = 3

    def migliora(quante, fatte_prima):
        if not mobili or quante <= 0:
            return
        for passo in range(quante):
            if passo % 2 == 0 or len(mobili) < 2:
                u = sorte.choice(mobili)
                g0, i0, a0 = u["giorno"], u["i0"], u["aula"]
                # Togliere PRIMA di misurare, non dopo. Il costo di una casella
                # dipende da che cosa c'è già in quella giornata, e misurandolo
                # con u ancora dentro si contava u anche fra i suoi vicini: la
                # ripetizione della stessa disciplina veniva contata una volta di
                # troppo, il costo di dov'era risultava più alto del vero, e
                # quasi ogni spostamento sembrava un miglioramento. Da lì il
                # comportamento che aveva tradito il difetto — più mosse davano
                # un orario peggiore, che è il contrario di quello che una
                # ricerca locale può fare.
                togli(u)
                prima = costo(u, g0, i0, a0)
                # E il buco che u LASCIA andandosene. Il costo di una casella
                # dice quanto vale stare lì; non dice niente di quello che
                # succede a dove si era, e una lezione tolta dal mezzo di una
                # giornata compatta la spacca in due. È il motivo per cui la
                # compattazione chiudeva i buchi e il giro dopo li ritrovava
                # aperti: nessuno li stava contando, quindi riaprirli era gratis.
                lasciato = P_BUCHE_CL * buche_di(u["classe"], g0) * 4.0
                scelta = migliore(u, prima)
                if scelta is not None and scelta[4] != g0 and scelta[0] + lasciato >= prima:
                    scelta = None
                if scelta is None:
                    piazza(u, g0, i0, a0)
                else:
                    piazza(u, scelta[4], scelta[2], scelta[5])
                    conti["accolte"] += 1
            else:
                a = sorte.choice(mobili)
                simili = [v for v in mobili if v is not a and v["lung"] == a["lung"]]
                if not simili:
                    continue
                b = sorte.choice(simili)
                ga, ia, aa = a["giorno"], a["i0"], a["aula"]
                gb, ib, ab = b["giorno"], b["i0"], b["aula"]
                # Stessa regola dello spostamento: si tolgono tutti e due e poi
                # si misura, così le due somme guardano lo stesso orario.
                togli(a)
                togli(b)
                prima = costo(a, ga, ia, aa) + costo(b, gb, ib, ab)
                dopo = None
                if ammessa(a, gb, ib, ab) and ammessa(b, ga, ia, aa):
                    dopo = costo(a, gb, ib, ab) + costo(b, ga, ia, aa)
                if dopo is not None and dopo < prima:
                    piazza(a, gb, ib, ab)
                    piazza(b, ga, ia, aa)
                    conti["accolte"] += 1
                else:
                    piazza(a, ga, ia, aa)
                    piazza(b, gb, ib, ab)
            if passo % 100 == 0:
                progress(fatte_prima + passo + 1, MOSSE,
                         "miglioramento: %d mosse accolte" % conti["accolte"])
                partial(righe())

    # --- Compattazione delle giornate ---------------------------------------
    # L'ultima cosa, e la sola che guarda una giornata intera invece di un blocco
    # per volta: una classe deve trovare le sue ore attaccate, dalla prima in
    # avanti, e un buco in mezzo è mezz'ora di trenta ragazzi in corridoio.
    #
    # Il primo tentativo fu di togliere tutti i blocchi della giornata e
    # rimetterli di seguito, e non chiudeva quasi niente: basta che UNO dei sei
    # non stia nella sua nuova casella — il docente è occupato in un'altra
    # classe, il laboratorio è pieno — e la giornata torna com'era, buchi
    # compresi. Sei condizioni che devono valere tutte insieme sono sei modi di
    # fallire.
    #
    # Questo invece sposta UN blocco per volta dentro il primo buco che trova, e
    # riprova finché ne trova. Ogni mossa che riesce toglie un buco e non ne
    # crea, quindi si può fermare in qualsiasi momento senza aver peggiorato
    # niente: è la differenza fra una cosa che riesce o fallisce e una che
    # migliora quanto può.
    #
    # Una casella fissata non si muove e blocca la sua giornata: farla scivolare
    # in su sarebbe esattamente il tradimento che la bandierina promette di non
    # fare.
    def buco_di(cls, g):
        # Il primo posto vuoto sotto l'ultima ora della classe quel giorno, e
        # quante ore libere ci sono di seguito. Le ore che una classe fa in un
        # giorno vanno da 0 in avanti senza salti, quindi «vuoto» comprende anche
        # una giornata che comincia in seconda ora.
        dentro = ore_classe.get((cls, g), set())
        if not dentro:
            return None, 0
        quante = len(dentro)
        primo = next((i for i in range(quante) if i not in dentro), None)
        if primo is None:
            return None, 0
        libere = 0
        while primo + libere < NORE and (primo + libere) not in dentro:
            libere += 1
        return primo, libere

    giornate = sorted({(u["classe"], u["giorno"]) for u in collocate})
    ferme = {(u["classe"], u["giorno"]) for u in collocate if id(u) in fissate}
    intoccabili = len(ferme)

    def compatta():
        for (cls, g) in sorted({(u["classe"], u["giorno"]) for u in collocate}):
            if (cls, g) in ferme:
                continue
            for _ in range(NORE * 2):
                buco, libere = buco_di(cls, g)
                if buco is None:
                    break
                # I candidati sono i blocchi di quel giorno che stanno DOPO il
                # buco e che ci entrano. Il più lungo per primo: chiude più buco
                # in una mossa sola, e lascia al giro dopo un buco più piccolo da
                # riempire con un blocco più piccolo.
                candidati = [u for u in collocate
                             if u["classe"] == cls and u["giorno"] == g
                             and u["i0"] > buco and u["lung"] <= libere]
                candidati.sort(key=lambda u: (-u["lung"], u["i0"]))
                spostato = False
                for u in candidati:
                    g0, i0, a0 = u["giorno"], u["i0"], u["aula"]
                    togli(u)
                    # La stanza di prima per prima, poi le altre ammesse: un
                    # blocco che non entra nel buco perché il SUO laboratorio è
                    # occupato a quell'ora spesso entra nell'altro, e insistere
                    # sulla stanza di partenza lasciava aperti buchi che una
                    # persona avrebbe chiuso senza pensarci.
                    scelte = [a0] + [a for a in u["aule"] if a is not a0]
                    for a in scelte:
                        if ammessa(u, g, buco, a):
                            piazza(u, g, buco, a)
                            spostato = True
                            conti["spostati"] += 1
                            break
                    if spostato:
                        break
                    piazza(u, g0, i0, a0)
                if not spostato:
                    break

    quante = MOSSE // GIRI
    for giro in range(GIRI):
        migliora(quante, giro * quante)
        compatta()

    result = righe()

    # --- Il sostegno --------------------------------------------------------
    # Una compresenza con "affianca" è già collocata: sta nell'unità del titolare
    # e ha pesato sulla scelta della casella. Resta quella SENZA, che non si
    # attacca a una cattedra ma alla classe intera, e prende le sue ore dalla
    # prima della settimana in avanti — che è il sostegno.
    #
    # Anche qui i vincoli valgono: un'ora rifiutata è un'ora che il docente non
    # può fare, e va detta, non nascosta prendendo la casella dopo in silenzio.
    posate = 0
    saltate = 0
    for k in data["cattedre"]:
        if not vero(k.get("compresenza", "")) or str(k.get("affianca", "")).strip():
            continue
        classe = classi.get(k.get("classe", ""))
        disciplina = discipline.get(k.get("disciplina", ""))
        docente = docenti.get(k.get("docente", ""))
        if not classe or not disciplina or not docente:
            continue
        doc = docente.get("cognome", "")
        giorni_non = [s.strip() for s in str(docente.get("giorniNon", "")).split(",") if s.strip()]
        max_ore = min(intero(docente.get("maxOreGiorno", ""), 0) or MAX_DOC, NORE)
        non_prima = vero(docente.get("nonPrimaOra", ""))
        quante = intero(k.get("ore", ""), 0)
        caselle = []
        for u in collocate:
            if u["classe"] != classe.get("nome", ""):
                continue
            for i in hours(u, u["i0"]):
                caselle.append((GIORNI.index(u["giorno"]), i, u))
        # Il sostegno si distribuisce sulla settimana, non si accumula. Prese in
        # ordine, diciotto ore riempirebbero i primi tre giorni per intero e
        # lascerebbero la classe scoperta negli altri tre — che è esattamente
        # quello che il sostegno non è. Si gira per giorni, un'ora per volta
        # dall'inizio della mattina, e il giorno libero richiesto è l'ultimo a
        # essere toccato: con diciotto ore su cinque giorni non lo si tocca mai.
        per_giorno = {}
        for casella in caselle:
            per_giorno.setdefault(casella[0], []).append(casella)
        for lista in per_giorno.values():
            lista.sort(key=lambda c: c[1])
        chiesto = docente.get("giornoLibero", "")
        preferiti = [gi for gi in sorted(per_giorno) if GIORNI[gi] != chiesto]
        ultimo = [gi for gi in sorted(per_giorno) if GIORNI[gi] == chiesto]
        caselle = []
        # I giri sui giorni buoni si esauriscono TUTTI prima di toccare il giorno
        # libero: metterlo in fondo all'ordine di un giro solo non bastava, perché
        # ogni giro lo visitava comunque una volta.
        for gruppo in (preferiti, ultimo):
            giro = 0
            while any(len(per_giorno[gi]) > giro for gi in gruppo):
                for gi in gruppo:
                    if len(per_giorno[gi]) > giro:
                        caselle.append(per_giorno[gi][giro])
                giro += 1

        for (gi, i, u) in caselle:
            if quante <= 0:
                break
            g, o = GIORNI[gi], ORE[i]
            if not docente_libero(doc, giorni_non, max_ore, non_prima, g, i, 1,
                                  u["aula"].get("plesso", "")):
                continue
            occ_docente[(doc, g, o)] = u["aula"].get("plesso", "")
            ore_doc.setdefault((doc, g), set()).add(i)
            result.append({
                "id": "l-%s-%s-%s-%s" % (u["classe"], g, o, k.get("id", "")),
                "classe": u["classe"],
                "disciplina": disciplina.get("nome", ""),
                "docente": doc,
                "aula": u["aula"].get("nome", ""),
                "plesso": u["aula"].get("plesso", ""),
                "giorno": g,
                "ora": o,
                "cattedra": k.get("id", ""),
                "compresenza": "true",
                "fisso": "false",
            })
            posate += 1
            quante -= 1
        if quante > 0:
            saltate += quante

    progress(max(MOSSE, 1), max(MOSSE, 1), "fatto")
    partial(result)

    ore_tot = sum(u["lung"] for u in unita)
    ore_messe = sum(u["lung"] for u in collocate)
    print("Ore collocate: %d su %d, in %d blocchi." % (ore_messe, ore_tot, len(collocate)))
    print("Mosse accolte nel miglioramento: %d su %d tentate, in %d giri alternati "
          "alla compattazione." % (conti["accolte"], MOSSE, GIRI))

    # La compattazione va raccontata per intero, comprese le giornate che non ha
    # potuto toccare: una buca rimasta ha sempre una ragione, e sapere quale è la
    # differenza fra correggerla e riprovare a caso.
    # Le ore buche si contano come le conta il controllo: i vuoti FRA la prima e
    # l'ultima ora. Una giornata che comincia in seconda ora non è bucata, è un
    # ingresso posticipato — la compattazione prova a toglierlo lo stesso, ma
    # chiamarlo buco farebbe due numeri diversi per la stessa cosa nelle due
    # pagine che la mostrano.
    residue = 0
    tardi = 0
    for (cls, g) in sorted({(u["classe"], u["giorno"]) for u in collocate}):
        dentro = sorted(ore_classe.get((cls, g), ()))
        if len(dentro) > 1:
            residue += (dentro[-1] - dentro[0] + 1) - len(dentro)
        if dentro and dentro[0] > 0:
            tardi += 1
    print("Compattazione: %d blocchi spostati, %d ore buche di classe rimaste."
          % (conti["spostati"], residue))
    if tardi:
        print("Giornate che cominciano dopo la prima ora: %d. Non sono ore buche, "
              "ma un ingresso posticipato è una cosa che si decide, non che capita."
              % tardi)
    if intoccabili:
        print("Giornate lasciate come stavano perché contengono una pre-assegnazione: %d."
              % intoccabili)
    if distribuzioni_ignorate:
        print("Distribuzioni con una giornata più lunga della giornata: %s."
              % "; ".join(sorted(set(distribuzioni_ignorate))))

    print("Ore di sostegno appoggiate alla classe: %d." % posate)
    if saltate:
        print("Ore di sostegno non appoggiate: %d (il docente era occupato o non "
              "disponibile in quelle caselle)." % saltate)
    if compresenze_scoperte:
        print("Compresenze senza un blocco intero da coprire: %s."
              % ", ".join(sorted(set(compresenze_scoperte))))
        print("Da controllare: che 'affianca' nomini una cattedra che esiste, e che "
              "le ore dichiarate non superino le sue.")
    if senza_aula:
        print("Cattedre senza nessuna aula ammessa: %s." % ", ".join(sorted(set(senza_aula))))
        print("Nessuna stanza del tipo richiesto è abbastanza capiente: ne va aggiunta "
              "una in Anagrafiche, oppure vanno corretti gli alunni della classe.")
    if non_collocate:
        mancanti = sorted({"%s %s (%d ore)" % (u["classe"], u["disciplina"], u["lung"])
                           for u in non_collocate})
        print("Blocchi non collocati (%d): %s." % (len(non_collocate), ", ".join(mancanti)))
        print("Sono i blocchi per cui non restava nessuna casella ammessa. Le leve: "
              "allargare i divieti, togliere qualche pre-assegnazione, ridurre un "
              "blocco, aggiungere un'aula del tipo richiesto.")
    print("Ora tocca al controllo: la griglia non vieta niente finché la collezione "
          "delle violazioni non viene riscritta.")
```
::/python

## Controlla i vincoli

Legge l'orario e le anagrafiche e riscrive da capo la collezione delle
violazioni: i divieti dichiarati, più tutto quello che trova. Un conflitto porta
l'id della lezione a cui si riferisce, così la casella se ne accorge senza
chiudersi per tutti; un divieto generale non ha nessun id e chiude la casella per
chiunque.

Il controllo è indipendente dal generatore, e questo è il punto: giudica un
orario **comunque sia nato** — generato, trascinato a mano, importato da un file.
Per questo ricontrolla anche le cose che il generatore non violerebbe mai.

::python{data="lezioni,cattedre,classi,docenti,discipline,aule,divieti" writes="violazioni" manual}
```python
# Quello che il controllo cerca, in ordine di gravità: docente doppio, classe
# doppia, aula con più classi di quante ne tiene, lezione in una casella vietata
# (generale o di quella risorsa), ORA BUCA DELLA CLASSE, aula troppo piccola,
# docente che cambia plesso fra un'ora e la successiva, giorno di non
# disponibilità, tetto e pavimento giornalieri della classe e del docente, giorni
# di servizio, massimo giornaliero di una materia, materie incompatibili o da
# tenere distanti, prima ora di chi non la fa, compresenza senza titolare — poi il
# giorno libero, che è una preferenza, e il monte ore che non torna fra la
# cattedra e le caselle collocate.
GIORNI = ["lun", "mar", "mer", "gio", "ven", "sab"]
ORE = ["1", "2", "3", "4", "5", "6"]

def intero(v, d=0):
    try:
        return int(float(str(v).strip().replace(",", ".")))
    except (TypeError, ValueError):
        return d

def vero(v):
    return str(v).strip().lower() in ("true", "1", "yes", "on", "si", "sì")

lezioni = data["lezioni"]
divieti = data["divieti"]
cattedre = data["cattedre"]

nome_classe = {r["id"]: r.get("nome", "") for r in data["classi"]}
nome_disciplina = {r["id"]: r.get("nome", "") for r in data["discipline"]}
cognome = {r["id"]: r.get("cognome", "") for r in data["docenti"]}
per_cognome = {r.get("cognome", ""): r for r in data["docenti"]}
per_aula = {r.get("nome", ""): r for r in data["aule"]}
per_classe = {r.get("nome", ""): r for r in data["classi"]}
discipline_righe = data["discipline"]
alunni = {r.get("nome", ""): intero(r.get("alunni", ""), 0) for r in data["classi"]}
plesso_classe = {r.get("nome", ""): r.get("plesso", "") for r in data["classi"]}

result = []
contatore = [0]

def segnala(tipo, riga, colonna, perche, per="", gravita="alta"):
    contatore[0] += 1
    result.append({"id": "v-%04d" % contatore[0], "tipo": tipo, "row": riga,
                   "col": colonna, "why": perche, "for": per, "gravita": gravita})

vietate = set()
vietate_per = {"aula": set(), "docente": set(), "classe": set()}
motivo_di = {}
for v in divieti:
    g, o = v.get("giorno", ""), str(v.get("ora", ""))
    ambito = str(v.get("ambito", "")).strip().lower()
    chi = str(v.get("chi", "")).strip()
    perche = v.get("motivo", "Casella non utilizzabile")
    if ambito in vietate_per and chi:
        vietate_per[ambito].add((chi, g, o))
        motivo_di[(ambito, chi, g, o)] = perche
    else:
        vietate.add((g, o))
        # Senza id: chiude la casella per chiunque, ed è così che la griglia la legge.
        segnala("divieto", o, g, perche)

totale = max(len(lezioni), 1)
progress(0, totale, "leggo l'orario")

visto_docente = {}
visto_classe = {}
visto_aula = {}
ore_collocate = {}
plesso_ora = {}
ore_giorno = {}
ore_classe_giorno = {}   # (classe, giorno) -> indici d'ora occupati
materia_giorno = {}      # (classe, disciplina, giorno) -> quante ore

for i, l in enumerate(lezioni):
    giorno = l.get("giorno", "")
    ora = str(l.get("ora", ""))
    classe = l.get("classe", "")
    docente = l.get("docente", "")
    aula = l.get("aula", "")
    disciplina = l.get("disciplina", "")
    lid = l.get("id", "")
    comp = vero(l.get("compresenza", ""))

    if docente:
        chiave = (docente, giorno, ora)
        if chiave in visto_docente:
            segnala("conflitto", ora, giorno,
                    "%s è già in %s a quest'ora" % (docente, visto_docente[chiave]), lid)
        else:
            visto_docente[chiave] = classe
        ore_giorno[(docente, giorno)] = ore_giorno.get((docente, giorno), 0) + 1

    # Una compresenza sta apposta nella casella di qualcun altro: la classe è la
    # stessa e l'aula è la stessa, e segnalarlo sarebbe segnalare che funziona.
    if classe and not comp:
        chiave = (classe, giorno, ora)
        if chiave in visto_classe:
            segnala("conflitto", ora, giorno,
                    "la %s ha già %s a quest'ora" % (classe, visto_classe[chiave]), lid)
        else:
            visto_classe[chiave] = disciplina

    if aula and not comp:
        # Quante CLASSI diverse ci sono dentro, non se è occupata: una palestra
        # divisa a metà ne tiene due, e chiamarlo conflitto vorrebbe dire vietare
        # a metà istituto le scienze motorie. Se è la stessa classe l'ha già detto
        # il controllo di sopra: due segnalazioni per un errore solo fanno
        # sembrare l'orario peggiore di quello che è.
        chiave = (aula, giorno, ora)
        dentro = visto_aula.setdefault(chiave, [])
        if classe not in dentro:
            dentro.append(classe)
            posti = max(1, intero(per_aula.get(aula, {}).get("classiInsieme", ""), 0) or 1)
            if len(dentro) > posti:
                segnala("conflitto", ora, giorno,
                        "in %s ci sono %d classi (%s) e ne tiene %d"
                        % (aula, len(dentro), ", ".join(dentro), posti), lid)

    if (giorno, ora) in vietate:
        segnala("conflitto", ora, giorno, "lezione collocata in una casella vietata", lid)
    for ambito, chi in (("aula", aula), ("docente", docente), ("classe", classe)):
        if chi and (chi, giorno, ora) in vietate_per[ambito]:
            segnala("conflitto", ora, giorno,
                    "%s non è disponibile a quest'ora: %s"
                    % (chi, motivo_di.get((ambito, chi, giorno, ora), "divieto")), lid)

    if aula and classe and not comp:
        posti = intero(per_aula.get(aula, {}).get("capienza", ""), 0)
        quanti = alunni.get(classe, 0)
        if posti and quanti and quanti > posti:
            segnala("capienza", ora, giorno,
                    "la %s è di %d alunni e %s ne tiene %d" % (classe, quanti, aula, posti),
                    lid)

    if aula and classe:
        suo = per_aula.get(aula, {}).get("plesso", "")
        if suo and plesso_classe.get(classe, suo) != suo:
            segnala("plesso", ora, giorno,
                    "la %s è in %s e %s è in %s"
                    % (classe, plesso_classe.get(classe, ""), aula, suo), lid, "media")
        if docente and suo:
            plesso_ora[(docente, giorno, ora)] = (suo, lid)

    anagrafe = per_cognome.get(docente, {})
    if docente and anagrafe:
        giorni_non = [s.strip() for s in str(anagrafe.get("giorniNon", "")).split(",") if s.strip()]
        if giorno in giorni_non:
            segnala("disponibilità", ora, giorno,
                    "%s non è in servizio di %s" % (docente, giorno), lid)
        if vero(anagrafe.get("nonPrimaOra", "")) and ora == "1":
            segnala("disponibilità", ora, giorno,
                    "%s non fa la prima ora" % docente, lid)

    if classe and disciplina and not comp:
        ore_collocate[(classe, disciplina)] = ore_collocate.get((classe, disciplina), 0) + 1
        if ora in ORE:
            ore_classe_giorno.setdefault((classe, giorno), set()).add(ORE.index(ora))
        materia_giorno[(classe, disciplina, giorno)] = \
            materia_giorno.get((classe, disciplina, giorno), 0) + 1

    progress(i + 1, totale, "controllo i vincoli")
    partial(result)

# Il cambio di plesso fra un'ora e la successiva: si vede solo guardando due ore
# vicine, quindi è un giro a parte.
progress(totale, totale, "confronto plessi, tetti e monte ore")
for (docente, giorno, ora), (suo, lid) in sorted(plesso_ora.items()):
    if ora not in ORE:
        continue
    dopo = ORE.index(ora) + 1
    if dopo >= len(ORE):
        continue
    altro = plesso_ora.get((docente, giorno, ORE[dopo]))
    if altro and altro[0] != suo:
        segnala("plesso", ora, giorno,
                "%s passa da %s a %s fra un'ora e l'altra" % (docente, suo, altro[0]), lid)

for (docente, giorno), quante in sorted(ore_giorno.items()):
    anagrafe = per_cognome.get(docente, {})
    tetto = intero(anagrafe.get("maxOreGiorno", ""), 0)
    if tetto and quante > tetto:
        segnala("tetto", "", giorno,
                "%s ha %d ore di %s e il suo massimo è %d" % (docente, quante, giorno, tetto),
                "", "media")
    pavimento = intero(anagrafe.get("minOreGiorno", ""), 0)
    if pavimento and quante < pavimento:
        segnala("tetto", "", giorno,
                "%s sale di %s per %d ora/e e il suo minimo è %d"
                % (docente, giorno, quante, pavimento), "", "media")

# I giorni di servizio: quanti giorni un docente sale in tutto. Si conta dopo,
# perché è una proprietà della settimana e non di una casella.
giorni_di = {}
for (docente, giorno) in ore_giorno:
    if ore_giorno[(docente, giorno)] > 0:
        giorni_di[docente] = giorni_di.get(docente, 0) + 1
for docente, quanti in sorted(giorni_di.items()):
    tetto = intero(per_cognome.get(docente, {}).get("maxGiorniServizio", ""), 0)
    if tetto and quanti > tetto:
        segnala("tetto", "", "",
                "%s sale %d giorni e ne ha dichiarati al massimo %d"
                % (docente, quanti, tetto), "", "media")

# Il giorno libero richiesto e non ottenuto. È una PREFERENZA e si segnala come
# tale, in fondo e con la gravità più bassa — ma si segnala: la pagina della
# qualità lo contava e il riepilogo del monitor leggeva zero, che sono due numeri
# diversi per la stessa cosa in due pagine dello stesso documento. Fra le due, la
# sbagliata era quella che taceva.
for docente, anagrafe in sorted(per_cognome.items()):
    chiesto = str(anagrafe.get("giornoLibero", "")).strip()
    if chiesto and ore_giorno.get((docente, chiesto), 0) > 0:
        segnala("giorno libero", "", chiesto,
                "%s aveva chiesto libero il %s e ha %d ora/e"
                % (docente, chiesto, ore_giorno[(docente, chiesto)]), "", "bassa")

# --- La giornata della classe ---------------------------------------------
# Le ore buche di una classe, che in una scuola italiana non sono un difetto di
# qualità: sono trenta ragazzi in corridoio, e un orario che le contiene non si
# pubblica. Si segnalano UNA per giornata, con dentro quali ore sono: una riga
# per ogni ora vuota farebbe sessanta segnalazioni per sei giornate storte.
buche_classi = 0
# Si gira su tutte le classi per tutti i giorni, non sulle sole giornate che
# hanno lezioni: una giornata VUOTA non compare in quella mappa, e girando su di
# essa una classe che il lunedì non viene affatto passava senza che nessuno
# dicesse niente — che è il minimo giornaliero violato nel modo più vistoso di
# tutti.
for classe in sorted(per_classe):
    if not any((classe, g) in ore_classe_giorno for g in GIORNI):
        continue          # classe senza orario: lo dice già il monte ore
    for giorno in GIORNI:
        indici = ore_classe_giorno.get((classe, giorno), set())
        dentro = sorted(indici)
        if len(dentro) > 1:
            vuote = [ORE[i] for i in range(dentro[0], dentro[-1] + 1) if i not in indici]
            if vuote:
                buche_classi += len(vuote)
                segnala("ora buca", "", giorno,
                        "la %s di %s ha %d ora/e buca/he: %s"
                        % (classe, giorno, len(vuote), "ª, ".join(vuote) + "ª"), "", "alta")
        quante = len(dentro)
        riga = per_classe.get(classe, {})
        tetto = intero(riga.get("maxOreGiorno", ""), 0)
        pavimento = intero(riga.get("minOreGiorno", ""), 0)
        if tetto and quante > tetto:
            segnala("tetto", "", giorno,
                    "la %s fa %d ore di %s e il suo massimo è %d"
                    % (classe, quante, giorno, tetto), "", "media")
        if pavimento and quante < pavimento:
            segnala("tetto", "", giorno,
                    "la %s fa %d ore di %s e il suo minimo è %d"
                    % (classe, quante or 0, giorno, pavimento), "", "media")

# Le regole fra materie, lette dall'anagrafica e simmetrizzate come nel
# generatore: dichiararle da una parte sola deve bastare anche qui, o il
# controllo direbbe di sì a un orario che la generazione avrebbe rifiutato.
incompatibili = {}
non_consecutive = {}
tetto_materia = {}


def _lega(mappa, a, b):
    if not a or not b or a == b:
        return
    mappa.setdefault(a, set()).add(b)
    mappa.setdefault(b, set()).add(a)


for r in discipline_righe:
    mio = r.get("nome", "")
    for altro in str(r.get("incompatibili", "")).split(","):
        _lega(incompatibili, mio, altro.strip())
    for altro in str(r.get("nonConsecutivaCon", "")).split(","):
        _lega(non_consecutive, mio, altro.strip())
    quante = intero(r.get("maxAlGiorno", ""), 0)
    if quante > 0:
        tetto_materia[mio] = quante

for (classe, materia, giorno), quante in sorted(materia_giorno.items()):
    tetto = tetto_materia.get(materia)
    if tetto and quante > tetto:
        segnala("materia", "", giorno,
                "la %s fa %d ore di %s di %s, e il massimo dichiarato è %d"
                % (classe, quante, materia, giorno, tetto), "", "media")
    for altra in sorted(incompatibili.get(materia, ())):
        # Solo in un verso, o la stessa coppia si segnala due volte.
        if materia < altra and materia_giorno.get((classe, altra, giorno), 0) > 0:
            segnala("materia", "", giorno,
                    "la %s ha %s e %s lo stesso giorno, e sono dichiarate incompatibili"
                    % (classe, materia, altra), "", "media")
    if giorno in GIORNI:
        n = GIORNI.index(giorno)
        if n + 1 < len(GIORNI):
            dopo = GIORNI[n + 1]
            for altra in sorted(non_consecutive.get(materia, ())):
                if materia_giorno.get((classe, altra, dopo), 0) > 0:
                    segnala("materia", "", giorno,
                            "la %s ha %s di %s e %s di %s, e vanno tenute distanti"
                            % (classe, materia, giorno, altra, dopo), "", "bassa")

# Una compresenza in una casella dove la classe non ha nessun titolare non è una
# compresenza: è un'ora di lezione tenuta da chi affianca e basta.
for l in lezioni:
    if not vero(l.get("compresenza", "")):
        continue
    if (l.get("classe", ""), l.get("giorno", ""), str(l.get("ora", ""))) not in visto_classe:
        segnala("compresenza", str(l.get("ora", "")), l.get("giorno", ""),
                "%s è in compresenza dove la %s non ha lezione"
                % (l.get("docente", ""), l.get("classe", "")), l.get("id", ""), "media")

# Il monte ore: quello che la cattedra promette contro quello che l'orario mantiene.
mancanti = 0
if not cattedre:
    print("Nessuna cattedra in uso: salto il confronto sul monte ore.")
for k in cattedre:
    if vero(k.get("compresenza", "")):
        continue
    classe = nome_classe.get(k.get("classe", ""), "")
    disciplina = nome_disciplina.get(k.get("disciplina", ""), "")
    docente = cognome.get(k.get("docente", ""), "")
    dovute = intero(k.get("ore", ""), 0)
    fatte = ore_collocate.get((classe, disciplina), 0)
    if fatte != dovute:
        mancanti += 1
        segnala("monte ore", "", "",
                "%s in %s: %d ore collocate su %d di cattedra (%s)"
                % (disciplina, classe, fatte, dovute, docente),
                "", "media" if fatte < dovute else "alta")

partial(result)
conflitti = len([r for r in result if r["tipo"] == "conflitto"])
gravi = len([r for r in result if r["gravita"] == "alta" and r["tipo"] != "divieto"])
print("Lezioni lette: %d." % len(lezioni))
print("Conflitti: %d. Segnalazioni gravi in tutto: %d. Monte ore fuori posto: %d."
      % (conflitti, gravi, mancanti))
if buche_classi:
    print("Ore buche delle classi: %d. Sono la sola cosa in questo elenco che una "
          "scuola non può pubblicare: rigenera, oppure chiudile trascinando."
          % buche_classi)
else:
    print("Nessuna classe ha ore buche.")
print("Divieti generali riportati in griglia: %d." % len(vietate))
if gravi == 0 and mancanti == 0:
    print("L'orario si chiude: nessuna violazione grave e nessuna ora fuori posto.")
```
::/python

::if-empty{path="violazioni"}
Nessuna segnalazione — oppure il controllo non è ancora stato eseguito. Le due
cose si distinguono soltanto premendo il pulsante.
::/if-empty

::if-any{path="violazioni"}
**:count{path="violazioni"}** segnalazioni in tutto, divieti dichiarati compresi.
I filtri sopra le colonne *Tipo* e *Gravità* separano i conflitti dal resto.

::table{path="violazioni" search sort="tipo" filters="tipo,gravita" deletable page-size="20"}
::column{field="tipo" label="Tipo"}
::column{field="col" label="Giorno"}
::column{field="row" label="Ora" align="end"}
::column{field="why" label="Che cosa non va"}
::column{field="gravita" label="Gravità"}
::/table
::/if-any

::/page

::page{title="Monitor" icon="dashboard"}

# Monitor

Due domande, e la prima si fa **prima** di generare.

*Questo orario può esistere?* è una domanda sulle anagrafiche, non sull'orario:
si risponde contando, e la risposta non cambia se si rigenera. Aspettare la
generazione per scoprire che sei classi chiedono dodici ore di palestra a
settimana e le palestre ne offrono ventiquattro in due — ma nel plesso sbagliato
— vuol dire aver aspettato per niente.

*Questo orario è pubblicabile?* è invece una domanda sul risultato, e si risponde
contando le segnalazioni del controllo per tipo.

## Prima di generare: si chiude?

::python{data="cattedre,classi,docenti,discipline,aule,divieti" writes="fattibilita" manual}
```python
# Nessuna di queste misure guarda le lezioni: sono tutte sulle anagrafiche, e
# tutte della stessa forma — quello che si chiede contro quello che c'è. Un
# rapporto sopra il 100% è una cosa che non entra e nessun solver farà entrare;
# sopra l'85% è una cosa che entra soltanto se tutto il resto le lascia strada.
GIORNI = ["lun", "mar", "mer", "gio", "ven", "sab"]
ORE = ["1", "2", "3", "4", "5", "6"]

def intero(v, d=0):
    try:
        return int(float(str(v).strip().replace(",", ".")))
    except (TypeError, ValueError):
        return d

def vero(v):
    return str(v).strip().lower() in ("true", "1", "yes", "on", "si", "sì")

classi = {r["id"]: r for r in data["classi"]}
docenti = {r["id"]: r for r in data["docenti"]}
discipline = {r["id"]: r for r in data["discipline"]}

# Le caselle che l'istituto non usa affatto valgono per tutti, e vanno tolte
# dal denominatore di ogni conto: sono ore che non esistono.
generali = set()
for v in data["divieti"]:
    if not str(v.get("ambito", "")).strip():
        generali.add((v.get("giorno", ""), str(v.get("ora", ""))))
caselle = len(GIORNI) * len(ORE) - len(generali)

result = []
contatore = [0]

def misura(che, chiesto, offerto, spiega):
    contatore[0] += 1
    quota = (chiesto * 100.0 / offerto) if offerto else 0.0
    if not offerto or chiesto > offerto:
        stato = "impossibile"
    elif quota >= 100.0:
        # Esattamente pieno. Sulla carta entra: c'è una casella per ogni ora, e
        # quindi una sola disposizione possibile. Nella pratica non entra mai,
        # perché quell'unica disposizione deve soddisfare anche tutti gli altri
        # vincoli, e nessuna euristica la trova per caso.
        stato = "al limite"
    elif quota >= 85.0:
        stato = "stretto"
    else:
        stato = "ok"
    result.append({
        "id": "f-%03d" % contatore[0], "misura": che, "chiesto": str(chiesto),
        "offerto": str(offerto), "percentuale": "%.0f" % quota,
        "stato": stato, "spiega": spiega,
    })

# 1. Ogni classe: le ore che le cattedre le promettono contro le caselle che ha.
for c in data["classi"]:
    ore = 0
    for k in data["cattedre"]:
        if k.get("classe", "") == c.get("id", "") and not vero(k.get("compresenza", "")):
            ore += intero(k.get("ore", ""), 0)
    tetto = intero(c.get("maxOreGiorno", ""), 0)
    sue = caselle if not tetto else min(caselle, tetto * len(GIORNI))
    misura("Classe %s" % c.get("nome", ""), ore, sue,
           "Le ore di cattedra della classe contro le caselle della sua settimana")

# 2. Ogni tipo di aula: le ore che lo chiedono contro le ore che offre. È il
#    collo di bottiglia vero di ogni orario, e si vede solo così.
per_tipo = {}
for a in data["aule"]:
    tipo = str(a.get("tipo", "")).strip().lower()
    if tipo:
        per_tipo[tipo] = per_tipo.get(tipo, 0) + max(1, intero(a.get("classiInsieme", ""), 0) or 1)
chieste = {}
for k in data["cattedre"]:
    if vero(k.get("compresenza", "")):
        continue
    m = discipline.get(k.get("disciplina", ""))
    if not m:
        continue
    tipo = str(m.get("aulaRichiesta", "")).strip().lower()
    if tipo:
        chieste[tipo] = chieste.get(tipo, 0) + intero(k.get("ore", ""), 0)
for tipo in sorted(set(list(per_tipo) + list(chieste))):
    misura("Aule di tipo «%s»" % tipo, chieste.get(tipo, 0), per_tipo.get(tipo, 0) * caselle,
           "Le ore che chiedono questo tipo contro le ore che le stanze di quel tipo offrono")

# 3. Ogni docente: le ore che le sue cattedre gli danno contro le caselle in cui
#    può stare — tolti i giorni in cui non è in servizio e il suo tetto.
for d in data["docenti"]:
    ore = 0
    for k in data["cattedre"]:
        if k.get("docente", "") == d.get("id", ""):
            ore += intero(k.get("ore", ""), 0)
    if ore == 0:
        continue
    giorni_non = [s.strip() for s in str(d.get("giorniNon", "")).split(",") if s.strip()]
    disponibili = [g for g in GIORNI if g not in giorni_non]
    tetto_giorni = intero(d.get("maxGiorniServizio", ""), 0)
    if tetto_giorni:
        disponibili = disponibili[:tetto_giorni]
    tetto = intero(d.get("maxOreGiorno", ""), 0) or len(ORE)
    sue = 0
    for g in disponibili:
        libere = len([o for o in ORE if (g, o) not in generali])
        if vero(d.get("nonPrimaOra", "")):
            libere = max(0, libere - 1)
        sue += min(tetto, libere)
    misura("Docente %s" % d.get("cognome", ""), ore, sue,
           "Le ore delle sue cattedre contro le caselle in cui può stare")

impossibili = [r for r in result if r["stato"] in ("impossibile", "al limite")]
stretti = [r for r in result if r["stato"] == "stretto"]
print("%d misure. Impossibili o al limite: %d. Strette: %d."
      % (len(result), len(impossibili), len(stretti)))
if impossibili:
    print("Non entra: %s." % ", ".join(r["misura"] for r in impossibili[:6]))
    print("Sono cose che nessuna euristica farà entrare, perché non c'è dove. Le "
          "leve: aggiungere una stanza del tipo che manca, togliere ore a una "
          "cattedra, allargare un vincolo dichiarato più stretto del vero.")
elif stretti:
    print("Entra, ma senza margine: %s." % ", ".join(r["misura"] for r in stretti[:6]))
    print("Genererà, e la prima variazione di ottobre non troverà più dove andare.")
else:
    print("Tutto sotto l'85%: c'è margine ovunque, l'orario si chiuderà comodo.")
```
::/python

::if-any{path="fattibilita"}
::table{path="fattibilita" search sort="percentuale" dir="desc" filters="stato" page-size="15"}
::column{field="misura" label="Che cosa"}
::column{field="chiesto" label="Chiesto" align="end"}
::column{field="offerto" label="Offerto" align="end"}
::column{field="percentuale" label="%" align="end"}
::column{field="stato" label="Stato"}
::/table
::/if-any

::if-empty{path="fattibilita"}
Non ancora calcolata. È il primo pulsante da premere dopo le anagrafiche, e
prima di generare.
::/if-empty

## I giorni liberi chiesti dai docenti

Il conto che salva più tempo di tutti, e il meno ovvio. Il giorno libero è una
preferenza personale, ma **la loro somma è un vincolo collettivo**: se nove
docenti su tredici chiedono il sabato, il sabato ha quattro docenti per sei
classi, e non è che la preferenza si perde — è l'orario che non si chiude.

Sotto il 20% dei docenti in un giorno si sta tranquilli; sopra il 30% quel giorno
è già una difficoltà; oltre il 40% conviene parlarne in collegio prima ancora di
provare a generare, perché nessun peso su nessuno slider crea un docente.

::python{data="docenti" writes="giorni-liberi" manual}
```python
GIORNI = [("lun", "Lunedì"), ("mar", "Martedì"), ("mer", "Mercoledì"),
          ("gio", "Giovedì"), ("ven", "Venerdì"), ("sab", "Sabato")]

quanti = len(data["docenti"]) or 1
chiesto = {}
for d in data["docenti"]:
    g = str(d.get("giornoLibero", "")).strip().lower()
    if g:
        chiesto.setdefault(g, []).append(d.get("cognome", ""))

result = []
for sigla, nome in GIORNI:
    chi = sorted(chiesto.get(sigla, []))
    quota = len(chi) * 100.0 / quanti
    if quota >= 40.0:
        stato = "critico"
    elif quota >= 30.0:
        stato = "difficile"
    elif quota >= 20.0:
        stato = "da tenere d'occhio"
    else:
        stato = "ok"
    result.append({
        "id": "gl-" + sigla, "giorno": nome, "docenti": str(len(chi)),
        "percentuale": "%.0f" % quota, "stato": stato, "chi": ", ".join(chi),
    })

senza = [d.get("cognome", "") for d in data["docenti"]
         if not str(d.get("giornoLibero", "")).strip()]
peggiore = max(result, key=lambda r: int(r["docenti"]))
print("%d docenti, %d senza giorno libero richiesto." % (quanti, len(senza)))
print("Il giorno più richiesto è %s: %s docenti su %d (%s%%)."
      % (peggiore["giorno"], peggiore["docenti"], quanti, peggiore["percentuale"]))
if peggiore["stato"] in ("critico", "difficile"):
    print("È una distribuzione sbilanciata: quel giorno resta scoperto e le ore "
          "di quelle classi devono comunque andare da qualche parte. Meglio "
          "spostarne qualcuno adesso che scoprirlo dopo venti generazioni.")
else:
    print("La distribuzione è equilibrata: nessun giorno è scoperto.")
```
::/python

::if-any{path="giorni-liberi"}
::chart-bar{data="giorni-liberi" x="giorno" y="docenti" height="240"}

::table{path="giorni-liberi" sort="percentuale" dir="desc"}
::column{field="giorno" label="Giorno"}
::column{field="docenti" label="Docenti" align="end"}
::column{field="percentuale" label="% del collegio" align="end"}
::column{field="stato" label="Stato"}
::column{field="chi" label="Chi"}
::/table
::/if-any

## Dopo aver generato: si pubblica?

Gli stessi indicatori che si guardano su un orario finito, contati per tipo. Non
li cerca questo blocco: li ha già trovati il controllo, e questo li **conta**.
Una segnalazione ha un tipo e una gravità, e un numero accanto a un tipo è quello
che si legge in dieci secondi prima di una riunione.

Il rapporto vale quanto l'ultima esecuzione del controllo: dopo uno spostamento
nella griglia va rieseguito.

::python{data="violazioni,lezioni,cattedre" writes="indicatori" manual}
```python
def vero(v):
    return str(v).strip().lower() in ("true", "1", "yes", "on", "si", "sì")

def intero(v, d=0):
    try:
        return int(float(str(v).strip().replace(",", ".")))
    except (TypeError, ValueError):
        return d

# L'ordine è quello della gravità, e non è alfabetico apposta: un'ora buca di una
# classe e una preferenza persa non si leggono con la stessa faccia.
ORDINE = [
    ("conflitto", "Conflitti", "Due lezioni nella stessa risorsa alla stessa ora", "alta"),
    ("ora buca", "Ore buche delle classi", "Ore vuote fra la prima e l'ultima di una giornata", "alta"),
    ("capienza", "Aule troppo piccole", "La classe non ci sta", "alta"),
    ("plesso", "Cambi di plesso", "Un docente attraversa la città fra un'ora e l'altra", "alta"),
    ("disponibilità", "Non disponibilità violate", "Lezioni nei giorni o nelle ore in cui il docente non c'è", "alta"),
    ("materia", "Regole fra materie", "Massimo giornaliero, incompatibilità, giorni consecutivi", "media"),
    ("tetto", "Tetti e pavimenti", "Ore giornaliere fuori dai limiti dichiarati", "media"),
    ("monte ore", "Monte ore fuori posto", "Le ore collocate non tornano con quelle di cattedra", "media"),
    ("compresenza", "Compresenze scoperte", "Chi affianca è in una casella senza titolare", "media"),
    ("giorno libero", "Giorni liberi non ottenuti", "Una preferenza persa: si può accettare", "bassa"),
    ("divieto", "Caselle vietate dichiarate", "Non sono errori: sono le regole dell'istituto", "nessuna"),
]

conta = {}
for v in data["violazioni"]:
    tipo = str(v.get("tipo", "")).strip()
    conta[tipo] = conta.get(tipo, 0) + 1

result = []
for n, (tipo, nome, spiega, gravita) in enumerate(ORDINE):
    quante = conta.pop(tipo, 0)
    result.append({
        "id": "i-%02d" % n, "indicatore": nome, "elementi": str(quante),
        "stato": "ok" if quante == 0 or gravita == "nessuna" else "da vedere",
        "gravita": gravita, "spiega": spiega,
    })

# Un tipo che il controllo scrive e questo elenco non conosce ancora: comparirà
# in fondo invece di sparire, perché una segnalazione che nessuno conta è una
# segnalazione che non esiste.
for n, (tipo, quante) in enumerate(sorted(conta.items())):
    result.append({
        "id": "i-x%02d" % n, "indicatore": tipo, "elementi": str(quante),
        "stato": "ok" if quante == 0 else "da vedere", "gravita": "media",
        "spiega": "Tipo non previsto da questo riepilogo",
    })

# Le ore che le cattedre promettono e che nell'orario non ci sono affatto: è
# l'indicatore che non nasce da una violazione ma da una sottrazione.
dovute = sum(intero(k.get("ore", ""), 0) for k in data["cattedre"]
             if not vero(k.get("compresenza", "")))
fatte = len([l for l in data["lezioni"] if not vero(l.get("compresenza", ""))])
result.insert(0, {
    "id": "i-00a", "indicatore": "Ore non collocate", "elementi": str(max(0, dovute - fatte)),
    "stato": "ok" if fatte >= dovute else "da vedere", "gravita": "alta",
    "spiega": "Ore di cattedra che nell'orario non compaiono",
})

gravi = sum(int(r["elementi"]) for r in result
            if r["gravita"] == "alta" and r["stato"] == "da vedere")
print("Lezioni in orario: %d, ore di cattedra dichiarate: %d." % (fatte, dovute))
if gravi:
    print("%d segnalazioni gravi: l'orario non è pubblicabile così." % gravi)
else:
    print("Nessuna segnalazione grave: l'orario si può pubblicare.")
    print("Quello che resta sono preferenze, e una preferenza persa è una scelta, "
          "non un errore.")
```
::/python

::if-any{path="indicatori"}
::table{path="indicatori" filters="stato,gravita"}
::column{field="indicatore" label="Indicatore"}
::column{field="spiega" label="Che cosa vuol dire"}
::column{field="gravita" label="Gravità"}
::column{field="elementi" label="Elementi" align="end"}
::column{field="stato" label="Stato"}
::/table
::/if-any

::if-empty{path="indicatori"}
Non ancora calcolati: si esegue prima *Controlla i vincoli*, poi questo blocco.
::/if-empty

::/page

::page{title="Laboratori e qualità" icon="data-check"}

# Laboratori e qualità

Un orario senza conflitti non è ancora un buon orario. Queste due misure sono
quello che si guarda dopo: quanto sono pieni i laboratori, e come sta la
giornata dei docenti. Sono due blocchi manuali, e vanno rieseguiti dopo ogni
generazione — le collezioni che scrivono sono loro e di nessun altro.

## Saturazione delle aule

Quante ore su quelle disponibili è occupata ogni stanza. È il numero che dice se
l'orario è fragile prima ancora che si rompa: sopra l'ottanta per cento un
laboratorio non ha più margine, e una qualsiasi variazione — una classe in più,
un'uscita didattica, un blocco spostato — non trova più dove andare.

::python{data="lezioni,aule,divieti" writes="saturazione" manual}
```python
GIORNI = ["lun", "mar", "mer", "gio", "ven", "sab"]
ORE = ["1", "2", "3", "4", "5", "6"]

def vero(v):
    return str(v).strip().lower() in ("true", "1", "yes", "on", "si", "sì")

# Le caselle davvero disponibili: quelle che un divieto generale toglie non sono
# capienza inutilizzata, sono capienza che non esiste.
chiuse = set()
for v in data["divieti"]:
    if not str(v.get("ambito", "")).strip():
        chiuse.add((v.get("giorno", ""), str(v.get("ora", ""))))
disponibili = len(GIORNI) * len(ORE) - len(chiuse)
disponibili = max(disponibili, 1)

# Una compresenza sta nella stessa stanza del titolare: contarla raddoppierebbe
# quell'ora, e una palestra risulterebbe piena il doppio di quanto è.
occupate = {}
for l in data["lezioni"]:
    if vero(l.get("compresenza", "")):
        continue
    aula = l.get("aula", "")
    if aula:
        occupate.setdefault(aula, set()).add((l.get("giorno", ""), str(l.get("ora", ""))))

result = []
for a in data["aule"]:
    nome = a.get("nome", "")
    ore = len(occupate.get(nome, ()))
    result.append({
        "id": "s-" + (a.get("id", "") or nome),
        "aula": nome,
        "tipo": a.get("tipo", ""),
        "plesso": a.get("plesso", ""),
        "capienza": a.get("capienza", ""),
        "ore": str(ore),
        "libere": str(disponibili - ore),
        "percentuale": str(round(ore * 100.0 / disponibili, 1)),
    })

result.sort(key=lambda r: -float(r["percentuale"]))
piene = [r for r in result if float(r["percentuale"]) >= 80.0]
print("%d aule su %d caselle disponibili a settimana." % (len(result), disponibili))
if piene:
    print("Sopra l'80%%: %s." % ", ".join("%s (%s%%)" % (r["aula"], r["percentuale"])
                                          for r in piene))
    print("Sono le stanze senza margine: un'aula in più di quel tipo è la sola cosa "
          "che cambi davvero le carte.")
else:
    print("Nessuna stanza è sopra l'80%: c'è margine per una variazione.")
```
::/python

::if-any{path="saturazione"}
::chart-bar{data="saturazione" x="aula" y="percentuale" height="260"}

::table{path="saturazione" sort="percentuale" dir="desc" filters="tipo,plesso"}
::column{field="aula" label="Aula"}
::column{field="tipo" label="Tipo"}
::column{field="plesso" label="Plesso"}
::column{field="capienza" label="Posti" align="end"}
::column{field="ore" label="Ore occupate" align="end"}
::column{field="libere" label="Ore libere" align="end"}
::column{field="percentuale" label="%" align="end"}
::/table
::/if-any

::if-empty{path="saturazione"}
Non ancora calcolata: si preme il pulsante qui sopra, a orario generato.
::/if-empty

## La giornata dei docenti

Le **ore buche** sono le ore vuote fra la prima e l'ultima di una giornata: sono
la misura che ogni collegio guarda per prima, e l'unica preferenza che si sente
tutti i giorni. Accanto ci sono i giorni di servizio, il giorno libero ottenuto o
no, e i cambi di plesso — che il generatore non produce mai da un'ora alla
successiva, ma un trascinamento a mano sì.

::python{data="lezioni,docenti,aule" writes="qualita-docenti" manual}
```python
GIORNI = ["lun", "mar", "mer", "gio", "ven", "sab"]
ORE = ["1", "2", "3", "4", "5", "6"]

plesso_aula = {a.get("nome", ""): a.get("plesso", "") for a in data["aule"]}

giornate = {}
for l in data["lezioni"]:
    doc, g, o = l.get("docente", ""), l.get("giorno", ""), str(l.get("ora", ""))
    if not doc or g not in GIORNI or o not in ORE:
        continue
    giornate.setdefault((doc, g), {})[ORE.index(o)] = plesso_aula.get(l.get("aula", ""), "")

result = []
for d in data["docenti"]:
    doc = d.get("cognome", "")
    ore = 0
    buche = 0
    giorni = 0
    cambi = 0
    picco = 0
    for g in GIORNI:
        dentro = giornate.get((doc, g))
        if not dentro:
            continue
        giorni += 1
        indici = sorted(dentro)
        ore += len(indici)
        picco = max(picco, len(indici))
        buche += (indici[-1] - indici[0] + 1) - len(indici)
        for i in range(len(indici) - 1):
            if indici[i + 1] == indici[i] + 1 and dentro[indici[i + 1]] != dentro[indici[i]]:
                cambi += 1
    chiesto = d.get("giornoLibero", "")
    if not chiesto:
        libero = "—"
    elif (doc, chiesto) in giornate:
        libero = "no"
    else:
        libero = "sì"
    result.append({
        "id": "q-" + (d.get("id", "") or doc),
        "docente": doc,
        "tipo": d.get("tipo", ""),
        "ore": str(ore),
        "cattedra": d.get("oreCattedra", ""),
        "giorni": str(giorni),
        "buche": str(buche),
        "picco": str(picco),
        "giornoLibero": libero,
        "cambiPlesso": str(cambi),
    })

result.sort(key=lambda r: (-int(r["buche"]), r["docente"]))
tot_buche = sum(int(r["buche"]) for r in result)
negati = [r["docente"] for r in result if r["giornoLibero"] == "no"]
print("Ore buche in tutta la settimana: %d, su %d docenti." % (tot_buche, len(result)))
print("Peggiori: %s." % ", ".join("%s (%s)" % (r["docente"], r["buche"])
                                  for r in result[:3] if int(r["buche"]) > 0)
      if tot_buche else "Nessun docente ha ore buche.")
if negati:
    print("Giorno libero non ottenuto: %s." % ", ".join(negati))
    print("Alza il peso del giorno libero e rigenera, oppure accettalo: è una "
          "preferenza, e le preferenze si perdono contro i vincoli duri.")
```
::/python

::if-any{path="qualita-docenti"}
::chart-bar{data="qualita-docenti" x="docente" y="buche" height="260"}

::table{path="qualita-docenti" search sort="buche" dir="desc" filters="tipo,giornoLibero"}
::column{field="docente" label="Docente"}
::column{field="tipo" label="Tipo"}
::column{field="ore" label="Ore in orario" align="end"}
::column{field="cattedra" label="Ore di cattedra" align="end"}
::column{field="giorni" label="Giorni" align="end"}
::column{field="buche" label="Ore buche" align="end"}
::column{field="picco" label="Max in un giorno" align="end"}
::column{field="giornoLibero" label="Giorno libero"}
::column{field="cambiPlesso" label="Cambi di plesso" align="end"}
::/table
::/if-any

::if-empty{path="qualita-docenti"}
Non ancora calcolata: si preme il pulsante qui sopra, a orario generato.
::/if-empty

## Come si legge tutto questo insieme

Un orario che si chiude con zero conflitti, nessuna stanza sopra l'ottanta per
cento e poche ore buche è un orario che regge anche alle variazioni di ottobre.
Se una delle tre cose non torna, le leve sono in ordine di efficacia: **aggiungere
un'aula** del tipo che satura, **togliere un vincolo duro** che nessuno aveva
davvero chiesto, e solo dopo **muovere i pesi** — che ridistribuiscono il disagio
senza toglierlo.

::/page

::page{title="Stampe" icon="print"}

# Stampe

Ogni pulsante stampa **una pagina per riga** della collezione che nomina:
imposta la chiave, lascia alle viste il tempo di rimettersi in pari, fotografa il
bersaglio e passa alla riga dopo, con l'interruzione di pagina fra l'una e
l'altra. La finestra di stampa salva anche in PDF, e alla fine la chiave torna al
valore che aveva.

Le stampe per classe, per docente e per aula sono in **orizzontale**: una
settimana è larga sei giorni e su una pagina verticale diventa una colonna di
frammenti. Il tabellone è invece un foglio solo, e sta più comodo in verticale.

Il bersaglio deve **dipendere dalla chiave**, altrimenti escono N pagine identiche
e niente lo segnala. Le sezioni qui sotto filtrano su quella chiave —
`classe=#classeSel` la prima, `docente=#docenteSel` la seconda — che sono le
stesse dei selettori della pagina **Orario**.

## Una pagina per classe

::columns{min="30rem" gap="m" id="stampaClasse"}
### Orario della classe :value[classeSel]{ref="#classeSel"}

IIS «Ada Lovelace» — anno scolastico 2026/2027

::timetable{path="lezioni" filter="classe=#classeSel" rows="ora" cols="giorno" row-values="1,2,3,4,5,6" row-labels="1ª,2ª,3ª,4ª,5ª,6ª" col-values="lun,mar,mer,gio,ven,sab" col-labels="Lunedì,Martedì,Mercoledì,Giovedì,Venerdì,Sabato" colour="disciplina"}
**{disciplina}**
{docente} · {aula}
::/timetable
::/columns

::print{target="stampaClasse" repeat="classi" key="classeSel" field="nome" landscape label="Stampa l'orario di ogni classe"}

## Una pagina per docente

::columns{min="30rem" gap="m" id="stampaDocente"}
### Orario del professore :value[docenteSel]{ref="#docenteSel"}

IIS «Ada Lovelace» — anno scolastico 2026/2027

::timetable{path="lezioni" filter="docente=#docenteSel" rows="ora" cols="giorno" row-values="1,2,3,4,5,6" row-labels="1ª,2ª,3ª,4ª,5ª,6ª" col-values="lun,mar,mer,gio,ven,sab" col-labels="Lunedì,Martedì,Mercoledì,Giovedì,Venerdì,Sabato" colour="classe"}
**{classe}**
{disciplina} · {aula}
::/timetable
::/columns

::print{target="stampaDocente" repeat="docenti" key="docenteSel" field="cognome" landscape label="Stampa l'orario di ogni docente"}

## Una pagina per aula

L'occupazione di ogni stanza, che è quello che si appende alla porta del
laboratorio. Stessa direttiva, stessa chiave della griglia in **Orario**.

::columns{min="30rem" gap="m" id="stampaAula"}
### Occupazione dell'aula :value[aulaSel]{ref="#aulaSel"}

IIS «Ada Lovelace» — anno scolastico 2026/2027

::timetable{path="lezioni" filter="aula=#aulaSel" rows="ora" cols="giorno" row-values="1,2,3,4,5,6" row-labels="1ª,2ª,3ª,4ª,5ª,6ª" col-values="lun,mar,mer,gio,ven,sab" col-labels="Lunedì,Martedì,Mercoledì,Giovedì,Venerdì,Sabato" colour="classe"}
**{classe}**
{disciplina} · {docente}
::/timetable
::/columns

::print{target="stampaAula" repeat="aule" key="aulaSel" field="nome" landscape label="Stampa l'occupazione di ogni aula"}

## Il tabellone

Le altre tre stampe fanno una pagina per riga; questa fa **una pagina sola con
dentro tutto**, ed è quella che si appende in sala professori. Sono le trentasei
caselle della settimana in riga e le classi in colonna, con la materia e la sigla
del docente in ogni casella.

È fatto in modo diverso dalle altre, e la differenza è istruttiva. Una griglia
per classe è una vista di una collezione; un tabellone è una **tabella
trasposta** — una riga per casella, una colonna per classe — e nessuna collezione
ha quella forma, perché una lezione non sa niente delle altre. Quindi la si
costruisce: un blocco legge le lezioni e scrive una collezione che ha esattamente
quella forma, con una colonna per classe.

Le colonne sono scritte a mano, una per classe dell'esempio, e questo è
onestamente il limite: aggiungere una classe vuol dire aggiungere qui la sua
colonna. Non è un difetto di questo documento ma la forma del problema — anche i
programmi che lo fanno per mestiere stampano cinque classi per foglio e passano
al foglio dopo, perché oltre non ci sta.

::python{data="lezioni,classi,docenti" writes="tabellone" manual}
```python
GIORNI = [("lun", "Lunedì"), ("mar", "Martedì"), ("mer", "Mercoledì"),
          ("gio", "Giovedì"), ("ven", "Venerdì"), ("sab", "Sabato")]
ORE = ["1", "2", "3", "4", "5", "6"]

def vero(v):
    return str(v).strip().lower() in ("true", "1", "yes", "on", "si", "sì")

# La sigla, non il cognome: in una casella larga un centimetro «De Santis» non ci
# sta, e un tabellone illeggibile è un tabellone che nessuno guarda.
sigla_di = {}
for d in data["docenti"]:
    sigla_di[d.get("cognome", "")] = str(d.get("sigla", "")).strip() or d.get("cognome", "")

dentro = {}
for l in data["lezioni"]:
    if vero(l.get("compresenza", "")):
        continue
    chiave = (l.get("giorno", ""), str(l.get("ora", "")), l.get("classe", ""))
    dentro[chiave] = "%s %s" % (l.get("disciplina", "")[:12],
                                sigla_di.get(l.get("docente", ""), ""))

nomi = sorted({c.get("nome", "") for c in data["classi"] if c.get("nome", "")})
result = []
for sigla, nome in GIORNI:
    for o in ORE:
        riga = {"id": "t-%s-%s" % (sigla, o), "giorno": nome, "ora": o + "ª"}
        for cls in nomi:
            riga[cls] = dentro.get((sigla, o, cls), "")
        result.append(riga)

piene = sum(1 for r in result for cls in nomi if r.get(cls))
print("Tabellone di %d classi su %d caselle: %d occupate."
      % (len(nomi), len(result), piene))
if len(nomi) > 6:
    print("Le classi sono %d e le colonne scritte qui sotto sono sei: serve una "
          "::column per ognuna delle altre, oppure si stampa in due volte." % len(nomi))
```
::/python

::if-any{path="tabellone"}
::columns{min="40rem" gap="s" id="stampaTabellone"}
### Tabellone orario — IIS «Ada Lovelace»

Anno scolastico 2026/2027

::table{path="tabellone"}
::column{field="giorno" label="Giorno"}
::column{field="ora" label="Ora"}
::column{field="1A" label="1A"}
::column{field="2A" label="2A"}
::column{field="3A" label="3A"}
::column{field="1B" label="1B"}
::column{field="2B" label="2B"}
::column{field="3B" label="3B"}
::/table
::/columns

::print{target="stampaTabellone" label="Stampa il tabellone"}
::/if-any

::if-empty{path="tabellone"}
Non ancora costruito: si preme il pulsante qui sopra, a orario generato.
::/if-empty

## Chi è a disposizione, e quando

Le ore che restano fra il monte ore di cattedra e le ore effettivamente in
orario. Non sono un errore — uno spezzone si completa altrove, il potenziamento
tiene ore libere apposta — ma sono l'elenco che serve il primo giorno di
supplenza, e va stampato con gli altri.

::python{data="docenti,lezioni" writes="a-disposizione" manual}
```python
def intero(v, d=0):
    try:
        return int(float(str(v).strip().replace(",", ".")))
    except (TypeError, ValueError):
        return d

in_orario = {}
for l in data["lezioni"]:
    doc = l.get("docente", "")
    if doc:
        in_orario[doc] = in_orario.get(doc, 0) + 1

result = []
for d in data["docenti"]:
    doc = d.get("cognome", "")
    dichiarate = intero(d.get("oreCattedra", ""), 0)
    fatte = in_orario.get(doc, 0)
    result.append({
        "id": "ad-" + (d.get("id", "") or doc), "docente": doc,
        "sigla": str(d.get("sigla", "")).strip() or doc, "tipo": d.get("tipo", ""),
        "cattedra": str(dichiarate), "orario": str(fatte),
        "disposizione": str(max(0, dichiarate - fatte)),
        "eccedenza": str(max(0, fatte - dichiarate)),
    })

result.sort(key=lambda r: (-int(r["disposizione"]), r["docente"]))
libere = sum(int(r["disposizione"]) for r in result)
oltre = [r for r in result if int(r["eccedenza"]) > 0]
print("Ore a disposizione in tutto: %d." % libere)
if oltre:
    print("Docenti con più ore in orario che di cattedra: %s."
          % ", ".join("%s (+%s)" % (r["docente"], r["eccedenza"]) for r in oltre))
    print("Non è una disposizione, è un monte ore sforato: la causa è nelle loro cattedre.")
```
::/python

::if-any{path="a-disposizione"}
::columns{min="30rem" gap="s" id="stampaDisposizione"}
### Ore a disposizione — IIS «Ada Lovelace»

::table{path="a-disposizione" sort="disposizione" dir="desc" filters="tipo"}
::column{field="docente" label="Docente"}
::column{field="sigla" label="Sigla"}
::column{field="tipo" label="Tipo"}
::column{field="cattedra" label="Di cattedra" align="end"}
::column{field="orario" label="In orario" align="end"}
::column{field="disposizione" label="A disposizione" align="end"}
::/table
::/columns

::print{target="stampaDisposizione" label="Stampa le ore a disposizione"}
::/if-any

::/page

::page{title="Sostituzioni" icon="replace"}

# Sostituzioni

L'orario si fa tre o quattro volte l'anno. Le sostituzioni si fanno **ogni
mattina alle sette e cinquanta**, in cinque minuti, ed è quello il lavoro che
consuma davvero il tempo di un ufficio. È la stessa griglia, aperta duecento
volte invece che quattro.

Questa pagina non è un secondo generatore, e la differenza è la ragione per cui
sta in una pagina sola. Scegliere chi copre un'ora **non è un problema
combinatorio**: la parte difficile è già stata risolta collocando le lezioni.
Quello che resta è un **ordinamento** — chi è libero a quell'ora, nello stesso
plesso, e in che ordine chiamarlo. Il blocco mette in fila i candidati e dice a
che titolo ognuno è tale; a decidere è chi sta al telefono, che sa cose che qui
non sono scritte da nessuna parte.

E c'è un secondo motivo, che vale più del primo: **il conto**. Quante ore di
sostituzione ha fatto ciascuno finora è il numero che rende una chiamata
difendibile in collegio, ed è precisamente quello che nessuno tiene, perché
tenerlo a mano è noioso. Qui si tiene da sé, perché è un conteggio su righe che
esistono già.

## L'approssimazione, dichiarata

Il generatore colloca le **cattedre**, non le ore a disposizione. Quindi una
casella vuota nell'orario di un docente è ambigua: può essere un'ora in cui è a
scuola e non ha classe, o un'ora in cui è a casa. L'orario, così com'è, non lo
sa.

La regola usata qui è quella che usano davvero tutte le scuole:

> è **in servizio** quel giorno se ha almeno un'ora di lezione, ed è **libero** a
> quell'ora se in quell'ora non ne ha nessuna.

Sbaglia di rado e non costa niente. Sbaglia in un caso solo, ed è meglio saperlo:
un docente il cui spezzone gli lascia una giornata intera a disposizione — nessuna
lezione, ma in servizio — qui non compare, perché dall'orario è indistinguibile
da uno che è a casa. La via d'uscita non è tarare questa regola: è far collocare
al generatore anche le ore a disposizione, e allora la domanda non si pone più.

Dentro quella regola, però, si distinguono due cose diverse, e la distinzione è
tutta la differenza fra una telefonata e un favore:

| | |
| --- | --- |
| **Dentro le sue ore** | l'ora libera sta *fra* due sue lezioni: quel docente è in istituto, di sicuro, e non deve muoversi |
| **Al bordo** | l'ora libera sta prima della sua prima lezione o dopo l'ultima: deve arrivare prima o fermarsi dopo |

## Chi è assente

Una riga per docente e per giorno. **Ore** si lascia vuoto quando manca tutta la
giornata; altrimenti si scrivono le ore separate da virgola — `1,2,3` per chi
rientra a metà mattina.

Sul motivo, una parola sola. *Assente* basta: il perché è un dato personale del
dipendente, non serve a coprire un'ora, e questa app non è il posto dove tenerlo.

::form{path="assenze" id="formAssenza"}
::input{field="data" legend="Giorno" type="date" required}
::input{field="docente" legend="Docente assente" type="ref" path="docenti" label="cognome" required}
::input{field="ore" legend="Ore" help="Vuoto: tutta la giornata. Altrimenti 1,2,3" pattern="[1-6](,[1-6])*|" message="Scrivi le ore separate da virgola, per esempio 1,2,3"}
::input{field="motivo" legend="Motivo" help="«Assente» basta: qui non va scritto perché"}
::input{field="note" legend="Note"}
::save{label="Registra l'assenza"}
::/form

::if-empty{path="assenze"}
Nessuna assenza registrata, e quindi niente da coprire. **L'app non ne semina
nessuna di esempio**, a differenza delle anagrafiche: un'assenza è un fatto di un
giorno preciso, e una finta appesa per sempre al sedici marzo sarebbe una bugia
che l'app ripete ogni mattina. Scrivine una qui sopra — due scelte e una data — e
la tabella sotto si riempie da sé.
::/if-empty

::if-any{path="assenze"}
**:count{path="assenze"}** assenze registrate.

::table{path="assenze" sort="data" dir="desc" search deletable editform="formAssenza"}
::column{field="data" label="Giorno"}
::column{field="docente>docenti.cognome" label="Docente"}
::column{field="ore" label="Ore"}
::column{field="motivo" label="Motivo"}
::column{field="note" label="Note"}
::/table
::/if-any

## Le ore da coprire, e chi può coprirle

Il blocco riparte da sé a ogni assenza registrata e a ogni sostituzione decisa —
non ha il pulsante *Esegui* delle anagrafiche, e la ragione è il ritmo: un'ora da
coprire va vista adesso, e questo conto dura un istante mentre una generazione
dura minuti.

Che rilegga anche le **sostituzioni già decise** non è un dettaglio. Chi è
appena stato mandato in 2A alla terza ora non è più libero a quell'ora, e sparisce
dai candidati delle altre classi scoperte in quella stessa ora: è l'unico modo
perché la seconda scelta della mattina sia giusta quanto la prima.

Per la stessa ragione **chi è assente non è un candidato**, e non è ovvio quanto
sembra: dall'orario un docente assente è indistinguibile da uno in servizio —
l'orario dice dove sarebbe, non dove è — e solo l'elenco delle assenze sa che non
c'è. Senza quel controllo la pagina proponeva l'assente delle nove come sostituto
dell'assente delle dieci, con una faccia serissima. Vale ora per ora: chi manca
le prime tre può coprire la quinta.

Finché non registri niente, però, le proposte **possono ripetersi**: due classi
scoperte alla terza ora si vedono proporre lo stesso nome, perché nessuna delle
due l'ha ancora impegnato. Registrane una e l'altra si corregge da sé. È il
comportamento giusto — una proposta non è una prenotazione — ma la prima volta
sorprende.

::python{data="assenze,sostituzioni,lezioni,docenti" writes="coperture"}
```python
# Le ore rimaste scoperte e i candidati per ognuna, in ordine. Nessuna decisione:
# il primo della lista è una PROPOSTA, e resta tale finché qualcuno non registra
# la sostituzione qui sotto.
import datetime

GIORNI = ["lun", "mar", "mer", "gio", "ven", "sab"]
NOMI = {"lun": "Lunedì", "mar": "Martedì", "mer": "Mercoledì",
        "gio": "Giovedì", "ven": "Venerdì", "sab": "Sabato"}
ORE = ["1", "2", "3", "4", "5", "6"]

def intero(v, d=0):
    try:
        return int(float(str(v).strip().replace(",", ".")))
    except (TypeError, ValueError):
        return d

def vero(v):
    return str(v).strip().lower() in ("true", "1", "yes", "on", "si", "sì")

# Le anagrafiche si citano per id, la griglia porta i nomi: è la stessa asimmetria
# spiegata in fondo a **Orario**, e qui va risolta nei due sensi.
per_id = {d.get("id", ""): d for d in data["docenti"]}
def cognome_di(valore):
    v = str(valore).strip()
    return per_id[v].get("cognome", "") if v in per_id else v

# La data è una data SCRITTA, non un istante: `datetime.date` non ha fusi da
# sbagliare. La trappola sarebbe `new Date("2027-03-16")` in JavaScript, che è
# mezzanotte UTC e a ovest di Greenwich cade il giorno prima.
def data_di(iso):
    parti = str(iso).strip()[:10].split("-")
    if len(parti) != 3:
        return None
    try:
        return datetime.date(int(parti[0]), int(parti[1]), int(parti[2]))
    except ValueError:
        return None

occupato = {}      # (cognome, giorno, ora) -> lezione
del_giorno = {}    # (cognome, giorno) -> ore
in_orario = {}     # cognome -> ore settimanali in griglia
for l in data["lezioni"]:
    doc = l.get("docente", "")
    if not doc:
        continue
    chiave = (doc, l.get("giorno", ""), str(l.get("ora", "")))
    occupato[chiave] = l
    del_giorno.setdefault((doc, l.get("giorno", "")), []).append(str(l.get("ora", "")))
    in_orario[doc] = in_orario.get(doc, 0) + 1

avvisi = []
buchi = {}
# Chi è via, ora per ora. Serve perché l'orario da solo non lo sa: dice che quel
# giorno il docente è in servizio, e lo direbbe anche mentre è a casa. Senza
# questo insieme un assente viene proposto come sostituto di un altro assente,
# che è l'errore più imbarazzante che questa pagina possa fare.
via = {}

for a in data["assenze"]:
    quando = data_di(a.get("data", ""))
    if quando is None:
        avvisi.append("Un'assenza non ha una data leggibile: «%s»." % a.get("data", ""))
        continue
    if quando.weekday() > 5:
        avvisi.append("%s è una domenica: niente da coprire." % a.get("data", ""))
        continue
    giorno = GIORNI[quando.weekday()]
    chi = cognome_di(a.get("docente", ""))
    if not chi:
        avvisi.append("Un'assenza non dice chi: la salto.")
        continue
    volute = [o.strip() for o in str(a.get("ore", "")).split(",") if o.strip()]
    via.setdefault((chi, a.get("data", "")), set()).update(volute or ORE)
    trovate = 0
    for ora in (volute or ORE):
        lezione = occupato.get((chi, giorno, ora))
        if lezione is None:
            continue
        # Una compresenza che manca non lascia una classe sola: il titolare è lì.
        # È un'ora di sostegno persa, non un buco da coprire — e confonderle
        # riempirebbe il foglio di ore che nessuno deve andare a fare.
        if vero(lezione.get("compresenza", "")):
            continue
        trovate += 1
        ident = "cop-%s-%s-%s" % (a.get("data", ""), ora, lezione.get("classe", ""))
        buchi[ident] = {
            "id": ident, "data": a.get("data", ""), "giorno": giorno,
            "giornoNome": NOMI[giorno], "ora": ora, "classe": lezione.get("classe", ""),
            "disciplina": lezione.get("disciplina", ""), "aula": lezione.get("aula", ""),
            "plesso": lezione.get("plesso", ""), "assente": chi,
            "chiave": "%s %s %sª · %s" % (a.get("data", ""), giorno, ora,
                                          lezione.get("classe", "")),
        }
    if trovate == 0:
        avvisi.append("%s il %s non ha lezioni da coprire%s."
                      % (chi, a.get("data", ""),
                         " in quelle ore" if volute else " (giorno libero?)"))

# Le sostituzioni già decise: chi è impegnato dove, e quante ne ha fatte finora.
# Il conto è su TUTTE le righe, non solo su quelle di oggi — è la misura che serve
# a chiamare il prossimo, e una che si azzerasse ogni mattina non direbbe niente.
scelte = {}
fatte = {}
impegnato = {}
for s in data["sostituzioni"]:
    quale = str(s.get("copertura", "")).strip()
    sostituto = cognome_di(s.get("sostituto", ""))
    if sostituto:
        fatte[sostituto] = fatte.get(sostituto, 0) + 1
    if quale in buchi:
        b = buchi[quale]
        scelte[quale] = (sostituto, str(s.get("titolo", "")).strip())
        if sostituto:
            impegnato[(sostituto, b["giorno"], b["ora"])] = b["classe"]
    elif quale:
        avvisi.append("Una sostituzione punta a un'ora che non c'è più: "
                      "l'assenza è stata tolta o l'orario è cambiato.")

def candidati(b):
    fuori = []
    for d in data["docenti"]:
        chi = d.get("cognome", "")
        if not chi or chi == b["assente"]:
            continue
        if b["ora"] in via.get((chi, b["data"]), ()):
            continue
        sue = del_giorno.get((chi, b["giorno"]), [])
        gia = occupato.get((chi, b["giorno"], b["ora"]))
        if gia is not None:
            # Il caso più economico di tutti: è già in quella classe, in
            # compresenza, e la classe non resta sola nemmeno per un minuto.
            if gia.get("classe", "") == b["classe"] and vero(gia.get("compresenza", "")):
                fuori.append((0, fatte.get(chi, 0), chi, "già in classe, in compresenza"))
            continue
        if (chi, b["giorno"], b["ora"]) in impegnato:
            continue
        if not sue:
            continue
        if b["ora"] == "1" and vero(d.get("nonPrimaOra", "")):
            continue
        plessi = {occupato[(chi, b["giorno"], o)].get("plesso", "") for o in sue}
        if b["plesso"] and b["plesso"] not in plessi:
            continue
        indici = sorted(ORE.index(o) for o in sue if o in ORE)
        qui = ORE.index(b["ora"])
        dentro = bool(indici) and indici[0] < qui < indici[-1]
        residuo = intero(d.get("oreCattedra", ""), 0) - in_orario.get(chi, 0)
        tetto = intero(d.get("maxOreGiorno", ""), 0)
        oltre = 1 if tetto and len(sue) >= tetto else 0
        if residuo > 0:
            rango, perche = (1 if dentro else 2), "a disposizione"
        else:
            rango, perche = (3 if dentro else 4), "ora eccedente"
        if not dentro:
            perche += ", fuori dalle sue ore"
        if oltre:
            perche += ", già al suo tetto giornaliero"
        fuori.append((rango + oltre, fatte.get(chi, 0), chi, perche))
    fuori.sort(key=lambda c: (c[0], c[1], c[2]))
    return fuori

result = []
for ident in sorted(buchi):
    b = buchi[ident]
    lista = candidati(b)
    sostituto, titolo = scelte.get(ident, ("", ""))
    b["candidati"] = " · ".join("%s (%s, %d finora)" % (c[2], c[3], c[1])
                                for c in lista[:4]) or "nessuno"
    b["proposto"] = lista[0][2] if lista else ""
    b["sostituto"] = sostituto
    b["titolo"] = titolo
    b["stato"] = "coperta" if sostituto else ("scoperta" if not lista else "da coprire")
    result.append(b)

aperte = [r for r in result if r["stato"] != "coperta"]
mute = [r for r in result if r["stato"] == "scoperta"]
print("Ore da coprire: %d. Ancora senza sostituto: %d." % (len(result), len(aperte)))
if mute:
    print("Senza nessun candidato: %s."
          % ", ".join("%s %sª %s" % (r["giorno"], r["ora"], r["classe"]) for r in mute))
    print("Restano l'accorpamento e la chiamata a chi oggi non è in istituto: "
          "sono decisioni, e l'app non le prende.")
for riga in avvisi[:8]:
    print(riga)
```
::/python

::if-any{path="coperture"}
::table{path="coperture" search sort="chiave" filters="data,stato,plesso,classe" page-size="20"}
::column{field="data" label="Data"}
::column{field="giornoNome" label="Giorno"}
::column{field="ora" label="Ora" align="end"}
::column{field="classe" label="Classe"}
::column{field="disciplina" label="Disciplina"}
::column{field="aula" label="Aula"}
::column{field="assente" label="Assente"}
::column{field="candidati" label="Chi può coprirla, in ordine"}
::column{field="sostituto" label="Assegnata a"}
::column{field="stato" label="Stato"}
::/table
::/if-any

## Registrare la sostituzione

Due scelte: quale ora, e chi. L'ora si prende dall'elenco qui sopra — l'elenco è
la collezione, quindi il campo la offre per nome invece di farla riscrivere — e
il nome dal registro dei docenti. Registrata, la riga di sopra passa a *coperta*
e quel docente sparisce dai candidati delle altre ore di quella stessa ora.

::form{path="sostituzioni" id="formSostituzione"}
::input{field="copertura" legend="Ora da coprire" type="ref" path="coperture" label="chiave" required}
::input{field="sostituto" legend="Chi la copre" type="ref" path="docenti" label="cognome" required}
::input{field="titolo" legend="A che titolo" help="a disposizione, ora eccedente, compresenza, accorpamento"}
::input{field="note" legend="Note"}
::save{label="Registra la sostituzione"}
::/form

::if-any{path="sostituzioni"}
**:count{path="sostituzioni"}** sostituzioni registrate.

::table{path="sostituzioni" search filters="titolo" deletable editform="formSostituzione"}
::column{field="copertura>coperture.chiave" label="Ora"}
::column{field="sostituto>docenti.cognome" label="Sostituto"}
::column{field="titolo" label="Titolo"}
::column{field="note" label="Note"}
::/table
::/if-any

## Chi ne ha fatte quante

Il conto che rende una chiamata difendibile. Non è una classifica: è il
tiebreaker che il blocco di sopra usa già da sé — a parità di titolo chiama chi
ne ha fatte meno — ed è qui perché la regola vada vista, non subita.

::python{data="sostituzioni,coperture,docenti,lezioni" writes="carico"}
```python
def intero(v, d=0):
    try:
        return int(float(str(v).strip().replace(",", ".")))
    except (TypeError, ValueError):
        return d

per_id = {d.get("id", ""): d for d in data["docenti"]}
def cognome_di(valore):
    v = str(valore).strip()
    return per_id[v].get("cognome", "") if v in per_id else v

coperture = {c.get("id", ""): c for c in data["coperture"]}

in_orario = {}
for l in data["lezioni"]:
    doc = l.get("docente", "")
    if doc:
        in_orario[doc] = in_orario.get(doc, 0) + 1

fatte = {}
ultima = {}
for s in data["sostituzioni"]:
    chi = cognome_di(s.get("sostituto", ""))
    if not chi:
        continue
    fatte[chi] = fatte.get(chi, 0) + 1
    quando = coperture.get(str(s.get("copertura", "")).strip(), {}).get("data", "")
    # Le date sono scritte ISO, quindi il massimo si prende confrontando le
    # stringhe: `2027-03-16` è ordinabile come testo, ed è metà del perché sono
    # scritte così.
    if quando > ultima.get(chi, ""):
        ultima[chi] = quando

result = []
for d in data["docenti"]:
    chi = d.get("cognome", "")
    if not chi:
        continue
    result.append({
        "id": "car-" + (d.get("id", "") or chi), "docente": chi,
        "sigla": str(d.get("sigla", "")).strip() or chi, "tipo": d.get("tipo", ""),
        "plesso": d.get("plesso", ""),
        "disposizione": str(max(0, intero(d.get("oreCattedra", ""), 0) - in_orario.get(chi, 0))),
        "fatte": str(fatte.get(chi, 0)), "ultima": ultima.get(chi, ""),
    })

result.sort(key=lambda r: (-int(r["fatte"]), r["docente"]))
totale = sum(int(r["fatte"]) for r in result)
print("Sostituzioni registrate: %d, su %d docenti." % (totale, len(result)))
if totale:
    massimo, minimo = int(result[0]["fatte"]), int(result[-1]["fatte"])
    print("Il più caricato ne ha %d, il meno caricato %d." % (massimo, minimo))
```
::/python

::if-any{path="carico"}
::table{path="carico" sort="fatte" dir="desc" filters="tipo,plesso"}
::column{field="docente" label="Docente"}
::column{field="tipo" label="Tipo"}
::column{field="plesso" label="Plesso"}
::column{field="disposizione" label="A disposizione" align="end"}
::column{field="fatte" label="Sostituzioni" align="end"}
::column{field="ultima" label="L'ultima"}
::/table

::chart-bar{data="carico" x="docente" y="fatte" horizontal height="20rem"}
::/if-any

## Il foglio del giorno

Quello che si appende in sala professori. Si scrive il giorno e si stampa: finché non
c'è un giorno il foglio è vuoto, e non è un difetto — un foglio delle
sostituzioni è di **un** giorno, e senza il giorno non è niente.

Il giorno va scritto **come è memorizzato**, `2027-03-16`, che non è come la
tabella qui sopra lo mostra: le date si scrivono ISO perché così si ordinano da
sé e valgono in ogni fuso, e si *mostrano* all'italiana perché così si leggono.
Il filtro lavora sul valore, non su come appare, ed è l'unico punto di questa
pagina in cui la differenza si vede.

::textfield[giornoSel]{label="Giorno da stampare, anno-mese-giorno" placeholder="2027-03-16"}

::columns{min="34rem" gap="s" id="foglioSostituzioni"}
### Sostituzioni del :value[giornoSel]{ref="#giornoSel"}

IIS «Ada Lovelace» — anno scolastico 2026/2027

::table{path="coperture" filter="data=#giornoSel" sort="chiave"}
::column{field="ora" label="Ora" align="end"}
::column{field="classe" label="Classe"}
::column{field="aula" label="Aula"}
::column{field="assente" label="Assente"}
::column{field="sostituto" label="Sostituisce"}
::column{field="titolo" label="A che titolo"}
::/table
::/columns

::print{target="foglioSostituzioni" label="Stampa il foglio del giorno"}

## Quello che questa pagina non fa

| Fa | Non fa |
| --- | --- |
| Ordina i candidati per titolo e, a parità, per chi ne ha fatte meno | Non conosce i contratti: quante ore eccedenti si possano chiedere a qualcuno lo sa solo chi fa l'orario |
| Toglie dai candidati chi è già stato impegnato in quell'ora | Non avvisa nessuno: se l'app è in uno spazio condiviso, la chat è lì per quello |
| Tiene il conto delle ore fatte da ciascuno, e lo mostra | Non è un registro delle presenze del personale, e il motivo dell'assenza non gli serve |
| Segnala le ore per cui non c'è nessuno | Non accorpa le classi, e non sceglie chi far entrare prima del suo orario |
| Stampa il foglio di un giorno | Non manda niente a nessuno, come tutto il resto di questa app |

::/page
