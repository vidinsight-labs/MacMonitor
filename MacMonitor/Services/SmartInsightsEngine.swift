import Foundation
import Combine

/// Yerel, kural tabanlı akıllı öneriler — bulut/API gerektirmez.
struct SmartInsight: Identifiable {
    let id = UUID()
    let icon: String
    let colorName: String   // green | yellow | red | blue
    let titleTR: String
    let titleEN: String
    let detailTR: String
    let detailEN: String

    var title: String { t(titleTR, titleEN) }
    var detail: String { t(detailTR, detailEN) }
}

final class SmartInsightsEngine: ObservableObject {
    @Published private(set) var insights: [SmartInsight] = []

    private let cpu: CPUMonitor
    private let memory: MemoryMonitor
    private let process: ProcessMonitor
    private let systemInfo: SystemInfoMonitor
    private let loadEvents: LoadEventRecorder
    private var cancellables = Set<AnyCancellable>()

    init(cpu: CPUMonitor, memory: MemoryMonitor, process: ProcessMonitor,
         systemInfo: SystemInfoMonitor, loadEvents: LoadEventRecorder) {
        self.cpu = cpu
        self.memory = memory
        self.process = process
        self.systemInfo = systemInfo
        self.loadEvents = loadEvents

        let trigger = Publishers.MergeMany(
            cpu.$totalUsage.map { _ in () }.eraseToAnyPublisher(),
            memory.$memory.map { _ in () }.eraseToAnyPublisher(),
            memory.$pressure.map { _ in () }.eraseToAnyPublisher(),
            process.$processes.map { _ in () }.eraseToAnyPublisher(),
            systemInfo.$diskFree.map { _ in () }.eraseToAnyPublisher(),
            loadEvents.$events.map { _ in () }.eraseToAnyPublisher()
        )

        trigger
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] in self?.refresh() }
            .store(in: &cancellables)

        refresh()
    }

    func refresh() {
        recompute(
            cpu: cpu.totalUsage,
            memory: memory.memory,
            pressure: memory.pressure,
            processes: process.processes,
            diskFree: systemInfo.diskFree,
            diskTotal: systemInfo.diskTotal,
            events: loadEvents.events
        )
    }

    private func recompute(cpu: Double, memory: MemoryData, pressure: MemoryPressure,
                           processes: [ProcessData], diskFree: Int64, diskTotal: Int64,
                           events: [LoadEvent]) {
        var result: [SmartInsight] = []
        let uptimeDays = ProcessInfo.processInfo.systemUptime / 86_400

        if uptimeDays >= 14 {
            result.append(.init(
                icon: "clock.arrow.circlepath", colorName: "yellow",
                titleTR: "\(Int(uptimeDays)) gündür yeniden başlatılmadı",
                titleEN: "No restart for \(Int(uptimeDays)) days",
                detailTR: "Uzun süre açık kalmak bellek parçalanmasına yol açabilir.",
                detailEN: "Long uptime can lead to memory fragmentation."
            ))
        }

        if let top = processes.first, top.cpuUsage >= 50 {
            result.append(.init(
                icon: "cpu", colorName: top.cpuUsage >= 80 ? "red" : "yellow",
                titleTR: "\(top.name) CPU'nun %\(Int(top.cpuUsage.rounded()))'ini kullanıyor",
                titleEN: "\(top.name) is using \(Int(top.cpuUsage.rounded()))% CPU",
                detailTR: "İşlemler sekmesinden detaylara bakabilirsin.",
                detailEN: "See the Processes tab for details."
            ))
        }

        if let hog = processes.max(by: { $0.memoryUsage < $1.memoryUsage }),
           memory.total > 0,
           Double(hog.memoryUsage) / Double(memory.total) > 0.15 {
            let pct = Int(Double(hog.memoryUsage) / Double(memory.total) * 100)
            result.append(.init(
                icon: "memorychip", colorName: "yellow",
                titleTR: "\(hog.name) RAM'in yaklaşık %\(pct)'ini kullanıyor",
                titleEN: "\(hog.name) uses about \(pct)% of RAM",
                detailTR: "Gereksizse kapatmak belleği rahatlatır.",
                detailEN: "Closing it if unneeded frees memory."
            ))
        }

        if pressure == .critical {
            result.append(.init(
                icon: "exclamationmark.triangle.fill", colorName: "red",
                titleTR: "Bellek kritik baskı altında",
                titleEN: "Memory under critical pressure",
                detailTR: "Uygulama kapatmak veya yeniden başlatmak önerilir.",
                detailEN: "Close apps or restart the device."
            ))
        }

        if diskTotal > 0 {
            let used = Double(diskTotal - diskFree) / Double(diskTotal) * 100
            if used >= 90 {
                result.append(.init(
                    icon: "internaldrive.fill", colorName: "red",
                    titleTR: "Disk %\(Int(used.rounded())) dolu",
                    titleEN: "Disk is \(Int(used.rounded()))% full",
                    detailTR: "Sistem sekmesinden yer açma önerilerine bak.",
                    detailEN: "Check space-saving tips on the System tab."
                ))
            } else if used >= 75 {
                result.append(.init(
                    icon: "internaldrive", colorName: "yellow",
                    titleTR: "Disk %\(Int(used.rounded())) dolu",
                    titleEN: "Disk is \(Int(used.rounded()))% full",
                    detailTR: "Yakında yer açman gerekebilir.",
                    detailEN: "You may need to free space soon."
                ))
            }
        }

        if cpu >= 90 {
            result.append(.init(
                icon: "flame.fill", colorName: "red",
                titleTR: "İşlemci çok yüklü (%\(Int(cpu.rounded())))",
                titleEN: "Processor heavily loaded (\(Int(cpu.rounded()))%)",
                detailTR: "Ağır uygulamaları kapatmayı düşün.",
                detailEN: "Consider closing heavy applications."
            ))
        }

        let recentEvents = events.filter { $0.startedAt > Date().addingTimeInterval(-7 * 86_400) }
        if recentEvents.count >= 5 {
            result.append(.init(
                icon: "chart.line.uptrend.xyaxis", colorName: "yellow",
                titleTR: "Son 7 günde \(recentEvents.count) yük olayı kaydedildi",
                titleEN: "\(recentEvents.count) load events recorded in the last 7 days",
                detailTR: "İşlemci sekmesindeki zaman çizelgesine bak.",
                detailEN: "See the timeline on the Processor tab."
            ))
        }

        if result.isEmpty {
            result.append(.init(
                icon: "checkmark.seal.fill", colorName: "green",
                titleTR: "Sistem rahat görünüyor",
                titleEN: "System looks healthy",
                detailTR: "Şu an dikkat gerektiren bir sorun yok.",
                detailEN: "Nothing needs attention right now."
            ))
        }

        insights = result
        publishWidgetSnapshot(cpu: cpu, memory: memory, insights: result)
    }

    private func publishWidgetSnapshot(cpu: Double, memory: MemoryData, insights: [SmartInsight]) {
        let ram = memory.total > 0 ? Double(memory.used) / Double(memory.total) * 100 : 0
        let worst = insights.first { $0.colorName == "red" }
            ?? insights.first { $0.colorName == "yellow" }
        let level: String
        let labelTR: String
        let labelEN: String
        if worst?.colorName == "red" {
            level = "critical"
            labelTR = "Kritik"
            labelEN = "Critical"
        } else if worst?.colorName == "yellow" {
            level = "warning"
            labelTR = "Dikkat"
            labelEN = "Attention"
        } else {
            level = "normal"
            labelTR = "Normal"
            labelEN = "Normal"
        }
        WidgetDataStore.save(WidgetSnapshot(
            healthLabelTR: labelTR, healthLabelEN: labelEN,
            healthLevel: level, cpuPercent: cpu, ramPercent: ram, updatedAt: Date()
        ))
    }
}
