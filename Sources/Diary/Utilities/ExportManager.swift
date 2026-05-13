import AppKit
import UniformTypeIdentifiers

enum ExportFormat: CaseIterable {
    case text, html, pdf

    var fileExtension: String {
        switch self {
        case .text: return "txt"
        case .html: return "html"
        case .pdf:  return "pdf"
        }
    }

    var utType: UTType {
        switch self {
        case .text: return .plainText
        case .html: return .html
        case .pdf:  return .pdf
        }
    }

    func displayName(_ lang: AppLanguage) -> String {
        switch self {
        case .text: return L.string(.exportText, lang: lang)
        case .html: return L.string(.exportHTML, lang: lang)
        case .pdf:  return L.string(.exportPDF, lang: lang)
        }
    }
}

enum ExportManager {

    static func export(entry: Entry, settings: SettingsStore) {
        let panel = NSSavePanel()
        panel.title = L.string(.exportTitle, lang: settings.appLanguage)
        panel.nameFieldStringValue = "\(entry.title).txt"
        panel.allowedContentTypes = ExportFormat.allCases.map { $0.utType }

        // Format picker accessory view
        let popup = NSPopUpButton(frame: NSRect(x: 78, y: 3, width: 182, height: 22))
        popup.font = .systemFont(ofSize: NSFont.systemFontSize)
        for fmt in ExportFormat.allCases {
            popup.addItem(withTitle: fmt.displayName(settings.appLanguage))
            popup.lastItem?.representedObject = fmt
        }

        let fmtLabel = NSTextField(labelWithString:
            settings.appLanguage.resolved == .chinese ? "格式：" : "Format:")
        fmtLabel.frame = NSRect(x: 0, y: 6, width: 74, height: 17)
        fmtLabel.alignment = .right
        fmtLabel.font = .systemFont(ofSize: 11)

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 270, height: 30))
        accessory.addSubview(fmtLabel)
        accessory.addSubview(popup)
        panel.accessoryView = accessory

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let format = popup.selectedItem?.representedObject as? ExportFormat ?? .text

        switch format {
        case .text:
            try? entry.content.write(to: url, atomically: true, encoding: .utf8)
        case .html:
            let html = generateHTML(entry: entry)
            try? html.write(to: url, atomically: true, encoding: .utf8)
        case .pdf:
            generatePDF(entry: entry, settings: settings, url: url)
        }
    }

    // MARK: - HTML

    private static func generateHTML(entry: Entry) -> String {
        """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <title>\(escapeHTML(entry.title))</title>
        <style>
          body { font-family: -apple-system, "Helvetica Neue", sans-serif;
                 max-width: 720px; margin: 2em auto; padding: 0 1em;
                 line-height: 1.7; color: #222; }
          h1 { font-size: 2em; border-bottom: 2px solid #eee; padding-bottom: 0.2em; }
          h2 { font-size: 1.5em; }
          h3 { font-size: 1.25em; }
          h4, h5, h6 { font-size: 1.1em; }
          code { background: #f4f4f4; padding: 0.15em 0.3em; border-radius: 3px;
                 font-family: "SF Mono", Menlo, monospace; font-size: 0.9em; }
          pre { background: #f4f4f4; padding: 0.8em; border-radius: 6px; overflow-x: auto; }
          pre code { background: none; padding: 0; }
          blockquote { border-left: 3px solid #ccc; margin: 0; padding: 0 1em; color: #555; }
          hr { border: none; border-top: 1px solid #ddd; margin: 1.5em 0; }
          table { border-collapse: collapse; }
          th, td { border: 1px solid #ddd; padding: 0.4em 0.8em; }
          img { max-width: 100%; }
        </style>
        </head>
        <body>
        \(markdownToHTML(entry.content))
        </body>
        </html>
        """
    }

    private static func markdownToHTML(_ text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        var result = ""
        var inCodeBlock = false

        for line in lines {
            if line.hasPrefix("```") {
                if inCodeBlock {
                    result += "</code></pre>\n"
                    inCodeBlock = false
                } else {
                    result += "<pre><code>"
                    inCodeBlock = true
                }
                continue
            }
            if inCodeBlock {
                result += escapeHTML(line) + "\n"
                continue
            }

            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                result += "\n"
                continue
            }

            // Heading
            if let match = try? NSRegularExpression(pattern: "^(#{1,6})\\s+(.+)").firstMatch(
                in: line, range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges >= 3,
               let markerR = Range(match.range(at: 1), in: line),
               let contentR = Range(match.range(at: 2), in: line) {
                let level = markerR.upperBound.utf16Offset(in: line) - markerR.lowerBound.utf16Offset(in: line)
                result += "<h\(level)>\(inlineHTML(String(line[contentR])))</h\(level)>\n"
                continue
            }

            // Horizontal rule
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if ["---", "***", "___"].contains(trimmed) {
                result += "<hr>\n"
                continue
            }

            // Blockquote
            if let match = try? NSRegularExpression(pattern: "^>\\s?(.*)").firstMatch(
                in: line, range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges >= 2,
               let contentR = Range(match.range(at: 1), in: line) {
                result += "<blockquote><p>\(inlineHTML(String(line[contentR])))</p></blockquote>\n"
                continue
            }

            // Unordered list
            if let match = try? NSRegularExpression(pattern: "^(\\s*)[-*+]\\s(.+)").firstMatch(
                in: line, range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges >= 3,
               let contentR = Range(match.range(at: 2), in: line) {
                result += "<li>\(inlineHTML(String(line[contentR])))</li>\n"
                continue
            }

            // Ordered list
            if let match = try? NSRegularExpression(pattern: "^(\\s*)\\d+\\.\\s(.+)").firstMatch(
                in: line, range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges >= 3,
               let contentR = Range(match.range(at: 2), in: line) {
                result += "<li>\(inlineHTML(String(line[contentR])))</li>\n"
                continue
            }

            // Paragraph
            result += "<p>\(inlineHTML(line))</p>\n"
        }

        if inCodeBlock {
            result += "</code></pre>\n"
        }

        return result
    }

    private static func inlineHTML(_ text: String) -> String {
        var s = escapeHTML(text)
        s = s.replacingOccurrences(of: "\\*\\*\\*(.+?)\\*\\*\\*", with: "<strong><em>$1</em></strong>", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "<strong>$1</strong>", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)", with: "<em>$1</em>", options: .regularExpression)
        s = s.replacingOccurrences(of: "~~(.+?)~~", with: "<del>$1</del>", options: .regularExpression)
        s = s.replacingOccurrences(of: "`(.+?)`", with: "<code>$1</code>", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\[(.+?)\\]\\((.+?)\\)", with: "<a href=\"$2\">$1</a>", options: .regularExpression)
        s = s.replacingOccurrences(of: "!\\[(.+?)\\]\\((.+?)\\)", with: "<img src=\"$2\" alt=\"$1\">", options: .regularExpression)
        return s
    }

    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    // MARK: - PDF

    private static func generatePDF(entry: Entry, settings: SettingsStore, url: URL) {
        let font = settings.editorFont.nsFont.withSize(settings.editorFontSize)
        let parser = MarkdownParser(baseFont: font, textColor: .black)
        let attrString = parser.parse(entry.content)

        let pageWidth: CGFloat = 595
        let margin: CGFloat = 40
        let textWidth = pageWidth - margin * 2

        // Measure content height
        let container = NSTextContainer(size: NSSize(width: textWidth, height: .greatestFiniteMagnitude))
        let lm = NSLayoutManager()
        let ts = NSTextStorage(attributedString: attrString)
        lm.addTextContainer(container)
        ts.addLayoutManager(lm)
        lm.ensureLayout(for: container)
        let textHeight = lm.usedRect(for: container).height

        // Render into a single page view
        let pageHeight = max(textHeight + margin * 2 + 20, 842)
        let pageView = NSView(frame: NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let textViewY = pageHeight - margin - textHeight - 8
        let textView = NSTextView(frame: NSRect(x: margin, y: textViewY, width: textWidth, height: textHeight + 8))
        textView.textStorage?.setAttributedString(attrString)
        textView.drawsBackground = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        pageView.addSubview(textView)

        let pdfData = pageView.dataWithPDF(inside: pageView.bounds)
        try? pdfData.write(to: url)
    }
}
