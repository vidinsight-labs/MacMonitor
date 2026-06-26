import Foundation

/// Yüksek yük ("riskli") anının kaydı — ne zaman olduğu, süresi ve yükü alan işlemler.
/// Diske kaydedilebilmesi için `Codable`.
struct LoadEvent: Identifiable, Codable {
    let id = UUID()
    let startedAt: Date
    var endedAt: Date?
    var peak: Double              // olaydaki tepe toplam CPU (%)
    var avgCPU: Double            // olay boyunca ortalama CPU (%)
    var culprits: [Culprit]       // en çok CPU kullanan işlemler (olay sonunda güncellenir)

    /// Bitmiş olaylarda `endedAt`; devam eden olaylarda şu ana kadarki süre (`isLive == true`).
    func duration(relativeTo now: Date = Date(), isLive: Bool = false) -> TimeInterval? {
        if let endedAt {
            return max(0, endedAt.timeIntervalSince(startedAt))
        }
        guard isLive else { return nil }
        return max(0, now.timeIntervalSince(startedAt))
    }

    private enum CodingKeys: String, CodingKey {
        case startedAt, endedAt, peak, avgCPU, culprits
    }

    init(startedAt: Date, peak: Double, avgCPU: Double = 0,
         culprits: [Culprit], endedAt: Date? = nil) {
        self.startedAt = startedAt
        self.peak = peak
        self.avgCPU = avgCPU
        self.culprits = culprits
        self.endedAt = endedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        endedAt = try c.decodeIfPresent(Date.self, forKey: .endedAt)
        peak = try c.decode(Double.self, forKey: .peak)
        avgCPU = try c.decodeIfPresent(Double.self, forKey: .avgCPU) ?? peak
        culprits = try c.decode([Culprit].self, forKey: .culprits)
    }

    struct Culprit: Identifiable, Codable {
        let id = UUID()
        let name: String
        let cpu: Double

        private enum CodingKeys: String, CodingKey {
            case name, cpu
        }
    }
}

// MARK: - Özet istatistikler

struct LoadEventWeekSummary {
    let eventCount: Int
    let totalDuration: TimeInterval
    let topCulprit: String?
}

enum LoadEventFormatting {
    static func duration(_ seconds: TimeInterval) -> (tr: String, en: String) {
        let s = Int(seconds.rounded())
        if s < 60 {
            return ("\(s) sn", "\(s)s")
        }
        let m = s / 60
        let rem = s % 60
        if m < 60 {
            if rem > 0 { return ("\(m) dk \(rem) sn", "\(m)m \(rem)s") }
            return ("\(m) dk", "\(m)m")
        }
        let h = m / 60
        let rm = m % 60
        return ("\(h) sa \(rm) dk", "\(h)h \(rm)m")
    }

    /// `liveFirst`: en yeni olay (`events` azalan sıralı olduğundan ilk öğe) hâlâ sürüyorsa,
    /// toplam süreye şu ana kadarki canlı süresi de katılır.
    static func weekSummary(from events: [LoadEvent], days: Int = 7,
                            liveFirst: Bool = false) -> LoadEventWeekSummary {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recent = events.filter { $0.startedAt >= cutoff }
        let now = Date()
        let total = recent.enumerated()
            .compactMap { index, event in
                event.duration(relativeTo: now, isLive: liveFirst && index == 0)
            }
            .reduce(0, +)

        var culpritCounts: [String: Int] = [:]
        for event in recent {
            if let top = event.culprits.first {
                culpritCounts[top.name, default: 0] += 1
            }
        }
        let top = culpritCounts.max(by: { $0.value < $1.value })?.key

        return LoadEventWeekSummary(eventCount: recent.count,
                                    totalDuration: total,
                                    topCulprit: top)
    }
}
