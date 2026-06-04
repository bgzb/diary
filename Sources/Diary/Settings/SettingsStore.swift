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

// MARK: - Custom Theme Colors

struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(nsColor: NSColor) {
        let srgb = nsColor.usingColorSpace(.sRGB) ?? NSColor(red: 0, green: 0, blue: 0, alpha: 1)
        red = Double(srgb.redComponent)
        green = Double(srgb.greenComponent)
        blue = Double(srgb.blueComponent)
        alpha = Double(srgb.alphaComponent)
    }

    init(color: Color) {
        self.init(nsColor: NSColor(color))
    }

    var nsColor: NSColor {
        NSColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

    var hexString: String {
        let r = UInt8(max(0, min(1, red)) * 255)
        let g = UInt8(max(0, min(1, green)) * 255)
        let b = UInt8(max(0, min(1, blue)) * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    init(hex: String) {
        let stripped = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: stripped)
        var hexValue: UInt64 = 0
        if scanner.scanHexInt64(&hexValue), stripped.count == 6 {
            red = Double((hexValue >> 16) & 0xFF) / 255.0
            green = Double((hexValue >> 8) & 0xFF) / 255.0
            blue = Double(hexValue & 0xFF) / 255.0
            alpha = 1.0
        } else {
            self = CodableColor(nsColor: .black)
        }
    }
}

struct CustomThemeColors: Codable, Equatable {
    var editorBackground: CodableColor
    var editorText: CodableColor
    var contentBackground: CodableColor
    var sidebarBackground: CodableColor
    var sidebarTint: CodableColor
    var accentColor: CodableColor
    var formBackground: CodableColor

    static let defaultLight = CustomThemeColors(
        editorBackground: CodableColor(nsColor: NSColor(red: 0.984, green: 0.980, blue: 0.969, alpha: 1)),
        editorText: CodableColor(nsColor: NSColor(red: 0.114, green: 0.110, blue: 0.102, alpha: 1)),
        contentBackground: CodableColor(nsColor: NSColor(white: 0.98, alpha: 1)),
        sidebarBackground: CodableColor(nsColor: NSColor(white: 0.91, alpha: 1)),
        sidebarTint: CodableColor(nsColor: NSColor(red: 0.80, green: 0.83, blue: 0.87, alpha: 1)),
        accentColor: CodableColor(nsColor: NSColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1)),
        formBackground: CodableColor(nsColor: NSColor(white: 0.98, alpha: 1))
    )
}

struct CustomThemePreset: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var colors: CustomThemeColors
}

// MARK: - Preview Theme

enum PreviewTheme: String, CaseIterable {
    case system = "System"
    case light = "Light"
    case grey = "Grey"
    case dark = "Dark"
    case custom = "Custom"

    func displayName(_ lang: AppLanguage) -> String {
        switch self {
        case .system: return L.string(.systemTheme, lang: lang)
        case .light: return L.string(.lightTheme, lang: lang)
        case .grey: return L.string(.softTheme, lang: lang)
        case .dark: return L.string(.darkTheme, lang: lang)
        case .custom: return L.string(.customTheme, lang: lang)
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

    // MARK: - Custom Theme
    var customThemeColors: CustomThemeColors = .defaultLight {
        didSet { saveCustomThemeColors() }
    }

    var presets: [CustomThemePreset] = [] {
        didSet { savePresets() }
    }

    var effectiveAccentColor: Color {
        previewTheme == .custom
            ? customThemeColors.accentColor.color
            : Color.accentColor
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

        // Load custom theme colors
        if let data = d.data(forKey: "diary_customThemeColors"),
           let decoded = try? JSONDecoder().decode(CustomThemeColors.self, from: data) {
            customThemeColors = decoded
        }

        // Load presets
        if let data = d.data(forKey: "diary_customThemePresets"),
           let decoded = try? JSONDecoder().decode([CustomThemePreset].self, from: data) {
            presets = decoded
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

    private func saveCustomThemeColors() {
        if let data = try? JSONEncoder().encode(customThemeColors) {
            UserDefaults.standard.set(data, forKey: "diary_customThemeColors")
        }
    }

    private func savePresets() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: "diary_customThemePresets")
        }
    }

    func savePreset(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        presets.removeAll { $0.name == trimmed }
        presets.append(CustomThemePreset(name: trimmed, colors: customThemeColors))
    }

    func applyPreset(_ preset: CustomThemePreset) {
        customThemeColors = preset.colors
    }

    func deletePreset(id: UUID) {
        presets.removeAll { $0.id == id }
    }

    func customColorBinding(for keyPath: WritableKeyPath<CustomThemeColors, CodableColor>) -> Binding<Color> {
        Binding(
            get: { self.customThemeColors[keyPath: keyPath].color },
            set: {
                var updated = self.customThemeColors
                updated[keyPath: keyPath] = CodableColor(color: $0)
                self.customThemeColors = updated
            }
        )
    }

    func customColorHexBinding(for keyPath: WritableKeyPath<CustomThemeColors, CodableColor>) -> Binding<String> {
        Binding(
            get: { self.customThemeColors[keyPath: keyPath].hexString },
            set: { newHex in
                let trimmed = newHex.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.count == 7, trimmed.hasPrefix("#") else { return }
                var updated = self.customThemeColors
                updated[keyPath: keyPath] = CodableColor(hex: trimmed)
                self.customThemeColors = updated
            }
        )
    }
}
