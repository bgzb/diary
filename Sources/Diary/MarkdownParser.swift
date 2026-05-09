import AppKit

struct MarkdownParser {
    let baseFont: NSFont
    let textColor: NSColor

    private var markerFont: NSFont {
        baseFont.withSize(max(8, baseFont.pointSize * 0.6))
    }
    private var markerColor: NSColor {
        textColor.withAlphaComponent(0.22)
    }

    func parse(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let paragraphs = text.components(separatedBy: "\n")

        for (i, line) in paragraphs.enumerated() {
            if i > 0 { result.append(NSAttributedString(string: "\n")) }
            if line.isEmpty { continue }

            if let heading = parseHeading(line) {
                result.append(heading)
            } else if let hr = parseHorizontalRule(line) {
                result.append(hr)
            } else if let blockquote = parseBlockquote(line) {
                result.append(blockquote)
            } else if let list = parseUnorderedList(line) {
                result.append(list)
            } else if let list = parseOrderedList(line) {
                result.append(list)
            } else {
                result.append(parseInline(line))
            }
        }

        return result
    }

    // MARK: - Block elements

    private func parseHeading(_ line: String) -> NSAttributedString? {
        guard let match = try? NSRegularExpression(pattern: "^(#{1,6})\\s+(.+)").firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges >= 3 else { return nil }

        let markerRange = match.range(at: 1)
        let contentRange = match.range(at: 2)
        let level = markerRange.length
        let scale: CGFloat = [0, 2.0, 1.5, 1.25, 1.1, 1.0, 0.9][level]
        let contentFont = NSFont(descriptor: baseFont.fontDescriptor.withSymbolicTraits(.bold), size: baseFont.pointSize * scale) ?? baseFont

        let attr = NSMutableAttributedString()
        let marker = String(line[Range(markerRange, in: line)!])
        attr.append(NSAttributedString(string: marker + " ", attributes: [
            .font: markerFont, .foregroundColor: markerColor,
        ]))
        let content = String(line[Range(contentRange, in: line)!])
        attr.append(parseInline(content, font: contentFont))
        return attr
    }

