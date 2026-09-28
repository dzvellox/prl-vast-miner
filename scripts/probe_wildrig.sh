#!/usr/bin/env bash
# Essai réel sur Kryptex : OC observable et au moins une share acceptée.
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${KRYPTEX_MINING_USERNAME:?}"
: "${WORKER_NAME:?}"
: "${POOL_URL:?}"
: "${GPU_COUNT:?}"
WILDRIG_BIN="$ROOT_DIR/.local/bin/wildrig"
LOG_FILE="$ROOT_DIR/logs/wildrig-probe.log"
TRIAL_SECONDS="${WILDRIG_TRIAL_SECONDS:-120}"
[[ "$TRIAL_SECONDS" =~ ^[0-9]+$ ]] && (( TRIAL_SECONDS >= 30 && TRIAL_SECONDS <= 300 )) || {
  echo "WILDRIG_TRIAL_SECONDS doit être compris entre 30 et 300" >&2
  exit 2
}
mkdir -p "$ROOT_DIR/logs"
: > "$LOG_FILE"
POOL_HOST="${POOL_URL#*://}"
CMD=(
  "$WILDRIG_BIN" -a pearlhash -o "$POOL_HOST"
  -u "${KRYPTEX_MINING_USERNAME}/${WORKER_NAME}" -p x
  --opencl-platforms nvidia
  --gpu-core-offset "$OC_CORE_OFFSET"
  --gpu-core-clock "$OC_LOCK_CORE"
  --gpu-memory-clock "$OC_LOCK_MEMORY"
  --gpu-powerlimit "$OC_POWER_LIMIT"
)
echo "[WildRig] Essai de ${TRIAL_SECONDS}s ; vérification des fréquences et d'une share Kryptex..."
"${CMD[@]}" > "$LOG_FILE" 2>&1 &
child=$!
cleanup() {
  if kill -0 "$child" 2>/dev/null; then
    kill -TERM "$child" 2>/dev/null || true
  fi
  wait "$child" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

oc_observed() {
  local telemetry
  telemetry="$(nvidia-smi --query-gpu=power.limit,clocks.current.graphics,clocks.current.memory --format=csv,noheader,nounits 2>/dev/null)" || return 1
  printf '%s\n' "$telemetry" | awk -F, -v expected="$GPU_COUNT" \
    -v power="$OC_POWER_LIMIT" -v core="$OC_LOCK_CORE" -v mem="$OC_LOCK_MEMORY" '
    function abs(x) { return x < 0 ? -x : x }
    NF != 3 { bad=1; next }
    { for (i=1;i<=3;i++) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i); if ($i !~ /^[0-9]+([.][0-9]+)?$/) bad=1 }
      if (abs($1-power)>1 || abs($2-core)>150 || abs($3-mem)>50) bad=1
      count++
    }
    END { exit (bad || count != expected) ? 1 : 0 }'
}
oc_seen=0
for ((elapsed=0; elapsed<TRIAL_SECONDS; elapsed+=5)); do
  sleep 5
  if ! kill -0 "$child" 2>/dev/null; then
    echo "[WildRig] Le mineur s'est arrêté pendant l'essai."
    exit 1
  fi
  if oc_observed; then oc_seen=1; fi
  if (( oc_seen == 1 )) && grep -Eiq 'accepted[[:space:]]*\([[:space:]]*[1-9][0-9]*/' "$LOG_FILE"; then
    echo "[WildRig] OC observé et share acceptée par Kryptex."
    exit 0
  fi
done
echo "[WildRig] Essai non validé (OC ou share non confirmés) ; voir $LOG_FILE"
exit 1
