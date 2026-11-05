# BÜHNE

[English](README.md) · [Deutsch](README.de.md) · [Русский](README.ru.md)

**Ein leichter, schöner, nativer Videoplayer für macOS — der Begleiter von [STRÖM](https://github.com/oskarreuss-create/strom).**

> STRÖM lädt herunter, BÜHNE spielt ab. Die beiden Apps sind als Paar gebaut und teilen sich ein Aussehen. BÜHNE ist kostenlos, ohne Zeitlimit und ohne kostenpflichtige „Plus“-Version.

## Funktionen
- Spielt MP4, M4V und MOV nativ (AVFoundation); MKV, AVI und alles andere über libmpv. Hardware-Dekodierung.
- Schwebende Bedienleiste in einer Zeile: auf sechs Positionen ziehbar; sie legt Teile ab, wenn das Fenster schrumpft, bis auf drei Tasten.
- Die Wiedergabeposition wird pro Datei gemerkt; beim erneuten Öffnen geht es dort weiter, wo Sie aufgehört haben.
- Wiedergabeliste aus einem Ordner (nur Videodateien), optional in der Bedienleiste.
- Tempo 0,5–3×, Audio- und Untertitelspuren, Seitenverhältnis, Zuschnitt, Drehung, Erkennung schwarzer Balken, Bild-in-Bild.
- Liquid-Glass-Look, hell / dunkel / automatisch, einstellbare Glas-Deckkraft.
- Oberfläche in 6 Sprachen: Englisch (Standard), Deutsch, Französisch, Italienisch, Russisch, Spanisch.
- Tastatur: Leertaste, ← → 10 s springen, ↑ ↓ Lautstärke, F Vollbild, M Stumm, [ ] Tempo, A / S Audio- / Untertitelspur, ⌘O öffnen, ⌘, Einstellungen.

## Zusammen mit STRÖM
STRÖM ist ein leichter BitTorrent-Client für macOS mit der Möglichkeit, das Hochladen abzuschalten. Laden Sie ihn von [der Releases-Seite](https://github.com/oskarreuss-create/strom/releases) herunter — der Link steht auch in den Einstellungen von BÜHNE.

Schauen während des Herunterladens: Drücken Sie in STRÖM auf Play, und BÜHNE öffnet das Video, während es ankommt. Über den bereits heruntergeladenen Teil hinaus kann man nicht springen.

## Voraussetzungen
macOS 26 oder neuer, Apple Silicon und [mpv](https://mpv.io) von Homebrew:

```bash
brew install mpv
```

## Installation
1. Laden Sie `Buehne-<Version>.zip` von den [Releases](../../releases) herunter und verschieben Sie BÜHNE in „Programme“.
2. Die App ist nicht mit einer Apple Developer ID signiert und nicht notarisiert, deshalb zeigt macOS beim ersten Start eine Warnung. Öffnen Sie *Systemeinstellungen → Datenschutz & Sicherheit*, suchen Sie BÜHNE und klicken Sie auf **Trotzdem öffnen**. Oder führen Sie aus:

```bash
xattr -dr com.apple.quarantine /Applications/Buehne.app
```

## Aus dem Quellcode bauen
Sie brauchen Xcode (Swift 6.2) und `brew install mpv`.

```bash
swift test
./scripts/make-app.sh      # erzeugt build/Buehne.app (ad-hoc signiert, nur lokal)
```

Datei von der Kommandozeile öffnen: `Buehne /pfad/zur/datei.mkv` oder `buehne://open?path=...`. Details: [BUEHNE_CONTRACT.md](BUEHNE_CONTRACT.md).

## Datenschutz
Kein Tracking, keine Werbung, keine Cookies, keine Konten, keine eigenen Netzwerkaufrufe (außer dem Streamen einer http/https-Adresse, die Sie abspielen lassen). Wiedergabepositionen und Einstellungen bleiben auf Ihrem Mac. Die einzige Verbindung ins Internet ist die Schaltfläche „STRÖM herunterladen“ in den Einstellungen, die Ihren Browser öffnet.

## Lizenz
Der Quellcode steht unter der [PolyForm Noncommercial License 1.0.0](LICENSE): Sie dürfen ihn lesen, ändern und für persönliche und nicht kommerzielle Zwecke nutzen. Verkauf, kostenpflichtige Forks oder kommerzielle Nutzung ohne Erlaubnis sind nicht gestattet. Siehe [NOTICE](NOTICE). libmpv und FFmpeg sind nicht Teil dieses Repositorys und behalten ihre eigenen Lizenzen. Andere Bedingungen: info@oskarreus.ch.

## Support
Fragen und Fehler: [Issues](../../issues) oder info@oskarreus.ch.
