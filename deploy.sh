#!/usr/bin/env bash
# ============================================================================
# Pubblica lo stack ReactiveNET su DUE macchine collegate da una VPN.
#
# Gli INDIRIZZI delle macchine non stanno in questo file: il repository è
# pubblico e la topologia della rete di produzione non è parte del codice.
# Vivono in deploy.env (gitignorato — copiare deploy.env.example) o
# nell'ambiente: APP_HOST, APP_DIR, DATA_HOST, DATA_DIR.
#
#   SERVER APP  ($APP_HOST) — riceve:
#     - sito vetrina/documentazione (build HUGO)   -> $APP_DIR/site
#     - app statica (build ReScript+Vite della PWA)-> $APP_DIR/dist
#     - PocketBase (hooks + migrazioni + launcher) -> $APP_DIR/pb, $APP_DIR/scripts
#     - server MCP (bundle unico + risorse runtime)-> $APP_DIR/mcp, $APP_DIR/doc
#     - Caddyfile                                  -> $APP_DIR/
#     poi RIAVVIA PocketBase, server MCP (PM2) e Caddy — sempre, a ogni deploy,
#     e verifica che siano tornati su (scripts/restart-services.sh).
#
#   SERVER DATI — riceve SOLO la parte dati:
#     - servizio dati open + warehouse DuckDB      -> $DATA_DIR/
#     poi riavvia il servizio dati (PM2).
#     La macchina ha DUE indirizzi e servono a due cose diverse: il deploy la
#     raggiunge in LAN, il Caddy del server app la raggiunge in VPN. Vedi la
#     nota su DATA_HOST più sotto.
#
# Il resto (sito/app/PocketBase/MCP) resta sul server app; il servizio DuckDB
# vive sul server dati, esposto a Internet solo dal Caddy del server app
# (reverse proxy data.reactivenet.ai → server dati via VPN — e /od/* su
# app.reactivenet.ai, per la connect-src 'self' dell'app).
#
# Uso (dal tuo client sulla VPN, in LAN col server dati):
#   ./deploy.sh
#   ./deploy.sh --app-only     # sito/app/Caddy + PocketBase + server MCP (salta i dati)
#   ./deploy.sh --mcp-only     # solo il server MCP (direttive o guida cambiate)
#   ./deploy.sh --pb-only      # solo PocketBase (hooks o migrazioni cambiate)
#   ./deploy.sh --data-only    # solo servizio dati + warehouse
#   APP_HOST=... DATA_HOST=... ./deploy.sh    # indirizzi diversi da deploy.env
#
# Prerequisiti locali:  bun, rsync, ssh (verso il server app in VPN e verso il
#                       server dati in LAN), hugo (build del sito).
# Prerequisiti server app:   bun + pm2 (PocketBase, MCP), Caddy (TLS),
#                            unzip (scripts/pocketbase.mjs scarica il binario
#                            pinnato al primo avvio e lo spacchetta).
# Prerequisiti server dati:  bun + pm2 (servizio dati). Node non richiesto
#                            (start-pm2.sh esegue PM2 via Bun se manca).
#
# Le password (se auth a password) vengono chieste una sola volta PER HOST:
# lo script apre una connessione SSH master (ControlMaster) per ciascuna
# macchina e tutti i comandi ssh/rsync successivi la riusano.
# ============================================================================
set -euo pipefail

# --- Destinazioni -----------------------------------------------------------
# Da deploy.env (gitignorato) o dall'ambiente; deploy.env.example documenta le
# variabili. Per DATA_HOST conviene l'indirizzo LAN del server dati: nove giga
# di warehouse su una VPN sono minuti che la rete locale non chiede. È solo il
# TRASPORTO del deploy — l'indirizzo di SERVIZIO resta quello VPN: il Caddy
# del server app continua a fare reverse proxy verso il server dati
# (data.reactivenet.ai e /od/*), che è l'unica strada per cui una macchina
# senza IP pubblico è raggiungibile da Internet. Le due cose non vanno
# confuse: cambiare DATA_HOST NON sposta il servizio, e il Caddyfile non ne
# sa nulla.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
if [ -f "$ROOT/deploy.env" ]; then
  # shellcheck source=/dev/null
  . "$ROOT/deploy.env"
