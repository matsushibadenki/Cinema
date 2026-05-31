#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Cinema"
BUNDLE_ID="com.littlebuddha.cinema"
CONFIGURATION="debug"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
BUNDLE_PATH="$DIST_DIR/$APP_NAME.app"
EXECUTABLE_PATH="$ROOT_DIR/.build/$CONFIGURATION/$APP_NAME"

cd "$ROOT_DIR"

if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  pkill -x "$APP_NAME" || true
fi

swift build

rm -rf "$BUNDLE_PATH"
mkdir -p "$BUNDLE_PATH/Contents/MacOS"
cp "$EXECUTABLE_PATH" "$BUNDLE_PATH/Contents/MacOS/$APP_NAME"

cat > "$BUNDLE_PATH/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>ja</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Cinema Storyboard</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSHandlerRank</key>
      <string>Owner</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>com.littlebuddha.cinema.storyboard</string>
      </array>
    </dict>
  </array>
  <key>UTExportedTypeDeclarations</key>
  <array>
    <dict>
      <key>UTTypeIdentifier</key>
      <string>com.littlebuddha.cinema.storyboard</string>
      <key>UTTypeDescription</key>
      <string>Cinema Storyboard Package</string>
      <key>UTTypeConformsTo</key>
      <array>
        <string>com.apple.package</string>
      </array>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key>
        <array>
          <string>cinemaboard</string>
        </array>
      </dict>
    </dict>
  </array>
</dict>
</plist>
PLIST

case "${1:-}" in
  --verify)
    /usr/bin/open -n "$BUNDLE_PATH"
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME is running."
    ;;
  --logs)
    /usr/bin/open -n "$BUNDLE_PATH"
    /usr/bin/log stream --style compact --predicate "process == '$APP_NAME'"
    ;;
  *)
    /usr/bin/open -n "$BUNDLE_PATH"
    ;;
esac
