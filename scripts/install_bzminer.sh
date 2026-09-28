#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/scripts/miner-version.env"

CACHE_DIR="$ROOT_DIR/.cache"
INSTALL_DIR="$ROOT_DIR/.local/$BZMINER_VERSION"
BIN_DIR="$ROOT_DIR/.local/bin"
ARCHIVE_PATH="$CACHE_DIR/$BZMINER_ARCHIVE"

mkdir -p "$CACHE_DIR" "$INSTALL_DIR" "$BIN_DIR"

VERSION_MARKER="$BIN_DIR/.bzminer-version"
if [[ -x "$BIN_DIR/bzminer" && -f "$VERSION_MARKER" && "$(<"$VERSION_MARKER")" == "$BZMINER_VERSION" ]]; then
  echo "BzMiner $BZMINER_VERSION déjà installé."
  exit 0
fi

command -v sha256sum >/dev/null 2>&1 || { echo "Erreur : sha256sum est requis." >&2; exit 10; }
command -v tar >/dev/null 2>&1 || { echo "Erreur : tar est requis." >&2; exit 10; }

if [[ ! -f "$ARCHIVE_PATH" ]]; then
  echo "Téléchargement de BzMiner $BZMINER_VERSION depuis GitHub..."
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 4 --retry-delay 2 -o "$ARCHIVE_PATH.part" "$BZMINER_URL"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$ARCHIVE_PATH.part" "$BZMINER_URL"
  else
    echo "Erreur : curl ou wget est requis." >&2
    exit 10
  fi
  mv "$ARCHIVE_PATH.part" "$ARCHIVE_PATH"
fi

echo "$BZMINER_SHA256  $ARCHIVE_PATH" | sha256sum -c - >/dev/null || {
  rm -f "$ARCHIVE_PATH"
  echo "Erreur : SHA-256 du mineur invalide. Archive supprimée." >&2
  exit 11
}

echo "SHA-256 BzMiner vérifié."
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
tar -xzf "$ARCHIVE_PATH" -C "$INSTALL_DIR"

found="$(find "$INSTALL_DIR" -type f -name bzminer -print -quit)"
[[ -n "$found" ]] || { echo "Erreur : binaire bzminer introuvable après extraction." >&2; exit 12; }

cp "$found" "$BIN_DIR/bzminer.new"
chmod 0755 "$BIN_DIR/bzminer.new"
mv -f "$BIN_DIR/bzminer.new" "$BIN_DIR/bzminer"
printf '%s\n' "$BZMINER_VERSION" > "$VERSION_MARKER"
echo "BzMiner $BZMINER_VERSION installé : $BIN_DIR/bzminer"
