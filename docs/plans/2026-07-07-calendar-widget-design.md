# macOS常駐Googleカレンダーウィジェット 設計書

日付: 2026-07-07

## 目的

macOS上に常駐し、Googleカレンダーの直近の予定(過去30分〜先2.5時間の3時間分)を常に最前面・半透明で表示するウィジェット。普段の作業の邪魔をしないことが最優先。

## 決定事項

| 項目 | 決定 |
|---|---|
| データ取得 | EventKit(macOSカレンダーにGoogleアカウントを同期済みであることが前提。OAuth不要) |
| 技術スタック | Swift + SwiftUI + AppKit(macOS 14以降) |
| アプリ形態 | メニューバー常駐(`LSUIElement`、Dockアイコンなし) |
| ウィンドウ | 枠なし`NSPanel`、`.floating`レベル、全Spaces表示 |
| 操作性 | 通常はクリック透過。ホバー時のみ操作可能になり不透明度が上がる |
| 表示形式 | 縦タイムライン型。現在時刻ラインは上から1/6の位置に固定され自動スライド |
| 時間窓 | 現在−30分 〜 現在+2.5時間(計3時間) |
| ビルド | Swift Package + `.app`バンドル生成スクリプト + ad-hoc署名 |

## アーキテクチャ

構成要素は4つ。

1. **AppDelegate + NSStatusItem** — メニューバーから表示/非表示、不透明度、表示カレンダー選択、位置リセット、ログイン時起動、終了を操作。
2. **WidgetPanel (NSPanel)** — `[.borderless, .nonactivatingPanel]`、`level = .floating`、`collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`。背景透明で中身は`NSHostingView`。クリックしてもフォーカスを奪わない。
3. **ホバー制御** — 約0.15秒間隔のタイマーで`NSEvent.mouseLocation`とパネルのframeを比較。カーソルが入ったら`ignoresMouseEvents = false`+不透明度95%、出たら`true`+基本不透明度(既定55%)。権限不要でシンプル。
4. **CalendarService (EventKit)** — `EKEventStore`で時間窓+前後バッファのイベントを取得し`@Published`で配信。

サイズ初期値: 幅260pt × 高さ540pt(1時間≒180pt)。ドラッグ移動可、位置は`frameAutosaveName`で記憶。

## タイムラインUI

- 30分刻みの罫線+時刻ラベル(正時は濃く)。
- 現在時刻ライン: 赤線+時刻。窓全体がスライドするため常に上から1/6。
- イベントブロック: カレンダー色の半透明背景+左端色帯。タイトルと開始時刻を表示。重複する予定は横に等分割(クラスタリング+貪欲な列割当)。
- 終日予定は最上部に細いバーで最大2件。
- 進行中は強調、終了済みは彩度を落とす。
- 背景は`ultraThinMaterial`+角丸。

## データ更新

1. 30秒タイマー — 現在時刻と時間窓のスライド。60秒ごとにイベント再取得。
2. `.EKEventStoreChanged`通知 — Google側の変更がmacOSに同期された瞬間に再取得。
3. `NSWorkspace.didWakeNotification` — スリープ復帰時に即時更新。

## 永続化・エラー処理

- `UserDefaults`: 基本不透明度、表示カレンダーID一覧、ウィンドウ位置。
- 権限未許可: ウィジェット内に案内+「システム設定を開く」ボタン。
- カレンダーなし: Googleアカウント同期の案内文を表示。

## ビルド

`swift build -c release` → `scripts/build-app.sh`で`build/CalendarWidget.app`を組み立て(Info.plistに`LSUIElement`と`NSCalendarsFullAccessUsageDescription`)→ `codesign -s -`でad-hoc署名。TCC(権限ダイアログ)はバンドル+署名があれば動作する。
