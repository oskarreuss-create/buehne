import SwiftUI
import Testing
import BuehneUI

@Test func catalogUsesStromVocabulary() {
    #expect(L10n.text(.settings, language: "de") == "Einstellungen")
    #expect(L10n.text(.done, language: "fr") == "Terminé")
    #expect(L10n.text(.theme, language: "es") == "Apariencia")
    #expect(L10n.text(.speed, language: "ru") == "Скорость")
    #expect(L10n.text(.opacity, language: "ru") == "Прозрачность")
    #expect(L10n.text(.light, language: "ru") == "Дневная")
    #expect(L10n.text(.settings, language: "en") == "Settings")
    #expect(L10n.text(.settings, language: "en") == "Settings")
    #expect(L10n.resolve("auto") == "en")
    #expect(L10n.resolve("") == "en")
    #expect(L10n.resolve("ru") == "ru")
    #expect(L10n.menuOrder.first == "en")
    #expect(L10n.text(.language, language: "de") == "Sprache")
    #expect(L10n.text(.language, language: "ru") == "Язык")
}

@Test func surfacesFollowStromGrayscale() {
    #expect(BuehneTheme.sidebarWhite(isLight: true, activity: .active) == 0.955)
    #expect(BuehneTheme.sidebarWhite(isLight: true, activity: .inactive) == 0.90)
    #expect(BuehneTheme.sidebarWhite(isLight: false, activity: .active) == 0.10)
    #expect(BuehneTheme.sidebarWhite(isLight: false, activity: .inactive) == 0.06)
    #expect(BuehneTheme.contentWhite(isLight: true, activity: .active) == 0.975)
    #expect(BuehneTheme.contentWhite(isLight: true, activity: .inactive) == 0.925)
    #expect(BuehneTheme.contentWhite(isLight: false, activity: .active) == 0.13)
    #expect(BuehneTheme.contentWhite(isLight: false, activity: .inactive) == 0.08)
}

@Test func preferredSchemeFollowsAutoLightDark() {
    #expect(BuehneTheme.preferredScheme("auto") == nil)
    #expect(BuehneTheme.preferredScheme("light") == .light)
    #expect(BuehneTheme.preferredScheme("dark") == .dark)
}

@Test func transparencyZeroIsOpaqueAndOneHundredIsClear() {
    #expect(GlassAppearance.sharedBacking(0) == 1)
    #expect(GlassAppearance.sharedBacking(100) == 0)
    #expect(GlassAppearance.sharedBacking(0) > GlassAppearance.sharedBacking(50))
    #expect(GlassAppearance.sharedBacking(50) > GlassAppearance.sharedBacking(100))
    #expect(GlassAppearance.menuBacking(0) == GlassAppearance.readableBacking(0))
    #expect(GlassAppearance.menuBacking(100) == GlassAppearance.backingOpacity(100))
    #expect(GlassAppearance.resolvedTransparency(stored: nil, unit: nil) == 65)
    #expect(GlassAppearance.resolvedTransparency(stored: 0, unit: "percent") == 0)
    #expect(GlassAppearance.percentLabel(0) == "0%")
    #expect(GlassAppearance.percentLabel(100) == "100%")
    #expect(GlassAppearance.percentLabel(65) == "65%")
}

@Test @MainActor func barTransparencyIsIndependentOfTheGlobalSlider() {
    let name = "buehne.bar-transparency-test"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    defaults.set(12.0, forKey: "buehne.glassOpacity")
    defaults.set(GlassAppearance.percentUnit, forKey: "buehne.glassOpacityUnit")
    defaults.set(80.0, forKey: "buehne.barTransparency")
    let settings = BuehneSettings(defaults: defaults)
    #expect(settings.glassOpacity == 12)
    #expect(settings.barTransparency == 80)
    #expect(GlassAppearance.sharedBacking(settings.barTransparency) != GlassAppearance.sharedBacking(settings.glassOpacity))
    let unsetName = name + ".unset"
    let unset = UserDefaults(suiteName: unsetName)!
    unset.removePersistentDomain(forName: unsetName)
    let fresh = BuehneSettings(defaults: unset)
    #expect(fresh.barTransparency == 65)
    #expect(GlassAppearance.sharedBacking(0) == 1)
    #expect(GlassAppearance.sharedBacking(100) == 0)
    #expect(GlassAppearance.sharedBacking(0) > GlassAppearance.sharedBacking(50))
    #expect(GlassAppearance.sharedBacking(50) > GlassAppearance.sharedBacking(100))
    #expect(L10n.text(.barTransparency, language: "en") == "Control bar transparency")
    #expect(L10n.text(.barTransparency, language: "ru") == "Прозрачность панели управления")
    #expect(L10n.text(.barTransparency, language: "de") == "Transparenz der Steuerleiste")
    #expect(L10n.text(.barTransparency, language: "fr") == "Transparence de la barre de contrôle")
    #expect(L10n.text(.barTransparency, language: "it") == "Trasparenza della barra di controllo")
    #expect(L10n.text(.barTransparency, language: "es") == "Transparencia de la barra de control")
}

@Test func typographyUsesStromPostScriptNames() {
    #expect(BuehneTypeName.body == "Helvetica-Light")
    #expect(BuehneTypeName.panelTitle == "Helvetica-Bold")
    #expect(BuehneTypeName.sectionTitle == "HelveticaNeue-Light")
    #expect(BuehneTypeName.label == "Helvetica")
}
