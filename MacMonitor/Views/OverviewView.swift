import SwiftUI

/// Genel Bakış — açılış sayfası. "Bilgisayarım iyi durumda mı?" sorusunu tek bakışta,
/// sade dille yanıtlar: büyük bir durum yargısı + 4 temel metrik kartı + (varsa) suçluyu
/// adıyla gösteren "Dikkat" uyarıları. Kartlara tıklanınca ilgili detay sekmesine geçer.
struct OverviewView: View {
    @ObservedObject private var loc = Localizer.shared
    @EnvironmentObject private var cpuMonitor: CPUMonitor
    @EnvironmentObject private var memoryMonitor: MemoryMonitor
    @EnvironmentObject private var fanMonitor: FanMonitor
    @EnvironmentObject private var processMonitor: ProcessMonitor
    @EnvironmentObject private var systemInfo: SystemInfoMonitor
    @EnvironmentObject private var security: SecurityMonitor
    @EnvironmentObject private var notifications: NotificationManager

    // Kartlara tıklayınca sekme değiştirmek için (MainView ile aynı kalıcı anahtar).
    @AppStorage("selectedTab") private var selectedTabRaw = MainView.Tab.overview.rawValue

    @State private var healthCheckRun = false

    // Sabit 4 sütun — pencere büyüse de yerleşim değişmez.
    private let metricColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PageHeader(
                    icon: "macbook.gen2",
                    gradient: [.blue, .teal],
                    title: t("Genel Bakış", "Overview"),
                    subtitle: systemInfo.diskTotal > 0 || !cpuMonitor.machineModel.isEmpty
                        ? (cpuMonitor.machineModel.isEmpty ? t("Bilgisayarınızın anlık özeti", "A quick snapshot of your computer") : cpuMonitor.machineModel)
                        : t("Bilgisayarınızın anlık özeti", "A quick snapshot of your computer")
                )

                verdictCard

                LazyVGrid(columns: metricColumns, spacing: 12) {
                    MetricCard(icon: "cpu", title: t("İşlemci", "Processor"),
                               value: "%\(Int(cpuMonitor.totalUsage.rounded()))",
                               level: cpuLevel)
                        .onTapGesture { go(.cpu) }

                    MetricCard(icon: "memorychip", title: t("Bellek", "Memory"),
                               value: "%\(Int(ramPercent.rounded()))",
                               level: ramLevel)
                        .onTapGesture { go(.memory) }

                    MetricCard(icon: "thermometer.medium", title: t("Sıcaklık", "Temperature"),
                               value: tempValue, level: tempLevel)
                        .onTapGesture { go(.fans) }

                    MetricCard(icon: "internaldrive", title: t("Disk", "Disk"),
                               value: "%\(Int(diskPercent.rounded()))",
                               level: diskLevel)
                        .onTapGesture { go(.system) }
                }

                attentionCard

                healthScanCard

