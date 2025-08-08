import SwiftUI
import Foundation

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "selectedLanguage")
            setAppLanguage(currentLanguage)
        }
    }
    
    let supportedLanguages = [
        "en": "English",
        "fr": "Français (French)", 
        "nl": "Nederlands (Dutch)",
        "de": "Deutsch (German)",
        "zh-Hans": "简体中文 (Chinese Simplified)",
        "zh-Hant": "繁體中文 (Chinese Traditional)",
        "es": "Español (Spanish)",
        "pt": "Português (Portuguese)"
    ]
    
    private init() {
        // Load saved language or use system default
        if let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage") {
            self.currentLanguage = savedLanguage
        } else {
            // Try to match system language with our supported languages
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            let systemRegion = Locale.current.language.region?.identifier
            
            // Check for specific Chinese variants first
            if systemLanguage == "zh" {
                if systemRegion == "CN" || systemRegion == "SG" {
                    self.currentLanguage = "zh-Hans"
                } else {
                    self.currentLanguage = "zh-Hant"
                }
            } else if supportedLanguages.keys.contains(systemLanguage) {
                self.currentLanguage = systemLanguage
            } else {
                self.currentLanguage = "en"
            }
        }
        setAppLanguage(currentLanguage)
    }
    
    private func setAppLanguage(_ language: String) {
        // Update UserDefaults for NSLocalizedString
        UserDefaults.standard.set([language], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    func getDisplayName(for languageCode: String) -> String {
        return supportedLanguages[languageCode] ?? languageCode
    }
}
