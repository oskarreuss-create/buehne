# BÜHNE launch contract

STRÖM is not modified by this repository. This is the call surface BÜHNE prepares.

- Display name: `BÜHNE`
- Executable: `Buehne`
- Bundle id, once wrapped with `App/Info.plist`: `ch.oskarreus.buehne`
- URL scheme: `buehne://open?path=` where `path` is percent-encoded. A file path or an `http`/`https` URL is accepted. A missing `path` is ignored.

## How to open a file

| Call | What BÜHNE does now |
|---|---|
| `Buehne /path/to/file.mp4` | Opens that file in the player window. |
| `buehne://open?path=/path/to/file.mp4` | Same, when the process receives the URL (`onOpenURL` or as an argument). |
| `open -a BÜHNE file.mp4` | Requires the `.app` bundle. The plist declares the scheme and movie UTIs. The raw `swift build` binary is not registered with Launch Services. |

One file at a time. There is no playlist.

## Position

Playback position is stored per canonical file path (or absolute URL) under UserDefaults prefix `buehne.position.`.

```
Buehne --print-position /path/to/file.mp4
```

Prints seconds and exits 0, or `none` and exits 2 when nothing was saved. A file that is still downloading is out of scope; the same `path` argument can point at a partial file later.

## Errors

- File missing: the window shows the path. No invented duration.
- Container other than `.mp4`, `.m4v`, `.mov`: routed to libmpv. libmpv is not linked in this build, so open fails with the probe text instead of playing.
- AVFoundation open failure: the window shows the system error.

## Engine choice

`EngineRouter` is the only chooser. Native containers go to AVFoundation. Everything else goes to libmpv. Hardware decode has no switch.

## Not in this build

Quick Look, app icon asset, letterbox measurement, Dolby Vision tone-map, a second rendered subtitle, brightness/contrast/saturation/gamma on the frame, and a registered `.app` bundle. Reverse hold seeks in 0.2s steps (2×) because AVFoundation does not play backwards reliably.

## Controls

Clicks are classified before any pause. A bar, slider, settings card, chrome, or window-activation click does not toggle playback. A video click toggles once. Two-finger scroll uses `isDirectionInvertedFromDevice` so physical up raises volume, clamped to 0...1, and shows a volume HUD.

| Control | Expected | Status |
|---|---|---|
| Space | Pause / play | Wired. One command. |
| Left / right | Seek 10 s | Wired. |
| Up / down | Volume | Wired. HUD shows the percent. |
| f | Full screen | Wired. Not in the original short list; added. |
| m | Mute | Wired. Restores the previous level. |
| Escape | Close settings, else leave full screen | Wired. |
| [ / ] | Speed down / up, 0.5–3× | Wired. |
| a / s | Next audio / subtitle track | Wired to aid/sid from track-list. sid=no clears subtitles. |
| Cmd-O | Open file | Wired. |
| Cmd-, | Settings card | Wired. |
| Video click | Pause once | Wired. Activation click ignored. |
| Double-click video | Full screen, no extra pause | Wired. |
| Bar, slider, settings, chrome | Do not pause | Wired. Overlay frames win over the video. |
| Hold left / right on video | Rewind or 2× after 0.3 s | Wired. Not on the bar or settings. |
| Two-finger up / down | Volume, HUD | Wired. Physical up raises. |
| Two-finger left / right | Seek 10 s | Wired. |
| Three-finger | System gesture, unused | Not bound. |
| Play, seek, PiP, floating, settings buttons | Their own action, no pause | Wired. |
| Volume icon | Opens the volume slider | Wired. |
| Theme, aspect, rotation, audio, subtitle menus | Dropdowns | Wired. |
| Glass, fill, lock, bars toggles | Toggles | Wired. |
| Speed, opacity sliders | 0.5–3× and 0–100% | Wired. |
| Brightness, contrast, saturation, gamma | Sliders | Stored only. Not applied to the frame. |
