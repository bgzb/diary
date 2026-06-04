import SwiftUI
import AppKit

// MARK: - NSViewRepresentable

struct MarkdownEditorView: NSViewRepresentable {
    @Binding var text: String
    let settings: SettingsStore
    var groupDir: URL?

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
        textView.groupDir = groupDir

        // Register for image drag types
        textView.registerForDraggedTypes([.fileURL, .png, .tiff])

        applySettingsOnce(to: textView)
        context.coordinator.setBaseStyle(font: textView.font ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                                          color: textView.textColor ?? .textColor)

        scrollView.documentView = textView
        context.coordinator.textView = textView

        if !text.isEmpty {
            let display = context.coordinator.buildDisplayText(from: text, baseURL: groupDir)
            textView.textStorage?.setAttributedString(display)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        guard !textView.hasMarkedText() else { return }

        applyRuntimeSettings(to: textView, coordinator: context.coordinator)
        (textView as? EditorTextView)?.groupDir = groupDir

        // Compare source text (reconstructed from display) with incoming binding
        let currentSource = context.coordinator.reconstructSourceText(from: textView.textStorage!)
        if currentSource != text {
            // External change — rebuild display from source
            let cursor = textView.selectedRange().location
            let display = context.coordinator.buildDisplayText(from: text, baseURL: groupDir)
            textView.textStorage?.setAttributedString(display)
            let clamped = min(cursor, display.length)
            textView.setSelectedRange(NSRange(location: clamped, length: 0))
        } else {
            // Same source — just refresh highlighting and new image patterns
            context.coordinator.refreshDisplay(baseURL: groupDir)
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
        var isInternalUpdate = false
        var isImageExpanded = false

        init(_ parent: MarkdownEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !textView.hasMarkedText() else { return }
            guard !isInternalUpdate else { return }

            let source = reconstructSourceText(from: textView.textStorage!)
            if source != parent.text {
                parent.text = source
            }
            scheduleRenderMarkdown()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView, let ts = textView.textStorage else {
                scheduleRenderMarkdown()
                return
            }

            // If image is expanded and cursor left the header area, collapse immediately
            // (no debounce wait) so the markdown-disappears-on-click-away feels instant.
            if isImageExpanded, let headerRange = findImageHeaderRange(in: ts) {
                let cursorPos = textView.selectedRange().location
                // +1 includes the attachment char right after the header
                if cursorPos < headerRange.location || cursorPos > NSMaxRange(headerRange) + 1 {
                    cleanupImageHeader(in: ts, textView: textView)
                    isImageExpanded = false
                }
            }

            scheduleRenderMarkdown()
        }

        // MARK: - Source ↔ Display conversion

        /// Reconstruct source markdown from display text (replace ImageAttachment chars with original markdown).
        /// Skips display-only header text marked with `.imageMarkdownHeader`.
        func reconstructSourceText(from textStorage: NSTextStorage) -> String {
            var result = ""
            textStorage.enumerateAttributes(in: NSRange(location: 0, length: textStorage.length)) { attrs, range, _ in
                // Skip display-only image markdown headers
                if attrs[.imageMarkdownHeader] != nil { return }
                if let attachment = attrs[.attachment] as? ImageAttachment {
                    result += attachment.sourceMarkdown
                } else {
                    result += textStorage.attributedSubstring(from: range).string
                }
            }
            return result
        }

        /// Build display NSAttributedString from source markdown: syntax highlighting + image attachments.
        func buildDisplayText(from source: String, baseURL: URL?) -> NSAttributedString {
            let parser = MarkdownParser(baseFont: baseFont, textColor: textColor)
            let mutable = NSMutableAttributedString(attributedString: parser.parse(source))
            applyImageAttachments(to: mutable, baseURL: baseURL, resolvingAgainst: nil)
            return mutable
        }

        /// Scan for `![alt](path)` patterns, convert to ImageAttachment for inline rendering.
        func applyImageAttachments(to attrString: NSMutableAttributedString, baseURL: URL?, resolvingAgainst entryDir: URL?) {
            guard let baseURL = baseURL ?? entryDir else { return }

            let fullText = attrString.string
            guard let regex = try? NSRegularExpression(pattern: "!\\[([^\\]]*)\\]\\(([^)]+)\\)") else { return }
            let matches = regex.matches(in: fullText, range: NSRange(fullText.startIndex..., in: fullText))

            for match in matches.reversed() {
                guard match.numberOfRanges >= 3 else { continue }
                if attrString.attribute(.attachment, at: match.range.location, effectiveRange: nil) is ImageAttachment {
                    continue
                }

                let path = (fullText as NSString).substring(with: match.range(at: 2))

                // Absolute path: load directly. Relative path: resolve against baseURL.
                let imageURL: URL
                if path.hasPrefix("/") {
                    imageURL = URL(fileURLWithPath: path)
                } else if path.hasPrefix("http://") || path.hasPrefix("https://") {
                    continue // skip remote URLs
                } else {
                    imageURL = baseURL.appendingPathComponent(path)
                }

                guard let image = NSImage(contentsOf: imageURL) else { continue }

                let sourceMarkdown = (fullText as NSString).substring(with: match.range)
                let attachment = ImageAttachment.make(image: image, path: path, markdown: sourceMarkdown)
                attrString.replaceCharacters(in: match.range, with: NSAttributedString(attachment: attachment))
            }
        }

        // MARK: - Rendering

        /// Refresh display: rebuild from source to apply syntax highlighting + convert new image patterns.
        /// When `isImageExpanded` is true and cursor is still in the header area, skips rebuild entirely
        /// (the header is a display-only artifact that would be removed by a full rebuild).
        func refreshDisplay(baseURL: URL?) {
            guard let textView, let textStorage = textView.textStorage else { return }
            guard textStorage.length > 0 else { return }

            // When an image is expanded and the user is still editing the header, skip rebuild.
            if isImageExpanded {
                if let headerRange = findImageHeaderRange(in: textStorage) {
                    let cursorPos = textView.selectedRange().location
                    // +1 for the attachment char right after the header
                    if cursorPos >= headerRange.location && cursorPos <= NSMaxRange(headerRange) + 1 {
                        return
                    }
                }
                // Cursor left the expanded area — clean up header, then fall through to rebuild
                cleanupImageHeader(in: textStorage, textView: textView)
                isImageExpanded = false
            }

            let cursorPos = textView.selectedRange().location
            let source = reconstructSourceText(from: textStorage)
            let display = buildDisplayText(from: source, baseURL: baseURL)

            if textStorage.string == display.string { return }

            isInternalUpdate = true
            textView.undoManager?.disableUndoRegistration()
            textStorage.setAttributedString(display)
            textView.undoManager?.enableUndoRegistration()
            isInternalUpdate = false

            let newCursor = min(cursorPos, textStorage.length)
            textView.setSelectedRange(NSRange(location: newCursor, length: 0))
        }

        /// Find the range of the display-only image markdown header, if present.
        fileprivate func findImageHeaderRange(in textStorage: NSTextStorage) -> NSRange? {
            var found: NSRange?
            textStorage.enumerateAttribute(.imageMarkdownHeader, in: NSRange(location: 0, length: textStorage.length), options: []) { value, range, stop in
                if value != nil { found = range; stop.pointee = true }
            }
            return found
        }

        /// Remove the image markdown header and update the attachment's sourceMarkdown from the edited text.
        fileprivate func cleanupImageHeader(in textStorage: NSTextStorage, textView: NSTextView) {
            guard let headerRange = findImageHeaderRange(in: textStorage) else { return }

            let headerText = textStorage.attributedSubstring(from: headerRange).string
            let markdown = headerText.trimmingCharacters(in: .newlines)

            // Update the attachment right after the header
            let attachmentIdx = NSMaxRange(headerRange)
            if attachmentIdx < textStorage.length,
               let attachment = textStorage.attribute(.attachment, at: attachmentIdx, effectiveRange: nil) as? ImageAttachment {
                attachment.sourceMarkdown = markdown
            }

            // Remove header text, keep the attachment
            textStorage.replaceCharacters(in: headerRange, with: "")
        }

        private func scheduleRenderMarkdown() {
            markdownTimer?.invalidate()
            markdownTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
                guard let self, let tv = self.textView, !tv.hasMarkedText() else { return }
                self.refreshDisplay(baseURL: self.parent.groupDir)
            }
        }

        func setBaseStyle(font: NSFont, color: NSColor) {
            baseFont = font
            textColor = color
        }
    }
}
