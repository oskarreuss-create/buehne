#!/bin/bash
# Native macOS icon build. Keep the work dir only for pixel review.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
WORK="$(mktemp -d /tmp/buehne-icons.XXXXXX)"
trap 'if [[ "${KEEP_ICON_WORK:-0}" != 1 ]]; then rm -rf "$WORK"; fi' EXIT
swiftc App/Icon/main.swift Sources/BuehneUI/Icons.swift -o "$WORK/render-icons"
QT_QPA_PLATFORM=offscreen "$WORK/render-icons" "$ROOT" "$WORK"
iconutil -c icns "$WORK/AppIcon.iconset" -o App/Icon/AppIcon.icns
iconutil -c icns "$WORK/VideoDocument.iconset" -o App/Icon/VideoDocument.icns
python3 App/Icon/check-icons.py
printf 'ICON_BUILD_OK app=App/Icon/AppIcon.icns document=App/Icon/VideoDocument.icns\n'
if [[ "${KEEP_ICON_WORK:-0}" == 1 ]]; then printf 'ICON_PREVIEWS=%s\n' "$WORK"; fi
