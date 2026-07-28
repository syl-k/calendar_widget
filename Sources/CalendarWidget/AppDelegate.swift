import AppKit
import Combine
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let service = CalendarService()
    private var widget: WidgetController!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        service.start()
        NotificationManager.shared.requestAuthorizationIfNeeded()
        widget = WidgetController(service: service)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "calendar",
            accessibilityDescription: "Calendar Widget"
        )

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        enableLoginAtLaunchOnFirstRun()
    }

    /// 初回起動時に一度だけ「ログイン時に起動」を有効化する。
    /// 以降はメニューの切り替えを尊重する(このフラグが立っていれば何もしない)。
    private func enableLoginAtLaunchOnFirstRun() {
        guard !Settings.shared.loginItemConfigured else { return }
        Settings.shared.loginItemConfigured = true
        // /Applications など安定した場所からでないと登録が無視されることがある
        try? SMAppService.mainApp.register()
    }

    // メニューを開くたびに現在の状態で組み立て直す
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let toggle = NSMenuItem(
            title: widget.isShown ? "ウィジェットを隠す" : "ウィジェットを表示",
            action: #selector(toggleWidget), keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        menu.addItem(.separator())
        menu.addItem(opacityMenuItem())
        menu.addItem(calendarsMenuItem())
        menu.addItem(notificationMenuItem())
        menu.addItem(.separator())

        let reset = NSMenuItem(title: "位置をリセット", action: #selector(resetPosition), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        let login = NSMenuItem(title: "ログイン時に起動", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func opacityMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "不透明度", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let current = Settings.shared.baseOpacity
        for percent in [30, 45, 55, 70, 90] {
            let sub = NSMenuItem(title: "\(percent)%", action: #selector(setOpacity(_:)), keyEquivalent: "")
            sub.target = self
            sub.tag = percent
            sub.state = abs(current - Double(percent) / 100) < 0.01 ? .on : .off
            submenu.addItem(sub)
        }
        item.submenu = submenu
        return item
    }

    private func calendarsMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "表示するカレンダー", action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        if service.calendars.isEmpty {
            let empty = NSMenuItem(
                title: service.authState == .authorized ? "カレンダーがありません" : "権限がありません",
                action: nil, keyEquivalent: ""
            )
            empty.isEnabled = false
            submenu.addItem(empty)
        } else {
            let all = NSMenuItem(title: "すべて表示", action: #selector(showAllCalendars), keyEquivalent: "")
            all.target = self
            all.state = Settings.shared.selectedCalendarIDs == nil ? .on : .off
            submenu.addItem(all)
            submenu.addItem(.separator())

            let selected = Settings.shared.selectedCalendarIDs
            for calendar in service.calendars {
                let sub = NSMenuItem(title: calendar.title, action: #selector(toggleCalendar(_:)), keyEquivalent: "")
                sub.target = self
                sub.representedObject = calendar.calendarIdentifier
                sub.state = (selected?.contains(calendar.calendarIdentifier) ?? true) ? .on : .off
                submenu.addItem(sub)
            }
        }
        item.submenu = submenu
        return item
    }

    private func notificationMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "予定の通知", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let current = Settings.shared.notificationLeadMinutes

        // (表示名, リード分. nil = オフ, 0 = 開始時)
        let options: [(String, Int?)] = [
            ("オフ", nil),
            ("開始時", 0),
            ("1分前", 1),
            ("5分前", 5),
            ("10分前", 10),
            ("15分前", 15),
        ]
        for (title, minutes) in options {
            let sub = NSMenuItem(title: title, action: #selector(setNotificationLead(_:)), keyEquivalent: "")
            sub.target = self
            // オフは -1 で表現(0 は「開始時」に使うため)
            sub.tag = minutes ?? -1
            sub.state = (current == minutes) ? .on : .off
            submenu.addItem(sub)
        }
        item.submenu = submenu
        return item
    }

    // MARK: Actions

    @objc private func toggleWidget() {
        widget.isShown ? widget.hide() : widget.show()
    }

    @objc private func resetPosition() {
        widget.resetPosition()
    }

    @objc private func setOpacity(_ sender: NSMenuItem) {
        Settings.shared.baseOpacity = Double(sender.tag) / 100
        widget.applyBaseOpacity()
    }

    @objc private func setNotificationLead(_ sender: NSMenuItem) {
        Settings.shared.notificationLeadMinutes = sender.tag < 0 ? nil : sender.tag
        NotificationManager.shared.requestAuthorizationIfNeeded()
        service.reload()  // 通知を新しいタイミングで組み直す
    }

    @objc private func showAllCalendars() {
        Settings.shared.selectedCalendarIDs = nil
        service.reload()
    }

    @objc private func toggleCalendar(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        // 「すべて表示」状態から個別トグルする場合は、全IDを起点にする
        var ids = Settings.shared.selectedCalendarIDs
            ?? Set(service.calendars.map(\.calendarIdentifier))
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        Settings.shared.selectedCalendarIDs = ids
        service.reload()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "ログイン時起動の設定に失敗しました"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
