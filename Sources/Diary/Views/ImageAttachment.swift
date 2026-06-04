import AppKit

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
