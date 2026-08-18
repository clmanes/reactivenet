#!/usr/bin/env bash
# ============================================================================
# Riavvia i servizi del SERVER APP: PocketBase, server MCP, Caddy.
#
# Gira SUL SERVER, non sul client: deploy.sh lo rsynca in $APP_DIR/scripts/ e
# lo esegue. Sta in un file suo e non in un heredoc dentro deploy.sh perché la
# logica di Caddy ha abbastanza rami da meritare di essere leggibile — e da
# poter essere controllata con `bash -n` prima di spedirla.
#
#   uso:  bash scripts/restart-services.sh <APP_DIR>
#
# Esce != 0 se anche uno solo dei servizi non è ripartito. Un deploy che
# annuncia "pubblicato" mentre un servizio è giù è peggio di un deploy fallito,
# perché nessuno va a guardare.
# ============================================================================
set -uo pipefail

APP_DIR="${1:?uso: restart-services.sh <APP_DIR>}"
CADDYFILE="$APP_DIR/Caddyfile"
export PATH="$HOME/.bun/bin:$PATH"
status=0

# PM2 via Bun se Node non c'è (stessa difesa di data/start-pm2.sh).
pm2cmd() { if command -v pm2 >/dev/null 2>&1; then pm2 "$@"; else bunx pm2 "$@"; fi; }

# Riavvia se PM2 lo conosce già, altrimenti lo avvia. --update-env perché le
# variabili qui sotto cambiano fra un deploy e l'altro e un restart secco si
# terrebbe quelle vecchie.
pm2_up() { # $1 = nome, $2 = comando
  if pm2cmd describe "$1" >/dev/null 2>&1; then
    pm2cmd restart "$1" --update-env
  else
    pm2cmd start "$2" --name "$1"
  fi
}

cd "$APP_DIR" || { echo "[errore] $APP_DIR non esiste"; exit 1; }

# --- PocketBase -------------------------------------------------------------
# Il launcher risolve .pocketbase/ e pb/ da process.cwd(): va avviato DALLA
# radice di $APP_DIR. Ascolta su 127.0.0.1:8090, esposto solo dal proxy /pb/*.
echo "-- PocketBase"
pm2_up pb "bun scripts/pocketbase.mjs" || { echo "[errore] PocketBase non riavviato"; status=1; }

# --- Server MCP -------------------------------------------------------------
# MCP_APP_URL: gli short link prodotti dai tool devono puntare all'app
# pubblicata, non a localhost. MCP_OD_URL: il catalogo open-data sta sull'altra
# macchina, via VPN.
echo "-- Server MCP"
export MCP_APP_URL="${MCP_APP_URL:-https://app.reactivenet.ai}"
export MCP_OD_URL="${MCP_OD_URL:-http://10.10.10.2:8788}"
pm2_up mcp "bun mcp/server.mjs" || { echo "[errore] server MCP non riavviato"; status=1; }

pm2cmd save >/dev/null 2>&1 || true

# --- Caddy ------------------------------------------------------------------
echo "-- Caddy"
if ! command -v caddy >/dev/null 2>&1; then
  echo "[errore] caddy non è nel PATH: il sito e l'app non sono serviti"
  status=1
elif [ ! -f "$CADDYFILE" ]; then
  echo "[errore] manca $CADDYFILE"
  status=1
else
  # Prima di toccare qualsiasi cosa: un config rotto va scoperto ORA, non dopo
  # aver fermato il server che sta servendo il sito.
  if ! caddy validate --adapter caddyfile --config "$CADDYFILE"; then
    echo "[errore] Caddyfile non valido: Caddy NON è stato riavviato"
    status=1
  else
  caddy_restarted=1
  # Prima di riavviare: FERMARE OGNI Caddy, non solo il servizio.
  #
  # Un'istanza avviata a mano (`caddy start`, magari da un giro precedente di
  # questo stesso script) non è sotto systemd. `systemctl restart caddy` la
  # ignora: lei continua a tenere le porte 80 e 443, il servizio "riparte"
  # senza poterle prendere, e a rispondere resta il processo vecchio con la
  # configurazione vecchia. È il processo fantasma, e da fuori è indistinguibile
  # da un deploy riuscito — anzi, `pgrep -x caddy` lo trova e lo scambia per il
  # servizio appena avviato, che è esattamente come questo controllo ha lasciato
  # passare una CSP vecchia per ore.
  #
  # Quindi: chiedere per bene (admin API, poi systemd), aspettare, e solo se
  # qualcosa resta in piedi terminarlo. In quest'ordine, perché uno spegnimento
  # pulito chiude le connessioni in corso e restituisce le porte.
  caddy stop >/dev/null 2>&1 || true
  systemctl stop caddy >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5; do pgrep -x caddy >/dev/null 2>&1 || break; sleep 1; done
  if pgrep -x caddy >/dev/null 2>&1; then
    echo "[info] un Caddy è rimasto in piedi dopo lo stop: lo termino (processo fantasma)"
    pkill -x caddy 2>/dev/null || true
    sleep 2
    pgrep -x caddy >/dev/null 2>&1 && { pkill -9 -x caddy 2>/dev/null || true; sleep 1; }
  fi

  if systemctl cat caddy >/dev/null 2>&1; then
    # Gestito da systemd, che di suo carica /etc/caddy/Caddyfile — il file di
    # DEFAULT, che qui non si usa e non si tocca: la configurazione di questo
    # sistema è quella versionata nel repo e deployata in $CADDYFILE, e deve
    # esserci una sola copia viva. Copiarla sul file di default creerebbe la
    # seconda, e da lì in poi non si saprebbe più quale delle due è in servizio.
    #
    # Si punta quindi la unit al file deployato, con un drop-in: un frammento in
    # caddy.service.d/ che riscrive ExecStart/ExecReload senza modificare la unit
    # del pacchetto (che un aggiornamento di Caddy sovrascriverebbe) e senza
    # scrivere una riga in /etc/caddy/. ExecStart va svuotato prima di
    # riassegnarlo: in systemd un secondo ExecStart si AGGIUNGE al primo, e la
    # unit partirebbe con due Caddy, il primo dei quali col config di default.
    # Sovrascrivibile solo perché il ramo systemd, altrimenti, si può provare
    # soltanto da root su una macchina vera.
    dropin_dir="${SYSTEMD_DROPIN_DIR:-/etc/systemd/system/caddy.service.d}"
    dropin="$dropin_dir/10-reactive.conf"
    wanted="# Generato da scripts/restart-services.sh — non modificare a mano.
