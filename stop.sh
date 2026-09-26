#!/usr/bin/env bash
set -u
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WATCHDOG_PID_FILE="$ROOT_DIR/.watchdog.pid"
MINER_PID_FILE="$ROOT_DIR/.miner.pid"

stop_pid() {
  local pid="$1"
  local label="$2"
  if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    return 1
  fi
  echo "Arrêt de $label (PID $pid)..."
  kill -TERM "$pid" 2>/dev/null || true
  for _ in $(seq 1 15); do
    kill -0 "$pid" 2>/dev/null || return 0
    sleep 1
  done
  kill -KILL "$pid" 2>/dev/null || true
  return 0
}

if [[ -f "$WATCHDOG_PID_FILE" ]]; then
  pid="$(cat "$WATCHDOG_PID_FILE" 2>/dev/null || true)"
  if stop_pid "$pid" "watchdog"; then
    rm -f "$WATCHDOG_PID_FILE" "$MINER_PID_FILE"
    echo "Mineur arrêté."
    exit 0
  fi
fi

# Fallback pour une ancienne exécution sans watchdog.pid.
if [[ -f "$MINER_PID_FILE" ]]; then
  pid="$(cat "$MINER_PID_FILE" 2>/dev/null || true)"
  if stop_pid "$pid" "mineur"; then
    rm -f "$MINER_PID_FILE"
    echo "Mineur arrêté."
    exit 0
  fi
fi

rm -f "$WATCHDOG_PID_FILE" "$MINER_PID_FILE"
echo "Aucun processus de minage actif."
