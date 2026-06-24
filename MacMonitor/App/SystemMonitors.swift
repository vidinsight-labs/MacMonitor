import Foundation

/// Tüm monitörlerin tek örneğini tutan paylaşılan kapsayıcı.
///
/// Hem `AppDelegate` (menü bar + popover) hem de SwiftUI sahnesi (sekmeler + durum çubuğu)
/// aynı örnekleri kullanır; böylece her veri yalnızca bir kez toplanır (çift `Timer`/tarama olmaz).
final class SystemMonitors {
    static let shared = SystemMonitors()

    let cpu = CPUMonitor()
    let memory = MemoryMonitor()
    let fan = FanMonitor()
    let process = ProcessMonitor()

    /// Sıkıntılı yük anlarını kaydeder (CPU + işlem verisine abone; ek yoklama yapmaz).
    let loadEvents: LoadEventRecorder

    /// Güç/termal/disk (canlı) + donanım envanteri (butonla).
    let systemInfo = SystemInfoMonitor()

    /// Kalıcılık öğeleri + imza durumu (butonla — Güvenlik Bakışı).
    let security = SecurityMonitor()

    /// Kritik durumda kullanıcıyı uyaran proaktif bildirimler.
    let notifications: NotificationManager

    private init() {
        loadEvents = LoadEventRecorder(cpu: cpu, process: process)
        notifications = NotificationManager(cpu: cpu, memory: memory,
                                            systemInfo: systemInfo, process: process)
    }
}
