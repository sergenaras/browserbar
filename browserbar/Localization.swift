import Foundation
import SwiftUI

struct Localization {
    static let currentLanguageCode = Locale.current.language.languageCode?.identifier ?? "en"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    
    enum Key: String {
        case settingsTitle = "settings.title"
        case settingsGeneral = "settings.general"
        case settingsBrowsers = "settings.browsers"
        case settingsAbout = "settings.about"
        case settingsLaunchAtLogin = "settings.launchAtLogin"
        case settingsLaunchAtLoginDescOn = "settings.launchAtLoginDescOn"
        case settingsLaunchAtLoginDescOff = "settings.launchAtLoginDescOff"
        case settingsBrowserList = "settings.browserList"
        case settingsBrowserListDesc = "settings.browserListDesc"
        case settingsLanguage = "settings.language"
        case settingsLanguageAuto = "settings.languageAuto"
        case menuBrowsers = "menu.browsers"
        case menuSettings = "menu.settings"
        case menuQuit = "menu.quit"
        case aboutTitle = "about.title"
        case aboutDesc = "about.desc"
        case aboutVersion = "about.version"
        case aboutFooter = "about.footer"
    }
    
    static func string(_ key: Key) -> String {
        // 1. Determine Language Code
        let manualLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "auto"
        var langCode = "en"
        
        if manualLanguage == "tr" {
            langCode = "tr"
        } else if manualLanguage == "en" {
            langCode = "en"
        } else {
            // Auto: check system preferences
            let systemLang = Locale.preferredLanguages.first ?? Locale.current.identifier
            if systemLang.lowercased().starts(with: "tr") {
                langCode = "tr"
            }
        }

        // 2. Try to load from .strings file in Bundle
        // This allows the use of the Resources/en.lproj files if they are properly added to the Build Phases.
        if let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let localizedString = bundle.localizedString(forKey: key.rawValue, value: nil, table: "Localizable")
            // If the lookup found something different than the key itself, return it.
            if localizedString != key.rawValue {
                return localizedString
            }
        }

        // 3. Fallback: Hardcoded strings (Safety net if files are missing from Bundle)
        let isTurkish = (langCode == "tr")
        
        switch key {
        case .settingsTitle: return isTurkish ? "Ayarlar" : "Settings"
        case .settingsGeneral: return isTurkish ? "Genel" : "General"
        case .settingsBrowsers: return isTurkish ? "Tarayıcılar" : "Browsers"
        case .settingsAbout: return isTurkish ? "Hakkında" : "About"
        case .settingsLaunchAtLogin: return isTurkish ? "Başlangıçta Çalıştır" : "Launch at Login"
        case .settingsLaunchAtLoginDescOn: return isTurkish ? "BrowserBar oturum açtığınızda otomatik başlayacak." : "BrowserBar will start automatically when you log in."
        case .settingsLaunchAtLoginDescOff: return isTurkish ? "BrowserBar otomatik başlamayacak." : "BrowserBar will not start automatically."
        case .settingsBrowserList: return isTurkish ? "Görünen Tarayıcılar" : "Visible Browsers"
        case .settingsBrowserListDesc: return isTurkish ? "Menüde hangi tarayıcıların görüneceğini seçin." : "Toggle which browsers appear in the menu."
        case .settingsLanguage: return isTurkish ? "Dil" : "Language"
        case .settingsLanguageAuto: return isTurkish ? "Otomatik (Sistem)" : "Auto (System)"
        case .menuBrowsers: return isTurkish ? "Tarayıcılar" : "Browsers"
        case .menuSettings: return isTurkish ? "Ayarlar..." : "Settings..."
        case .menuQuit: return isTurkish ? "Çıkış" : "Quit"
        case .aboutTitle: return "BrowserBar"
        case .aboutDesc: return isTurkish ? "macOS'te varsayılan tarayıcıyı değiştirmenin en basit yolu." : "The simplest way to toggle your default browser on macOS."
        case .aboutVersion: return isTurkish ? "Sürüm \(Self.appVersion)" : "Version \(Self.appVersion)"
        case .aboutFooter: return "https://github.com/sergenaras"
        }
    }
}
