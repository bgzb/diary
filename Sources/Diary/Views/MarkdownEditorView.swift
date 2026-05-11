import SwiftUI
import AppKit

// MARK: - NSTextView subclass

final class EditorTextView: NSTextView {
    override func keyDown(with event: NSEvent) {
        guard let chars = event.charactersIgnoringModifiers else {
            super.keyDown(with: event)
            return
        }

        let cmd = event.modifierFlags.contains(.command)
        let shift = event.modifierFlags.contains(.shift)

        if cmd && !shift {
            switch chars {
            case "b": toggleWrap("**"); return
            case "i": toggleWrap("*"); return
            case "k": insertLink(); return
            case "=", "+": adjustHeading(up: true); return
            case "-": adjustHeading(up: false); return
            case "1"..."6":
                if let level = Int(chars) { setHeading(level) }; return
            default: break
            }
        }

        if cmd && shift {
            switch chars {
            case "x", "X": toggleWrap("~~"); return
            case "b", "B": toggleBlockquote(); return
            case "7": toggleOrderedList(); return
            case "8": toggleUnorderedList(); return
            default: break
            }
        }

        super.keyDown(with: event)
    }

    private func toggleWrap(_ marker: String) {
        let sel = selectedRange()
        guard sel.length > 0 else {
            insertText(marker + marker, replacementRange: sel)
            setSelectedRange(NSRange(location: sel.location + marker.count, length: 0))
            return
        }
        let text = (string as NSString).substring(with: sel)
        let mlen = marker.count
        if text.hasPrefix(marker) && text.hasSuffix(marker) && text.count >= mlen * 2 {
            let inner = String(text.dropFirst(mlen).dropLast(mlen))
            insertText(inner, replacementRange: sel)
            setSelectedRange(NSRange(location: sel.location, length: inner.count))
        } else {
            let wrapped = marker + text + marker
            insertText(wrapped, replacementRange: sel)
            setSelectedRange(NSRange(location: sel.location, length: wrapped.count))
        }
    }

    private func insertLink() {
        let sel = selectedRange()
        if sel.length > 0 {
            let text = (string as NSString).substring(with: sel)
            insertText("[\(text)](url)", replacementRange: sel)
        } else {
            insertText("[](url)", replacementRange: sel)
            setSelectedRange(NSRange(location: sel.location + 1, length: 0))
        }
    }

    private func setHeading(_ level: Int) {
        let lineRange = currentLineRange()
        let line = (string as NSString).substring(with: lineRange)
        let prefix = String(repeating: "#", count: level) + " "
        let cleaned = line.replacingOccurrences(of: "^#{1,6}\\s*", with: "", options: .regularExpression)
        insertText(prefix + cleaned, replacementRange: lineRange)
    }

    private func adjustHeading(up: Bool) {
        let lineRange = currentLineRange()
        let line = (string as NSString).substring(with: lineRange)
        if let match = try? NSRegularExpression(pattern: "^(#{1,6})\\s").firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            let currentLevel = match.range(at: 1).length
            let newLevel = up ? max(1, currentLevel - 1) : min(6, currentLevel + 1)
            setHeading(newLevel)
        } else if !up {
            setHeading(1)
        }
    }

    private func toggleBlockquote() {
        let lineRange = currentLineRange()
        let line = (string as NSString).substring(with: lineRange)
        if line.hasPrefix("> ") {
            insertText(String(line.dropFirst(2)), replacementRange: lineRange)
        } else {
            insertText("> " + line, replacementRange: lineRange)
        }
    }

    private func toggleOrderedList() {
        let lineRange = currentLineRange()
        let line = (string as NSString).substring(with: lineRange)
        if let match = try? NSRegularExpression(pattern: "^(\\d+)\\.\\s").firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            let cleaned = String(line[Range(match.range, in: line)!.upperBound...])
            insertText(cleaned, replacementRange: lineRange)
        } else {
            insertText("1. " + line, replacementRange: lineRange)
        }
    }

    private func toggleUnorderedList() {
        let lineRange = currentLineRange()
        let line = (string as NSString).substring(with: lineRange)
        if let match = try? NSRegularExpression(pattern: "^[-*+]\\s").firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            let cleaned = String(line[Range(match.range, in: line)!.upperBound...])
            insertText(cleaned, replacementRange: lineRange)
        } else {
            insertText("- " + line, replacementRange: lineRange)
        }
    }

    private func currentLineRange() -> NSRange {
        (string as NSString).lineRange(for: selectedRange())
    }
}

// MARK: - NSViewRepresentable

