import Foundation
import UserNotifications
import EventKit

/// 予定の開始前に macOS 通知を出す。
///
/// リロードのたびに「自分が出した予定通知」を全部消して組み直す。
/// 通知タイミング(リード時間)は Settings.notificationLeadMinutes で決まり、
/// nil(オフ)のときは何もスケジュールしない。
final class NotificationManager {
    static let shared = NotificationManager()

    /// 自分が登録した通知だけを識別するための接頭辞
    private let identifierPrefix = "calendar-widget-event-"

    /// UNUserNotificationCenter はアプリバンドル(署名付き)でないと使えないため、
    /// バンドル外(swift run 直実行など)では通知機能を無効化する。
    private var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    private var authorized = false

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "H:mm"
        return f
    }()

    /// 通知が有効なら権限を要求する。設定変更時にも呼ぶ。
    func requestAuthorizationIfNeeded() {
        guard isAvailable, Settings.shared.notificationLeadMinutes != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            self?.authorized = granted
        }
    }

    /// 予定リストから通知を組み直す。
    func reschedule(events: [EKEvent]) {
        guard isAvailable else { return }
        let center = UNUserNotificationCenter.current()

        // まず自分が登録した予定通知を全て取り消す
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(self.identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }

        guard let lead = Settings.shared.notificationLeadMinutes else { return }
        let leadInterval = TimeInterval(lead * 60)
        let now = Date()

        for event in events {
            guard event.startDate > now else { continue }
            let fireDate = event.startDate.addingTimeInterval(-leadInterval)
            let interval = max(fireDate.timeIntervalSince(now), 1)

            let content = UNMutableNotificationContent()
            content.title = event.title ?? "(無題)"
            content.body = "\(Self.timeFormatter.string(from: event.startDate)) 開始"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifierPrefix + identifier(for: event),
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    /// 通知を全て取り消す(通知オフ時)。
    func cancelAll() {
        guard isAvailable else { return }
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(self.identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// 繰り返し予定でも一意になるよう、識別子に開始時刻を混ぜる。
    private func identifier(for event: EKEvent) -> String {
        let base = event.eventIdentifier ?? event.title ?? "event"
        return "\(base)-\(Int(event.startDate.timeIntervalSince1970))"
    }
}
