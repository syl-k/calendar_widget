import EventKit
import Combine
import AppKit

/// EventKit経由で予定を取得し、SwiftUIに配信する。
final class CalendarService: ObservableObject {
    enum AuthState {
        case undetermined
        case denied
        case authorized
    }

    let store = EKEventStore()

    @Published var authState: AuthState = .undetermined
    @Published var timedEvents: [EKEvent] = []
    @Published var allDayEvents: [EKEvent] = []
    @Published var calendars: [EKCalendar] = []
    @Published var now: Date = Date()

    /// 表示窓: 現在−30分 〜 現在+2.5時間
    static let windowBefore: TimeInterval = 30 * 60
    static let windowLength: TimeInterval = 3 * 60 * 60

    private var clockTimer: Timer?
    private var reloadTimer: Timer?

    func start() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            authState = .authorized
            didAuthorize()
        case .denied, .restricted, .writeOnly:
            authState = .denied
        default:
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.authState = granted ? .authorized : .denied
                    if granted { self.didAuthorize() }
                }
            }
        }

        // 権限に関わらず時計は動かす(権限付与後すぐ反映されるように)
        clockTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.now = Date()
        }
        reloadTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.reload()
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(storeChanged),
            name: .EKEventStoreChanged, object: store)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    private func didAuthorize() {
        calendars = store.calendars(for: .event)
            .sorted { ($0.source.title, $0.title) < ($1.source.title, $1.title) }
        reload()
    }

    @objc private func storeChanged() {
        guard authState == .authorized else { return }
        calendars = store.calendars(for: .event)
            .sorted { ($0.source.title, $0.title) < ($1.source.title, $1.title) }
        reload()
    }

    @objc private func didWake() {
        now = Date()
        reload()
    }

    func reload() {
        guard authState == .authorized else { return }
        now = Date()

        let visibleCalendars: [EKCalendar]?
        if let ids = Settings.shared.selectedCalendarIDs {
            let filtered = calendars.filter { ids.contains($0.calendarIdentifier) }
            // 選択がすべて無効になった場合は全カレンダーにフォールバック
            visibleCalendars = filtered.isEmpty ? nil : filtered
        } else {
            visibleCalendars = nil
        }

        // 表示窓の前後に1時間のバッファを持たせて取得
        let start = now.addingTimeInterval(-Self.windowBefore - 3600)
        let end = now.addingTimeInterval(Self.windowLength - Self.windowBefore + 3600)
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: visibleCalendars)
        let events = store.events(matching: predicate)

        timedEvents = events
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
        allDayEvents = events
            .filter { $0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        scheduleNotifications()
    }

    /// 通知は表示窓より先の予定にも必要なので、当日いっぱいを別枠で取得して組み直す。
    private func scheduleNotifications() {
        guard Settings.shared.notificationLeadMinutes != nil else {
            NotificationManager.shared.cancelAll()
            return
        }

        let visibleCalendars: [EKCalendar]?
        if let ids = Settings.shared.selectedCalendarIDs {
            let filtered = calendars.filter { ids.contains($0.calendarIdentifier) }
            visibleCalendars = filtered.isEmpty ? nil : filtered
        } else {
            visibleCalendars = nil
        }

        let calendar = Calendar.current
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now.addingTimeInterval(12 * 3600)
        // 深夜近くでも最低 6 時間先までは通知対象にする
        let end = max(endOfDay, now.addingTimeInterval(6 * 3600))
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: visibleCalendars)
        let upcoming = store.events(matching: predicate).filter { !$0.isAllDay }

        NotificationManager.shared.reschedule(events: upcoming)
    }
}
