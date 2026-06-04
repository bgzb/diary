#!/usr/bin/env swift
import AppKit

/// Generate a diary app icon — an open journal with a bookmark ribbon.
/// Runs standalone: `swift icon_generator.swift`

let sizes: [(width: Int, height: Int, name: String)] = [
    (16,   16,   "icon_16x16.png"),
    (32,   32,   "icon_16x16@2x.png"),
    (32,   32,   "icon_32x32.png"),
    (64,   64,   "icon_32x32@2x.png"),
    (128,  128,  "icon_128x128.png"),
    (256,  256,  "icon_128x128@2x.png"),
    (256,  256,  "icon_256x256.png"),
    (512,  512,  "icon_256x256@2x.png"),
    (512,  512,  "icon_512x512.png"),
    (1024, 1024, "icon_512x512@2x.png"),
]

let iconset = "AppIcon.iconset"
let fm = FileManager.default
let cwd = fm.currentDirectoryPath
let dir = URL(fileURLWithPath: cwd).appendingPathComponent(iconset)

try? fm.removeItem(at: dir)
try fm.createDirectory(at: dir, withIntermediateDirectories: true)

for size in sizes {
    let w = CGFloat(size.width)
    let h = CGFloat(size.height)

    let image = NSImage(size: NSSize(width: w, height: h))
    image.lockFocus()

    // ── Background: rounded rect ──
    let bgPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: w, height: h),
                              xRadius: w * 0.225, yRadius: h * 0.225)
    // Warm amber-to-coral gradient (journal feel)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.95, green: 0.50, blue: 0.25, alpha: 1.0),  // warm orange
        NSColor(calibratedRed: 0.85, green: 0.25, blue: 0.20, alpha: 1.0),  // deep coral
    ])!
    gradient.draw(in: bgPath, angle: 135)

    // ── Pages (white, slight left-of-center) ──
    let pageInsetX = w * 0.22
    let pageInsetY = h * 0.16
    let pageWidth  = (w - pageInsetX * 2) * 0.58
    let pageHeight = h - pageInsetY * 2
    let pageX = w * 0.20

    // Right page (slightly offset — open book feel)
    let rightPage = NSBezierPath(roundedRect: NSRect(x: pageX + pageWidth * 0.35,
                                                     y: pageInsetY,
                                                     width: pageWidth,
                                                     height: pageHeight),
                                 xRadius: w * 0.03, yRadius: h * 0.03)
    NSColor.white.withAlphaComponent(0.92).setFill()
    rightPage.fill()

    // Left page
    let leftPage = NSBezierPath(roundedRect: NSRect(x: pageX - pageWidth * 0.10,
                                                    y: pageInsetY,
                                                    width: pageWidth,
                                                    height: pageHeight),
                                xRadius: w * 0.03, yRadius: h * 0.03)
    NSColor.white.withAlphaComponent(0.85).setFill()
    leftPage.fill()

    // ── Text lines on pages ──
    let lineColor = NSColor(calibratedRed: 0.75, green: 0.78, blue: 0.82, alpha: 1.0)
    lineColor.setStroke()
    let lineStart = pageX + pageWidth * 0.20
    let lineEnd   = pageX + pageWidth * 0.85
    let lineY0    = pageInsetY + pageHeight * 0.78
    let spacing   = h * 0.065

    for i in 0..<5 {
        let y = lineY0 - CGFloat(i) * spacing
        let line = NSBezierPath()
        line.lineWidth = max(w * 0.012, 1)
        line.move(to: NSPoint(x: lineStart, y: y))
        line.line(to: NSPoint(x: lineEnd, y: y))
        line.stroke()
    }

    // ── Ribbon bookmark (top edge) ──
    let ribbonColor = NSColor(calibratedRed: 0.92, green: 0.78, blue: 0.35, alpha: 1.0)  // gold
    let ribbonPath = NSBezierPath()
    let ribbonX = pageX + pageWidth * 0.18
    let ribbonW = w * 0.08
    let ribbonTop = pageInsetY + pageHeight
    let ribbonBottom = h * 0.20
    ribbonPath.move(to: NSPoint(x: ribbonX, y: ribbonTop))
    ribbonPath.line(to: NSPoint(x: ribbonX + ribbonW, y: ribbonTop))
    ribbonPath.line(to: NSPoint(x: ribbonX + ribbonW * 0.55, y: ribbonBottom + h * 0.04))
    ribbonPath.line(to: NSPoint(x: ribbonX + ribbonW * 0.5, y: ribbonBottom))
    ribbonPath.line(to: NSPoint(x: ribbonX + ribbonW * 0.45, y: ribbonBottom + h * 0.04))
    ribbonPath.close()
    ribbonColor.setFill()
    ribbonPath.fill()

    // ── Subtle inner shadow on pages (spine line) ──
    let spineColor = NSColor(calibratedRed: 0.82, green: 0.84, blue: 0.86, alpha: 0.6)
    spineColor.setStroke()
    let spineX = pageX + pageWidth * 0.30
    let spine = NSBezierPath()
    spine.lineWidth = max(w * 0.008, 0.5)
    spine.move(to: NSPoint(x: spineX, y: pageInsetY + pageHeight * 0.08))
    spine.line(to: NSPoint(x: spineX, y: pageInsetY + pageHeight * 1.05))
    spine.stroke()

    image.unlockFocus()

    // ── Write PNG ──
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("ERROR: could not get cgImage for \(size.name)")
        continue
    }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    rep.size = NSSize(width: w, height: h)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        print("ERROR: could not encode \(size.name)")
        continue
    }
    try data.write(to: dir.appendingPathComponent(size.name))
    print("  ✓ \(size.name) (\(Int(w))×\(Int(h)))")
}

// ── Create .icns via iconutil ──
print("\nRunning iconutil...")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", dir.path, "-o", "\(cwd)/AppIcon.icns"]
task.currentDirectoryURL = URL(fileURLWithPath: cwd)
try task.run()
task.waitUntilExit()

if task.terminationStatus == 0 {
    print("✅ AppIcon.icns created")
} else {
    print("❌ iconutil failed with exit code \(task.terminationStatus)")
}
