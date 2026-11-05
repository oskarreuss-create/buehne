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
cp "$ROOT/App/Icon/"{AppIcon,VideoDocument,BUEHNE-icon-glass}.icns "$APP/Contents/Resources/"
for b in "$(dirname "$BIN")"/*.bundle; do cp -R "$b" "$APP/Contents/Resources/"; done
chmod +x "$APP/Contents/MacOS/Buehne"
# A stable signing identity keeps macOS privacy grants across rebuilds; ad-hoc changes with every build.
# The identity lives in its own keychain (see scripts/setup-signing.sh). Falls back to ad-hoc.
xattr -cr "$APP" 2>/dev/null || true
KC="$HOME/Library/Keychains/buehne-signing.keychain-db"
PF="$HOME/Library/Keychains/.buehne-signing-pass"
IDENTITY="BUEHNE Local Signing"
if [ -f "$KC" ] && [ -f "$PF" ]; then
  security unlock-keychain -p "$(cat "$PF")" "$KC"
  codesign --force --deep --keychain "$KC" --sign "$IDENTITY" "$APP" && echo "SIGNED_WITH=$IDENTITY"
else
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
  echo "SIGNED_WITH=ad-hoc (run scripts/setup-signing.sh once for a stable identity)"
fi
echo "BUEHNE_APP=$APP"