# Punta Caddy alla configurazione deployata dal repo, non a /etc/caddy/Caddyfile.
[Service]
ExecStart=
ExecStart=$(command -v caddy) run --environ --config $CADDYFILE --adapter caddyfile
ExecReload=
ExecReload=$(command -v caddy) reload --config $CADDYFILE --adapter caddyfile --force"
    if [ "$(cat "$dropin" 2>/dev/null)" != "$wanted" ]; then
      if mkdir -p "$dropin_dir" && printf '%s\n' "$wanted" > "$dropin"; then
        echo "[info] drop-in systemd aggiornato: Caddy caricherà $CADDYFILE"
        systemctl daemon-reload || { echo "[errore] systemctl daemon-reload"; status=1; }
      else
        echo "[errore] non ho potuto scrivere $dropin (servono i permessi di root)"
        status=1
      fi
    fi
    systemctl start caddy || { echo "[errore] systemctl start caddy"; status=1; }
  else
    # Nessuna unit: si avvia a mano, sempre dal file deployato.
    caddy start --config "$CADDYFILE" --adapter caddyfile ||
      { echo "[errore] caddy start"; status=1; }
  fi
  fi
fi

# --- Verifica che siano davvero tornati su ----------------------------------
# Riavviare e non guardare è metà del lavoro: PM2 dichiara "restarted" anche per
# un processo che muore subito dopo, quindi si controlla lo stato, non l'esito
# del comando.
sleep 2
for service in pb mcp; do
  if pm2cmd describe "$service" 2>/dev/null | grep -q "online"; then
    echo "[ok] $service è online"
  else
    echo "[errore] $service NON è online"
    status=1
  fi
done

if ! pgrep -x caddy >/dev/null 2>&1; then
  echo "[errore] caddy NON è in esecuzione"
  status=1
else
  echo "[ok] caddy è in esecuzione"

  # ...ma "in esecuzione" non è la domanda. La domanda è QUALE configurazione
  # sta servendo, e le due si separano esattamente nel caso che conta: un
  # processo fantasma è in esecuzione, risponde, e serve quella di ieri. Un
  # deploy che si ferma a pgrep annuncia "pubblicato" e pubblica il passato.
  #
  # Quindi si chiede a Caddy un header e lo si confronta con quello che il
  # Caddyfile deployato dice. La CSP è la riga giusta da usare: è lunga, cambia
  # spesso, e se sbaglia non è un dettaglio — è metà delle difese dell'app.
  # --resolve manda la richiesta a 127.0.0.1 tenendo nome e SNI, così si parla
  # con QUESTO Caddy e il certificato resta valido.
  expected_csp="$(sed -n 's/.*Content-Security-Policy[[:space:]]*"\(.*\)".*/\1/p' "$CADDYFILE" | head -1)"
  # Il dominio è quello del blocco che dichiara la CSP, letto dal file: così non
  # c'è un secondo posto dove tenerlo aggiornato.
  app_domain="$(awk '/^[^[:space:]#].*\{[[:space:]]*$/ {site=$1} /Content-Security-Policy/ {print site; exit}' "$CADDYFILE")"

  if [ "${caddy_restarted:-0}" -eq 0 ]; then
    # Non è stato riavviato (config non valido, o caddy assente): quello che
    # sta servendo è per definizione il vecchio, e dirlo "verificato" sarebbe
    # la bugia che questo controllo esiste per impedire.
    echo "[avviso] Caddy non è stato riavviato: sta servendo la configurazione precedente"
  elif [ -z "$expected_csp" ] || [ -z "$app_domain" ]; then
    echo "[avviso] non ho trovato CSP o dominio in $CADDYFILE: verifica saltata"
  elif ! command -v curl >/dev/null 2>&1; then
    echo "[avviso] curl non c'è: non ho potuto verificare cosa Caddy sta servendo"
  else
    served_csp=""
    for _ in 1 2 3 4 5 6; do
      served_csp="$(curl -sS -I --max-time 5 --resolve "$app_domain:443:127.0.0.1" \
        "https://$app_domain/" 2>/dev/null | tr -d '\r' |
        sed -n 's/^[Cc]ontent-[Ss]ecurity-[Pp]olicy:[[:space:]]*//p' | head -1)"
      [ -n "$served_csp" ] && break
      sleep 2
    done
    if [ -z "$served_csp" ]; then
      echo "[errore] $app_domain non risponde su questa macchina: Caddy non serve l'app"
      status=1
    elif [ "$served_csp" = "$expected_csp" ]; then
      echo "[ok] caddy sta servendo la configurazione appena deployata"
    else
      echo "[errore] caddy risponde con una CSP DIVERSA da quella deployata."
      echo "         attesa:   $expected_csp"
      echo "         servita:  $served_csp"
      echo "         (di solito: un altro Caddy tiene le porte, oppure la unit"
      echo "          carica un file diverso da $CADDYFILE)"
      status=1
    fi
  fi
fi

exit "$status"
