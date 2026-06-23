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

    /// Riskli bölge eşiği (% toplam CPU).
    let threshold: Double = 80

    /// Saklama süresi: 1 ay (30 gün).
    private let retention: TimeInterval = 30 * 24 * 60 * 60
    /// Bellek/dosya için güvenlik üst sınırı (1 ayda beklenenden çok fazlası birikmesin).
    private let maxEvents = 2_000
    private let culpritCount = 3

    private var inHighLoad = false
    private var cancellable: AnyCancellable?

    /// Disk işlemleri için ayrı seri kuyruk (ana iş parçacığını bloklamaz).
    private let ioQueue = DispatchQueue(label: "com.macmonitor.loadevents.io", qos: .utility)
    private let fileURL: URL

    init(cpu: CPUMonitor, process: ProcessMonitor) {
        fileURL = Self.makeFileURL()
        events = Self.loadFromDisk(fileURL, retention: retention)

        // Mevcut CPU yayınına abone ol — yeni bir ölçüm zamanlayıcısı oluşturmaz.
        cancellable = cpu.$totalUsage
            .sink { [weak self, weak process] usage in
                self?.handle(usage: usage, processes: process?.processes ?? [])
            }
    }

    // MARK: - Olay yakalama

    private func handle(usage: Double, processes: [ProcessData]) {
        guard usage >= threshold else {
            // Riskli dönem bitti: son tepe değerini diske yaz (nadir; her tik değil).
            if inHighLoad {
                inHighLoad = false
                save()
            }
            return
        }

        if inHighLoad {
            // Sürmekte olan olayın tepe değerini bellekte güncelle — disk yazımı yok.
            if !events.isEmpty {
                events[0].peak = max(events[0].peak, usage)
            }
            return
        }

        // Yeni riskli olay: o anki ilk N işlemi (CPU'ya göre sıralı) yakala.
        inHighLoad = true
        let culprits = processes.prefix(culpritCount).map {
            LoadEvent.Culprit(name: $0.name, cpu: $0.cpuUsage)
        }
        events.insert(LoadEvent(startedAt: Date(), peak: usage, culprits: Array(culprits)), at: 0)
        prune()
        save()
    }

    func clear() {
        events.removeAll()
        save()
    }

    // MARK: - Saklama / temizleme

    /// 1 aydan eski kayıtları (ve güvenlik sınırını aşanları) at.
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

    /// Diskten yükler ve 1 aydan eski kayıtları eler.
    private static func loadFromDisk(_ url: URL, retention: TimeInterval) -> [LoadEvent] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([LoadEvent].self, from: data)
        else { return [] }

        let cutoff = Date().addingTimeInterval(-retention)
        return decoded
            .filter { $0.startedAt >= cutoff }
            .sorted { $0.startedAt > $1.startedAt }
    }

    /// Anlık görüntüyü arka planda diske yazar (atomik). Yalnızca olay sınırlarında çağrılır.
    private func save() {
        let snapshot = events
        ioQueue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: self.fileURL, options: .atomic)
        }
    }
}
