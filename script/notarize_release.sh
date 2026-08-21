#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Cinema"
VERSION="${1:?Usage: script/notarize_release.sh <version>}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_PATH="$ROOT_DIR/dist/$APP_NAME.app"
RELEASES_DIR="$ROOT_DIR/releases"
ARCHIVE_PATH="$RELEASES_DIR/$APP_NAME-$VERSION.zip"
NOTARY_PROFILE="${NOTARY_PROFILE:-Cinema Notarization}"

if [[ -z "${CODE_SIGN_IDENTITY:-}" ]]; then
  echo "Set CODE_SIGN_IDENTITY to a Developer ID Application identity." >&2
  exit 1
fi

cd "$ROOT_DIR"
CONFIGURATION=release CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" \
  script/build_and_run.sh --package-only

mkdir -p "$RELEASES_DIR"
rm -f "$ARCHIVE_PATH"
ditto -c -k --sequesterRsrc --keepParent "$BUNDLE_PATH" "$ARCHIVE_PATH"

xcrun notarytool submit "$ARCHIVE_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$BUNDLE_PATH"
xcrun stapler validate "$BUNDLE_PATH"

rm -f "$ARCHIVE_PATH"
ditto -c -k --sequesterRsrc --keepParent "$BUNDLE_PATH" "$ARCHIVE_PATH"

echo "Notarized archive: $ARCHIVE_PATH"
