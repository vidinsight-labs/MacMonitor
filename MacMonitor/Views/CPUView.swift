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
                // Aşağıdaki iki kart yalnızca LoadEventRecorder'ı gözleyen ayrı görünümlerdir;
                // böylece 2 sn'lik CPU tiki bunları (ve olayların yeniden bucket'lanmasını) tetiklemez.
                LoadHistoryView()
                LoadEventsCard()
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
                LazyVGrid(columns: PageLayout.coreGridColumns(), spacing: 12) {
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

// MARK: - Yük olayları kartı (geriye dönük takip)

/// Yalnızca `LoadEventRecorder`'ı gözleyen ayrı kart — CPU'nun 2 sn'lik tiki bu kartı
/// (hafta özeti, olay listesi, satır yeniden kimlikleme) tekrar hesaplatmaz.
struct LoadEventsCard: View {
    @ObservedObject private var loc = Localizer.shared
    @EnvironmentObject private var loadEvents: LoadEventRecorder

    @State private var expandedEventID: UUID?
    @State private var showAllEvents = false

    private var weekSummary: LoadEventWeekSummary {
        LoadEventFormatting.weekSummary(from: loadEvents.events,
                                        liveFirst: loadEvents.hasActiveHighLoadEvent)
    }

    private var visibleEvents: [LoadEvent] {
        let limit = showAllEvents ? loadEvents.events.count : min(30, loadEvents.events.count)
        return Array(loadEvents.events.prefix(limit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle(icon: "exclamationmark.bubble", title: t("Yük Olayları", "Load Events"))
                if !loadEvents.events.isEmpty {
                    Button(t("Temizle", "Clear")) { loadEvents.clear() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }

            Text(t("CPU %\(Int(loadEvents.threshold)) üstüne çıktığında başlangıç, süre, tepe/ortalama CPU ve yükü alan işlemler kaydedilir. Son 1 ay saklanır.", "When CPU rises above %\(Int(loadEvents.threshold)), start time, duration, peak/average CPU and responsible processes are recorded. Kept for the last 1 month."))
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
                weekSummaryBanner

                VStack(spacing: 0) {
                    ForEach(Array(visibleEvents.enumerated()), id: \.element.id) { index, event in
                        if index > 0 { Divider() }
                        LoadEventRowView(
                            event: event,
                            isLive: loadEvents.hasActiveHighLoadEvent && index == 0,
                            isExpanded: expandedEventID == event.id,
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedEventID = expandedEventID == event.id ? nil : event.id
                                }
                            }
                        )
                    }
                }

                if loadEvents.events.count > 30 {
                    Button(showAllEvents
                           ? t("Daha az göster", "Show less")
                           : t("Tümünü göster (\(loadEvents.events.count))", "Show all (\(loadEvents.events.count))")) {
                        withAnimation { showAllEvents.toggle() }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
            }
        }
        .card()
    }

    private var weekSummaryBanner: some View {
        let fmt = LoadEventFormatting.duration(weekSummary.totalDuration)
        return HStack(spacing: 12) {
            summaryChip(icon: "calendar", value: "\(weekSummary.eventCount)",
                        label: t("7 günde olay", "events in 7d"))
            summaryChip(icon: "clock", value: t(fmt.tr, fmt.en),
                        label: t("toplam süre", "total duration"))
            if let top = weekSummary.topCulprit {
                summaryChip(icon: "app.fill", value: loadEvents.displayName(forName: top),
                            label: t("en sık suçlu", "top culprit"))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    private func summaryChip(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(label, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            Text(value)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
