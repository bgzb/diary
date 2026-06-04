import AppKit

// MARK: - Theme Colors

struct EditorColors {
    let bg: NSColor
    let text: NSColor
    let cursor: NSColor
    let selection: NSColor

    static func from(_ theme: PreviewTheme, customColors: CustomThemeColors? = nil) -> EditorColors {
        switch theme {
        case .light:
            return EditorColors(
                bg: NSColor(red: 0.984, green: 0.980, blue: 0.969, alpha: 1),
                text: NSColor(red: 0.114, green: 0.110, blue: 0.102, alpha: 1),
                cursor: NSColor(red: 0.357, green: 0.608, blue: 0.835, alpha: 1),
                selection: NSColor(red: 0.816, green: 0.878, blue: 0.945, alpha: 1)
            )
        case .grey:
            return EditorColors(
                bg: NSColor(red: 0.935, green: 0.925, blue: 0.900, alpha: 1),
                text: NSColor(red: 0.200, green: 0.196, blue: 0.188, alpha: 1),
                cursor: NSColor(red: 0.357, green: 0.608, blue: 0.835, alpha: 1),
                selection: NSColor(red: 0.745, green: 0.820, blue: 0.902, alpha: 1)
            )
        case .dark:
            return EditorColors(
                bg: NSColor(red: 0.157, green: 0.153, blue: 0.145, alpha: 1),
                text: NSColor(red: 0.812, green: 0.808, blue: 0.784, alpha: 1),
                cursor: NSColor(red: 0.424, green: 0.706, blue: 0.933, alpha: 1),
                selection: NSColor(red: 0.145, green: 0.208, blue: 0.271, alpha: 1)
            )
        case .custom:
            guard let c = customColors else { return from(.light) }
            let accent = c.accentColor.nsColor
            let bg = c.editorBackground.nsColor
            return EditorColors(
                bg: bg,
                text: c.editorText.nsColor,
                cursor: accent,
                selection: bg.blended(withFraction: 0.15, of: accent) ?? bg
            )
        case .system:
            let name = NSApp.effectiveAppearance.name
            return (name == .darkAqua || name == .vibrantDark) ? from(.dark) : from(.light)
        }
    }
}
