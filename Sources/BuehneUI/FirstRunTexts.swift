import Foundation

/// Texts of the first-launch windows. The licence text itself (LICENSE, NOTICE) is legally binding in English only.
struct FirstRunPack {
    let language, shortcut, termsTitle, licenseTitle, readmeTitle, step, decline, accept, start: String
    let terms: [(String, String)]
    let licenseNote: String
    let readme: [(String, String)]
}

enum FirstRunTexts {
    static let languages: [(code: String, name: String)] = [
        ("en", "English"), ("de", "Deutsch"), ("fr", "Français"), ("it", "Italiano"), ("ru", "Русский"), ("es", "Español")]

    static func pack(_ code: String) -> FirstRunPack { packs[code] ?? packs["en"]! }

    static let packs: [String: FirstRunPack] = [
        "en": FirstRunPack(
            language: "Language", shortcut: "Place the BÜHNE icon on the desktop",
            termsTitle: "Terms of use", licenseTitle: "Licence", readmeTitle: "About BÜHNE",
            step: "Step", decline: "Decline", accept: "Accept", start: "Start",
            terms: [
                ("Free", "BÜHNE is free: no time limit, no ads, no paid version."),
                ("No data collection", "BÜHNE collects no data and sends none to anyone. Only your settings and the playback position of each video are kept, on your Mac."),
                ("Licence", "BÜHNE is licensed under the PolyForm Noncommercial License 1.0.0. The full text is in the next window."),
                ("mpv", "BÜHNE plays many formats through libmpv, which is installed separately and has its own licences (see the notice in the next window)."),
                ("No warranty", "The software is provided as it is, under the terms of the licence. By pressing Accept you agree to these terms.")],
            licenseNote: "The licence text is legally binding in English.",
            readme: [
                ("What it is", "A light, native video player for macOS with a Liquid Glass look. It is the companion of STRÖM, the torrent client: STRÖM downloads, BÜHNE plays."),
                ("What it does", "Plays MP4, MKV, AVI, HEVC and more with hardware decoding, subtitles and audio tracks. Floating window on top of everything, picture-in-picture, remembers where you stopped."),
                ("You need", "macOS 26 or later, Apple Silicon, and mpv from Homebrew (brew install mpv).")]),
        "de": FirstRunPack(
            language: "Sprache", shortcut: "BÜHNE-Symbol auf dem Schreibtisch ablegen",
            termsTitle: "Nutzungsbedingungen", licenseTitle: "Lizenz", readmeTitle: "Über BÜHNE",
            step: "Schritt", decline: "Ablehnen", accept: "Akzeptieren", start: "Los",
            terms: [
                ("Kostenlos", "BÜHNE ist kostenlos: ohne Zeitlimit, ohne Werbung, ohne kostenpflichtige Version."),
                ("Keine Datenerhebung", "BÜHNE erhebt keine Daten und sendet keine an Dritte. Nur Ihre Einstellungen und die Abspielposition jedes Videos werden auf Ihrem Mac gespeichert."),
                ("Lizenz", "BÜHNE steht unter der PolyForm Noncommercial License 1.0.0. Den vollständigen Text sehen Sie im nächsten Fenster."),
                ("mpv", "BÜHNE spielt viele Formate über libmpv ab. Diese Bibliothek wird separat installiert und hat eigene Lizenzen (siehe Hinweis im nächsten Fenster)."),
                ("Keine Gewähr", "Die Software wird wie sie ist bereitgestellt, gemäß den Lizenzbedingungen. Mit „Akzeptieren“ stimmen Sie diesen Bedingungen zu.")],
            licenseNote: "Rechtlich verbindlich ist der englische Lizenztext.",
            readme: [
                ("Was es ist", "Ein leichter, nativer Videoplayer für macOS im Liquid-Glass-Look. Der Begleiter von STRÖM, dem Torrent-Client: STRÖM lädt, BÜHNE spielt ab."),
                ("Was es kann", "Spielt MP4, MKV, AVI, HEVC und mehr mit Hardware-Dekodierung, Untertiteln und Tonspuren. Schwebendes Fenster über allem, Bild-in-Bild, merkt sich die Position."),
                ("Voraussetzungen", "macOS 26 oder neuer, Apple Silicon und mpv von Homebrew (brew install mpv).")]),
        "fr": FirstRunPack(
            language: "Langue", shortcut: "Placer l’icône BÜHNE sur le bureau",
            termsTitle: "Conditions d’utilisation", licenseTitle: "Licence", readmeTitle: "À propos de BÜHNE",
            step: "Étape", decline: "Refuser", accept: "Accepter", start: "Commencer",
            terms: [
                ("Gratuit", "BÜHNE est gratuit : sans limite de temps, sans publicité, sans version payante."),
                ("Aucune collecte de données", "BÜHNE ne collecte aucune donnée et n’en envoie à personne. Seuls vos réglages et la position de lecture de chaque vidéo sont conservés sur votre Mac."),
                ("Licence", "BÜHNE est sous licence PolyForm Noncommercial License 1.0.0. Le texte complet est dans la fenêtre suivante."),
                ("mpv", "BÜHNE lit de nombreux formats via libmpv, installée séparément et soumise à ses propres licences (voir l’avis dans la fenêtre suivante)."),
                ("Sans garantie", "Le logiciel est fourni tel quel, selon les termes de la licence. En appuyant sur Accepter, vous acceptez ces conditions.")],
            licenseNote: "Le texte de la licence fait foi en anglais.",
            readme: [
                ("De quoi s’agit-il", "Un lecteur vidéo léger et natif pour macOS, au style Liquid Glass. Le compagnon de STRÖM, le client torrent : STRÖM télécharge, BÜHNE lit."),
                ("Ce qu’il fait", "Lit MP4, MKV, AVI, HEVC et plus, avec décodage matériel, sous-titres et pistes audio. Fenêtre flottante, image dans l’image, reprise là où vous vous êtes arrêté."),
                ("Prérequis", "macOS 26 ou plus récent, Apple Silicon, et mpv via Homebrew (brew install mpv).")]),
        "it": FirstRunPack(
            language: "Lingua", shortcut: "Metti l’icona BÜHNE sulla scrivania",
            termsTitle: "Condizioni d’uso", licenseTitle: "Licenza", readmeTitle: "Informazioni su BÜHNE",
            step: "Passo", decline: "Rifiuta", accept: "Accetta", start: "Inizia",
            terms: [
                ("Gratuito", "BÜHNE è gratuito: senza limiti di tempo, senza pubblicità, senza versione a pagamento."),
                ("Nessuna raccolta di dati", "BÜHNE non raccoglie dati e non ne invia a nessuno. Solo le impostazioni e la posizione di riproduzione di ogni video restano sul tuo Mac."),
                ("Licenza", "BÜHNE è concesso con la PolyForm Noncommercial License 1.0.0. Il testo completo è nella finestra successiva."),
                ("mpv", "BÜHNE riproduce molti formati tramite libmpv, installata separatamente e con licenze proprie (vedi l’avviso nella finestra successiva)."),
                ("Nessuna garanzia", "Il software è fornito così com’è, secondo i termini della licenza. Premendo Accetta accetti queste condizioni.")],
            licenseNote: "Il testo della licenza è vincolante in inglese.",
            readme: [
                ("Che cos’è", "Un lettore video leggero e nativo per macOS, in stile Liquid Glass. Il compagno di STRÖM, il client torrent: STRÖM scarica, BÜHNE riproduce."),
                ("Cosa fa", "Riproduce MP4, MKV, AVI, HEVC e altro con decodifica hardware, sottotitoli e tracce audio. Finestra flottante, picture-in-picture, ricorda dove ti sei fermato."),
                ("Requisiti", "macOS 26 o successivo, Apple Silicon e mpv da Homebrew (brew install mpv).")]),
        "ru": FirstRunPack(
            language: "Язык", shortcut: "Поместить значок BÜHNE на рабочий стол",
            termsTitle: "Условия использования", licenseTitle: "Лицензия", readmeTitle: "О программе BÜHNE",
            step: "Шаг", decline: "Отказаться", accept: "Принять", start: "Начать",
            terms: [
                ("Бесплатно", "BÜHNE бесплатен: без ограничения по времени, без рекламы, без платной версии."),
                ("Без сбора данных", "BÜHNE не собирает данные и никому их не отправляет. На вашем Mac хранятся только настройки и место, где вы остановили каждое видео."),
                ("Лицензия", "BÜHNE распространяется по лицензии PolyForm Noncommercial License 1.0.0. Полный текст — в следующем окне."),
                ("mpv", "BÜHNE воспроизводит многие форматы через libmpv. Она устанавливается отдельно и имеет собственные лицензии (см. уведомление в следующем окне)."),
                ("Без гарантий", "Программа предоставляется «как есть» на условиях лицензии. Нажимая «Принять», вы соглашаетесь с этими условиями.")],
            licenseNote: "Юридическую силу имеет английский текст лицензии.",
            readme: [
                ("Что это", "Лёгкий нативный видеоплеер для macOS в стиле Liquid Glass. Спутник STRÖM, загрузчика торрентов: STRÖM скачивает, BÜHNE показывает."),
                ("Что умеет", "Играет MP4, MKV, AVI, HEVC и другие форматы с аппаратным декодированием, субтитрами и звуковыми дорожками. Плавающее окно поверх всех, «картинка в картинке», помнит, где вы остановились."),
                ("Что нужно", "macOS 26 или новее, Apple Silicon и mpv из Homebrew (brew install mpv).")]),
        "es": FirstRunPack(
            language: "Idioma", shortcut: "Colocar el icono de BÜHNE en el escritorio",
            termsTitle: "Condiciones de uso", licenseTitle: "Licencia", readmeTitle: "Acerca de BÜHNE",
            step: "Paso", decline: "Rechazar", accept: "Aceptar", start: "Empezar",
            terms: [
                ("Gratis", "BÜHNE es gratis: sin límite de tiempo, sin anuncios, sin versión de pago."),
                ("Sin recopilación de datos", "BÜHNE no recopila datos ni los envía a nadie. Solo se guardan en tu Mac los ajustes y la posición de reproducción de cada vídeo."),
                ("Licencia", "BÜHNE se distribuye bajo la PolyForm Noncommercial License 1.0.0. El texto completo está en la ventana siguiente."),
                ("mpv", "BÜHNE reproduce muchos formatos mediante libmpv, que se instala aparte y tiene sus propias licencias (consulta el aviso en la ventana siguiente)."),
                ("Sin garantía", "El software se ofrece tal cual, según los términos de la licencia. Al pulsar Aceptar aceptas estas condiciones.")],
            licenseNote: "El texto de la licencia es vinculante en inglés.",
            readme: [
                ("Qué es", "Un reproductor de vídeo ligero y nativo para macOS con aspecto Liquid Glass. El compañero de STRÖM, el cliente torrent: STRÖM descarga, BÜHNE reproduce."),
                ("Qué hace", "Reproduce MP4, MKV, AVI, HEVC y más con decodificación por hardware, subtítulos y pistas de audio. Ventana flotante, imagen en imagen, recuerda dónde lo dejaste."),
                ("Necesitas", "macOS 26 o posterior, Apple Silicon y mpv de Homebrew (brew install mpv).")]),
    ]
}
