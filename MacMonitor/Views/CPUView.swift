import SwiftUI
import Charts

/// İşlemci sayfası — kart tabanlı, modern düzen.
struct CPUView: View {
    @EnvironmentObject private var monitor: CPUMonitor
    @EnvironmentObject private var loadEvents: LoadEventRecorder

    private let coreColumns = [GridItem(.adaptive(minimum: 132), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                heroCard
                coresCard
                historyCard
                eventsCard
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Başlık kartı (model + bilgiler)

    private var headerCard: some View {
        PageHeader(
            icon: "cpu",
            gradient: [.blue, .indigo],
            title: monitor.modelName.isEmpty ? "İşlemci" : monitor.modelName,
            subtitle: monitor.machineModel
        )
    }

    // MARK: - Ana kart (gösterge + özet)

    private var heroCard: some View {
        HStack(spacing: 28) {
            UsageGauge(value: monitor.totalUsage,
                       color: cpuUsageColor(monitor.totalUsage),
                       caption: "Toplam Kullanım")
                .frame(width: 168, height: 168)

            VStack(alignment: .leading, spacing: 14) {
                summaryRow(icon: "person.fill", tint: .blue,
                           title: "Kullanıcı", value: avgUser)
                Divider()
                summaryRow(icon: "gearshape.fill", tint: .purple,
                           title: "Sistem", value: avgSystem)
                Divider()
                summaryRow(icon: "arrow.up.to.line", tint: cpuUsageColor(peakCore),
                           title: "En yüksek çekirdek", value: peakCore)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card()
    }

    private func summaryRow(icon: String, tint: Color, title: String, value: Double) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.15)))

            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Text(String(format: "%.1f%%", value))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
    }

    // MARK: - Çekirdekler kartı

    private var coresCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(icon: "square.grid.3x3.fill", title: "Çekirdekler")

            if monitor.cores.isEmpty {
                placeholder("Veri toplanıyor…")
            } else {
                LazyVGrid(columns: coreColumns, spacing: 12) {
                    ForEach(monitor.cores) { core in
                        CoreTile(core: core)
                    }
                }
            }
        }
        .card()
    }

    // MARK: - Geçmiş grafiği kartı

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle(icon: "waveform.path.ecg", title: "Kullanım Geçmişi")
            Text("Son 60 saniye · riskli eşik %\(Int(loadEvents.threshold))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            if monitor.totalUsageHistory.count > 1 {
                Chart {
                    ForEach(historyPoints, id: \.x) { point in
                        AreaMark(x: .value("Saniye", point.x),
                                 y: .value("Kullanım", point.y))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(colors: [.blue.opacity(0.35), .blue.opacity(0.02)],
                                               startPoint: .top, endPoint: .bottom)
                            )

                        LineMark(x: .value("Saniye", point.x),
                                 y: .value("Kullanım", point.y))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(.blue)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }

                    // Sıkıntılı eşik çizgisi
                    RuleMark(y: .value("Eşik", loadEvents.threshold))
                        .foregroundStyle(.orange.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("riskli")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Int.self) { Text("\(v)%") }
                        }
                    }
                }
                .chartXScale(domain: -60...0)
                .chartXAxis {
                    AxisMarks(values: [-60, -40, -20, 0]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text(v == 0 ? "şimdi" : "\(v)sn")
                            }
                        }
                    }
                }
                .frame(height: 180)
            } else {
                placeholder("Veri toplanıyor…")
                    .frame(height: 180)
            }
        }
        .card()
    }

    /// Geçmişi (x: saniye önce, en yeni = 0) noktalara çevirir.
    private var historyPoints: [(x: Int, y: Double)] {
        let h = monitor.totalUsageHistory
        let n = h.count
        return h.enumerated().map { (i, value) in (x: -(n - 1 - i) * 2, y: value) }
    }

    // MARK: - Yük olayları kartı (geriye dönük takip)

    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle(icon: "exclamationmark.bubble", title: "Yük Olayları")
                if !loadEvents.events.isEmpty {
                    Button("Temizle") { loadEvents.clear() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }

            Text("CPU %\(Int(loadEvents.threshold)) üstüne çıktığında o an ve yükü alan işlemler kaydedilir. Son 1 ay saklanır.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if loadEvents.events.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("Riskli yük kaydı yok — sistem rahat.")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(loadEvents.events.prefix(10).enumerated()), id: \.element.id) { index, event in
                        if index > 0 { Divider() }
                        eventRow(event)
                    }
                }
            }
        }
        .card()
    }

    private func eventRow(_ event: LoadEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(cpuUsageColor(event.peak))
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(event.startedAt.formatted(date: .omitted, time: .standard))
                        .font(.callout.weight(.medium))
                        .monospacedDigit()
                    Text("· tepe %\(Int(event.peak.rounded()))")
                        .font(.callout)
                        .foregroundStyle(cpuUsageColor(event.peak))
                }
                Text(culpritText(event))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    private func culpritText(_ event: LoadEvent) -> String {
        guard !event.culprits.isEmpty else { return "İşlem bilgisi yok" }
        return event.culprits
            .map { "\($0.name) %\(Int($0.cpu.rounded()))" }
            .joined(separator: "  ·  ")
    }

    // MARK: - Ortak parçalar

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 24)
    }

    // MARK: - Hesaplanan değerler

    private var avgUser: Double {
        let c = monitor.cores
        return c.isEmpty ? 0 : c.map(\.user).reduce(0, +) / Double(c.count)
    }
    private var avgSystem: Double {
        let c = monitor.cores
        return c.isEmpty ? 0 : c.map(\.system).reduce(0, +) / Double(c.count)
    }
    private var peakCore: Double {
        monitor.cores.map(\.usage).max() ?? 0
    }
}

// MARK: - Kullanım yüzdesine göre renk (yeşil <50, sarı <80, kırmızı ≥80)

func cpuUsageColor(_ usage: Double) -> Color {
    switch usage {
    case ..<50: return .green
    case ..<80: return .yellow
    default:    return .red
    }
}

// MARK: - Çekirdek kutucuğu

struct CoreTile: View {
    let core: CPUData

    /// Çekirdek tipine göre renk (Performans turuncu, Verimlilik camgöbeği).
    private var kindTint: Color {
        switch core.kind {
        case .performance: return .orange
        case .efficiency:  return .teal
        case .unknown:     return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "Core - %02d", core.id + 1))
                        .font(.caption.weight(.semibold))
                    if !core.kind.label.isEmpty {
                        Text("(\(core.kind.label))")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(kindTint)
                    }
                }
                Spacer()
                Text("\(Int(core.usage.rounded()))%")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(cpuUsageColor(core.usage))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(cpuUsageColor(core.usage))
                        .frame(width: geo.size.width * min(max(core.usage, 0), 100) / 100)
                }
            }
            .frame(height: 7)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
    }
}

#Preview {
    CPUView()
        .environmentObject(CPUMonitor())
        .environmentObject(LoadEventRecorder(cpu: CPUMonitor(), process: ProcessMonitor()))
        .frame(width: 640, height: 800)
}
