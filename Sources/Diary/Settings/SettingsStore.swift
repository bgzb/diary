import SwiftUI
import Observation

// MARK: - Shortcut Config

struct ShortcutAction {
    static let newEntry = "newEntry"
    static let save = "save"
    static let deleteEntry = "deleteEntry"
    static let export = "export"
    static let calendar = "calendar"

    static let all: [(id: String, defaultKey: String, defaultModifiers: EventModifiers)] = [
        (newEntry, "n", .command),
        (save, "s", .command),
        (deleteEntry, "d", .command),
        (export, "p", .command),
        (calendar, "c", [.command, .shift]),
    ]
}

struct ShortcutConfig: Codable, Equatable {
    var key: String
    var modifiers: Int

    var displayString: String {
        var parts: [String] = []
        let m = EventModifiers(rawValue: modifiers)
        if m.contains(.command) { parts.append("⌘") }
        if m.contains(.option) { parts.append("⌥") }
        if m.contains(.control) { parts.append("⌃") }
        if m.contains(.shift) { parts.append("⇧") }

        switch key {
        case String(Character(UnicodeScalar(NSBackspaceCharacter)!)):
            parts.append("⌫")
        case String(Character(UnicodeScalar(NSDeleteCharacter)!)):
            parts.append("⌦")
        case String(Character(UnicodeScalar(NSCarriageReturnCharacter)!)):
            parts.append("↩")
        case String(Character(UnicodeScalar(NSTabCharacter)!)):
            parts.append("⇥")
        case String(Character(UnicodeScalar(27))):
            parts.append("⎋")
        case " ":
            parts.append("␣")
        default:
            parts.append(key.uppercased())
        }
        return parts.joined(separator: " ")
    }

    var keyEquivalent: KeyEquivalent {
        KeyEquivalent(Character(key).firstCharacter)
    }

    var eventModifiers: EventModifiers {
        EventModifiers(rawValue: modifiers)
    }
}

private extension Character {
    var firstCharacter: Character { self }
}

// MARK: - Preview Theme

enum PreviewTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case grey = "Grey"
    case dark = "Dark"

    func displayName(_ lang: AppLanguage) -> String {
        switch self {
        case .system: return L.string(.systemTheme, lang: lang)
        case .light: return L.string(.lightTheme, lang: lang)
        case .grey: return L.string(.softTheme, lang: lang)
        case .dark: return L.string(.darkTheme, lang: lang)
        }
    }
}

enum EditorFont: String, CaseIterable {
    case systemMonospaced = "System Monospaced"
    case sfMono = "SF Mono"
    case menlo = "Menlo"
    case jetBrainsMono = "JetBrains Mono"

    func displayName(_ lang: AppLanguage) -> String {
        switch self {
        case .systemMonospaced: return L.string(.fontSystemMonospaced, lang: lang)
        case .sfMono: return L.string(.fontSFMono, lang: lang)
        case .menlo: return L.string(.fontMenlo, lang: lang)
        case .jetBrainsMono: return L.string(.fontJetBrainsMono, lang: lang)
        }
    }

    var nsFont: NSFont {
        switch self {
        case .systemMonospaced:
            NSFont.monospacedSystemFont(ofSize: 0, weight: .regular)
        case .sfMono:
            NSFont(name: "SF Mono", size: 0) ?? NSFont.monospacedSystemFont(ofSize: 0, weight: .regular)
        case .menlo:
            NSFont(name: "Menlo", size: 0) ?? NSFont.monospacedSystemFont(ofSize: 0, weight: .regular)
        case .jetBrainsMono:
            NSFont(name: "JetBrains Mono", size: 0) ?? NSFont.monospacedSystemFont(ofSize: 0, weight: .regular)
        }
    }
}

@Observable
final class SettingsStore {
    // MARK: - Storage (stored properties + didSet → UserDefaults)
    var storagePath: String = "" {
        didSet { save(storagePath, for: "storagePath") }
    }

    var useDatePrefix: Bool = false {
        didSet { save(useDatePrefix, for: "useDatePrefix") }
    }

    // MARK: - Editor
    var editorFontSize: Double = 14 {
        didSet { save(editorFontSize, for: "editorFontSize") }
    }

    var editorFont: EditorFont = .systemMonospaced {
        didSet { save(editorFont.rawValue, for: "editorFont") }
    }

    var editorLineSpacing: Double = 4 {
        didSet { save(editorLineSpacing, for: "editorLineSpacing") }
    }

    var editorSpellCheck: Bool = false {
        didSet { save(editorSpellCheck, for: "editorSpellCheck") }
    }

