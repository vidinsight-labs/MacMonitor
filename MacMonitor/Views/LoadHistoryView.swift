import SwiftUI
import Charts

/// Yük olayları zaman çizelgesi — günlük tepe CPU ve suçlu uygulama.
struct LoadHistoryView: View {
    @ObservedObject private var loc = Localizer.shared
    @EnvironmentObject private var loadEvents: LoadEventRecorder

    private var dailyBuckets: [DailyLoadBucket] {
        Self.bucketEvents(loadEvents.events)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "calendar", title: t("Yük Zaman Çizelgesi", "Load Timeline"))
            Text(t("Son 30 günde günlük tepe CPU ve en sık suçlu uygulama.", "Daily peak CPU and top culprit app over the last 30 days."))
                .font(.caption)
                .foregroundStyle(.secondary)

            if dailyBuckets.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text(t("Henüz kayıtlı yük olayı yok.", "No load events recorded yet."))
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.vertical, 8)
            } else {
                Chart(dailyBuckets) { bucket in
                    BarMark(
                        x: .value("Gün", bucket.day, unit: .day),
                        y: .value("Tepe", bucket.peakCPU)
                    )
                    .foregroundStyle(cpuUsageColor(bucket.peakCPU))
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 80, 100]) { v in
                        AxisGridLine()
                        AxisValueLabel {
                            if let n = v.as(Int.self) { Text("\(n)%") }
                        }
                    }
                }
                .frame(height: 180)

                VStack(spacing: 0) {
                    ForEach(dailyBuckets.prefix(7)) { bucket in
                        HStack {
                            Text(bucket.day.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                            Spacer()
                            if bucket.eventCount > 0 {
                                Text(t("\(bucket.eventCount) olay", "\(bucket.eventCount) events"))
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
                            }
                            Text(t("Tepe %\(Int(bucket.peakCPU.rounded()))", "Peak %\(Int(bucket.peakCPU.rounded()))"))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(cpuUsageColor(bucket.peakCPU))
                            if let culprit = bucket.topCulprit {
                                Text("· \(loadEvents.displayName(forName: culprit))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: 120, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 4)
                        if bucket.id != dailyBuckets.prefix(7).last?.id { Divider() }
                    }
                }
            }
        }
        .card()
    }
}

struct DailyLoadBucket: Identifiable {
    let id: String
    let day: Date
    let peakCPU: Double
    let topCulprit: String?
    let eventCount: Int
}

extension LoadHistoryView {
    static func bucketEvents(_ events: [LoadEvent]) -> [DailyLoadBucket] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let filtered = events.filter { $0.startedAt >= cutoff }
        guard !filtered.isEmpty else { return [] }

        var byDay: [String: (peak: Double, culprits: [String: Int], count: Int)] = [:]
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        for event in filtered {
            let day = calendar.startOfDay(for: event.startedAt)
            let key = dayFormatter.string(from: day)
            var entry = byDay[key] ?? (peak: 0, culprits: [:], count: 0)
            entry.peak = max(entry.peak, event.peak)
            entry.count += 1
            if let top = event.culprits.first {
                entry.culprits[top.name, default: 0] += 1
            }
            byDay[key] = entry
        }

        return byDay.compactMap { key, value -> DailyLoadBucket? in
            guard let day = dayFormatter.date(from: key) else { return nil }
            let top = value.culprits.max(by: { $0.value < $1.value })?.key
            return DailyLoadBucket(id: key, day: day, peakCPU: value.peak,
                                   topCulprit: top, eventCount: value.count)
        }
        .sorted { $0.day > $1.day }
    }
}

#Preview {
    LoadHistoryView()
        .environmentObject(LoadEventRecorder(cpu: CPUMonitor(), process: ProcessMonitor()))
        .padding()
}
