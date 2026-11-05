#!/bin/bash
# Usage: scripts/package.sh /abs/path/build/Buehne.app /abs/NEW/output/dir
# Packages an ad-hoc signed build (no Developer ID) as .dmg + .zip with SHA-256 sums.
# The .dmg opens as a classic installer window: BÜHNE on the left, Applications on the right, an arrow between them.
set -euo pipefail
src="${1:?path to built .app}"; outdir="${2:?absolute NEW output dir}"
case "$src$outdir" in /*/*) ;; *) echo 'Absolute paths required' >&2; exit 2;; esac
[ -d "$src" ] || { echo "No such app: $src" >&2; exit 2; }
if [ -e "$outdir" ] && [ -n "$(ls -A "$outdir")" ]; then echo 'Output dir must be new or empty' >&2; exit 3; fi
mkdir -p "$outdir"
here="$(cd "$(dirname "$0")" && pwd)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$src/Contents/Info.plist")"
stage="$(mktemp -d "${TMPDIR:-/tmp}/buehne-pkg.XXXXXX")"
ditto --noextattr "$src" "$stage/BÜHNE.app"; xattr -cr "$stage/BÜHNE.app"
codesign --force --deep --sign - "$stage/BÜHNE.app" >/dev/null  # ad-hoc, no Developer ID
codesign --verify --deep --strict "$stage/BÜHNE.app"
ln -s /Applications "$stage/Applications"
mkdir "$stage/.background"
swift "$here/make_dmg_background.swift" "$stage/.background/background.png"
rwdir="$(mktemp -d "${TMPDIR:-/tmp}/buehne-rw.XXXXXX")"; rw="$rwdir/rw.dmg"
hdiutil create -volname "BÜHNE" -srcfolder "$stage" -ov -format UDRW "$rw" >/dev/null
mount_out="$(hdiutil attach "$rw" -readwrite -noverify -noautoopen)"
disk="$(printf '%s\n' "$mount_out" | grep -o '/dev/disk[0-9]*' | head -1)"
osascript <<OSA >/dev/null
tell application "Finder"
  tell disk "BÜHNE"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 540}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set text size of opts to 13
    set background picture of opts to file ".background:background.png"
    set position of item "BÜHNE.app" of container window to {165, 220}
    set position of item "Applications" of container window to {495, 220}
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
OSA
sync
hdiutil detach "$disk" >/dev/null
hdiutil convert "$rw" -format UDZO -o "$outdir/Buehne-$version.dmg" >/dev/null
ditto -c -k --keepParent --noextattr "$stage/BÜHNE.app" "$outdir/Buehne-$version.zip"
( cd "$outdir" && shasum -a 256 Buehne-"$version".dmg Buehne-"$version".zip | tee SHA256SUMS.txt )
echo "Release files in: $outdir"
