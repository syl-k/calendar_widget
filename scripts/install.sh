#!/bin/bash
# CalendarWidget.app をビルドして /Applications にインストールし、起動する。
# 安定した場所に置くことで「ログイン時に起動」が確実に機能する。
set -euo pipefail
cd "$(dirname "$0")/.."

DEST="/Applications/CalendarWidget.app"

# 既存インスタンスを終了(古い場所・新しい場所どちらも)
pkill -x CalendarWidget 2>/dev/null || true
sleep 1

# ビルドして build/CalendarWidget.app を作る
./scripts/build-app.sh release

# /Applications へ配置し直す
rm -rf "$DEST"
cp -R "build/CalendarWidget.app" "$DEST"

# 移動先で ad-hoc 署名し直す(TCC 権限・ログイン項目の同一性のため)
codesign --force --sign - "$DEST"

# 起動
open "$DEST"

echo ""
echo "インストール完了: $DEST"
echo "メニューバーのカレンダーアイコンから操作できます。"
echo "ログイン時の自動起動は初回起動で有効になります"
echo "(メニュー →「ログイン時に起動」でいつでも切り替え可能)。"
