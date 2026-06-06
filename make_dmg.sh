#!/bin/bash
set -e
cd "$(dirname "$0")"

# ── 1. Build app ──
./build.sh

# ── 2. Staging ──
STAGING="$PWD/.dmg_staging"
rm -rf "$STAGING"
mkdir -p "$STAGING/.background"
cp -R Diary.app "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# ── 3. Background image (warm paper gradient + arrow) ──
swift - <<'SWIFT' "$STAGING/.background/bg.png"
import CoreGraphics; import Foundation; import ImageIO; import UniformTypeIdentifiers
let w=600,h=400,cs=CGColorSpace(name: CGColorSpace.sRGB)!,ctx=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:cs,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
let g=CGGradient(colorsSpace:cs,colors:[CGColor(red:0.996,green:0.988,blue:0.973,alpha:1),CGColor(red:0.961,green:0.929,blue:0.878,alpha:1)] as CFArray,locations:[0,1])!
ctx.drawLinearGradient(g,start:CGPoint(x:0,y:0),end:CGPoint(x:0,y:CGFloat(h)),options:[])
ctx.setStrokeColor(CGColor(red:0.75,green:0.70,blue:0.64,alpha:0.85));ctx.setLineWidth(3);ctx.setLineCap(.round)
ctx.move(to:CGPoint(x:248,y:210));ctx.addLine(to:CGPoint(x:348,y:210));ctx.strokePath()
ctx.setFillColor(CGColor(red:0.75,green:0.70,blue:0.64,alpha:0.85))
ctx.move(to:CGPoint(x:352,y:210));ctx.addLine(to:CGPoint(x:338,y:201));ctx.addLine(to:CGPoint(x:338,y:219));ctx.closePath();ctx.fillPath()
let u=URL(fileURLWithPath:CommandLine.arguments[1]);let d=CGImageDestinationCreateWithURL(u as CFURL,UTType.png.identifier as CFString,1,nil)!;CGImageDestinationAddImage(d,ctx.makeImage()!,nil);CGImageDestinationFinalize(d)
SWIFT

# ── 4. Build .DS_Store with window layout ──
python3 <<'PYEOF'
from ds_store import DSStore
import os

ds = DSStore.open(os.path.expanduser('~/Developer/diary/.dmg_staging/.DS_Store'), 'w+')

ds[b'Diary.app'][b'Iloc'] = (160, 150)
ds[b'Applications'][b'Iloc'] = (360, 150)

ds[b'.'][b'icvp'] = {
    'iconSize': 80.0,
    'arrange': 'none',
    'showItemInfo': False,
    'showIconPreview': True,
    'backgroundType': 2,
    'backgroundColorBlue': 1.0,
    'backgroundColorGreen': 1.0,
    'backgroundColorRed': 1.0,
    'textSize': 12.0,
    'labelOnBottom': True,
}

ds[b'.'][b'bwsp'] = {
    'WindowBounds': '{{400, 200}, {600, 400}}',
    'ShowToolbar': False,
    'ShowStatusBar': False,
    'ShowPathbar': False,
    'ShowSidebar': False,
}

ds.close()
PYEOF

# ── 5. Create compressed DMG directly ──
rm -f Diary.dmg
hdiutil create -volname Diary -srcfolder "$STAGING" -ov \
    -format UDZO -imagekey zlib-level=9 -fs HFS+ Diary.dmg > /dev/null

# ── 6. Sign ──
codesign --force --sign - Diary.dmg 2>/dev/null || true

# ── 7. Cleanup ──
rm -rf "$STAGING"

echo "✅ Diary.dmg ready ($(du -h Diary.dmg | cut -f1))"
