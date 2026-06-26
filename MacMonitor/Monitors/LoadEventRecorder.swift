import Foundation
import Combine

/// CPU "riskli bölgeye" (eşik üstü) girdiğinde o anı ve yükü alan işlemleri kaydeder.
///
/// **Ekstra sistem yükü getirmez:**
/// - Yeni `Timer`/yoklama yoktur; zaten toplanan CPU (2 sn) ve işlem (3 sn) verisine abone olur.
/// - Disk yazımı yalnızca **olay başlarken ve biterken** yapılır (2 sn'lik her tik'te değil),
///   ayrı bir kuyrukta (arka planda). Açılışta dosya bir kez okunur.
/// - **Son 1 ay** saklanır; daha eski kayıtlar açılışta ve her yeni olayda temizlenir.
final class LoadEventRecorder: ObservableObject {
    @Published private(set) var events: [LoadEvent] = []
    /// CPU hâlâ eşik üstündeyse true — ilk listedeki olay "devam ediyor" sayılır.
    @Published private(set) var hasActiveHighLoadEvent = false

    /// Riskli bölge eşiği (% toplam CPU).
    let threshold: Double = 80

    /// Saklama süresi: 1 ay (30 gün).
    private let retention: TimeInterval = 30 * 24 * 60 * 60
    /// Bellek/dosya için güvenlik üst sınırı (1 ayda beklenenden çok fazlası birikmesin).
    private let maxEvents = 2_000
    private let culpritCount = 3

    private var inHighLoad = false
    private var activeSampleCount = 0
    private var activeCpuSum = 0.0
    /// Olay boyunca görülen en yüksek uygulama CPU değerleri (ad → tepe %).
    private var activePeakCulprits: [String: Double] = [:]
    private var cancellables = Set<AnyCancellable>()

    /// Disk işlemleri için ayrı seri kuyruk (ana iş parçacığını bloklamaz).
    private let ioQueue = DispatchQueue(label: "com.macmonitor.loadevents.io", qos: .utility)
    private let fileURL: URL

    init(cpu: CPUMonitor, process: ProcessMonitor) {
        fileURL = Self.makeFileURL()
        events = Self.loadFromDisk(fileURL, retention: retention).map { Self.repairCulprits($0) }

        cpu.$totalUsage
            .combineLatest(process.$processes)
            .sink { [weak self] usage, processes in
                self?.handle(usage: usage, processes: processes)
            }
            .store(in: &cancellables)
    }

    // MARK: - Olay yakalama

    private func handle(usage: Double, processes: [ProcessData]) {
        guard usage >= threshold else {
            if inHighLoad {
                finalizeActiveEvent()
                inHighLoad = false
                hasActiveHighLoadEvent = false
                activeSampleCount = 0
                activeCpuSum = 0
                activePeakCulprits = [:]
                save()
            }
            return
        }

        if inHighLoad {
            guard !events.isEmpty else { return }
            activeSampleCount += 1
            activeCpuSum += usage
            events[0].peak = max(events[0].peak, usage)
            events[0].avgCPU = activeCpuSum / Double(activeSampleCount)
            mergePeakCulprits(from: processes)
            applyCulpritsToActiveEvent()
            return
        }

        inHighLoad = true
        hasActiveHighLoadEvent = true
        activeSampleCount = 1
        activeCpuSum = usage
        activePeakCulprits = [:]
        mergePeakCulprits(from: processes)

        var event = LoadEvent(startedAt: Date(), peak: usage, avgCPU: usage, culprits: [])
        applyCulprits(to: &event)
        events.insert(event, at: 0)
        prune()
        save()
    }

    private func mergePeakCulprits(from processes: [ProcessData]) {
        // Önce bu tikteki aynı isimli süreçleri topla (çok süreçli uygulamalar — ör. tarayıcı
        // yardımcıları — tek satırda toplam yükleriyle görünsün), sonra zamana göre tepeyi al.
        var perTick: [String: Double] = [:]
        for proc in processes where proc.cpuUsage > 0 {
            perTick[proc.name, default: 0] += proc.cpuUsage
        }
        for (name, cpu) in perTick where cpu > 0.5 {
            activePeakCulprits[name] = max(activePeakCulprits[name] ?? 0, cpu)
        }
    }

    private func applyCulpritsToActiveEvent() {
        guard !events.isEmpty else { return }
        applyCulprits(to: &events[0])
    }

    private func applyCulprits(to event: inout LoadEvent) {
        var culprits = activePeakCulprits
            .sorted { $0.value > $1.value }
            .prefix(culpritCount)
            .map { LoadEvent.Culprit(name: $0.key, cpu: $0.value) }

        if culprits.isEmpty && event.peak >= threshold {
            culprits = [LoadEvent.Culprit(name: Self.systemLoadLabel, cpu: event.peak)]
        }

        event.culprits = Array(culprits)
    }

    private func finalizeActiveEvent() {
        guard !events.isEmpty else { return }
        events[0].endedAt = Date()
        if activeSampleCount > 0 {
            events[0].avgCPU = activeCpuSum / Double(activeSampleCount)
        }
        applyCulpritsToActiveEvent()
    }

    static let systemLoadLabel = "—"

    func displayName(for culprit: LoadEvent.Culprit) -> String {
        displayName(forName: culprit.name)
    }

    /// Suçlu adını gösterime çevirir — sistem-yükü etiketi ("—") yerelleştirilir.
    func displayName(forName name: String) -> String {
        name == Self.systemLoadLabel
            ? t("Toplam sistem yükü", "Total system load")
            : name
    }

    /// Eski kayıtlarda olay bitince 0% ile ezilmiş suçluları düzeltir.
    private static func repairCulprits(_ event: LoadEvent) -> LoadEvent {
        var fixed = event
        let allZero = fixed.culprits.isEmpty || fixed.culprits.allSatisfy { $0.cpu < 1 }
        if allZero && fixed.peak >= 80 {
            fixed.culprits = [LoadEvent.Culprit(name: systemLoadLabel, cpu: fixed.peak)]
        }
        return fixed
    }

    func clear() {
        events.removeAll()
        inHighLoad = false
        hasActiveHighLoadEvent = false
        activeSampleCount = 0
        activeCpuSum = 0
        activePeakCulprits = [:]
        save()
    }

    // MARK: - Saklama / temizleme

    private func prune() {
        let cutoff = Date().addingTimeInterval(-retention)
        events.removeAll { $0.startedAt < cutoff }
        if events.count > maxEvents {
            events.removeLast(events.count - maxEvents)
        }
    }

    // MARK: - Disk

    private static func makeFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("MacMonitor", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("load_events.json")
    }

    private static func loadFromDisk(_ url: URL, retention: TimeInterval) -> [LoadEvent] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([LoadEvent].self, from: data)
        else { return [] }

        let cutoff = Date().addingTimeInterval(-retention)
        return decoded
            .filter { $0.startedAt >= cutoff }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private func save() {
        let snapshot = events
        ioQueue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: self.fileURL, options: .atomic)
        }
    }
}
