#!/bin/bash
set -e

cd "$(dirname "$0")"

# Kill existing instance
pkill -f Diary.app 2>/dev/null || true

# Clean
rm -rf Diary.app

# Build .app bundle structure
mkdir -p Diary.app/Contents/MacOS
mkdir -p Diary.app/Contents/Resources

# Compile
find Sources/Diary -name "*.swift" -print0 | xargs -0 \
    swiftc -o Diary.app/Contents/MacOS/Diary \
    -framework SwiftUI \
    -framework AppKit \
    -framework CryptoKit \
    -parse-as-library \
    -target arm64-apple-macosx14.0

# Copy Info.plist
cp Info.plist Diary.app/Contents/

echo "Build: Diary.app"