fi
APP_HOST="${APP_HOST:?APP_HOST mancante: copia deploy.env.example in deploy.env e compilalo}"
APP_DIR="${APP_DIR:?APP_DIR mancante (vedi deploy.env.example)}"
DATA_HOST="${DATA_HOST:?DATA_HOST mancante (vedi deploy.env.example)}"
DATA_DIR="${DATA_DIR:?DATA_DIR mancante (vedi deploy.env.example)}"

# --- Selezione fasi ---------------------------------------------------------
DO_APP=1
DO_PB=1
DO_MCP=1
DO_DATA=1
for arg in "$@"; do
  case "$arg" in
    # --app-only comprende PocketBase e il server MCP: vivono sulla stessa
    # macchina e sono la parte "app" del sistema. --mcp-only e --pb-only
    # servono a ripubblicare solo quelli — i casi frequenti quando si toccano
    # direttive/guida (MCP) o hooks/migrazioni (PocketBase).
    --app-only)  DO_DATA=0 ;;
    --mcp-only)  DO_APP=0; DO_PB=0; DO_DATA=0 ;;
    --pb-only)   DO_APP=0; DO_MCP=0; DO_DATA=0 ;;
    --data-only) DO_APP=0; DO_PB=0; DO_MCP=0 ;;
    *) echo "opzione sconosciuta: $arg (usa --app-only | --mcp-only | --pb-only | --data-only)" >&2; exit 2 ;;
  esac
done

# --- Prerequisiti locali ----------------------------------------------------
for cmd in bun rsync ssh; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "manca '$cmd' nel PATH" >&2; exit 1; }
done
# hugo serve solo alla fase APP (build del sito).
if [ "$DO_APP" -eq 1 ]; then
  command -v hugo >/dev/null 2>&1 || { echo "manca 'hugo' nel PATH (build del sito)" >&2; exit 1; }
fi

# --- SSH multiplexato, un socket PER HOST -----------------------------------
SSH_SOCK_DIR="$(mktemp -d)"
SSH_OPTS=(-o ControlMaster=auto -o ControlPath="$SSH_SOCK_DIR/ctrl-%r@%h:%p" -o ControlPersist=10m)
OPENED_HOSTS=()

open_ssh() { # $1 = host
  echo "== SSH: apro la connessione verso $1 (password richiesta una sola volta) =="
  ssh "${SSH_OPTS[@]}" -MNf "$1"
  OPENED_HOSTS+=("$1")
}

cleanup() {
  for h in "${OPENED_HOSTS[@]:-}"; do
    [ -n "$h" ] && ssh "${SSH_OPTS[@]}" -O exit "$h" >/dev/null 2>&1 || true
  done
  rm -rf "$SSH_SOCK_DIR"
}
trap cleanup EXIT

RSYNC_SSH="ssh ${SSH_OPTS[*]}"

# --- Avanzamento di rsync ---------------------------------------------------
# Quasi tutto questo deploy è veloce; il warehouse no. Nove gigabyte su una VPN
# sono minuti, e senza avanzamento non c'è modo di distinguere «sta copiando» da
# «è appeso» — l'unica cosa da fare diventa aspettare e sperare.
#
# `--info=progress2` dà UNA riga per l'intero trasferimento — percentuale,
# velocità, tempo rimasto — invece della riga per file di `--progress`, che con
# le centinaia di file di dist/ e site/ sarebbe rumore e con un file solo da
# nove giga non direbbe nulla di più.
#
# `--no-inc-recursive` è ciò che rende quella percentuale vera: con la ricorsione
# incrementale rsync non conosce il totale quando comincia, quindi la percentuale
# sale e poi torna indietro man mano che scopre altri file. Costa una scansione
# in più prima di partire, che su queste cartelle è nulla.
#
# Solo su terminale: la riga si riscrive con dei ritorni a capo, e finita in un
# file di log diventerebbe una riga sola lunghissima. Redirezionato, il deploy
# torna a dire soltanto che cosa ha copiato.
RSYNC_FLAGS=(-avz --human-readable)
if [ -t 1 ]; then
  RSYNC_FLAGS+=(--info=progress2 --no-inc-recursive)
