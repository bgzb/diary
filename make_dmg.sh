#!/bin/bash
set -e
cd "$(dirname "$0")"

APP_NAME="Diary"
VOL_NAME="Diary"
DMG_NAME="Diary.dmg"
DMG_TMP="Diary_rw.dmg"
BG_NAME="bg.png"

# ── Build app ──
./build.sh

# ── Detect system appearance ──
if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -q Dark; then
    COLOR_MODE="dark"
    echo "Theme: dark → charcoal gradient + label plates for readability"
else
    COLOR_MODE="light"
    echo "Theme: light → warm paper gradient background (Finder black labels)"
fi

# ── Generate gradient background ──
echo "Generating background..."
swift - <<'SWIFT' /tmp/${BG_NAME} $COLOR_MODE
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let width = 600, height = 400
let isDark = CommandLine.arguments.count > 2 && CommandLine.arguments[2] == "dark"

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

// ── Draw gradient ──
let topColor: CGColor
let bottomColor: CGColor

if isDark {
    topColor    = CGColor(red: 0.227, green: 0.227, blue: 0.227, alpha: 1.0)  // #3A3A3A
    bottomColor = CGColor(red: 0.145, green: 0.145, blue: 0.145, alpha: 1.0)  // #252525
} else {
    topColor    = CGColor(red: 0.996, green: 0.988, blue: 0.973, alpha: 1.0) // #FEFCF8
    bottomColor = CGColor(red: 0.961, green: 0.929, blue: 0.878, alpha: 1.0) // #F5EDE0
}

let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [topColor, bottomColor] as CFArray,
    locations: [0.0, 1.0]
)!

let ctx = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

ctx.drawLinearGradient(gradient,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: 0, y: CGFloat(height)),
    options: []
)

// ── Dark mode: draw light label plates so black text is readable ──
// Finder: Diary.app {180,180} sz=80, Applications {420,180} sz=80
// Icon bottom at Finder y=260. Label at Finder y≈270..294.
// CG y = 400 − Finder y → CG label: y=106..130
if isDark {
    let plateColor = CGColor(red: 0.90, green: 0.88, blue: 0.85, alpha: 0.88)
    ctx.setFillColor(plateColor)

    let diaryRect = CGRect(x: 165, y: 106, width: 110, height: 24)
    let appsRect  = CGRect(x: 390, y: 106, width: 140, height: 24)

    let p1 = CGPath(roundedRect: diaryRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
    ctx.addPath(p1)
    ctx.fillPath()

    let p2 = CGPath(roundedRect: appsRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
    ctx.addPath(p2)
    ctx.fillPath()
}

let image = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
SWIFT

# ── Clean old DMG ──
rm -f "$DMG_NAME" "$DMG_TMP"

# ── Create staging directory ──
STAGING="$(mktemp -d)"

# Copy app + symlink
cp -R "$APP_NAME.app" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# Copy background into hidden .background folder
mkdir -p "$STAGING/.background"
cp "/tmp/${BG_NAME}" "$STAGING/.background/${BG_NAME}"

# ── Create read-write DMG from staging ──
echo "Creating DMG..."
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    "$DMG_TMP" > /dev/null

# ── Mount read-write ──
DEVICE=$(hdiutil attach -readwrite -nobrowse "$DMG_TMP" 2>&1 | tee /dev/stderr | head -1 | awk '{print $1}')
echo "Mounted at /Volumes/${VOL_NAME} (device: $DEVICE)"

# ── Configure Finder window via AppleScript ──
# Key: a single open–configure–update–close cycle lets Finder detect
# background brightness and pick the right label color (white on dark, black on light).
echo "Configuring Finder window..."
osascript <<'APPLESCRIPT'
tell application "Finder"
    tell disk "Diary"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 200, 1000, 600}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        set background picture of theViewOptions to file ".background:bg.png"
        set position of item "Diary.app" of container window to {180, 180}
        set position of item "Applications" of container window to {420, 180}
        update without registering applications
        delay 1
    end tell
end tell
APPLESCRIPT

sleep 1

# ── Unmount ──
echo "Unmounting..."
hdiutil detach "$DEVICE" -force 2>/dev/null || true
hdiutil detach "/Volumes/${VOL_NAME}" -force 2>/dev/null || true

# ── Convert to compressed read-only DMG ──
echo "Compressing DMG..."
hdiutil convert "$DMG_TMP" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_NAME" > /dev/null

# ── Sign the DMG ──
echo "Signing DMG..."
codesign --force --sign - "$DMG_NAME" 2>/dev/null || true

# ── Cleanup ──
rm -f "$DMG_TMP"
rm -rf "$STAGING"
rm -f "/tmp/${BG_NAME}"

echo ""
echo "✅ ${DMG_NAME} ready ($(du -h ${DMG_NAME} | cut -f1))"
echo ""
echo "📦 分发说明："
echo "   用户从 GitHub 下载后，首次打开需要："
echo "   右键点击 Diary.app → 打开 → 仍要打开"
echo "   （因为未使用 Apple Developer ID 签名，macOS Gatekeeper 会拦截）"
