import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension NSAttributedString.Key {
    /// Marks a text run that is a display-only image markdown header (not part of the document source).
    static let imageMarkdownHeader = NSAttributedString.Key("com.diary.imageMarkdownHeader")
}

// MARK: - Image Attachment

final class ImageAttachment: NSTextAttachment {
    var sourceMarkdown: String = ""
    var imagePath: String = ""

    /// Resize preset widths (points)
    static let sizePresets: [(label: String, width: CGFloat)] = [
        ("Small", 150),
        ("Medium", 300),
        ("Large", 500),
        ("Original", 0),
    ]

    // MARK: - NSSecureCoding (survive internal copy/paste)

    // Required override — NSTextAttachment's designated initializer.
    override init(data: Data?, ofType: String?) {
        super.init(data: data, ofType: ofType)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        sourceMarkdown = coder.decodeObject(of: NSString.self, forKey: "sourceMarkdown") as String? ?? ""
        imagePath = coder.decodeObject(of: NSString.self, forKey: "imagePath") as String? ?? ""
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(sourceMarkdown, forKey: "sourceMarkdown")
        coder.encode(imagePath, forKey: "imagePath")
    }

    static func make(image: NSImage, path: String, markdown: String, maxWidth: CGFloat = 300) -> ImageAttachment {
        let a = ImageAttachment(data: nil, ofType: nil)
        a.image = image
        a.imagePath = path
        a.sourceMarkdown = markdown
        a.applyWidth(maxWidth)
        return a
    }

    func applyWidth(_ width: CGFloat) {
        guard let image = image else { return }
        let size = image.size
        if width <= 0 || size.width <= width {
            bounds = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        } else {
            let ratio = width / size.width
            bounds = NSRect(x: 0, y: 0, width: width, height: size.height * ratio)
        }
    }

    var displayWidth: CGFloat {
        bounds.width
    }
}

// MARK: - NSTextView subclass

final class EditorTextView: NSTextView {
    var groupDir: URL?

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

    // MARK: - Image Interaction

