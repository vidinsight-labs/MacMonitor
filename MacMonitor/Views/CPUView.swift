import SwiftUI
import Charts

/// İşlemci sayfası — kart tabanlı, modern düzen.
struct CPUView: View {
    @ObservedObject private var loc = Localizer.shared
    @EnvironmentObject private var monitor: CPUMonitor
    @EnvironmentObject private var loadEvents: LoadEventRecorder
    @Environment(\.contentWidth) private var contentWidth

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                StatusBanner(level: cpuLevel, title: cpuStatus.title, message: cpuStatus.message)
                heroCard
                coresCard
                historyCard
                LoadHistoryView()
                eventsCard
            }
            .responsivePageLayout()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Başlık kartı (model + bilgiler)

    private var headerCard: some View {
        PageHeader(
            icon: "cpu",
            gradient: [.blue, .indigo],
            title: monitor.modelName.isEmpty ? t("İşlemci", "Processor") : monitor.modelName,
            subtitle: monitor.machineModel
        )
    }

    // MARK: - Ana kart (gösterge + özet)

    private var heroCard: some View {
        HeroMetricLayout(spacing: 28) {
            UsageGauge(value: monitor.totalUsage,
                       color: cpuUsageColor(monitor.totalUsage),
                       caption: t("Toplam Kullanım", "Total Usage"))
                .frame(width: 168, height: 168)
        } summary: {
            VStack(alignment: .leading, spacing: 14) {
                summaryRow(icon: "person.fill", tint: .blue,
                           title: t("Kullanıcı", "User"), value: avgUser)
                Divider()
                summaryRow(icon: "gearshape.fill", tint: .purple,
                           title: t("Sistem", "System"), value: avgSystem)
                Divider()
                summaryRow(icon: "arrow.up.to.line", tint: cpuUsageColor(peakCore),
                           title: t("En yüksek çekirdek", "Highest core"), value: peakCore)
            }
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
            sectionTitle(icon: "square.grid.3x3.fill", title: t("Çekirdekler", "Cores"))

            if monitor.cores.isEmpty {
                placeholder(t("Veri toplanıyor…", "Collecting data…"))
            } else {
                LazyVGrid(columns: PageLayout.coreGridColumns(for: contentWidth), spacing: 12) {
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
            sectionTitle(icon: "waveform.path.ecg", title: t("Kullanım Geçmişi", "Usage History"))
            Text(t("Son 60 saniye · riskli eşik %\(Int(loadEvents.threshold))", "Last 60 seconds · risky threshold %\(Int(loadEvents.threshold))"))
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
                            Text(t("riskli", "risky"))
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
                                Text(v == 0 ? t("şimdi", "now") : t("\(v)sn", "\(v)s"))
                            }
                        }
                    }
                }
                .frame(height: 180)
            } else {
                placeholder(t("Veri toplanıyor…", "Collecting data…"))
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
                sectionTitle(icon: "exclamationmark.bubble", title: t("Yük Olayları", "Load Events"))
                if !loadEvents.events.isEmpty {
                    Button(t("Temizle", "Clear")) { loadEvents.clear() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }

            Text(t("CPU %\(Int(loadEvents.threshold)) üstüne çıktığında o an ve yükü alan işlemler kaydedilir. Son 1 ay saklanır.", "When CPU rises above %\(Int(loadEvents.threshold)), that moment and the processes taking up the load are recorded. Kept for the last 1 month."))
                .font(.caption)
                .foregroundStyle(.secondary)

            if loadEvents.events.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text(t("Riskli yük kaydı yok — sistem rahat.", "No risky load records — the system is relaxed."))
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
                    Text(t("· tepe %\(Int(event.peak.rounded()))", "· peak %\(Int(event.peak.rounded()))"))
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
        guard !event.culprits.isEmpty else { return t("İşlem bilgisi yok", "No process information") }
        return event.culprits
            .map { "\($0.name) %\(Int($0.cpu.rounded()))" }
            .joined(separator: "  ·  ")
    }

    // MARK: - Ortak parçalar

    private func placeholder(_ text: String) -> some View {
        VStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 24)
    }

    // MARK: - Hesaplanan değerler

    /// Sayfa üstü durum yargısı (ortak eşikler — Genel Bakış ile aynı kaynak).
    private var cpuLevel: Level { .cpu(monitor.totalUsage) }

    private var cpuStatus: (title: String, message: String) {
        switch cpuLevel {
        case .normal:
            return (t("İşlemci rahat", "Processor relaxed"), t("Belirgin bir yavaşlama yok; sistem boşta sayılır.", "No noticeable slowdown; the system is essentially idle."))
        case .warning:
            return (t("İşlemci yoğun çalışıyor", "Processor working hard"), t("Şu an oldukça meşgul. Ağır uygulamalar ve çok sayıda sekme yükü artırır.", "It is quite busy right now. Heavy apps and many tabs increase the load."))
        case .critical:
            return (t("İşlemci çok yüklü", "Processor overloaded"), t("Uygulamalar yavaşlayabilir — aşağıdaki çekirdek ve yük olaylarından sebebi görebilirsin.", "Apps may slow down — you can find the cause in the cores and load events below."))
        }
    }

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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "Core - %02d", core.id + 1))
                        .font(.callout.weight(.semibold))
                    if !core.kind.label.isEmpty {
                        Text("(\(core.kind.label))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(kindTint)
                    }
                }
                Spacer()
                Text("\(Int(core.usage.rounded()))%")
                    .font(.title3.weight(.bold))
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
            .frame(height: 9)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
    }
}

#Preview("720×520") {
    CPUView()
        .environmentObject(CPUMonitor())
        .environmentObject(LoadEventRecorder(cpu: CPUMonitor(), process: ProcessMonitor()))
        .previewLayout(width: 720, height: 520, detailWidth: 700)
}

#Preview("1280×800") {
    CPUView()
        .environmentObject(CPUMonitor())
        .environmentObject(LoadEventRecorder(cpu: CPUMonitor(), process: ProcessMonitor()))
        .previewLayout(width: 1280, height: 800, detailWidth: 1000)
}
