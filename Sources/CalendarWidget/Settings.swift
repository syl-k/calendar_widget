import Foundation

final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let baseOpacity = "baseOpacity"
        static let selectedCalendarIDs = "selectedCalendarIDs"
        static let widgetVisible = "widgetVisible"
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
}
