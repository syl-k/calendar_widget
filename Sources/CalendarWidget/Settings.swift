import Foundation

final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let baseOpacity = "baseOpacity"
        static let selectedCalendarIDs = "selectedCalendarIDs"
        static let widgetVisible = "widgetVisible"
        static let notificationLeadMinutes = "notificationLeadMinutes"
        static let notificationConfigured = "notificationConfigured"
    }

    var baseOpacity: Double {
        get {
            let v = defaults.double(forKey: Key.baseOpacity)
            return v == 0 ? 0.55 : v
        }
        set { defaults.set(newValue, forKey: Key.baseOpacity) }
    }

    /// nil = すべてのカレンダーを表示
    var selectedCalendarIDs: Set<String>? {
        get {
            guard let arr = defaults.array(forKey: Key.selectedCalendarIDs) as? [String] else { return nil }
            return Set(arr)
        }
        set {
            if let ids = newValue {
                defaults.set(Array(ids), forKey: Key.selectedCalendarIDs)
            } else {
                defaults.removeObject(forKey: Key.selectedCalendarIDs)
            }
        }
    }

    var widgetVisible: Bool {
        get { defaults.object(forKey: Key.widgetVisible) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.widgetVisible) }
    }

    /// 予定開始の何分前に通知するか。nil = 通知オフ。既定は 5 分前。
    var notificationLeadMinutes: Int? {
        get {
            // 未設定(初回)は既定 5 分、明示的にオフにした場合のみ nil
            guard defaults.bool(forKey: Key.notificationConfigured) else { return 5 }
            let v = defaults.integer(forKey: Key.notificationLeadMinutes)
            return v == 0 ? nil : v
        }
        set {
            defaults.set(true, forKey: Key.notificationConfigured)
            defaults.set(newValue ?? 0, forKey: Key.notificationLeadMinutes)
        }
    }
}