    private func parseHorizontalRule(_ line: String) -> NSAttributedString? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard ["---", "***", "___"].contains(trimmed) else { return nil }
        return NSAttributedString(string: line, attributes: [
            .font: markerFont, .foregroundColor: markerColor,
        ])
    }

    private func parseBlockquote(_ line: String) -> NSAttributedString? {
        guard let match = try? NSRegularExpression(pattern: "^>\\s?(.*)").firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { return nil }
        let attr = NSMutableAttributedString()
        attr.append(NSAttributedString(string: "> ", attributes: [
            .font: markerFont, .foregroundColor: markerColor,
        ]))
        if match.numberOfRanges >= 2, let contentRange = Range(match.range(at: 1), in: line) {
            attr.append(parseInline(String(line[contentRange])))
        }
        attr.addAttribute(.foregroundColor, value: textColor.withAlphaComponent(0.75), range: NSRange(location: 0, length: attr.length))
        return attr
    }

    private func parseUnorderedList(_ line: String) -> NSAttributedString? {
        guard let match = try? NSRegularExpression(pattern: "^(\\s*)([-*+])\\s(.+)").firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges >= 4 else { return nil }
        let attr = NSMutableAttributedString()
        if let indentRange = Range(match.range(at: 1), in: line) {
            let indent = String(line[indentRange])
            if !indent.isEmpty {
                attr.append(NSAttributedString(string: indent, attributes: [.font: baseFont, .foregroundColor: textColor]))
            }
        }
        if let markerRange = Range(match.range(at: 2), in: line) {
            attr.append(NSAttributedString(string: String(line[markerRange]) + " ", attributes: [
                .font: markerFont, .foregroundColor: markerColor,
            ]))
        }
        if let contentRange = Range(match.range(at: 3), in: line) {
            attr.append(parseInline(String(line[contentRange])))
        }
        return attr
    }

    private func parseOrderedList(_ line: String) -> NSAttributedString? {
        guard let match = try? NSRegularExpression(pattern: "^(\\s*)(\\d+)\\.\\s(.+)").firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges >= 4 else { return nil }
        let attr = NSMutableAttributedString()
        if let indentRange = Range(match.range(at: 1), in: line) {
            let indent = String(line[indentRange])
            if !indent.isEmpty {
                attr.append(NSAttributedString(string: indent, attributes: [.font: baseFont, .foregroundColor: textColor]))
            }
        }
        if let numRange = Range(match.range(at: 2), in: line) {
            attr.append(NSAttributedString(string: String(line[numRange]) + ". ", attributes: [
                .font: markerFont, .foregroundColor: markerColor,
            ]))
        }
        if let contentRange = Range(match.range(at: 3), in: line) {
            attr.append(parseInline(String(line[contentRange])))
        }
        return attr
    }

    // MARK: - Inline elements

    func parseInline(_ text: String, font: NSFont? = nil) -> NSAttributedString {
        let f = font ?? baseFont
        let result = NSMutableAttributedString()
        var remaining = text

        let patterns: [(String, (String) -> [NSAttributedString.Key: Any])] = [
            ("\\*\\*\\*(.+?)\\*\\*\\*", { _ in
                let fd = f.fontDescriptor.withSymbolicTraits([.bold, .italic])
                return [.font: NSFont(descriptor: fd, size: f.pointSize) ?? f, .foregroundColor: self.textColor]
            }),
            ("\\*\\*(.+?)\\*\\*", { _ in
                let fd = f.fontDescriptor.withSymbolicTraits(.bold)
                return [.font: NSFont(descriptor: fd, size: f.pointSize) ?? f, .foregroundColor: self.textColor]
            }),
            ("(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)", { _ in
                let fd = f.fontDescriptor.withSymbolicTraits(.italic)
                return [.font: NSFont(descriptor: fd, size: f.pointSize) ?? f, .foregroundColor: self.textColor]
            }),
            ("~~(.+?)~~", { _ in
                [.font: f, .foregroundColor: self.textColor, .strikethroughStyle: NSUnderlineStyle.single.rawValue]
            }),
            ("`(.+?)`", { _ in
                [.font: NSFont.monospacedSystemFont(ofSize: f.pointSize * 0.9, weight: .regular),
                 .foregroundColor: self.textColor,
                 .backgroundColor: self.textColor.withAlphaComponent(0.08)]
            }),
        ]

        while !remaining.isEmpty {
            var earliestMatch: (NSRange, [NSAttributedString.Key: Any])?
            var earliestIndex = remaining.count

            for (pattern, attrsFn) in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: remaining, range: NSRange(remaining.startIndex..., in: remaining)) else { continue }
                if match.range.location < earliestIndex {
                    let content = String(remaining[Range(match.range(at: 1), in: remaining)!])
                    earliestMatch = (match.range, attrsFn(content))
                    earliestIndex = match.range.location
                }
            }

            if let (matchRange, attrs) = earliestMatch, earliestIndex < remaining.count {
                if earliestIndex > 0 {
                    let before = String(remaining[remaining.startIndex..<remaining.index(remaining.startIndex, offsetBy: earliestIndex)])
                    result.append(NSAttributedString(string: before, attributes: [.font: f, .foregroundColor: textColor]))
                }

                let fullMatchStr = String(remaining[Range(matchRange, in: remaining)!])
                let cs: Int
                if fullMatchStr.hasPrefix("***") { cs = 3 }
                else if fullMatchStr.hasPrefix("**") || fullMatchStr.hasPrefix("~~") { cs = 2 }
                else { cs = 1 }

                let ce = fullMatchStr.count - cs
                if cs > 0 {
                    result.append(NSAttributedString(string: String(fullMatchStr.prefix(cs)), attributes: [
                        .font: markerFont, .foregroundColor: markerColor,
                    ]))
                }
                let content = String(fullMatchStr.dropFirst(cs).dropLast(fullMatchStr.count - ce))
                result.append(NSAttributedString(string: content, attributes: attrs))
                if fullMatchStr.count - ce > 0 {
                    result.append(NSAttributedString(string: String(fullMatchStr.suffix(fullMatchStr.count - ce)), attributes: [
                        .font: markerFont, .foregroundColor: markerColor,
                    ]))
                }

                let advanceIndex = remaining.index(remaining.startIndex, offsetBy: matchRange.location + matchRange.length)
                remaining = String(remaining[advanceIndex...])
            } else {
                result.append(NSAttributedString(string: remaining, attributes: [.font: f, .foregroundColor: textColor]))
                break
            }
        }

        return result
    }
}
