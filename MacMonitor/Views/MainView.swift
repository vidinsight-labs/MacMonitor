import SwiftUI
import Combine

/// Ana ekran: kenar çubuğu (NavigationSplitView) + sekme içeriği + alt durum çubuğu.
///
/// Performans notu: Durum çubuğundaki saat ve sağlık göstergesi **ayrı alt görünümlerdir**.
/// Böylece 1 sn'lik saat tüm ağır detay görünümünü (grafik vb.) değil yalnızca kendini
/// yeniden çizer; detay görünümü de yalnızca ilgili monitör veri yayınladığında güncellenir.
struct MainView: View {
    @State private var selection: Tab? = .assistant

    /// Kenar çubuğu sekmeleri.
    enum Tab: String, CaseIterable, Hashable {
        case assistant, system, cpu, memory, fans, processes, help

        var title: String {
            switch self {
            case .assistant: return "Asistan"
            case .system:    return "Sistem"
            case .cpu:       return "İşlemci"
            case .memory:    return "Bellek"
            case .fans:      return "Fanlar"
            case .processes: return "İşlemler"
            case .help:      return "Yardım"
            }
        }

        var symbol: String {
            switch self {
            case .assistant: return "sparkles"
            case .system:    return "gauge.with.dots.needle.bottom.50percent"
            case .cpu:       return "cpu"
            case .memory:    return "memorychip"
            case .fans:      return "fanblades"
            case .processes: return "list.bullet.rectangle"
            case .help:      return "questionmark.circle"
            }
        }

        /// Kenar çubuğu ikonunun rengi (sayfa başlıklarıyla uyumlu).
        var color: Color {
            switch self {
            case .assistant: return .pink
            case .system:    return .gray
            case .cpu:       return .blue
            case .memory:    return .purple
            case .fans:      return .teal
            case .processes: return .green
            case .help:      return .orange
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, id: \.self, selection: $selection) { tab in
                Label {
                    Text(tab.title)
                } icon: {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(tab.color)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: tab.symbol)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                        )
                }
                .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
            .navigationTitle("MacMonitor")
        } detail: {
            VStack(spacing: 0) {
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                StatusBarView()
            }
            .navigationTitle(selection?.title ?? "MacMonitor")
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    // MARK: - Sekme içeriği

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .cpu {
        case .cpu:       CPUView()
        case .memory:    MemoryView()
        case .fans:      FanView()
        case .processes: ProcessView()
        case .system:    SystemView()
        case .assistant: AssistantView()
        case .help:      HelpView()
        }
    }
}

// MARK: - Alt durum çubuğu

/// Çalışma süresi + sağlık göstergesi + saat. CPU/bellek değiştiğinde yalnızca bu çubuk
/// yeniden çizilir (ağır detay görünümü değil).
private struct StatusBarView: View {
    @EnvironmentObject private var cpuMonitor: CPUMonitor
    @EnvironmentObject private var memoryMonitor: MemoryMonitor

    var body: some View {
        HStack(spacing: 16) {
            Label(uptimeString, systemImage: "clock.arrow.circlepath")

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(health.color)
                    .frame(width: 8, height: 8)
                Text("Sistem: \(health.label)")
            }

            Spacer()

            StatusClock()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    /// CPU veya RAM kullanımının yükseği (%).
    private var load: Double {
        let cpu = cpuMonitor.totalUsage
        let mem = memoryMonitor.memory
        let ram = mem.total > 0 ? Double(mem.used) / Double(mem.total) * 100 : 0
        return max(cpu, ram)
    }

    private var health: (color: Color, label: String) {
        switch load {
        case ..<70:  return (.green, "Normal")
        case ..<90:  return (.yellow, "Yüksek")
        default:     return (.red, "Kritik")
        }
    }

    private var uptimeString: String {
        let total = Int(ProcessInfo.processInfo.systemUptime)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let mins = (total % 3_600) / 60
        if days > 0  { return "Çalışma: \(days)g \(hours)s \(mins)d" }
        if hours > 0 { return "Çalışma: \(hours)s \(mins)d" }
        return "Çalışma: \(mins)d"
    }
}

/// Saniyede bir güncellenen saat — yalnızca kendini yeniden çizer.
private struct StatusClock: View {
    @State private var now = Date()
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Label(now.formatted(date: .omitted, time: .standard), systemImage: "clock")
            .monospacedDigit()
            .onReceive(clock) { now = $0 }
    }
}

#Preview {
    MainView()
        .environmentObject(CPUMonitor())
        .environmentObject(MemoryMonitor())
        .environmentObject(FanMonitor())
        .environmentObject(ProcessMonitor())
}
