#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Cinema"
CONFIGURATION="${CONFIGURATION:-debug}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUNDLE_PATH="$DIST_DIR/$APP_NAME.app"
BUILD_DIR=""
EXECUTABLE_PATH=""
SPARKLE_FRAMEWORK_PATH=""
INFO_PLIST_PATH="$ROOT_DIR/Sources/Cinema/Resources/Info.plist"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
QUIET_LOG_PATH="${TMPDIR:-/tmp}/cinema-launch.log"

cd "$ROOT_DIR"

swift build -c "$CONFIGURATION"
BUILD_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
EXECUTABLE_PATH="$BUILD_DIR/$APP_NAME"
SPARKLE_FRAMEWORK_PATH="$BUILD_DIR/Sparkle.framework"

rm -rf "$BUNDLE_PATH"
mkdir -p "$BUNDLE_PATH/Contents/MacOS" "$BUNDLE_PATH/Contents/Frameworks" "$BUNDLE_PATH/Contents/Resources"
cp "$EXECUTABLE_PATH" "$BUNDLE_PATH/Contents/MacOS/$APP_NAME"
cp "$INFO_PLIST_PATH" "$BUNDLE_PATH/Contents/Info.plist"
cp "$ROOT_DIR/Sources/Cinema/Resources/AppIcon.icns" "$BUNDLE_PATH/Contents/Resources/AppIcon.icns"
ditto "$SPARKLE_FRAMEWORK_PATH" "$BUNDLE_PATH/Contents/Frameworks/Sparkle.framework"

if [[ "$CODE_SIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$BUNDLE_PATH"
else
  codesign --force --deep --options runtime --timestamp --sign "$CODE_SIGN_IDENTITY" "$BUNDLE_PATH"
fi

launch_quietly() {
  if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    pkill -x "$APP_NAME" || true
  fi

  (
    cd "$ROOT_DIR"
    OS_ACTIVITY_MODE=disable "$BUNDLE_PATH/Contents/MacOS/$APP_NAME" \
      >"$QUIET_LOG_PATH" 2>&1
  ) &
}

case "${1:-}" in
  --verify)
    launch_quietly
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME is running."
    ;;
  --logs)
    /usr/bin/open -n "$BUNDLE_PATH"
    /usr/bin/log stream --style compact --predicate "process == '$APP_NAME'"
    ;;
  --package-only)
    echo "Packaged $BUNDLE_PATH"
    ;;
  *)
    launch_quietly
    ;;
esac
