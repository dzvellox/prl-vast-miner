#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================
# COMPTE KRYPTEX (AUTO-EXCHANGE -> RETRAIT BNB)
# ============================================================
KRYPTEX_MINING_USERNAME="${KRYPTEX_MINING_USERNAME:-krxYD3M464}"

# ============================================================
# POOLS PRL KRYPTEX + ROUTES DE SECOURS
# ============================================================
# Route principale : Global en TCP.
POOL_URL="${POOL_URL:-stratum+tcp://prl.kryptex.network:7048}"

# BzMiner sait gérer les pools de secours nativement. Si la route principale
# ne répond plus, il passe à la suivante puis revient automatiquement au
# primaire lorsqu'il redevient valide.
#
# Ordre par défaut :
#   1) Global SSL   -> secours immédiat si TCP/7048 est filtré
#   2) Europe SSL  -> autre endpoint + autre port/protocole
#   3) Europe TCP
#   4) US SSL
#   5) US TCP
#
# Format : URLs séparées par des virgules. Pour désactiver : POOL_FALLBACKS=""
POOL_FALLBACKS="${POOL_FALLBACKS-stratum+ssl://prl.kryptex.network:8048,stratum+ssl://prl-eu.kryptex.network:8048,stratum+tcp://prl-eu.kryptex.network:7048,stratum+ssl://prl-us.kryptex.network:8048,stratum+tcp://prl-us.kryptex.network:7048}"

# ============================================================
# PROFIL OVERCLOCK RTX 5090
# ============================================================
OC_ENABLE="${OC_ENABLE:-1}"
OC_TARGET_MODEL="${OC_TARGET_MODEL:-RTX 5090}"
OC_CORE_OFFSET="${OC_CORE_OFFSET:-200}"
OC_LOCK_CORE="${OC_LOCK_CORE:-2490}"
OC_LOCK_MEMORY="${OC_LOCK_MEMORY:-7001}"
OC_POWER_LIMIT="${OC_POWER_LIMIT:-575}"

mkdir -p "$ROOT_DIR/logs" "$ROOT_DIR/.cache" "$ROOT_DIR/.local/bin"

if [[ -z "$KRYPTEX_MINING_USERNAME" || "$KRYPTEX_MINING_USERNAME" == "REMPLACE_ICI_PAR_TON_MINING_USERNAME_KRYPTEX" ]]; then
  echo "Erreur : configure ton Mining Username Kryptex dans run.sh (KRYPTEX_MINING_USERNAME=...)." >&2
  exit 2
fi

if [[ "$KRYPTEX_MINING_USERNAME" != krx* ]]; then
  echo "AVERTISSEMENT : le Mining Username Kryptex ne commence pas par 'krx'. Vérifie la valeur dans ton profil Kryptex." >&2
fi

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "Erreur : nvidia-smi introuvable. Utilise une instance Vast.ai avec GPU NVIDIA et driver exposé au conteneur." >&2
  exit 3
fi

mapfile -t GPU_NAMES < <(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | sed 's/^ *//;s/ *$//')
GPU_COUNT="${#GPU_NAMES[@]}"
if (( GPU_COUNT < 1 )); then
  echo "Erreur : aucun GPU NVIDIA visible." >&2
  exit 3
fi

echo "GPU NVIDIA détectés : $GPU_COUNT"
nvidia-smi --query-gpu=index,name,driver_version,memory.total,power.limit --format=csv,noheader || true

# Kryptex demande un worker <= 32 caractères, lettres latines et chiffres uniquement.
if [[ -z "${WORKER_NAME:-}" ]]; then
  if [[ -n "${VAST_CONTAINERLABEL:-}" ]]; then
    RAW_WORKER="$VAST_CONTAINERLABEL"
  else
    RAW_WORKER="$(hostname)"
  fi
else
  RAW_WORKER="$WORKER_NAME"
fi
WORKER_NAME="$(printf '%s' "$RAW_WORKER" | tr -cd 'A-Za-z0-9' | cut -c1-32)"
WORKER_NAME="${WORKER_NAME:-VastRig}"

OC_APPLY=0
if [[ "$OC_ENABLE" == "1" ]]; then
  all_target=1
  for gpu_name in "${GPU_NAMES[@]}"; do
    if [[ "$gpu_name" != *"$OC_TARGET_MODEL"* ]]; then
      all_target=0
      break
    fi
  done

  if (( all_target == 0 )); then
    echo "[OC] Profil non appliqué : au moins un GPU n'est pas un $OC_TARGET_MODEL."
  elif [[ "$(id -u)" -ne 0 ]]; then
    echo "[OC] Profil non appliqué : BzMiner doit être lancé en root sous Linux pour modifier les clocks/power limit."
  else
    OC_APPLY=1
    echo "[OC] Profil RTX 5090 demandé : core +${OC_CORE_OFFSET}, lock core ${OC_LOCK_CORE} MHz, lock mémoire ${OC_LOCK_MEMORY} MHz, PL ${OC_POWER_LIMIT} W."
  fi
else
  echo "[OC] Désactivé (OC_ENABLE=$OC_ENABLE)."
fi

export KRYPTEX_MINING_USERNAME POOL_URL POOL_FALLBACKS WORKER_NAME
export RESTART_DELAY="${RESTART_DELAY:-5}"
export MAX_RESTARTS="${MAX_RESTARTS:-0}"
export EXTRA_ARGS="${EXTRA_ARGS:-}"
export OC_APPLY OC_CORE_OFFSET OC_LOCK_CORE OC_LOCK_MEMORY OC_POWER_LIMIT

if [[ -n "${MINER_BIN:-}" ]]; then
  echo "[Mineur] Binaire BzMiner personnalisé : $MINER_BIN"
else
  MINER_BIN="$ROOT_DIR/.local/bin/bzminer"
  bash "$ROOT_DIR/scripts/install_bzminer.sh"
fi
export MINER_BIN

echo
echo "=== Lancement PRL -> Kryptex ==="
echo "Mineur         : BzMiner"
echo "Pool principal : $POOL_URL"
if [[ -n "$POOL_FALLBACKS" ]]; then
  IFS=',' read -r -a _fallback_display <<< "$POOL_FALLBACKS"
  echo "Pools secours  : ${#_fallback_display[@]} route(s)"
  for _p in "${_fallback_display[@]}"; do
    [[ -n "$_p" ]] && echo "  -> $_p"
  done
else
  echo "Pools secours  : désactivés"
fi
echo "Compte Kryptex : ${KRYPTEX_MINING_USERNAME:0:4}***"
echo "Worker         : $WORKER_NAME"
echo "Paiement visé  : BNB Smart Chain depuis le compte Kryptex"
echo "GPU            : $GPU_COUNT NVIDIA (tous les GPU visibles)"
if [[ "$OC_APPLY" == "1" ]]; then
  echo "OC demandé     : +${OC_CORE_OFFSET} core / ${OC_LOCK_CORE} core lock / ${OC_LOCK_MEMORY} mem lock / ${OC_POWER_LIMIT} W"
else
  echo "OC             : non appliqué"
fi
echo "Log            : $ROOT_DIR/logs/miner.log"
echo

exec "$ROOT_DIR/scripts/watchdog.sh"
