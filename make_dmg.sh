#!/bin/bash
set -e
cd "$(dirname "$0")"

# ── Build app ──
./build.sh

# ── Warm paper gradient background (always light — Finder labels are black) ──
swift - <<'SWIFT' /tmp/dmg_bg.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let w = 600, h = 400
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                    bytesPerRow: w * 4, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

let gradient = CGGradient(colorsSpace: cs,
    colors: [CGColor(red: 0.996, green: 0.988, blue: 0.973, alpha: 1.0),
             CGColor(red: 0.961, green: 0.929, blue: 0.878, alpha: 1.0)] as CFArray,
    locations: [0.0, 1.0])!

ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0),
                       end: CGPoint(x: 0, y: CGFloat(h)), options: [])

let img = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dst, img, nil)
CGImageDestinationFinalize(dst)
SWIFT

# ── Clean old artifacts ──
rm -f Diary.dmg Diary_rw.dmg

# ── Stage: .app + Applications symlink + hidden background ──
STAGING=$(mktemp -d)
cp -R Diary.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"
mkdir -p "$STAGING/.background"
cp /tmp/dmg_bg.png "$STAGING/.background/bg.png"

# ── Create read-write DMG ──
hdiutil create -volname Diary -srcfolder "$STAGING" -ov \
    -format UDRW -fs HFS+ Diary_rw.dmg > /dev/null

# ── Mount ──
DEV=$(hdiutil attach -readwrite Diary_rw.dmg 2>&1 | head -1 | awk '{print $1}')
sleep 2

# ── Configure Finder window (open → set → close, in one clean pass) ──
osascript <<'OSA'
tell application "Finder"
    tell disk "Diary"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 200, 1000, 600}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 80
        set background picture of opts to POSIX file "/Volumes/Diary/.background/bg.png"
        set position of item "Diary.app" of container window to {160, 140}
        set position of item "Applications" of container window to {380, 140}
        update without registering applications
    end tell
end tell
OSA

# Let Finder settle, then detach — Finder saves .DS_Store on forced eject
sleep 3

# Force eject: Finder writes window state to .DS_Store before releasing the volume
hdiutil detach "$DEV" -force 2>/dev/null || true
hdiutil detach /Volumes/Diary -force 2>/dev/null || true
sleep 1

# ── Convert to compressed read-only ──
hdiutil convert Diary_rw.dmg -format UDZO -imagekey zlib-level=9 \
    -o Diary.dmg > /dev/null

# ── Sign ──
codesign --force --sign - Diary.dmg 2>/dev/null || true

# ── Cleanup ──
rm -f Diary_rw.dmg /tmp/dmg_bg.png
rm -rf "$STAGING"

echo "✅ Diary.dmg ready ($(du -h Diary.dmg | cut -f1))"
