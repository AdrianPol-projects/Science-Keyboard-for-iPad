import Foundation

/// Shared App Group used by the container app and the keyboard extension.
enum AppGroup {
    static let identifier: String = {
        if let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String,
           !id.isEmpty, !id.contains("$(") {
            return id
        }
        return "group.com.adrianpol.ScienceKeyboard"
    }()

    /// Falls back to a local store when the App Group entitlement is missing
    /// (e.g. after re-signing without app groups): everything still works, the
    /// app and keyboard just stop sharing data.
    static let defaults: UserDefaults = UserDefaults(suiteName: identifier) ?? .standard
}

// MARK: - Settings

enum FlickMode: String, Codable, CaseIterable, Identifiable {
    case numbers, greek, off
    var id: String { rawValue }
    var title: String {
        switch self {
        case .numbers: return "Numbers & punctuation"
        case .greek: return "Greek letters"
        case .off: return "Off"
        }
    }
}

enum TypingLanguage: String, Codable, CaseIterable, Identifiable {
    case english, czech, off
    var id: String { rawValue }
    var title: String {
        switch self {
        case .english: return "English"
        case .czech: return "Čeština"
        case .off: return "Off"
        }
    }
    var short: String {
        switch self {
        case .english: return "EN"
        case .czech: return "CZ"
        case .off: return "—"
        }
    }
    /// Language prefix used to pick a UITextChecker language.
    var checkerPrefix: String? {
        switch self {
        case .english: return "en"
        case .czech: return "cs"
        case .off: return nil
        }
    }
}

enum LetterLayout: String, Codable, CaseIterable, Identifiable {
    case automatic, qwerty, qwertz
    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: return "Automatic (QWERTZ for Czech)"
        case .qwerty: return "QWERTY"
        case .qwertz: return "QWERTZ"
        }
    }
}

enum KeyboardTheme: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum AccentChoice: String, Codable, CaseIterable, Identifiable {
    case blue, indigo, purple, pink, red, orange, green, teal
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct KeyboardSettings: Codable, Equatable {
    var haptics = true
    var keyClicks = true
    var autoCapitalize = true
    var doubleSpacePeriod = true
    var smartSuggestions = true
    var flickMode: FlickMode = .numbers
    var keyPopups = true
    var spaceCursorControl = true
    var heightScale: Double = 1.0
    var theme: KeyboardTheme = .system
    var accent: AccentChoice = .blue
    var clipboardAutoCapture = true
    var clipboardLimit = 60
    var angleInDegrees = false
    var language: TypingLanguage = .english
    var autocorrect = true
    var predictions = true
    var letterLayout: LetterLayout = .automatic

    var usesQWERTZ: Bool {
        switch letterLayout {
        case .automatic: return language == .czech
        case .qwerty: return false
        case .qwertz: return true
        }
    }

    init() {}

    private enum CodingKeys: String, CodingKey {
        case haptics, keyClicks, autoCapitalize, doubleSpacePeriod, smartSuggestions, flickMode
        case keyPopups, spaceCursorControl, heightScale, theme, accent, clipboardAutoCapture
        case clipboardLimit, angleInDegrees, language, autocorrect, predictions, letterLayout
    }

    // Tolerates missing keys so new settings never wipe old ones.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = KeyboardSettings()
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? d.haptics
        keyClicks = try c.decodeIfPresent(Bool.self, forKey: .keyClicks) ?? d.keyClicks
        autoCapitalize = try c.decodeIfPresent(Bool.self, forKey: .autoCapitalize) ?? d.autoCapitalize
        doubleSpacePeriod = try c.decodeIfPresent(Bool.self, forKey: .doubleSpacePeriod) ?? d.doubleSpacePeriod
        smartSuggestions = try c.decodeIfPresent(Bool.self, forKey: .smartSuggestions) ?? d.smartSuggestions
        flickMode = try c.decodeIfPresent(FlickMode.self, forKey: .flickMode) ?? d.flickMode
        keyPopups = try c.decodeIfPresent(Bool.self, forKey: .keyPopups) ?? d.keyPopups
        spaceCursorControl = try c.decodeIfPresent(Bool.self, forKey: .spaceCursorControl) ?? d.spaceCursorControl
        heightScale = try c.decodeIfPresent(Double.self, forKey: .heightScale) ?? d.heightScale
        theme = try c.decodeIfPresent(KeyboardTheme.self, forKey: .theme) ?? d.theme
        accent = try c.decodeIfPresent(AccentChoice.self, forKey: .accent) ?? d.accent
        clipboardAutoCapture = try c.decodeIfPresent(Bool.self, forKey: .clipboardAutoCapture) ?? d.clipboardAutoCapture
        clipboardLimit = try c.decodeIfPresent(Int.self, forKey: .clipboardLimit) ?? d.clipboardLimit
        angleInDegrees = try c.decodeIfPresent(Bool.self, forKey: .angleInDegrees) ?? d.angleInDegrees
        language = try c.decodeIfPresent(TypingLanguage.self, forKey: .language) ?? d.language
        autocorrect = try c.decodeIfPresent(Bool.self, forKey: .autocorrect) ?? d.autocorrect
        predictions = try c.decodeIfPresent(Bool.self, forKey: .predictions) ?? d.predictions
        letterLayout = try c.decodeIfPresent(LetterLayout.self, forKey: .letterLayout) ?? d.letterLayout
    }
}

