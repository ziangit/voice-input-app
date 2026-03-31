import Foundation

enum Language: String, CaseIterable {
    case simplifiedChinese = "zh-CN"
    case traditionalChinese = "zh-TW"
    case english = "en-US"
    case japanese = "ja-JP"
    case korean = "ko-KR"

    var displayName: String {
        switch self {
        case .simplifiedChinese:  return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .english:            return "English"
        case .japanese:           return "日本語"
        case .korean:             return "한국어"
        }
    }
}

final class Preferences {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let language        = "selectedLanguage"
        static let llmEnabled      = "llmEnabled"
        static let llmAPIBaseURL   = "llmAPIBaseURL"
        static let llmAPIKey       = "llmAPIKey"
        static let llmModel        = "llmModel"
    }

    var language: Language {
        get {
            let raw = defaults.string(forKey: Key.language) ?? Language.simplifiedChinese.rawValue
            return Language(rawValue: raw) ?? .simplifiedChinese
        }
        set { defaults.set(newValue.rawValue, forKey: Key.language) }
    }

    var llmEnabled: Bool {
        get { defaults.bool(forKey: Key.llmEnabled) }
        set { defaults.set(newValue, forKey: Key.llmEnabled) }
    }

    var llmAPIBaseURL: String {
        get { defaults.string(forKey: Key.llmAPIBaseURL) ?? "" }
        set { defaults.set(newValue, forKey: Key.llmAPIBaseURL) }
    }

    var llmAPIKey: String {
        get { defaults.string(forKey: Key.llmAPIKey) ?? "" }
        set { defaults.set(newValue, forKey: Key.llmAPIKey) }
    }

    var llmModel: String {
        get { defaults.string(forKey: Key.llmModel) ?? "gpt-4o-mini" }
        set { defaults.set(newValue, forKey: Key.llmModel) }
    }

    var llmConfigured: Bool {
        return !llmAPIBaseURL.isEmpty && !llmAPIKey.isEmpty && !llmModel.isEmpty
    }
}
