#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/wildrig-version.env"
CACHE_DIR="$ROOT_DIR/.cache"
BIN_DIR="$ROOT_DIR/.local/bin"
ARCHIVE_PATH="$CACHE_DIR/$WILDRIG_ARCHIVE"
VERSION_MARKER="$BIN_DIR/.wildrig-version"
mkdir -p "$CACHE_DIR" "$BIN_DIR"
if [[ -x "$BIN_DIR/wildrig" && -f "$VERSION_MARKER" && "$(<"$VERSION_MARKER")" == "$WILDRIG_VERSION" ]]; then
  exit 0
fi
command -v sha256sum >/dev/null || exit 10
command -v tar >/dev/null || exit 10
if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "Téléchargement de WildRig Multi $WILDRIG_VERSION..."
  if command -v curl >/dev/null; then
    curl -fL --retry 4 --retry-delay 2 -o "$ARCHIVE_PATH.part" "$WILDRIG_URL"
  elif command -v wget >/dev/null; then
    wget -O "$ARCHIVE_PATH.part" "$WILDRIG_URL"
  else
    echo "curl ou wget est requis" >&2
    exit 10
  fi
  mv "$ARCHIVE_PATH.part" "$ARCHIVE_PATH"
fi
echo "$WILDRIG_SHA256  $ARCHIVE_PATH" | sha256sum -c - >/dev/null || {
  rm -f "$ARCHIVE_PATH"
  echo "SHA-256 WildRig invalide" >&2
  exit 11
}
INSTALL_DIR="$ROOT_DIR/.local/wildrig-$WILDRIG_VERSION"
mkdir -p "$INSTALL_DIR"
tar -xzf "$ARCHIVE_PATH" -C "$INSTALL_DIR"
found="$(find "$INSTALL_DIR" -type f \( -name wildrig -o -name wildrig-multi \) -print -quit)"
[[ -n "$found" ]] || { echo "Binaire WildRig introuvable" >&2; exit 12; }
cp "$found" "$BIN_DIR/wildrig.new"
chmod 0755 "$BIN_DIR/wildrig.new"
mv -f "$BIN_DIR/wildrig.new" "$BIN_DIR/wildrig"
printf '%s\n' "$WILDRIG_VERSION" > "$VERSION_MARKER"
echo "WildRig Multi $WILDRIG_VERSION installé."
