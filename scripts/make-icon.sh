#!/bin/bash
# scripts/make-icon.swift から Resources/AppIcon.icns と icon-1024.png を再生成する。
set -euo pipefail
cd "$(dirname "$0")/.."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1024px の元画像を描画
swiftc scripts/make-icon.swift -o "$TMP/make-icon"
"$TMP/make-icon" "Resources/icon-1024.png"

# 各サイズを生成して iconset を組む
SET="$TMP/AppIcon.iconset"
mkdir -p "$SET"
SRC="Resources/icon-1024.png"
sips -z 16 16   "$SRC" --out "$SET/icon_16x16.png"      >/dev/null
sips -z 32 32   "$SRC" --out "$SET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32   "$SRC" --out "$SET/icon_32x32.png"      >/dev/null
sips -z 64 64   "$SRC" --out "$SET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128 "$SRC" --out "$SET/icon_128x128.png"    >/dev/null
sips -z 256 256 "$SRC" --out "$SET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$SRC" --out "$SET/icon_256x256.png"    >/dev/null
sips -z 512 512 "$SRC" --out "$SET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$SRC" --out "$SET/icon_512x512.png"    >/dev/null
cp "$SRC" "$SET/icon_512x512@2x.png"

iconutil -c icns "$SET" -o "Resources/AppIcon.icns"
echo "Generated: Resources/AppIcon.icns"
