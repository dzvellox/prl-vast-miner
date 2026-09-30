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
  say_ok "exécution root : les réglages OC BzMiner peuvent être tentés"
else
  say_warn "pas root : le profil OC sera automatiquement ignoré sous Linux"
fi

PRIMARY_POOL="${POOL_URL:-stratum+tcp://prl.kryptex.network:7048}"
FALLBACK_POOLS="${POOL_FALLBACKS-stratum+ssl://prl.kryptex.network:8048,stratum+ssl://prl-eu.kryptex.network:8048,stratum+tcp://prl-eu.kryptex.network:7048,stratum+ssl://prl-us.kryptex.network:8048,stratum+tcp://prl-us.kryptex.network:7048}"
POOLS=("$PRIMARY_POOL")
if [[ -n "$FALLBACK_POOLS" ]]; then
  IFS=',' read -r -a _fb <<< "$FALLBACK_POOLS"
  POOLS+=("${_fb[@]}")
fi

reachable=0
for pool in "${POOLS[@]}"; do
  [[ -n "$pool" ]] || continue
  hostport="${pool#*://}"
  host="${hostport%%:*}"
  port="${hostport##*:}"
  scheme="${pool%%://*}"

  if command -v getent >/dev/null 2>&1 && getent hosts "$host" >/dev/null 2>&1; then
    dns_status="DNS OK"
  else
    dns_status="DNS ?"
  fi

  if command -v timeout >/dev/null 2>&1 && timeout 3 bash -c "</dev/tcp/$host/$port" >/dev/null 2>&1; then
    say_ok "route pool accessible ($scheme) : $host:$port [$dns_status]"
    reachable=$((reachable + 1))
  else
    say_warn "route pool non confirmée ($scheme) : $host:$port [$dns_status]"
  fi
done

if (( reachable == 0 )); then
  say_warn "aucune route Kryptex n'a été confirmée par le test TCP; BzMiner essaiera quand même toutes les routes configurées"
else
  say_ok "$reachable route(s) Kryptex accessible(s) sur ${#POOLS[@]} testée(s)"
fi

if [[ -x "$ROOT_DIR/.local/bin/bzminer" ]]; then
  say_ok "BzMiner installé localement"
else
  say_warn "BzMiner pas encore installé (run.sh l'installera automatiquement)"
fi

exit $(( ok ? 0 : 1 ))
