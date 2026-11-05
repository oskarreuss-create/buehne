# BÜHNE icon sources and visual receipts

## Build and verify

From the checkout root, on macOS with the Xcode command-line tools:

```sh
bash App/Icon/make-icon.sh
swift build
swift test
bash scripts/make-app.sh
python3 App/Icon/check-icons.py --bundle
bash App/Icon/capture-ui.sh after
```

`make-icon.sh` compiles `main.swift` and the actual UI `Icons.swift` with native Swift/AppKit/CoreGraphics/CoreText, then calls Apple's `iconutil`. There are no additional dependencies. It writes:

- `AppIcon.icns` — charcoal rounded macOS tile, raised rim, swept black player, white play triangle and Swiss-red ribbon/cross.
- `VideoDocument.icns` — folded document, filmstrip badge, supplied scene crop and lower BÜHNE band. This is a **static type icon**, not a per-file thumbnail or Quick Look extension.
- Four vector PDFs in `Sources/BuehneUI/Resources`, with light/dark standalone marks and horizontal wordmarks. The Helvetica Bold-style lettering and circular umlauts are paths; no font is embedded.
- Four reference comparison PNGs: `reference/buehne-icons-{app,file,wordmark,glyphs}.png`.

Both ICNS files contain all ten macOS representations: 16, 32, 128, 256 and 512 points, each at 1× and 2× (16–1024 pixels). Each is rendered directly from geometry, not enlarged from a small raster. The document scene is a crop of the **operator-supplied reference 12**; it excludes its movie title and MP4 label. The generic VIDEO badge does not invent the opened file's format or title. Public-distribution rights for that supplied artwork are not established here.

`KEEP_ICON_WORK=1 bash App/Icon/make-icon.sh` retains and prints a temporary directory containing the twenty PNG representations for pixel review. Otherwise temporary build products are removed. PDF metadata may vary between builds; the sources and rendered geometry are reproducible.

`check-icons.py` decodes both ICNS files back into iconsets and checks every representation, dimensions, app/document Info.plist registration (including MKV), font-free PDFs and the packaging copy line. With `--bundle`, it also checks the generated app's plist, exact ICNS bytes and wordmark resources.

The only change to `scripts/make-app.sh` is **line 12**:

```sh
cp "$ROOT/App/Icon/"{AppIcon,VideoDocument}.icns "$APP/Contents/Resources/"
```

## UI ownership and remaining integration

`Glass.swift`, `PlayerRootView.swift`, `WindowChrome.swift` and `Settings.swift` are owned by the concurrent Grok seat and are untouched. Only icon call sites are changed in ControlBar and SettingsCard. Engine calls, seek gestures, button frames and accessibility action labels are retained.

The reusable `BuehneWordmark(width: 280)` in `Branding.swift` is ready and tested, **but is not yet used by the empty state**: that call site is in the protected PlayerRootView. The owner should replace the existing `BuehneMark()` plus `Text(OpenContract.displayName)`/font/tracking block inside `emptyState` with:

```swift
BuehneWordmark(width: 280)
```

The lockup already includes the play mark; do not retain the separate old mark beside it. `BuehneBrandMark(width:)` is available when the standalone mark is needed. Both views load standalone PDF resources explicitly, not via asset-catalog name lookup, and adapt to the native color scheme.

Run the explicit integration gate afterward:

```sh
python3 App/Icon/check-icons.py --empty-state
```

It intentionally fails until the owner makes that integration. This is an ownership handoff, not an engine or framework defect.

## Pixel review

Read `reference/buehne-icons-app.png`, `-file.png`, `-wordmark.png`, and `-glyphs.png`: reference and new artwork are juxtaposed. The glyph sheet also shows the old SF choices and new black/white template paths. It includes reference 16's numbered subtitle labels. Redacted/unseen states are labeled as such; their exact silhouettes cannot be recovered from the references.

Before UI receipts were captured from merged baseline **e4181639a19d537de6ba5b22075c614b7692596c**, before changing call sites. The after receipts use the current real PlayerRootView, not a recreated toolbar. `capture-ui.sh after` writes `buehne-icons-after-{player,settings}.png` and `buehne-icons-wordmark-view.png` (the standalone wordmark view in both themes, **not** an integrated empty state). It never overwrites the baseline images unless explicitly called with `before`.

The capture window is constrained entirely to (-32000,-32000), alpha 1, without activation; frame assertions prevent operator-visible placement. A neutral silent video fixture supplies real playback state. AppKit caching omits hardware video, so its actual decoded first frame is placed underneath the unchanged hosting hierarchy. These receipts show actual glyph rasterization/layout, not compositor refraction or Finder icon-cache behavior.

The first review found a reversed brush orientation, lettering-outline drift and a document seam; those were corrected in one batch. Native raster tests additionally caught subpixel-soft audio at 16pt/1× and blank PDF name lookup; whole-pixel-aligned bars and explicit NSImage PDF loading corrected them without weakening assertions. Independent visual acceptance, actual Finder/Dock presentation, Quick Look and VoiceOver remain unverified.

The final comparison still shows a narrow extra red/white scene edge above the document band's right side, and the custom brush/PiP silhouettes are not pixel-identical to the supplied glyphs. These are remaining visual-fidelity tails, not claimed as accepted. The SF comparison column preserves each symbol's native aspect ratio; the full before/after hosting captures remain the actual UI baseline.

The stronger pre-order, all-display guard caught AppKit centering an offscreen-requested window during initialization: `(480,448)` despite the requested negative origin. The harness now explicitly forces `(-32000,-32000)` **before attaching or ordering**, asserts `isVisible == false`, then checks display nonintersection both before ordering and at capture. Final runs passed. Earlier captures had only a post-layout negative-coordinate assertion; transient initial-order visibility of those earlier runs is unverified.
