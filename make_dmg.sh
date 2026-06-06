#!/bin/bash
set -e
cd "$(dirname "$0")"

# ── Build app first ──
./build.sh

# ── Clean old DMG ──
rm -f Diary.dmg

# ── Create a clean staging directory with proper layout ──
STAGING="$(mktemp -d)"
DMG_DIR="$STAGING/dmg"
mkdir -p "$DMG_DIR"

# Copy .app into staging
cp -R Diary.app "$DMG_DIR/"

# Create Applications symlink (drag-to-install pattern)
ln -s /Applications "$DMG_DIR/Applications"

# ── Create DMG (compressed, read-only) ──
echo "Creating Diary.dmg..."
hdiutil create \
    -volname "Diary" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    -fs HFS+ \
    "Diary.dmg"

# ── Sign the DMG (ad-hoc) ──
echo "Signing DMG..."
codesign --force --sign - "Diary.dmg" 2>/dev/null || true

# ── Cleanup ──
rm -rf "$STAGING"

echo ""
echo "✅ Diary.dmg ready ($(du -h Diary.dmg | cut -f1))"
echo ""
echo "📦 分发说明："
echo "   用户从 GitHub 下载后，首次打开需要："
echo "   右键点击 Diary.app → 打开 → 仍要打开"
echo "   （因为未使用 Apple Developer ID 签名，macOS Gatekeeper 会拦截）"
echo ""
echo "   或者用户可以在终端运行："
echo "   xattr -cr /Applications/Diary.app"
