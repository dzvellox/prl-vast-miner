#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$ROOT_DIR/logs/miner.log"
PID_FILE="$ROOT_DIR/.miner.pid"
WATCHDOG_PID_FILE="$ROOT_DIR/.watchdog.pid"
MINER_BIN="${MINER_BIN:-$ROOT_DIR/.local/bin/bzminer}"
MINER_KIND="${MINER_KIND:-bzminer}"

: "${KRYPTEX_MINING_USERNAME:?KRYPTEX_MINING_USERNAME manquant}"
: "${POOL_URL:?POOL_URL manquant}"
: "${WORKER_NAME:?WORKER_NAME manquant}"

RESTART_DELAY="${RESTART_DELAY:-5}"
MAX_RESTARTS="${MAX_RESTARTS:-0}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
OC_APPLY="${OC_APPLY:-0}"
OC_CORE_OFFSET="${OC_CORE_OFFSET:-200}"
OC_LOCK_CORE="${OC_LOCK_CORE:-2490}"
OC_LOCK_MEMORY="${OC_LOCK_MEMORY:-7001}"
OC_POWER_LIMIT="${OC_POWER_LIMIT:-575}"

[[ -x "$MINER_BIN" ]] || { echo "Erreur : mineur introuvable : $MINER_BIN" >&2; exit 20; }

mkdir -p "$(dirname "$LOG_FILE")"
echo "$$" > "$WATCHDOG_PID_FILE"
STOP_REQUESTED=0
CHILD_PID=""

cleanup() {
  STOP_REQUESTED=1
  if [[ -n "${CHILD_PID:-}" ]] && kill -0 "$CHILD_PID" 2>/dev/null; then
    kill -TERM "$CHILD_PID" 2>/dev/null || true
    wait "$CHILD_PID" 2>/dev/null || true
  fi
  rm -f "$PID_FILE" "$WATCHDOG_PID_FILE"
}
trap cleanup INT TERM EXIT

read -r -a EXTRA_ARR <<< "$EXTRA_ARGS"

# Kryptex documente BzMiner avec WALLET_OR_USERNAME/WORKER dans -w.
# En mode compte Kryptex, le "wallet" est le Mining Username (krx...).
KRYPTEX_LOGIN="${KRYPTEX_MINING_USERNAME}/${WORKER_NAME}"

if [[ "$MINER_KIND" == "srbminer" ]]; then
  TLS_ARGS=()
  if [[ "$POOL_URL" == stratum+ssl://* ]]; then TLS_ARGS=(--tls true); fi
  CMD=(
    "$MINER_BIN" --disable-cpu --disable-gpu-amd --disable-gpu-intel
    --algorithm pearlhash --pool "${POOL_URL#*://}"
    --wallet "${KRYPTEX_MINING_USERNAME}.${WORKER_NAME}" --password x
    "${TLS_ARGS[@]}"
    --gpu-coffset0 "$OC_CORE_OFFSET"
    --gpu-cclock0 "$OC_LOCK_CORE"
    --gpu-mclock0 "$OC_LOCK_MEMORY"
    --gpu-plimit0 "$OC_POWER_LIMIT"
  )
else
  CMD=(
    "$MINER_BIN" -a pearl -p "$POOL_URL" -w "$KRYPTEX_LOGIN"
    --nvidia 1 --amd 0 --intel 0 --igpu 0 --cpu 0 --cpu_threads 0 --nc 1
  )
  if [[ "$OC_APPLY" == "1" ]]; then
    CMD+=(
      --oc-core-clock-offset "$OC_CORE_OFFSET"
      --oc-lock-core-clock "$OC_LOCK_CORE"
      --oc-lock-memory-clock "$OC_LOCK_MEMORY"
      --oc-power-limit "$OC_POWER_LIMIT"
    )
  fi
fi

if (( ${#EXTRA_ARR[@]} > 0 )); then
  CMD+=("${EXTRA_ARR[@]}")
fi

restart_count=0
while (( STOP_REQUESTED == 0 )); do
  printf '\n[%s] Démarrage %s sur Kryptex (tentative %d)\n' "$(date -Is)" "$MINER_KIND" "$((restart_count + 1))" | tee -a "$LOG_FILE"
  printf '[%s] Commande: ' "$(date -Is)" | tee -a "$LOG_FILE"
  printf '%q ' "${CMD[@]}" | sed "s#${KRYPTEX_MINING_USERNAME}#<KRYPTEX_USER>#g" | tee -a "$LOG_FILE"
  echo | tee -a "$LOG_FILE"

  set +e
  if [[ "$MINER_KIND" == "srbminer" ]]; then
    (cd "$(dirname "$MINER_BIN")" && exec "${CMD[@]}") > >(tee -a "$LOG_FILE") 2>&1 &
  else
    "${CMD[@]}" > >(tee -a "$LOG_FILE") 2>&1 &
  fi
  CHILD_PID=$!
  echo "$CHILD_PID" > "$PID_FILE"
  wait "$CHILD_PID"
  rc=$?
  set -e
  CHILD_PID=""
  rm -f "$PID_FILE"

  if (( STOP_REQUESTED != 0 )); then
    break
  fi

  restart_count=$((restart_count + 1))
  printf '[%s] Mineur %s arrêté (code %d).\n' "$(date -Is)" "$MINER_KIND" "$rc" | tee -a "$LOG_FILE"

  if (( MAX_RESTARTS > 0 && restart_count >= MAX_RESTARTS )); then
    echo "Nombre maximal de relances atteint ($MAX_RESTARTS)." | tee -a "$LOG_FILE"
    exit "$rc"
  fi

  echo "Relance dans ${RESTART_DELAY}s..." | tee -a "$LOG_FILE"
  sleep "$RESTART_DELAY"
done
