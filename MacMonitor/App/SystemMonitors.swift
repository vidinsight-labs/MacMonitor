import Foundation

/// Tüm monitörlerin tek örneğini tutan paylaşılan kapsayıcı.
final class SystemMonitors {
    static let shared = SystemMonitors()

    let cpu = CPUMonitor()
    let memory = MemoryMonitor()
    let fan = FanMonitor()
    let process = ProcessMonitor()
    let loadEvents: LoadEventRecorder
    let systemInfo = SystemInfoMonitor()
    let security = SecurityMonitor()
    let notifications: NotificationManager
    let smartInsights: SmartInsightsEngine

    private init() {
        loadEvents = LoadEventRecorder(cpu: cpu, process: process)
        notifications = NotificationManager(cpu: cpu, memory: memory,
                                            systemInfo: systemInfo, process: process)
        smartInsights = SmartInsightsEngine(cpu: cpu, memory: memory, process: process,
                                            systemInfo: systemInfo, loadEvents: loadEvents)
    }
}