fi

# Un riavvio fallito non ferma il resto del deploy, ma non passa inosservato:
# viene raccolto qui e lo script esce != 0 dicendo che cosa è rimasto giù.
FAILED=()

# --- Build ------------------------------------------------------------------
# ReScript prima di tutto: sia `vite build` sia il bundle MCP consumano i
# .res.mjs emessi — `bun run build` NON compila ReScript (regola di CLAUDE.md),
# e mcp/server.mjs importa i moduli compilati da src/.
if [ "$DO_APP" -eq 1 ] || [ "$DO_MCP" -eq 1 ]; then
  echo "== Compilazione ReScript =="
  bun run res:build
fi

if [ "$DO_APP" -eq 1 ]; then
  echo "== Build dell'app (Vite) =="
  bun run build

  echo "== Build del sito (Hugo) =="
  # PRIMA della build: i documenti di legal/ vengono sincronizzati dentro
  # site/content — i legali seguono il codice, e il sito pubblica la copia
  # sincronizzata, mai una a mano.
  bun site/scripts/sync-legal.mjs
  # Il contrasto è un vincolo di build (WCAG 2.2 AA), non un consiglio: se il
  # check esiste e fallisce, il deploy si ferma qui.
  if [ -f site/scripts/check-contrast.mjs ]; then
    ( cd site && bun scripts/check-contrast.mjs )
  fi
  # --cleanDestinationDir: site/public è mirrorato con --delete più sotto,
  # quindi anche il build locale parte pulito (niente residui di build vecchie).
  hugo --minify --cleanDestinationDir -s site
fi

# Bundle del server MCP: un file unico con dentro le dipendenze (SDK MCP, zod,
# i .res.mjs del core), così sul server non servono né node_modules né bun
# install. Restano FUORI dal bundle le risorse lette a runtime con readFileSync
# (doc/, mcp/examples/, package.json): vanno rsyncate accanto, rispettando la
# struttura di cartelle che il bundle si aspetta (vedi fase MCP).
if [ "$DO_MCP" -eq 1 ]; then
  echo "== Bundle del server MCP =="
  # Svuotata come dist/ e site/public: il bundle è un file solo, ma una versione
  # precedente rimasta accanto verrebbe rsyncata sul server come se fosse viva.
  rm -rf mcp/dist
  bun build mcp/server.mjs --target=bun --outfile=mcp/dist/server.mjs
fi

# ============================================================================
# FASE APP — sito, app statica, Caddy  → SERVER APP
# ============================================================================
# Una sola connessione SSH verso il server app, condivisa da APP, PB e MCP.
if [ "$DO_APP" -eq 1 ] || [ "$DO_PB" -eq 1 ] || [ "$DO_MCP" -eq 1 ]; then
  open_ssh "$APP_HOST"
fi

if [ "$DO_APP" -eq 1 ]; then
  echo "== Server app ($APP_HOST): preparo le cartelle =="
  ssh "${SSH_OPTS[@]}" "$APP_HOST" "mkdir -p '$APP_DIR/dist' '$APP_DIR/site'"

  echo "== Server app: sync (rsync) =="
  # App: mirror completo — --delete rimuove i vecchi asset con hash non più usati.
  rsync "${RSYNC_FLAGS[@]}" --delete -e "$RSYNC_SSH" dist/ "$APP_HOST:$APP_DIR/dist/"
  # Sito: mirror completo del build Hugo (site/public).
  rsync "${RSYNC_FLAGS[@]}" --delete -e "$RSYNC_SSH" site/public/ "$APP_HOST:$APP_DIR/site/"
  # Caddyfile (i proxy same-origin /pb /od /mcp /pa e gli header di sicurezza
  # dell'app vivono lì: va deployato insieme all'app che li presuppone).
  rsync "${RSYNC_FLAGS[@]}" -e "$RSYNC_SSH" Caddyfile "$APP_HOST:$APP_DIR/"

