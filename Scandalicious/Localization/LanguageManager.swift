//
//  LanguageManager.swift
//  Scandalicious
//
//  Manages app-wide language selection with UserDefaults persistence.
//

import Foundation
import Combine

@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private static let languageKey = "app_language"

    @Published var currentLanguage: ProfileLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: LanguageManager.languageKey)
        }
    }

    private init() {
        if let saved = UserDefaults.standard.string(forKey: LanguageManager.languageKey),
           let lang = ProfileLanguage(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            self.currentLanguage = .english
        }
    }

    func syncFromProfile(_ language: String?) {
        if let lang = ProfileLanguage.from(apiValue: language) {
            currentLanguage = lang
        }
    }

    /// Read current language code directly from UserDefaults (nonisolated-safe).
    nonisolated static var currentLanguageCode: String {
        UserDefaults.standard.string(forKey: languageKey) ?? "en"
    }
}

/// Global localization accessor. Returns the translated string for the current language.
func L(_ key: String) -> String {
    let lang = LanguageManager.currentLanguageCode
    return AppStrings.strings[key]?[lang] ?? AppStrings.strings[key]?["en"] ?? key
}
