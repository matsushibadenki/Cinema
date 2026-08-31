#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVES_DIR="${1:-$ROOT_DIR/releases}"
APPCAST_PATH="$ROOT_DIR/appcast.xml"
GENERATE_APPCAST="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/generate_appcast"
DOWNLOAD_URL_PREFIX="${DOWNLOAD_URL_PREFIX:-}"

if [[ ! -x "$GENERATE_APPCAST" ]]; then
  echo "Sparkle tools are not available. Run: swift build -c release" >&2
  exit 1
fi

if [[ ! -d "$ARCHIVES_DIR" ]] || ! compgen -G "$ARCHIVES_DIR/*.zip" >/dev/null; then
  echo "Place signed Cinema release .zip archives in: $ARCHIVES_DIR" >&2
  exit 1
fi

if [[ -z "$DOWNLOAD_URL_PREFIX" ]]; then
  echo "Set DOWNLOAD_URL_PREFIX to the GitHub Release download URL, for example:" >&2
  echo "https://github.com/matsushibadenki/Cinema/releases/download/v0.1.1/" >&2
  exit 1
fi

mkdir -p "$ARCHIVES_DIR"
cp "$APPCAST_PATH" "$ARCHIVES_DIR/appcast.xml"
"$GENERATE_APPCAST" \
  --download-url-prefix "${DOWNLOAD_URL_PREFIX%/}/" \
  --link "https://github.com/matsushibadenki/Cinema/releases" \
  -o "$ARCHIVES_DIR/appcast.xml" \
  "$ARCHIVES_DIR"

# generate_appcast applies the current prefix to every archive in the folder.
# Restore each full ZIP URL to the GitHub tag matching that archive's version.
perl -0pi -e 's{releases/download/v[^/]+/(Cinema-([0-9.]+)\.zip)}{releases/download/v$2/$1}g' \
  "$ARCHIVES_DIR/appcast.xml"
cp "$ARCHIVES_DIR/appcast.xml" "$APPCAST_PATH"

echo "Updated $APPCAST_PATH"
