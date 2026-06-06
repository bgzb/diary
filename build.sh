#!/bin/bash
set -e

cd "$(dirname "$0")"

SWIFT_FILES=$(find Sources/Diary -name "*.swift" -print0 | xargs -0)
FRAMEWORKS="-framework SwiftUI -framework AppKit -framework CryptoKit"

# Kill existing instance
pkill -f Diary.app 2>/dev/null || true

# Clean
rm -rf Diary.app

# Build .app bundle structure
mkdir -p Diary.app/Contents/MacOS
mkdir -p Diary.app/Contents/Resources

# ── Build universal binary (arm64 + x86_64) ──
echo "Building arm64..."
swiftc $SWIFT_FILES -o Diary_arm64 \
    $FRAMEWORKS \
    -parse-as-library \
    -target arm64-apple-macosx14.0 \
    -O

echo "Building x86_64..."
swiftc $SWIFT_FILES -o Diary_x86_64 \
    $FRAMEWORKS \
    -parse-as-library \
    -target x86_64-apple-macosx14.0 \
    -O

echo "Creating universal binary..."
lipo -create Diary_arm64 Diary_x86_64 -output Diary.app/Contents/MacOS/Diary
rm Diary_arm64 Diary_x86_64

# ── Ad-hoc code sign the app ──
echo "Signing app (ad-hoc)..."
codesign --force --deep --sign - Diary.app

# Copy Info.plist
cp Info.plist Diary.app/Contents/

# Copy icon
cp AppIcon.icns Diary.app/Contents/Resources/

# Verify
echo "---"
echo "Architecture: $(lipo -info Diary.app/Contents/MacOS/Diary)"
echo "Signature:    $(codesign -dv Diary.app 2>&1 | grep 'Signature=')"
echo "Build: Diary.app ✅"
