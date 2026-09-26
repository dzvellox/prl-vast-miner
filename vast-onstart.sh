#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="${REPO_URL:-https://github.com/VOTRE_USER/prl-vast-miner.git}"
TARGET_DIR="${TARGET_DIR:-/workspace/prl-vast-miner}"

if [[ "$REPO_URL" == *"VOTRE_USER"* ]]; then
  echo "Configurez REPO_URL avec l'URL de votre dépôt GitHub." >&2
  exit 2
fi

if [[ ! -d "$TARGET_DIR/.git" ]]; then
  git clone "$REPO_URL" "$TARGET_DIR"
else
  git -C "$TARGET_DIR" pull --ff-only || true
fi

cd "$TARGET_DIR"
chmod +x run.sh check.sh status.sh stop.sh scripts/*.sh
exec ./run.sh