// MARK: - Clipboard & snippets

struct ClipItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    var date = Date()
    var pinned = false
}

struct Snippet: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var text: String

    static let defaults: [Snippet] = [
        Snippet(title: "Mass–energy", text: "E = mc²"),
        Snippet(title: "Ideal gas", text: "pV = nRT"),
        Snippet(title: "Gibbs", text: "ΔG = ΔH − TΔS"),
        Snippet(title: "Schrödinger", text: "iℏ ∂ψ/∂t = Ĥψ"),
        Snippet(title: "Gauss", text: "∇·E = ρ/ε₀"),
        Snippet(title: "Faraday", text: "∇×E = −∂B/∂t"),
        Snippet(title: "Ampère–Maxwell", text: "∇×B = μ₀J + μ₀ε₀ ∂E/∂t"),
        Snippet(title: "Euler", text: "e^(iπ) + 1 = 0"),
        Snippet(title: "pH", text: "pH = −log₁₀[H₃O⁺]"),
        Snippet(title: "Avogadro", text: "Nₐ = 6.022 × 10²³ mol⁻¹"),
        Snippet(title: "Photon", text: "E = hν = hc/λ"),
        Snippet(title: "de Broglie", text: "λ = h/p"),
        Snippet(title: "Arrhenius", text: "k = A·e^(−Eₐ/RT)"),
        Snippet(title: "Nernst", text: "E = E° − (RT/nF) ln Q"),
        Snippet(title: "Newton II", text: "F⃗ = m·a⃗"),
        Snippet(title: "Uncertainty", text: "ΔxΔp ≥ ℏ/2"),
    ]
}

// MARK: - Persistent store

final class SharedStore {
    static let shared = SharedStore()

    let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
    }

    private enum Key {
        static let settings = "settings.v1"
        static let clipboard = "clipboard.v1"
        static let snippets = "snippets.v1"
        static let presets = "customPresets.v1"
        static let recents = "recents.v1"
        static let favorites = "favorites.v1"
        static let pasteboardChange = "pasteboardChangeCount"
    }

    private func decode<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    var settings: KeyboardSettings {
        get { decode(Key.settings, as: KeyboardSettings.self) ?? KeyboardSettings() }
        set { encode(newValue, key: Key.settings) }
    }

    var clipboard: [ClipItem] {
        get { decode(Key.clipboard, as: [ClipItem].self) ?? [] }
        set { encode(newValue, key: Key.clipboard) }
    }

    var snippets: [Snippet] {
        get { decode(Key.snippets, as: [Snippet].self) ?? Snippet.defaults }
        set { encode(newValue, key: Key.snippets) }
    }

    var customPresets: [Preset] {
        get { decode(Key.presets, as: [Preset].self) ?? [] }
        set { encode(newValue, key: Key.presets) }
    }

    var recents: [String] {
        get { defaults.stringArray(forKey: Key.recents) ?? [] }
        set { defaults.set(newValue, forKey: Key.recents) }
    }

    var favorites: [String] {
        get { defaults.stringArray(forKey: Key.favorites) ?? [] }
        set { defaults.set(newValue, forKey: Key.favorites) }
    }

    var lastPasteboardChangeCount: Int {
        get { defaults.integer(forKey: Key.pasteboardChange) }
        set { defaults.set(newValue, forKey: Key.pasteboardChange) }
    }

    func addRecent(_ symbol: String) {
        var list = recents
        list.removeAll { $0 == symbol }
        list.insert(symbol, at: 0)
        if list.count > 60 { list.removeLast(list.count - 60) }
        recents = list
    }

    @discardableResult
    func toggleFavorite(_ symbol: String) -> Bool {
        var list = favorites
        if let idx = list.firstIndex(of: symbol) {
            list.remove(at: idx)
            favorites = list
            return false
        }
        list.insert(symbol, at: 0)
        favorites = list
        return true
    }

    /// Adds text to the clipboard history (deduplicated, newest first).
    @discardableResult
    func addClip(_ text: String, limit: Int) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        var list = clipboard
        if let idx = list.firstIndex(where: { $0.text == text }) {
            var item = list.remove(at: idx)
            item.date = Date()
            list.insert(item, at: 0)
        } else {
            list.insert(ClipItem(text: text), at: 0)
        }
        clipboard = Self.trimmed(list, limit: limit)
        return true
    }

    static func trimmed(_ list: [ClipItem], limit: Int) -> [ClipItem] {
        var unpinned = 0
        return list.filter { item in
            if item.pinned { return true }
            unpinned += 1
            return unpinned <= max(limit, 1)
        }
    }
}