                notificationCard
            }
            .padding(20)
            .centeredPageContent()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Üst durum yargısı (genel sağlık)

    private var verdictCard: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(overall.color.opacity(0.18))
                .frame(width: 54, height: 54)
                .overlay(
                    Image(systemName: overall.verdictIcon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(overall.color)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(overall.headline)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(overall.color)
                Text(overall.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .card()
    }

    // MARK: - Dikkat (suçlu uygulama + öneri) ya da "her şey yolunda"

    private var attentionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: issues.isEmpty ? "checkmark.circle" : "exclamationmark.bubble",
                         title: issues.isEmpty ? t("Durum", "Status") : t("Dikkat", "Attention"))

            if issues.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text(t("Şu an dikkat gerektiren bir şey yok — sistem rahat.", "Nothing needs your attention right now — the system is relaxed."))
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(issues.enumerated()), id: \.element.id) { index, issue in
                        if index > 0 { Divider() }
                        issueRow(issue)
                    }
                }
            }
        }
        .card()
    }

    private func issueRow(_ issue: Issue) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: issue.icon)
                .foregroundStyle(issue.color)
                .frame(width: 22)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.title)
                    .font(.callout.weight(.semibold))
                Text(issue.advice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Sağlık Taraması (tek tıkla tam kontrol listesi)

    private var healthScanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle(icon: "stethoscope", title: t("Sağlık Taraması", "Health Scan"))
                if healthCheckRun && !security.isScanning {
                    Button(t("Yeniden Kontrol Et", "Check Again")) { runHealthCheck() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }

            if !healthCheckRun {
                Text(t("İşlemci, bellek, disk, sıcaklık, pil ve güvenliği tek seferde kontrol edip yapılacaklar listesi çıkarır.", "Checks the processor, memory, disk, temperature, battery and security all at once and produces a to-do list."))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    runHealthCheck()
                } label: {
                    Label(t("Mac'imi Kontrol Et", "Check My Mac"), systemImage: "checklist")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                // Özet
                HStack(spacing: 8) {
                    Image(systemName: healthSummaryLevel.verdictIcon)
                        .foregroundStyle(healthSummaryLevel.color)
                    Text(healthSummaryText)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(healthSummaryLevel.color)
                }
                .padding(.bottom, 2)

                VStack(spacing: 0) {
                    ForEach(Array(healthChecks.enumerated()), id: \.element.id) { index, check in
                        if index > 0 { Divider() }
                        healthRow(check)
                    }
                }
            }
        }
        .card()
    }

    private func healthRow(_ check: HealthCheck) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: check.scanning ? "hourglass" : check.level.verdictIcon)
                .foregroundStyle(check.scanning ? Color.secondary : check.level.color)
                .frame(width: 22)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(check.title).font(.callout.weight(.semibold))
                Text(check.message).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if check.tab != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { if let t = check.tab { go(t) } }
    }

    private func runHealthCheck() {
        healthCheckRun = true
        security.scan()                  // güvenlik (kalıcılık) taramasını tetikle
        systemInfo.loadBatteryHealth()   // pil sağlığını tazele
    }

    // MARK: - Bildirimler (aç/kapat)

    private var notificationCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.blue.opacity(0.15)))

            VStack(alignment: .leading, spacing: 2) {
                Text(t("Kritik durumda beni uyar", "Alert me when critical"))
                    .font(.callout.weight(.semibold))
                Text(notifications.authorizationDenied
                     ? t("Bildirim izni kapalı — Sistem Ayarları > Bildirimler'den MacMonitor'a izin ver.", "Notification permission is off — allow MacMonitor in System Settings > Notifications.")
                     : t("İşlemci, bellek, disk veya ısı bir süre kritik kalırsa (uygulama kapalıyken bile) bildirim gönderilir.", "If the processor, memory, disk or temperature stays critical for a while, you'll get a notification (even when the app is closed)."))
                    .font(.caption)
                    .foregroundStyle(notifications.authorizationDenied ? .orange : .secondary)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: $notifications.enabled)
                .labelsHidden()
        }
        .card()
    }

    // MARK: - Sekme geçişi

    private func go(_ tab: MainView.Tab) {
        selectedTabRaw = tab.rawValue
    }

    // MARK: - Seviye hesapları

    private var ramPercent: Double {
        let m = memoryMonitor.memory
        return m.total > 0 ? Double(m.used) / Double(m.total) * 100 : 0
    }

    private var diskPercent: Double { systemInfo.diskUsedPercent }

    private var maxTemp: Double? {
        fanMonitor.temperatures.map(\.celsius).max() ?? fanMonitor.cpuTemperature
    }

    private var cpuLevel: Level { .cpu(cpuMonitor.totalUsage) }
    private var ramLevel: Level { .memory(memoryMonitor.pressure) }
    private var diskLevel: Level { .disk(usedPercent: diskPercent) }

    /// Termal: ortak eşik mantığı (FanView ile aynı).
    private var tempLevel: Level {
        thermalLevel(maxTemp: maxTemp, thermalState: systemInfo.thermalState)
    }

    private var tempValue: String {
        if let t = maxTemp { return "\(Int(t.rounded()))°C" }
        return "—"
    }

    /// En kötü metrik genel sağlığı belirler.
    private var overall: Level {
        [cpuLevel, ramLevel, tempLevel, diskLevel].max() ?? .normal
    }

    // MARK: - Sağlık taraması hesapları

    private var batteryHealthLevel: Level { systemInfo.batteryHealth.level }

    private var batteryHealthMessage: String {
        let h = systemInfo.batteryHealth
        let facts = h.factsText.isEmpty ? "" : " (\(h.factsText))"
        switch h.level {
        case .normal:   return t("Pil sağlıklı\(facts).", "Battery is healthy\(facts).")
        case .warning:  return t("Pil yaşlanıyor\(facts). Şarj eskisinden çabuk biter.", "Battery is aging\(facts). It drains faster than it used to.")
        case .critical: return t("Pil ömrünü doldurmuş olabilir\(facts). Servis değişimi değerlendir.", "Battery may have reached the end of its life\(facts). Consider a service replacement.")
        }
    }

    private var healthChecks: [HealthCheck] {
        var checks: [HealthCheck] = []

        checks.append(HealthCheck(
            title: t("İşlemci yükü", "Processor load"), level: cpuLevel,
            message: cpuLevel == .normal
                ? t("Normal aralıkta (%\(Int(cpuMonitor.totalUsage.rounded()))).", "In the normal range (%\(Int(cpuMonitor.totalUsage.rounded()))).")
                : t("Şu an yüksek (%\(Int(cpuMonitor.totalUsage.rounded()))). Ağır uygulamaları azaltmayı düşün.", "Currently high (%\(Int(cpuMonitor.totalUsage.rounded()))). Consider reducing heavy apps."),
            tab: .cpu))

        checks.append(HealthCheck(
            title: t("Bellek", "Memory"), level: ramLevel,
            message: ramLevel == .normal ? t("Bellek rahat.", "Memory is relaxed.")
                : t("Bellek baskı altında. Gereksiz uygulamaları kapat.", "Memory is under pressure. Close unnecessary apps."),
            tab: .memory))

        checks.append(HealthCheck(
            title: t("Disk alanı", "Disk space"), level: diskLevel,
            message: diskLevel == .normal
                ? t("Yeterli boş alan var (%\(Int(diskPercent.rounded())) dolu).", "There is enough free space (%\(Int(diskPercent.rounded())) full).")
                : t("Disk %\(Int(diskPercent.rounded())) dolu. 'Yer Aç' ile temizleyebilirsin.", "Disk is %\(Int(diskPercent.rounded())) full. You can clean up with 'Free Up Space'."),
            tab: .system))

        checks.append(HealthCheck(
            title: t("Sıcaklık", "Temperature"), level: tempLevel,
            message: tempLevel == .normal ? t("Termal durum normal.", "Thermal status is normal.")
                : t("Sıcaklık yüksek. Havalandırmayı kontrol et, ağır işleri azalt.", "Temperature is high. Check ventilation and reduce heavy workloads."),
            tab: .fans))

        if systemInfo.batteryHealth.present {
            checks.append(HealthCheck(
                title: t("Pil sağlığı", "Battery health"), level: batteryHealthLevel,
                message: batteryHealthMessage, tab: .system))
        }

        let days = Int(ProcessInfo.processInfo.systemUptime / 86_400)
        let uptimeLevel: Level = days >= 7 ? .warning : .normal
        checks.append(HealthCheck(
            title: t("Açık kalma süresi", "Uptime"), level: uptimeLevel,
            message: uptimeLevel == .normal
                ? t("\(days) gündür açık — sorun yok.", "Up for \(days) days — no problem.")
                : t("\(days) gündür açık. Yeniden başlatmak takılmaları ve bellek birikimini temizler.", "Up for \(days) days. Restarting clears hangs and memory buildup."),
            tab: .memory))

        if security.isScanning {
            checks.append(HealthCheck(title: t("Güvenlik", "Security"), level: .normal,
                message: t("Açılışta çalışan öğeler taranıyor…", "Scanning login items…"), tab: .security, scanning: true))
        } else if security.scanDone {
            let n = security.flaggedCount
            checks.append(HealthCheck(title: t("Güvenlik", "Security"),
                level: n == 0 ? .normal : .warning,
                message: n == 0 ? t("Açılışta çalışan öğelerin hepsi imzalı.", "All login items are signed.")
                                : t("\(n) öğe gözden geçirilmeli (imzasız / tuhaf konum).", "\(n) item(s) should be reviewed (unsigned / unusual location)."),
                tab: .security))
        } else {
            checks.append(HealthCheck(title: t("Güvenlik", "Security"), level: .normal,
                message: t("Henüz taranmadı.", "Not scanned yet."), tab: .security))
        }

        return checks
    }

    private var healthSummaryLevel: Level {
        let levels = healthChecks.filter { !$0.scanning }.map(\.level)
        if levels.contains(.critical) { return .critical }
        if levels.contains(.warning) { return .warning }
        return .normal
    }

    private var healthSummaryText: String {
        if security.isScanning { return t("Kontrol ediliyor…", "Checking…") }
        let problems = healthChecks.filter { !$0.scanning && $0.level != .normal }.count
        return problems == 0 ? t("Mac'in iyi durumda — tüm kontroller geçti.", "Your Mac is in good shape — all checks passed.")
                             : t("\(problems) madde dikkat/öneri gerektiriyor.", "\(problems) item(s) need attention/advice.")
    }

    // MARK: - Dikkat maddeleri (öncelik sırasıyla)

    private var issues: [Issue] {
        var list: [Issue] = []

        // İşlemci
        if cpuLevel != .normal {
            if let p = processMonitor.processes.first, p.cpuUsage >= 30 {
                list.append(Issue(
                    id: "cpu", icon: "cpu", color: cpuLevel.color,
                    title: t("\(p.name) işlemciyi %\(Int(p.cpuUsage.rounded())) kullanıyor.", "\(p.name) is using %\(Int(p.cpuUsage.rounded())) of the processor."),
                    advice: t("Gerekmiyorsa bu uygulamayı kapatmak işlemciyi rahatlatır.", "If you don't need it, closing this app eases the processor.")))
            } else {
                list.append(Issue(
                    id: "cpu", icon: "cpu", color: cpuLevel.color,
                    title: t("İşlemci şu an yoğun (%\(Int(cpuMonitor.totalUsage.rounded()))).", "The processor is busy right now (%\(Int(cpuMonitor.totalUsage.rounded())))."),
                    advice: t("Ağır uygulamaları azaltınca yük düşer.", "Reducing heavy apps lowers the load.")))
            }
        }

        // Bellek
        if ramLevel != .normal {
            if let p = processMonitor.processes.max(by: { $0.memoryUsage < $1.memoryUsage }) {
                list.append(Issue(
                    id: "ram", icon: "memorychip", color: ramLevel.color,
                    title: t("Bellek baskı altında — en çok \(p.name) kullanıyor.", "Memory is under pressure — \(p.name) is using the most."),
                    advice: t("Gereksiz uygulamaları kapatın; gerekirse cihazı yeniden başlatın.", "Close unnecessary apps; restart the device if needed.")))
            } else {
                list.append(Issue(
                    id: "ram", icon: "memorychip", color: ramLevel.color,
                    title: t("Bellek dolmaya başladı.", "Memory is starting to fill up."),
                    advice: t("Gereksiz uygulamaları kapatmak yavaşlamayı önler.", "Closing unnecessary apps prevents slowdowns.")))
            }
        }

        // Sıcaklık
        if tempLevel != .normal {
            list.append(Issue(
                id: "temp", icon: "thermometer.high", color: tempLevel.color,
                title: maxTemp.map { t("Cihaz ısındı (\(Int($0.rounded()))°C).", "The device has heated up (\(Int($0.rounded()))°C).") } ?? t("Cihaz ısınıyor.", "The device is heating up."),
                advice: t("Ağır işleri azaltıp cihazın serinlemesini beklemek hızı geri getirir.", "Reducing heavy workloads and letting the device cool down restores speed.")))
        }

        // Disk
        if diskLevel != .normal {
            list.append(Issue(
                id: "disk", icon: "internaldrive", color: diskLevel.color,
                title: t("Disk doluyor (%\(Int(diskPercent.rounded()))).", "Disk is filling up (%\(Int(diskPercent.rounded())))."),
                advice: t("Yer açmak (gereksiz dosyaları silmek) sistemi hızlandırır.", "Freeing up space (deleting unnecessary files) speeds up the system.")))
        }

        // Düşük Güç Modu (bilgi amaçlı — yavaşlığın sebebi olabilir)
        if systemInfo.lowPowerMode {
            list.append(Issue(
                id: "lowpower", icon: "leaf.fill", color: .green,
                title: t("Düşük Güç Modu açık.", "Low Power Mode is on."),
                advice: t("Pili korumak için performans bilinçli olarak kısıtlı; kapatınca hızlanır.", "Performance is intentionally limited to save battery; turning it off speeds things up.")))
        }

        return list
    }
}

