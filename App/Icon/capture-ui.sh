#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
PHASE="${1:-after}"
[[ "$PHASE" == before || "$PHASE" == after ]]
swift build
# Neutral fixture: no copyrighted film, mock tracks or fabricated playback state.
ffmpeg -hide_banner -loglevel error -f lavfi -i 'color=c=0x455568:s=960x540:d=30' \
    -c:v libx264 -pix_fmt yuv420p -an -y /tmp/buehne-icons-video.mp4
BIN="$(swift build --show-bin-path)"
swiftc -parse-as-library App/Icon/CaptureUI.swift -o "$BIN/buehne-icons-capture" \
    -I "$BIN" -Xcc -fmodule-map-file=.build/out/Intermediates.noindex/GeneratedModuleMaps/Cmpv.modulemap \
    "$BIN/BuehneCore.o" "$BIN/BuehneEngine.o" "$BIN/BuehneUI.o" "$BIN/Cmpv.o" \
    -L/opt/homebrew/opt/mpv/lib -lmpv -framework OpenGL -framework IOSurface -framework CoreVideo \
    -framework Metal -framework QuartzCore -framework CoreGraphics
QT_QPA_PLATFORM=offscreen "$BIN/buehne-icons-capture" "$PHASE"