    var editorTabWidth: Int = 4 {
        didSet { save(editorTabWidth, for: "editorTabWidth") }
    }

    // MARK: - Preview
    var previewTheme: PreviewTheme = .system {
        didSet { save(previewTheme.rawValue, for: "previewTheme") }
    }

    // MARK: - General
    var openLastEntry: Bool = true {
        didSet { save(openLastEntry, for: "openLastEntry") }
    }

    var autoSaveInterval: Double = 1.0 {
        didSet { save(autoSaveInterval, for: "autoSaveInterval") }
    }

    var appLanguage: AppLanguage = .system {
        didSet { save(appLanguage.rawValue, for: "appLanguage"); rescheduleReminder() }
    }

    // MARK: - Reminder
    var reminderEnabled: Bool = false {
        didSet { save(reminderEnabled, for: "reminderEnabled"); rescheduleReminder() }
    }

    var reminderHour: Int = 20 {
        didSet { save(reminderHour, for: "reminderHour"); rescheduleReminder() }
    }

    var reminderMinute: Int = 0 {
        didSet { save(reminderMinute, for: "reminderMinute"); rescheduleReminder() }
    }

    // MARK: - Shortcuts
    var shortcuts: [String: ShortcutConfig] = [:] {
        didSet { saveShortcuts() }
    }

    func shortcutConfig(for action: String) -> ShortcutConfig {
        shortcuts[action] ?? defaultShortcut(for: action)
    }

    func defaultShortcut(for action: String) -> ShortcutConfig {
        guard let entry = ShortcutAction.all.first(where: { $0.id == action }) else {
            return ShortcutConfig(key: " ", modifiers: 0)
        }
        return ShortcutConfig(key: entry.defaultKey, modifiers: Int(entry.defaultModifiers.rawValue))
    }

    func resetShortcuts() {
        var defaults: [String: ShortcutConfig] = [:]
        for entry in ShortcutAction.all {
            defaults[entry.id] = ShortcutConfig(key: entry.defaultKey, modifiers: Int(entry.defaultModifiers.rawValue))
        }
        shortcuts = defaults
    }

    // MARK: - Derived
    var defaultStoragePath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Diary/entries").path
    }

    var resolvedStoragePath: String {
        (storagePath as NSString).expandingTildeInPath
    }

    // MARK: - Reminder scheduling
    private func rescheduleReminder() {
        ReminderManager.schedule(
            enabled: reminderEnabled, hour: reminderHour, minute: reminderMinute, lang: appLanguage
        )
    }

    // MARK: - Init (load from UserDefaults)
    init() {
        let d = UserDefaults.standard
        func load<T>(_ key: String, fallback: T) -> T {
            (d.object(forKey: "diary_\(key)") as? T) ?? fallback
        }
        func loadEnum<T: RawRepresentable>(_ key: String, fallback: T) -> T where T.RawValue == String {
            guard let raw = d.string(forKey: "diary_\(key)") else { return fallback }
            return T(rawValue: raw) ?? fallback
        }

        storagePath = load("storagePath", fallback: defaultStoragePath)
        useDatePrefix = load("useDatePrefix", fallback: false)
        editorFontSize = load("editorFontSize", fallback: 14.0)
        editorFont = loadEnum("editorFont", fallback: .systemMonospaced)
        editorLineSpacing = load("editorLineSpacing", fallback: 4.0)
        editorSpellCheck = load("editorSpellCheck", fallback: false)
        editorTabWidth = load("editorTabWidth", fallback: 4)
        previewTheme = loadEnum("previewTheme", fallback: .system)
        openLastEntry = load("openLastEntry", fallback: true)
        autoSaveInterval = load("autoSaveInterval", fallback: 1.0)
        appLanguage = loadEnum("appLanguage", fallback: .system)
        reminderEnabled = load("reminderEnabled", fallback: false)
        reminderHour = load("reminderHour", fallback: 20)
        reminderMinute = load("reminderMinute", fallback: 0)

        // Load shortcuts
        if let data = d.data(forKey: "diary_shortcuts"),
           let decoded = try? JSONDecoder().decode([String: ShortcutConfig].self, from: data) {
            shortcuts = decoded
        } else {
            resetShortcuts()
        }

        rescheduleReminder()
    }

    // MARK: - Persistence
    private func save<T>(_ value: T, for key: String) {
        UserDefaults.standard.set(value, forKey: "diary_\(key)")
    }

    private func saveShortcuts() {
        if let data = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(data, forKey: "diary_shortcuts")
        }
    }
}