// MARK: - Durum seviyesi (ortak)

/// Sade durum yargısı: yeşil normal · turuncu yüksek · kırmızı kritik.
enum Level: Int, Comparable {
    case normal, warning, critical

    static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }

    var color: Color {
        switch self {
        case .normal:   return .green
        case .warning:  return .orange
        case .critical: return .red
        }
    }

    /// Metrik kartındaki tek kelimelik durum.
    var word: String {
        switch self {
        case .normal:   return t("Normal", "Normal")
        case .warning:  return t("Yüksek", "High")
        case .critical: return t("Kritik", "Critical")
        }
    }

    var verdictIcon: String {
        switch self {
        case .normal:   return "checkmark.seal.fill"
        case .warning:  return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    var headline: String {
        switch self {
        case .normal:   return t("Bilgisayarınız rahat çalışıyor", "Your computer is running smoothly")
        case .warning:  return t("Bilgisayarınız biraz yük altında", "Your computer is under some load")
        case .critical: return t("Bilgisayarınız zorlanıyor", "Your computer is struggling")
        }
    }

    var subtitle: String {
        switch self {
        case .normal:   return t("Her şey normal aralıkta.", "Everything is in the normal range.")
        case .warning:  return t("Bazı değerler yükseldi ama kritik değil — aşağıdaki nota bakın.", "Some values have risen but aren't critical — see the note below.")
        case .critical: return t("Bir veya daha fazla değer kritik seviyede — aşağıdaki öneriye bakın.", "One or more values are at a critical level — see the advice below.")
        }
    }
}

// MARK: - Dikkat maddesi

private struct Issue: Identifiable {
    let id: String          // kategori anahtarı (sabit) — her yeniden çizimde aynı kalsın
    let icon: String
    let color: Color
    let title: String
    let advice: String
}

// MARK: - Sağlık taraması maddesi

private struct HealthCheck: Identifiable {
    var id: String { title }   // başlık sabit (yüzde içermez) → kararlı kimlik
    let title: String
    let level: Level
    let message: String
    var tab: MainView.Tab? = nil
    var scanning: Bool = false
}

// MARK: - Metrik kartı

private struct MetricCard: View {
    @ObservedObject private var loc = Localizer.shared
    let icon: String
    let title: String
    let value: String
    let level: Level

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(level.color)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }

            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            HStack(spacing: 5) {
                Circle().fill(level.color).frame(width: 7, height: 7)
                Text(level.word)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(level.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .help(t("Detay için tıklayın", "Click for details"))
    }
}

#Preview {
    OverviewView()
        .environmentObject(CPUMonitor())
        .environmentObject(MemoryMonitor())
        .environmentObject(FanMonitor())
        .environmentObject(ProcessMonitor())
        .environmentObject(SystemInfoMonitor())
        .environmentObject(SecurityMonitor())
        .environmentObject(SystemMonitors.shared.notifications)
        .frame(width: 760, height: 760)
}
