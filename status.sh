#!/usr/bin/env bash
set -u
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$ROOT_DIR/.miner.pid"
WATCHDOG_PID_FILE="$ROOT_DIR/.watchdog.pid"

echo "=== GPU ==="
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=index,name,utilization.gpu,temperature.gpu,power.draw,power.limit,clocks.current.graphics,clocks.current.memory,memory.used,memory.total --format=csv,noheader 2>/dev/null || nvidia-smi
else
  echo "nvidia-smi introuvable"
fi

echo
if [[ -f "$WATCHDOG_PID_FILE" ]]; then
  wpid="$(cat "$WATCHDOG_PID_FILE" 2>/dev/null || true)"
  if [[ -n "$wpid" ]] && kill -0 "$wpid" 2>/dev/null; then
    echo "Watchdog actif : PID $wpid"
  else
    echo "Watchdog inactif"
  fi
fi

if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    echo "Mineur actif : PID $pid"
  else
    echo "PID file présent mais processus inactif"
  fi
else
  echo "Aucun PID file : mineur probablement arrêté"
fi

echo
if [[ -f "$ROOT_DIR/logs/miner.log" ]]; then
  echo "=== Dernières lignes du log ==="
  tail -n 30 "$ROOT_DIR/logs/miner.log"
fi