    override func mouseDown(with event: NSEvent) {
        // If an image is already expanded, let super handle the click (cursor placement / collapse).
        if (delegate as? MarkdownEditorView.Coordinator)?.isImageExpanded == true {
            super.mouseDown(with: event)
            return
        }

        // Check if clicking on an ImageAttachment → show markdown header above image.
        var handled = false
        if let textContainer = textContainer, let lm = layoutManager, let ts = textStorage {
            let point = convert(event.locationInWindow, from: nil)

            var attachments: [(ImageAttachment, NSRange)] = []
            ts.enumerateAttribute(.attachment, in: NSRange(location: 0, length: ts.length), options: []) { value, range, _ in
                if let a = value as? ImageAttachment { attachments.append((a, range)) }
            }

            for (attachment, range) in attachments {
                let glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                var rect = lm.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                rect = rect.insetBy(dx: -2, dy: -2)
                if NSPointInRect(point, rect) {
                    handled = true
                    let header = attachment.sourceMarkdown + "\n"
                    let headerAttr = NSAttributedString(string: header, attributes: [
                        .imageMarkdownHeader: true,
                        .font: (font ?? NSFont.systemFont(ofSize: 13)).withSize(13),
                        .foregroundColor: NSColor.tertiaryLabelColor,
                    ])

                    let coordinator = delegate as? MarkdownEditorView.Coordinator
                    coordinator?.isInternalUpdate = true
                    coordinator?.isImageExpanded = true

                    ts.beginEditing()
                    ts.insert(headerAttr, at: range.location)
                    ts.endEditing()

                    setSelectedRange(NSRange(location: range.location, length: header.count - 1))
                    didChangeText()

                    coordinator?.isInternalUpdate = false
                    break
                }
            }
        }
        guard handled else {
            super.mouseDown(with: event)
            return
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event)

        // Only add image size options when right-clicking on an ImageAttachment
        guard let menu = menu,
              let textContainer = textContainer,
              let lm = layoutManager else { return menu }

        let point = convert(event.locationInWindow, from: nil)
        let idx = lm.characterIndex(for: point, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        guard idx < textStorage?.length ?? 0,
              let attachment = textStorage?.attribute(.attachment, at: idx, effectiveRange: nil) as? ImageAttachment else {
            return menu
        }

        menu.insertItem(.separator(), at: 0)
        for preset in ImageAttachment.sizePresets {
            let item = NSMenuItem(title: preset.label, action: #selector(resizeImage(_:)), keyEquivalent: "")
            item.representedObject = (attachment: attachment, width: preset.width)
            item.target = self
            menu.insertItem(item, at: 0)
        }
        let titleItem = NSMenuItem(title: "Image Size", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        titleItem.attributedTitle = NSAttributedString(
            string: "Image Size",
            attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .semibold)]
        )
        menu.insertItem(titleItem, at: 0)

        return menu
    }

    @objc private func resizeImage(_ sender: NSMenuItem) {
        guard let (attachment, width) = sender.representedObject as? (ImageAttachment, CGFloat) else { return }
        attachment.applyWidth(width)
        // Force text view to re-layout the attachment
        textStorage?.edited(.editedAttributes, range: NSRange(location: 0, length: textStorage?.length ?? 0), changeInLength: 0)
        setNeedsDisplay(bounds)
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard(name: .general)
        let types = pasteboard.types ?? []

        // 1. Internal copy/paste: if pasteboard has RTF/RTFD, let NSTextView deserialize.
        let internalTypes: Set<NSPasteboard.PasteboardType> = [.rtf, .rtfd]
        if !internalTypes.isDisjoint(with: types) {
            super.paste(sender)
            return
        }

        guard let groupDir = groupDir else {
            super.paste(sender)
            return
        }

        // 2. File URLs (Finder copy) → insert markdown with absolute path, no copy.
        //     Must check BEFORE raw data, because Finder also provides image data.
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first, isImageFile(url) {
            let markdown = "![](\(url.path))"
            (delegate as? MarkdownEditorView.Coordinator)?.isImageExpanded = false
            insertText(markdown, replacementRange: selectedRange())
            return
        }

        // 3. External image (screenshot / browser copy) → save raw data, no conversion.
        var imageData: Data?
        var ext = "png"

        if let data = pasteboard.data(forType: .png) {
            imageData = data; ext = "png"
        } else if let data = pasteboard.data(forType: .tiff) {
            imageData = data; ext = "tiff"
        }

        if let data = imageData, let img = NSImage(data: data), img.size.width > 0,
           let fileURL = saveImageData(data, ext: ext, groupDir: groupDir) {
            let relativePath = "assets/" + fileURL.lastPathComponent
            let markdown = "![](\(relativePath))"
            let attachment = ImageAttachment.make(image: img, path: relativePath, markdown: markdown)
            let attachmentStr = NSAttributedString(attachment: attachment)
            let sel = selectedRange()
            textStorage?.replaceCharacters(in: sel, with: attachmentStr)
            setSelectedRange(NSRange(location: sel.location + 1, length: 0))
            didChangeText()
            (delegate as? MarkdownEditorView.Coordinator)?.isImageExpanded = false
            return
        }

        // 4. Fall back to system paste for plain text.
        super.paste(sender)
    }

    // MARK: - Drag & Drop

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        guard let groupDir = groupDir else { return false }

        // Any new image insertion cancels the previous image-expanded state
        (delegate as? MarkdownEditorView.Coordinator)?.isImageExpanded = false

        // File URLs from Finder → reference absolute path, no copy.
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first,
           isImageFile(url) {
            let markdown = "![](\(url.path))"
            insertText(markdown, replacementRange: selectedRange())
            return true
        }

        // Image data (e.g. from browser) — only accept raw data, no conversion.
        var dragImageData: Data?
        var dragExt = "png"
        if let data = pasteboard.data(forType: .png) {
            dragImageData = data; dragExt = "png"
        } else if let data = pasteboard.data(forType: .tiff) {
            dragImageData = data; dragExt = "tiff"
        }

        if let data = dragImageData, !data.isEmpty,
           let img = NSImage(data: data),
           let fileURL = saveImageData(data, ext: dragExt, groupDir: groupDir) {
            let relativePath = "assets/" + fileURL.lastPathComponent
            let markdown = "![](\(relativePath))"
            let attachment = ImageAttachment.make(image: img, path: relativePath, markdown: markdown)
            let attachmentStr = NSAttributedString(attachment: attachment)
            let sel = selectedRange()
            textStorage?.replaceCharacters(in: sel, with: attachmentStr)
            setSelectedRange(NSRange(location: sel.location + 1, length: 0))
            didChangeText()
            return true
        }

        return super.performDragOperation(sender)
    }

    private func isImageFile(_ url: URL) -> Bool {
        let imageExts: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "tiff", "tif", "bmp", "heic", "heif"]
        return imageExts.contains(url.pathExtension.lowercased())
    }

    private func saveImageData(_ data: Data, ext: String, groupDir: URL) -> URL? {
        let assetsDir = groupDir.appendingPathComponent("assets")
        try? FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd_HHmmss"
        let ts = fmt.string(from: Date())
        let filename = "image_\(ts)_\(UUID().uuidString.prefix(6)).\(ext)"
        let fileURL = assetsDir.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
}

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
        fileprivate var isInternalUpdate = false
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
