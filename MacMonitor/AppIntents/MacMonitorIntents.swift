import AppIntents
import Foundation

/// Sistem sağlık özeti (Shortcuts / Siri).
struct SystemHealthIntent: AppIntent {
    static var title: LocalizedStringResource = "Sistem Sağlığını Kontrol Et"
    static var description = IntentDescription("MacMonitor sistem sağlık özetini döndürür.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let snap = WidgetDataStore.load()
        let label = snap.healthLabelTR
        let text = "Sistem: \(label). CPU %\(Int(snap.cpuPercent.rounded())), RAM %\(Int(snap.ramPercent.rounded()))."
        return .result(value: text)
    }
}

/// Güvenlik taraması başlat (Shortcuts).
struct SecurityScanIntent: AppIntent {
    static var title: LocalizedStringResource = "Güvenlik Taraması Yap"
    static var description = IntentDescription("Açılış öğeleri taramasını başlatır.")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            SystemMonitors.shared.security.scan()
        }
        return .result(dialog: "Güvenlik taraması başlatıldı. MacMonitor uygulamasında sonuçları görebilirsin.")
    }
}

/// En çok kaynak tüketen işlemleri listele.
struct TopProcessesIntent: AppIntent {
    static var title: LocalizedStringResource = "En Çok Kaynak Tüketen İşlemler"
    static var description = IntentDescription("CPU'ya göre ilk 5 işlemi listeler.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let procs = await MainActor.run { Array(SystemMonitors.shared.process.processes.prefix(5)) }
        if procs.isEmpty {
            return .result(value: "Henüz işlem verisi yok.")
        }
        let text = procs.map { "\($0.name) %\(Int($0.cpuUsage.rounded())) CPU" }.joined(separator: ", ")
        return .result(value: text)
    }
}

/// Shortcuts kısayol listesine eklenir.
struct MacMonitorShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SystemHealthIntent(),
            phrases: ["\(.applicationName) sağlık kontrolü", "Check system health with \(.applicationName)"],
            shortTitle: "Sağlık Kontrolü",
            systemImageName: "heart.text.square"
        )
        AppShortcut(
            intent: SecurityScanIntent(),
            phrases: ["\(.applicationName) güvenlik taraması", "Run security scan with \(.applicationName)"],
            shortTitle: "Güvenlik Taraması",
            systemImageName: "lock.shield"
        )
        AppShortcut(
            intent: TopProcessesIntent(),
            phrases: ["\(.applicationName) top işlemler", "Top processes in \(.applicationName)"],
            shortTitle: "Top İşlemler",
            systemImageName: "list.bullet.rectangle"
        )
    }
}
