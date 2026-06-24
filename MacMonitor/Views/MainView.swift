import SwiftUI
import Combine

/// Ana ekran: kenar çubuğu (NavigationSplitView) + sekme içeriği + alt durum çubuğu.
///
/// Performans notu: Durum çubuğundaki saat ve sağlık göstergesi **ayrı alt görünümlerdir**.
/// Böylece 1 sn'lik saat tüm ağır detay görünümünü (grafik vb.) değil yalnızca kendini
/// yeniden çizer; detay görünümü de yalnızca ilgili monitör veri yayınladığında güncellenir.
struct MainView: View {
    @ObservedObject private var loc = Localizer.shared

    // Seçili sekme kalıcı (yeniden açılışta hatırlanır).
    @AppStorage("selectedTab") private var selectedTabRaw = Tab.overview.rawValue

    private var currentTab: Tab { Tab(rawValue: selectedTabRaw) ?? .overview }
    private var selectionBinding: Binding<Tab?> {
        Binding(get: { currentTab },
                set: { selectedTabRaw = ($0 ?? .overview).rawValue })
    }

    /// Kenar çubuğu sekmeleri.
    enum Tab: String, CaseIterable, Hashable {
        case overview, cpu, memory, fans, system, security, processes, help

        var title: String {
            switch self {
            case .overview:  return t("Genel Bakış", "Overview")
            case .system:    return t("Sistem", "System")
            case .cpu:       return t("İşlemci", "Processor")
            case .memory:    return t("Bellek", "Memory")
            case .fans:      return t("Fanlar", "Fans")
            case .security:  return t("Güvenlik", "Security")
            case .processes: return t("İşlemler", "Processes")
            case .help:      return t("Yardım", "Help")
            }
        }

        var symbol: String {
            switch self {
            case .overview:  return "square.grid.2x2.fill"
            case .system:    return "gauge.with.dots.needle.bottom.50percent"
            case .cpu:       return "cpu"
            case .memory:    return "memorychip"
            case .fans:      return "fanblades"
            case .security:  return "lock.shield"
            case .processes: return "list.bullet.rectangle"
            case .help:      return "questionmark.circle"
            }
        }

        /// Kenar çubuğu ikonunun rengi (sayfa başlıklarıyla uyumlu).
        var color: Color {
            switch self {
            case .overview:  return .blue
            case .system:    return .gray
            case .cpu:       return .blue
            case .memory:    return .purple
            case .fans:      return .teal
            case .security:  return .indigo
            case .processes: return .green
            case .help:      return .orange
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, id: \.self, selection: selectionBinding) { tab in
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
            .safeAreaInset(edge: .bottom) {
                LanguageToggle()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
        } detail: {
            VStack(spacing: 0) {
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                StatusBarView()
            }
            .navigationTitle(currentTab.title)
        }
        .frame(minWidth: 720, minHeight: 520)
        .background { tabShortcuts.opacity(0) }   // ⌘1…⌘8 ile sekme geçişi
    }

    /// Gizli kısayol butonları: ⌘1…⌘8 sekmeleri açar.
    private var tabShortcuts: some View {
        ZStack {
            ForEach(Array(Tab.allCases.enumerated()), id: \.offset) { index, tab in
                // Yalnızca ⌘1…⌘9 (tek haneli) — 10+ sekmede Character("10") çökerdi.
                if index < 9 {
                    Button("") { selectedTabRaw = tab.rawValue }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
        }
    }

    // MARK: - Sekme içeriği

    @ViewBuilder
    private var detail: some View {
        switch currentTab {
        case .overview:  OverviewView()
        case .cpu:       CPUView()
        case .memory:    MemoryView()
        case .fans:      FanView()
        case .processes: ProcessView()
        case .system:    SystemView()
        case .security:  SecurityView()
        case .help:      HelpView()
        }
    }
}

// MARK: - Alt durum çubuğu

/// Çalışma süresi + sağlık göstergesi + saat. CPU/bellek değiştiğinde yalnızca bu çubuk
/// yeniden çizilir (ağır detay görünümü değil).
private struct StatusBarView: View {
    @ObservedObject private var loc = Localizer.shared
    @EnvironmentObject private var cpuMonitor: CPUMonitor
    @EnvironmentObject private var memoryMonitor: MemoryMonitor

    var body: some View {
        HStack(spacing: 16) {
            Label(uptimeString, systemImage: "clock.arrow.circlepath")
                .help(t("Cihazın açık kalma süresi", "Time the device has been on"))

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(health.color)
                    .frame(width: 8, height: 8)
                Text("\(t("Sistem", "System")): \(health.label)")
            }
            .help(t("Genel sistem yükü (CPU ve RAM kullanımının yükseği)",
                    "Overall system load (higher of CPU and RAM usage)"))

            Spacer()

            StatusClock()
                .help(t("Geçerli saat", "Current time"))
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
        case ..<70:  return (.green, t("Normal", "Normal"))
        case ..<90:  return (.yellow, t("Yüksek", "High"))
        default:     return (.red, t("Kritik", "Critical"))
        }
    }

    private var uptimeString: String {
        let total = Int(ProcessInfo.processInfo.systemUptime)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let mins = (total % 3_600) / 60
        let prefix = t("Çalışma", "Uptime")
        if days > 0  { return t("\(prefix): \(days)g \(hours)s \(mins)d", "\(prefix): \(days)d \(hours)h \(mins)m") }
        if hours > 0 { return t("\(prefix): \(hours)s \(mins)d", "\(prefix): \(hours)h \(mins)m") }
        return t("\(prefix): \(mins)d", "\(prefix): \(mins)m")
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
