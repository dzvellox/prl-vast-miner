#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/srbminer-version.env"
CACHE_DIR="$ROOT_DIR/.cache"
BIN_DIR="$ROOT_DIR/.local/bin"
ARCHIVE_PATH="$CACHE_DIR/$SRBMINER_ARCHIVE"
VERSION_MARKER="$BIN_DIR/.srbminer-version"
PATH_MARKER="$BIN_DIR/.srbminer-path"
mkdir -p "$CACHE_DIR" "$BIN_DIR"
if [[ -f "$PATH_MARKER" && -x "$(<"$PATH_MARKER")" && -f "$VERSION_MARKER" && "$(<"$VERSION_MARKER")" == "$SRBMINER_VERSION" ]]; then
  exit 0
fi
command -v sha256sum >/dev/null || exit 10
command -v tar >/dev/null || exit 10
if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "Téléchargement de SRBMiner-MULTI $SRBMINER_VERSION..."
  if command -v curl >/dev/null; then
    curl -fL --retry 4 --retry-delay 2 -o "$ARCHIVE_PATH.part" "$SRBMINER_URL"
  elif command -v wget >/dev/null; then
    wget -O "$ARCHIVE_PATH.part" "$SRBMINER_URL"
  else
    echo "curl ou wget est requis" >&2
    exit 10
  fi
  mv "$ARCHIVE_PATH.part" "$ARCHIVE_PATH"
fi
echo "$SRBMINER_SHA256  $ARCHIVE_PATH" | sha256sum -c - >/dev/null || {
  rm -f "$ARCHIVE_PATH"
  echo "SHA-256 SRBMiner invalide" >&2
  exit 11
}
INSTALL_DIR="$ROOT_DIR/.local/srbminer-$SRBMINER_VERSION"
mkdir -p "$INSTALL_DIR"
tar -xzf "$ARCHIVE_PATH" -C "$INSTALL_DIR"
found="$(find "$INSTALL_DIR" -type f -name SRBMiner-MULTI -print -quit)"
[[ -n "$found" ]] || { echo "Binaire SRBMiner introuvable" >&2; exit 12; }
chmod 0755 "$found"
printf '%s\n' "$found" > "$PATH_MARKER"
printf '%s\n' "$SRBMINER_VERSION" > "$VERSION_MARKER"
echo "SRBMiner-MULTI $SRBMINER_VERSION installé."