fi

# ============================================================================
# FASE PB — PocketBase (short link + spazi condivisi)  → SERVER APP
# ============================================================================
if [ "$DO_PB" -eq 1 ]; then
  echo "== Server app ($APP_HOST): PocketBase =="
  ssh "${SSH_OPTS[@]}" "$APP_HOST" "mkdir -p '$APP_DIR/pb' '$APP_DIR/scripts'"

  # SOLO schema e comportamento (versionati in pb/) e il launcher che scarica
  # il binario pinnato. Mai .pocketbase/ (binario + pb_data: lo stato runtime
  # del server è SUO — sovrascriverlo butterebbe via link e spazi condivisi).
  rsync "${RSYNC_FLAGS[@]}" --delete -e "$RSYNC_SSH" pb/pb_hooks pb/pb_migrations "$APP_HOST:$APP_DIR/pb/"
  rsync "${RSYNC_FLAGS[@]}" -e "$RSYNC_SSH" scripts/pocketbase.mjs "$APP_HOST:$APP_DIR/scripts/"

fi

# ============================================================================
# FASE MCP — server MCP (connettore di Claude + assistente in-app) → SERVER APP
# ============================================================================
if [ "$DO_MCP" -eq 1 ]; then
  echo "== Server app ($APP_HOST): server MCP =="
  ssh "${SSH_OPTS[@]}" "$APP_HOST" "mkdir -p '$APP_DIR/mcp/examples' '$APP_DIR/doc'"

  # Il bundle ingloba le dipendenze, ma risolve i percorsi a runtime rispetto
  # a import.meta (HERE = cartella del bundle): legge la guida in HERE/../doc,
  # gli esempi in HERE/examples e la versione in HERE/../package.json. La
  # struttura sul server replica quindi quella del repo:
  #   $APP_DIR/mcp/server.mjs      (il bundle, da mcp/dist/)
  #   $APP_DIR/mcp/examples/*.md   (le ricette)
  #   $APP_DIR/doc/*.md            (la guida servita a sezioni)
  #   $APP_DIR/package.json        (solo per il campo version)
  rsync "${RSYNC_FLAGS[@]}" -e "$RSYNC_SSH" mcp/dist/server.mjs "$APP_HOST:$APP_DIR/mcp/"
  rsync "${RSYNC_FLAGS[@]}" --delete -e "$RSYNC_SSH" mcp/examples/ "$APP_HOST:$APP_DIR/mcp/examples/"
  rsync "${RSYNC_FLAGS[@]}" --delete -e "$RSYNC_SSH" doc/ "$APP_HOST:$APP_DIR/doc/"
  rsync "${RSYNC_FLAGS[@]}" -e "$RSYNC_SSH" package.json "$APP_HOST:$APP_DIR/"

fi

# ============================================================================
# RIAVVIO — PocketBase, server MCP, Caddy  → SERVER APP
# ============================================================================
# Sempre, qualunque fase sia stata scelta: un deploy che copia i file e lascia
# in vita i processi vecchi pubblica una cosa e ne serve un'altra. Vale anche
# per Caddy, che prima veniva solo ricaricato.
#
# Solo sulle macchine che questo deploy tocca già: con --data-only aprire una
# seconda connessione al server app significherebbe chiedere una password per
# riavviare servizi che nessuno ha toccato.
if [ "$DO_APP" -eq 1 ] || [ "$DO_PB" -eq 1 ] || [ "$DO_MCP" -eq 1 ]; then
  echo "== Server app ($APP_HOST): riavvio i servizi =="
  ssh "${SSH_OPTS[@]}" "$APP_HOST" "mkdir -p '$APP_DIR/scripts'"
  rsync "${RSYNC_FLAGS[@]}" -e "$RSYNC_SSH" scripts/restart-services.sh "$APP_HOST:$APP_DIR/scripts/"
  if ssh "${SSH_OPTS[@]}" "$APP_HOST" "bash '$APP_DIR/scripts/restart-services.sh' '$APP_DIR'"; then
    echo "[ok] servizi del server app riavviati"
  else
    FAILED+=("server app: uno dei servizi non è ripartito")
  fi
