#!/usr/bin/env bash
# ============================================================================
# Avvia (o ricarica) il servizio dati open di Reactive sotto PM2.
# Gemello di relay/start-pm2.sh: Bun come interprete, PM2 via Bun se manca Node.
#
# Uso:
#   bun install                    # una tantum: binding DuckDB nativo
#   ./start-pm2.sh                 # porta 8788
#   PORT=9100 ./start-pm2.sh       # override via variabili d'ambiente
#
# Variabili (con default): PORT=8788  OLLAMA_URL=http://localhost:11434
#                          EMBED_MODEL=qwen3-embedding:0.6b
#
# NB1: /search embedda la query col motore ONNX INTEGRATO (Transformers.js su
#      CPU, modello ~600 MB scaricato al primo avvio in model-cache/): il
#      servizio è autosufficiente. Se sul server c'è anche Ollama (con
#      qwen3-embedding:0.6b) viene usato come acceleratore, ma non serve.
# NB2: il servizio apre warehouse.duckdb in SOLA LETTURA; l'ETL va eseguito a
#      servizio fermo (pm2 stop reactive-data) o su una copia poi sostituita.
# NB3: ascolta in chiaro su :8788, bindando tutte le interfacce (Bun.serve),
#      così è raggiungibile via VPN. Gira sul SERVER DATI (VPN 10.10.10.2); il
#      TLS e l'esposizione a Internet li mette il Caddy del SERVER APP, che fa
#      reverse proxy data.reactivenet.ai → 10.10.10.2:8788 (vedi Caddyfile).
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="reactive-data"

BUN_BIN="$(command -v bun || true)"
if [ -z "$BUN_BIN" ]; then
  echo "ERRORE: 'bun' non trovato nel PATH. Installa Bun: https://bun.sh" >&2
  exit 1
fi

PM2_CLI="$(command -v pm2 || true)"
if [ -z "$PM2_CLI" ]; then
  echo "ERRORE: 'pm2' non trovato nel PATH. Installalo con: bun add -g pm2" >&2
  exit 1
fi

if command -v node >/dev/null 2>&1; then
  pm2() { command pm2 "$@"; }
else
  echo "→ Node assente: eseguo PM2 tramite Bun"
  pm2() { "$BUN_BIN" "$PM2_CLI" "$@"; }
fi

export PORT="${PORT:-8788}"
export OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
export EMBED_MODEL="${EMBED_MODEL:-qwen3-embedding:0.6b}"

if [ ! -f "$SCRIPT_DIR/warehouse.duckdb" ]; then
  echo "ERRORE: warehouse.duckdb assente. Esegui l'ETL in locale e ripubblica" >&2
  echo "  (deploy.sh lo sincronizza), oppure: bun run etl && bun run embed" >&2
  exit 1
fi

if [ ! -d "$SCRIPT_DIR/node_modules" ]; then
  echo "→ node_modules assente: bun install"
  "$BUN_BIN" install
fi

echo "→ Bun:    $BUN_BIN"
echo "→ Porta:  $PORT"
echo "→ Ollama: $OLLAMA_URL ($EMBED_MODEL)"

if pm2 describe "$APP_NAME" >/dev/null 2>&1; then
  echo "→ Processo esistente: ricarico ($APP_NAME)"
  pm2 restart "$APP_NAME" --update-env
else
  echo "→ Primo avvio ($APP_NAME)"
  pm2 start "$SCRIPT_DIR/server.mjs" \
    --name "$APP_NAME" \
    --interpreter "$BUN_BIN" \
    --time
fi

pm2 save

echo
echo "✓ Servizio dati attivo sotto PM2."
echo "  Log:     pm2 logs $APP_NAME"
echo "  Health:  curl -s http://localhost:$PORT/"
