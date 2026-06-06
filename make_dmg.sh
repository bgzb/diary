#!/bin/bash
set -e
cd "$(dirname "$0")"

# ── 1. Build universal binary + sign ──
./build.sh

# ── 2. Generate background image (warm paper gradient + arrow) ──
BG_DIR="$(mktemp -d)"
BG_PNG="$BG_DIR/bg.png"

swift - <<'SWIFT' "$BG_PNG"
import CoreGraphics; import Foundation; import ImageIO; import UniformTypeIdentifiers
let w=600,h=400,cs=CGColorSpace(name: CGColorSpace.sRGB)!,ctx=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:cs,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
let g=CGGradient(colorsSpace:cs,colors:[CGColor(red:0.996,green:0.988,blue:0.973,alpha:1),CGColor(red:0.961,green:0.929,blue:0.878,alpha:1)] as CFArray,locations:[0,1])!
ctx.drawLinearGradient(g,start:CGPoint(x:0,y:0),end:CGPoint(x:0,y:CGFloat(h)),options:[])
ctx.setStrokeColor(CGColor(red:0.75,green:0.70,blue:0.64,alpha:0.85));ctx.setLineWidth(3);ctx.setLineCap(.round)
ctx.move(to:CGPoint(x:215,y:250));ctx.addLine(to:CGPoint(x:345,y:250));ctx.strokePath()
ctx.setFillColor(CGColor(red:0.75,green:0.70,blue:0.64,alpha:0.85))
ctx.move(to:CGPoint(x:350,y:250));ctx.addLine(to:CGPoint(x:336,y:241));ctx.addLine(to:CGPoint(x:336,y:259));ctx.closePath();ctx.fillPath()
let u=URL(fileURLWithPath:CommandLine.arguments[1]);let d=CGImageDestinationCreateWithURL(u as CFURL,UTType.png.identifier as CFString,1,nil)!;CGImageDestinationAddImage(d,ctx.makeImage()!,nil);CGImageDestinationFinalize(d)
SWIFT

# ── 3. Install dmgbuild if needed ──
pip3 install dmgbuild 2>/dev/null || true

# ── 4. Build DMG via dmgbuild ──
rm -f Diary.dmg
dmgbuild -s dmgbuild_settings.py -D bg_path="$BG_PNG" "Diary" Diary.dmg

# ── 5. Sign DMG ──
codesign --force --sign - Diary.dmg 2>/dev/null || true

# ── 6. Cleanup ──
rm -rf "$BG_DIR"

echo "✅ Diary.dmg ready ($(du -h Diary.dmg | cut -f1))"
