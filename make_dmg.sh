#!/bin/bash
set -e
cd "$(dirname "$0")"

# ── Build app first ──
./build.sh

# ── Clean old DMG ──
rm -f Diary.dmg

# ── Temp staging dir ──
STAGING="$(mktemp -d)"

# Copy .app into staging
cp -R Diary.app "$STAGING/"

# Create Applications symlink (用户拖入这里 = 安装)
ln -s /Applications "$STAGING/Applications"

# ── Create DMG (compressed, read-only) ──
echo "Creating Diary.dmg..."
hdiutil create \
    -volname "Diary" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "Diary.dmg"

# ── Cleanup ──
rm -rf "$STAGING"

echo "✅ Diary.dmg ready ($(du -h Diary.dmg | cut -f1))"
echo "   Double-click to mount, drag Diary.app to Applications to install."