struct MarkdownEditorView: NSViewRepresentable {
    @Binding var text: String
    let settings: SettingsStore

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = EditorTextView()
        textView.delegate = context.coordinator
        textView.allowsUndo = true
        textView.isRichText = true
        textView.isGrammarCheckingEnabled = false
        textView.textContainerInset = NSSize(width: 64, height: 48)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        applySettingsOnce(to: textView)
        context.coordinator.setBaseStyle(font: textView.font ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                                          color: textView.textColor ?? .textColor)

        scrollView.documentView = textView
        context.coordinator.textView = textView

        if !text.isEmpty {
            textView.string = text
            context.coordinator.renderMarkdown()
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        guard !textView.hasMarkedText() else { return }

        applyRuntimeSettings(to: textView, coordinator: context.coordinator)

        if textView.string != text {
            textView.string = text
            context.coordinator.renderMarkdown()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize {
        return proposal.replacingUnspecifiedDimensions()
    }

    private func applySettingsOnce(to textView: NSTextView) {
        let fontSize = CGFloat(settings.editorFontSize)
        let font = settings.editorFont.nsFont.withSize(fontSize)
        textView.font = font
        textView.isContinuousSpellCheckingEnabled = settings.editorSpellCheck

        let lineH = (1.9 + settings.editorLineSpacing / 10.0) * fontSize
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = lineH
        style.maximumLineHeight = lineH
        style.defaultTabInterval = CGFloat(settings.editorTabWidth * Int(fontSize))
        style.tabStops = []
        textView.defaultParagraphStyle = style

        let colors = EditorColors.from(settings.previewTheme)
        textView.backgroundColor = colors.bg
        textView.textColor = colors.text
        textView.insertionPointColor = colors.cursor
        textView.selectedTextAttributes = [
            .backgroundColor: colors.selection,
            .foregroundColor: colors.text,
        ]
    }

    private func applyRuntimeSettings(to textView: NSTextView, coordinator: Coordinator) {
        let fontSize = CGFloat(settings.editorFontSize)
        textView.font = settings.editorFont.nsFont.withSize(fontSize)
        textView.isContinuousSpellCheckingEnabled = settings.editorSpellCheck

        let lineH = (1.9 + settings.editorLineSpacing / 10.0) * fontSize
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = lineH
        style.maximumLineHeight = lineH
        style.defaultTabInterval = CGFloat(settings.editorTabWidth * Int(fontSize))
        style.tabStops = []
        textView.defaultParagraphStyle = style

        let colors = EditorColors.from(settings.previewTheme)
        textView.backgroundColor = colors.bg
        textView.textColor = colors.text
        textView.insertionPointColor = colors.cursor
        textView.selectedTextAttributes = [
            .backgroundColor: colors.selection,
            .foregroundColor: colors.text,
        ]

        coordinator.setBaseStyle(font: textView.font ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                                  color: textView.textColor ?? .textColor)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: MarkdownEditorView
        weak var textView: NSTextView?
        private var markdownTimer: Timer?
        private var baseFont: NSFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
        private var textColor: NSColor = .textColor

        init(_ parent: MarkdownEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !textView.hasMarkedText() else { return }

            if textView.string != parent.text {
                parent.text = textView.string
            }
            scheduleRenderMarkdown()
        }

        // MARK: - Markdown rendering (debounced)

        private func scheduleRenderMarkdown() {
            markdownTimer?.invalidate()
            markdownTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
                guard let self, let tv = self.textView, !tv.hasMarkedText() else { return }
                self.renderMarkdown()
            }
        }

        func setBaseStyle(font: NSFont, color: NSColor) {
            baseFont = font
            textColor = color
        }

        fileprivate func renderMarkdown() {
            guard let textView, let textStorage = textView.textStorage else { return }

            let fullRange = NSRange(location: 0, length: textStorage.length)
            guard fullRange.length > 0 else { return }

            let parser = MarkdownParser(baseFont: baseFont, textColor: textColor)
            let attributed = parser.parse(textStorage.string)

            textView.undoManager?.disableUndoRegistration()
            textStorage.beginEditing()
            let mdKeys: [NSAttributedString.Key] = [.font, .foregroundColor, .backgroundColor, .strikethroughStyle]
            for key in mdKeys {
                textStorage.removeAttribute(key, range: fullRange)
            }
            attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attrs, range, _ in
                let actual = NSRange(location: range.location, length: range.length)
                if actual.upperBound <= textStorage.length {
                    textStorage.addAttributes(attrs, range: actual)
                }
            }
            textStorage.endEditing()
            textView.undoManager?.enableUndoRegistration()
        }
    }
}

// MARK: - Theme Colors

struct EditorColors {
    let bg: NSColor
    let text: NSColor
    let cursor: NSColor
    let selection: NSColor

    static func from(_ theme: PreviewTheme) -> EditorColors {
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
        case .system:
            let name = NSApp.effectiveAppearance.name
            return (name == .darkAqua || name == .vibrantDark) ? from(.dark) : from(.light)
        }
    }
}
