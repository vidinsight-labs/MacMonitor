import Foundation

/// Widget extension ile paylaşılan anlık sistem özeti (App Group).
struct WidgetSnapshot: Codable {
    var healthLabelTR: String = "Normal"
    var healthLabelEN: String = "Normal"
    var healthLevel: String = "normal"
    var cpuPercent: Double = 0
    var ramPercent: Double = 0
    var updatedAt: Date = .distantPast
}

enum WidgetDataStore {
    static let appGroupID = "group.com.macmonitor.app"
    private static let key = "widgetSnapshot"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults?.data(forKey: key),
              let decoded = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return WidgetSnapshot() }
        return decoded
    }
}
