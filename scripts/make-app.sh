#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build
BIN="$(swift build --show-bin-path)/Buehne"
APP="$ROOT/build/Buehne.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Buehne"
cp "$ROOT/App/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/App/Icon/"{AppIcon,VideoDocument}.icns "$APP/Contents/Resources/"
for b in "$(dirname "$BIN")"/*.bundle; do cp -R "$b" "$APP/Contents/Resources/"; cp -R "$b" "$APP/"; done
chmod +x "$APP/Contents/MacOS/Buehne"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
echo "BUEHNE_APP=$APP"
