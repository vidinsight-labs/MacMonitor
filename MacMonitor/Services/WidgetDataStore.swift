import Foundation

/// Widget ve Shortcuts ile paylaşılan anlık sistem özeti (App Group).
struct WidgetSnapshot: Codable {
    var healthLabelTR: String = "Normal"
    var healthLabelEN: String = "Normal"
    var healthLevel: String = "normal"   // normal | warning | critical
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

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults?.data(forKey: key),
              let decoded = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return WidgetSnapshot() }
        return decoded
    }
}
