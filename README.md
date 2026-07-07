# Calendar Widget

macOSのデスクトップに常駐し、Googleカレンダーの直近の予定(過去30分〜先2.5時間)を常に最前面・半透明で表示するウィジェット。

## 特徴

- **常に最前面・半透明** — 通常はクリックが背面のアプリに素通りするので作業の邪魔になりません
- **ホバーで操作** — マウスを乗せると不透明になり、ドラッグで移動できます
- **タイムライン表示** — 現在時刻の赤いラインを基準に、3時間分の予定を縦タイムラインで表示。時間の経過とともに自動でスライドします
- **メニューバー常駐** — Dockには表示されず、メニューバーから不透明度・表示カレンダーなどを設定できます

## 前提条件

- macOS 14 (Sonoma) 以降
- macOSの「カレンダー」アプリにGoogleアカウントを追加済みであること
  (システム設定 → インターネットアカウント → Google → 「カレンダー」をオン)

Googleカレンダーのデータは macOS の EventKit 経由で読み取るため、OAuth設定やAPIキーは不要です。

## ビルドと起動

```bash
./scripts/build-app.sh
open build/CalendarWidget.app
```

初回起動時にカレンダーへのアクセス許可を求めるダイアログが表示されるので「フルアクセスを許可」を選択してください。

## 使い方

- メニューバーのカレンダーアイコンから: 表示/非表示、不透明度(30〜90%)、表示するカレンダーの選択、位置のリセット、ログイン時に起動、終了
- ウィジェットにマウスを乗せてドラッグすると好きな位置に移動できます(位置は記憶されます)
- 終日予定はウィジェット上部に最大2件表示されます

## 構成

| ファイル | 役割 |
|---|---|
| `Sources/CalendarWidget/AppDelegate.swift` | メニューバーアイコンとメニュー |
| `Sources/CalendarWidget/WidgetPanel.swift` | 最前面パネルとホバー/クリック透過制御 |
| `Sources/CalendarWidget/CalendarService.swift` | EventKitによる予定取得と自動更新 |
| `Sources/CalendarWidget/WidgetView.swift` | タイムラインUI (SwiftUI) |
| `Sources/CalendarWidget/EventLayout.swift` | 重複予定の列割当 |
| `docs/plans/2026-07-07-calendar-widget-design.md` | 設計書 |