fi

# ============================================================================
# FASE DATI — servizio dati open + warehouse  → SERVER DATI
# ============================================================================
if [ "$DO_DATA" -eq 1 ]; then
  open_ssh "$DATA_HOST"
  echo "== Server dati ($DATA_HOST): preparo la cartella =="
  ssh "${SSH_OPTS[@]}" "$DATA_HOST" "mkdir -p '$DATA_DIR'"

  echo "== Server dati: sync (rsync) =="
  # Codice + script d'avvio. Mai `raw/` (cache download) né node_modules
  # (binding DuckDB nativo: bun install lo fa start-pm2.sh al primo avvio).
  rsync "${RSYNC_FLAGS[@]}" -e "$RSYNC_SSH" data/server.mjs data/package.json data/start-pm2.sh data/README.md \
    "$DATA_HOST:$DATA_DIR/"
  # Warehouse (prodotto dall'ETL in locale): rsync è incrementale, ma il PRIMO
  # deploy trasferisce tutto. Mai le cache *-emb.duckdb (servono solo all'ETL,
  # gitignored).
  rsync "${RSYNC_FLAGS[@]}" -e "$RSYNC_SSH" data/warehouse.duckdb "$DATA_HOST:$DATA_DIR/"

  echo "== Server dati: riavvio servizio (best-effort) =="
  # Riavvio DOPO aver sostituito il warehouse (il servizio lo apre read-only).
  if ssh "${SSH_OPTS[@]}" "$DATA_HOST" bash -s <<EOF
set -e
export PATH="\$HOME/.bun/bin:\$PATH"
cd '$DATA_DIR'
chmod +x start-pm2.sh
./start-pm2.sh
EOF
  then
    echo "[ok] servizio dati riavviato"
  else
    FAILED+=("server dati: start-pm2.sh non riuscito (bun/pm2 nel PATH?)")
  fi
fi

echo
if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "✗ Pubblicato, MA qualcosa non è ripartito:"
  for problem in "${FAILED[@]}"; do echo "    - $problem"; done
  echo "  I file sono sul server; i servizi elencati vanno guardati a mano."
  exit 1
fi

echo "✓ Pubblicato."
# `if`, non `[ … ] && { … }`: con `set -e` un test falso in ULTIMA posizione fa
# uscire lo script con 1, così `--app-only` riportava un fallimento pur essendo
# andato tutto bene. Ora l'uscita dice qualcosa, quindi deve dire il vero.
if [ "$DO_APP" -eq 1 ]; then
  echo "  Sito:   https://reactivenet.ai       ($APP_HOST:$APP_DIR/site)"
  echo "  App:    https://app.reactivenet.ai   ($APP_HOST:$APP_DIR/dist)"
fi
if [ "$DO_PB" -eq 1 ]; then
  echo "  PB:     https://app.reactivenet.ai/pb/  (proxy → localhost:8090)"
fi
if [ "$DO_MCP" -eq 1 ]; then
  echo "  MCP:    https://mcp.reactivenet.ai/mcp  (proxy → localhost:8789, anche /mcp sull'app)"
fi
if [ "$DO_DATA" -eq 1 ]; then
  # Il percorso che si stampa è quello del SERVIZIO, non quello del deploy:
  # chi legge questa riga vuole sapere da dove passano le richieste, e passano
  # dalla VPN. L'indirizzo LAN ha già fatto il suo lavoro qualche riga sopra.
  echo "  Dati:   https://data.reactivenet.ai  (Caddy sul server app → VPN 10.10.10.2:8788)"
  echo "          pubblicato su $DATA_HOST:$DATA_DIR"
fi
