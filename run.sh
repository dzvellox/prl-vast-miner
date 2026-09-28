#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================
# COMPTE KRYPTEX (AUTO-EXCHANGE -> RETRAIT BNB)
# ============================================================
# Mets ici ton "Mining Username" Kryptex, visible dans ton profil.
# Exemple : krxABC123
#
# IMPORTANT : ne mets PAS ton adresse BNB ici.
# Le minage est crédité sur ton compte Kryptex ; le retrait BNB
# (BNB Smart Chain / BEP20) se fait ensuite depuis Kryptex.
KRYPTEX_MINING_USERNAME="krxYD3M464"

# Pool PRL Kryptex officiel GLOBAL (TCP).
# On garde volontairement Global par défaut car la région de la machine Vast.ai peut varier.
# Aucune région de secours n'est choisie automatiquement.
# Surcharge manuelle possible : POOL_URL=... ./run.sh
POOL_URL="${POOL_URL:-stratum+tcp://prl.kryptex.network:7048}"

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
  echo "Tu le trouves dans ton profil Kryptex. Exemple de format : krxXXXXXX" >&2
  exit 2
fi

# Le format habituel est krx..., mais on ne bloque pas si Kryptex change son format.
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

# Décide si le profil OC peut être utilisé sans risquer de l'appliquer à un autre modèle.
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

export KRYPTEX_MINING_USERNAME POOL_URL WORKER_NAME
export RESTART_DELAY="${RESTART_DELAY:-5}"
export MAX_RESTARTS="${MAX_RESTARTS:-0}"
export EXTRA_ARGS="${EXTRA_ARGS:-}"
export OC_APPLY OC_CORE_OFFSET OC_LOCK_CORE OC_LOCK_MEMORY OC_POWER_LIMIT

MINER_KIND=bzminer
if [[ -n "${MINER_BIN:-}" ]]; then
  echo "[Mineur] Binaire personnalisé : $MINER_BIN"
else
  MINER_BIN="$ROOT_DIR/.local/bin/bzminer"
  if [[ "$OC_APPLY" == "1" && "${WILDRIG_AUTO:-1}" == "1" ]]; then
    export GPU_COUNT
    if bash "$ROOT_DIR/scripts/install_wildrig.sh" &&
       bash "$ROOT_DIR/scripts/probe_wildrig.sh"; then
      MINER_KIND=wildrig
      MINER_BIN="$(<"$ROOT_DIR/.local/bin/.wildrig-path")"
    else
      echo "[Mineur] Essai WildRig non validé : utilisation de BzMiner."
    fi
  fi
  if [[ "$MINER_KIND" == "bzminer" ]]; then
    bash "$ROOT_DIR/scripts/install_bzminer.sh"
  fi
fi
export MINER_BIN MINER_KIND

echo
echo "=== Lancement PRL -> Kryptex ==="
echo "Mineur         : $MINER_KIND"
echo "Pool           : $POOL_URL"
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
