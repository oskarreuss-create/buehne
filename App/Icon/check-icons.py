#!/usr/bin/env python3
"""Asset/registration/package gates. Standard library + native iconutil only."""
import argparse
import pathlib
import plistlib
import re
import struct
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--bundle', action='store_true')
p.add_argument('--empty-state', action='store_true')
args = p.parse_args()


def validate_plist(path):
    info = plistlib.loads(path.read_bytes())
    assert info['CFBundleIconFile'] == 'AppIcon.icns', 'app icon not registered'
    types = info['CFBundleDocumentTypes']
    assert all(t['CFBundleTypeIconFile'] == 'VideoDocument.icns' for t in types)
    utis = {u for t in types for u in t['LSItemContentTypes']}
    assert {'org.matroska.mkv', 'public.mpeg-4', 'com.apple.quicktime-movie', 'public.avi'} <= utis


def png_dimensions(path):
    b = path.read_bytes()
    assert b[:8] == b'\x89PNG\r\n\x1a\n', f'not PNG: {path}'
    return struct.unpack('>II', b[16:24])


validate_plist(ROOT / 'App/Info.plist')
entries = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
for name in ['AppIcon', 'VideoDocument']:
    icon = ROOT / f'App/Icon/{name}.icns'
    data = icon.read_bytes()
    assert data[:4] == b'icns' and struct.unpack('>I', data[4:8])[0] == len(data)
    with tempfile.TemporaryDirectory(prefix='buehne-icon-check-') as work:
        output = pathlib.Path(work) / f'{name}.iconset'
        subprocess.run(['iconutil', '-c', 'iconset', str(icon), '-o', str(output)], check=True)
        for points, scale in entries:
            file = output / f'icon_{points}x{points}{"@2x" if scale == 2 else ""}.png'
            assert png_dimensions(file) == (points * scale, points * scale), f'wrong/missing size: {file}'
    print(f'ICON_SIZES_OK {name} representations=10 range=16..1024')

for name in ['BuehneMark-light', 'BuehneMark-dark', 'BuehneWordmark-light', 'BuehneWordmark-dark']:
    data = (ROOT / f'Sources/BuehneUI/Resources/{name}.pdf').read_bytes()
    assert data.startswith(b'%PDF-') and b'/Font' not in data, f'not font-free vector: {name}'
print('ICON_REGISTRATION_OK app=1 documentTypes=1 mkv/mp4/mov/avi=1 vectorPDFs=4 embeddedFonts=0')

# The brief permits exactly this one additional packaging line.
line = 'cp "$ROOT/App/Icon/"{AppIcon,VideoDocument}.icns "$APP/Contents/Resources/"'
script = (ROOT / 'scripts/make-app.sh').read_text()
assert script.splitlines().count(line) == 1
print(f'ICON_COPY_LINE={script.splitlines().index(line) + 1}: {line}')

if args.bundle:
    app = ROOT / 'build/Buehne.app/Contents'
    validate_plist(app / 'Info.plist')
    for name in ['AppIcon.icns', 'VideoDocument.icns']:
        assert (app / f'Resources/{name}').read_bytes() == (ROOT / f'App/Icon/{name}').read_bytes()
    resource_pdfs = list(app.glob('**/BuehneWordmark-light.pdf'))
    assert resource_pdfs, 'wordmark resources not packaged'
    print('ICON_BUNDLE_OK icns=2 wordmarkResource=1')

if args.empty_state:
    source = (ROOT / 'Sources/BuehneUI/PlayerRootView.swift').read_text()
    assert re.search(r'^\s+BuehneWordmark\(', source, re.M), 'owner integration pending: emptyState still uses old BuehneMark + Text'
    print('ICON_EMPTY_STATE_WIRING_OK')
