#!/bin/bash
# swift build の成果物から CalendarWidget.app を組み立てて ad-hoc 署名する
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="build/CalendarWidget.app"

swift build -c "$CONFIG"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp ".build/$CONFIG/CalendarWidget" "$APP/Contents/MacOS/CalendarWidget"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

codesign --force --sign - "$APP"

echo "Built: $APP"
echo "Run:   open $APP"
