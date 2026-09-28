#!/usr/bin/env bash
set -u
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ok=1
say_ok(){ printf '[OK] %s\n' "$1"; }
say_warn(){ printf '[WARN] %s\n' "$1"; }
say_err(){ printf '[ERREUR] %s\n' "$1"; ok=0; }

if command -v nvidia-smi >/dev/null 2>&1; then
  say_ok "nvidia-smi présent"
  if nvidia-smi >/dev/null 2>&1; then
    count="$(nvidia-smi --query-gpu=index --format=csv,noheader 2>/dev/null | wc -l | tr -d ' ')"
    say_ok "$count GPU NVIDIA visible(s)"
    nvidia-smi --query-gpu=index,name,driver_version,temperature.gpu,power.draw,power.limit,memory.total --format=csv,noheader 2>/dev/null || true
  else
    say_err "nvidia-smi ne peut pas communiquer avec le driver"
  fi
else
  say_err "nvidia-smi introuvable"
fi

if [[ "$(id -u)" -eq 0 ]]; then
  say_ok "exécution root : les réglages OC SRBMiner/BzMiner peuvent être tentés"
else
  say_warn "pas root : le profil OC sera automatiquement ignoré sous Linux"
fi

pool="${POOL_URL:-stratum+tcp://prl.kryptex.network:7048}"
hostport="${pool#*://}"
host="${hostport%%:*}"
port="${hostport##*:}"
if command -v getent >/dev/null 2>&1 && getent hosts "$host" >/dev/null 2>&1; then
  say_ok "DNS du pool Kryptex résolu : $host"
else
  say_warn "impossible de confirmer la résolution DNS du pool : $host"
fi

if command -v timeout >/dev/null 2>&1 && timeout 3 bash -c "</dev/tcp/$host/$port" >/dev/null 2>&1; then
  say_ok "port du pool accessible : $host:$port"
else
  say_warn "impossible de confirmer l'accès TCP à $host:$port (cela peut dépendre du conteneur/réseau)"
fi

if [[ -x "$ROOT_DIR/.local/bin/bzminer" ]]; then
  say_ok "BzMiner installé localement"
else
  say_warn "BzMiner pas encore installé (run.sh l'installera en cas de repli)"
fi

if [[ -f "$ROOT_DIR/.local/bin/.srbminer-path" ]] && [[ -x "$(<"$ROOT_DIR/.local/bin/.srbminer-path")" ]]; then
  say_ok "SRBMiner installé localement"
else
  say_warn "SRBMiner pas encore installé (run.sh le testera si le profil OC est éligible)"
fi

exit $(( ok ? 0 : 1 ))
