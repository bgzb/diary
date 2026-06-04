import AppKit
import UniformTypeIdentifiers

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
