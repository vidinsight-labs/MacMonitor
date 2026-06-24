import SwiftUI

/// Sistem sayfası — güç & termal (canlı) + disk + donanım bileşenleri (butonla).
struct SystemView: View {
    @ObservedObject private var loc = Localizer.shared
    @EnvironmentObject private var monitor: SystemInfoMonitor

    @State private var confirmEmptyTrash = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PageHeader(icon: "gauge.with.dots.needle.bottom.50percent",
                           gradient: [.gray, .blue],
                           title: t("Sistem", "System"),
                           subtitle: t("Güç, termal durum ve donanım", "Power, thermal state and hardware"))

                StatusBanner(level: sysLevel, title: sysStatus.title, message: sysStatus.message)

                powerThermalCard
                if monitor.batteryHealth.present {
                    batteryHealthCard
                }
                diskCard
                spaceCard
                hardwareCard
            }
            .padding(20)
            .centeredPageContent()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Güç & Termal

    private var powerThermalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(icon: "bolt.heart", title: t("Güç & Termal", "Power & Thermal"))

            // Termal (performans kısılması)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "thermometer.medium")
                    .foregroundStyle(thermal.color)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(t("Termal durum", "Thermal state"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(thermal.label)
                            .fontWeight(.semibold)
                            .foregroundStyle(thermal.color)
                    }
                    Text(thermal.advice)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout)

            Divider()

            statusRow(icon: "leaf", tint: monitor.lowPowerMode ? .green : .secondary,
                      title: t("Düşük Güç Modu", "Low Power Mode"),
                      value: monitor.lowPowerMode ? t("Açık (performans kısılı)", "On (performance limited)") : t("Kapalı", "Off"))

            Divider()

            statusRow(icon: batteryIcon, tint: batteryTint,
                      title: t("Güç kaynağı", "Power source"), value: batteryText)
        }
        .card()
    }

    private func statusRow(icon: String, tint: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 22)
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }

    // MARK: - Disk

    private var diskCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "internaldrive", title: t("Disk", "Disk"))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(diskColor)
                        .frame(width: geo.size.width * diskUsedFraction)
                }
            }
            .frame(height: 10)

            HStack {
                Text(t("Boş: \(gb(monitor.diskFree))", "Free: \(gb(monitor.diskFree))"))
                Spacer()
                Text(t("Toplam: \(gb(monitor.diskTotal))", "Total: \(gb(monitor.diskTotal))"))
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .monospacedDigit()

            if diskUsedFraction > 0.9 {
                Label(t("Boş alan azaldı — bu performansı düşürebilir.", "Free space is low — this may reduce performance."),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .card()
    }

    // MARK: - Pil Sağlığı

    private var batteryHealthCard: some View {
        let h = monitor.batteryHealth
        return VStack(alignment: .leading, spacing: 14) {
            sectionTitle(icon: "battery.100.bolt", title: t("Pil Sağlığı", "Battery Health"))

            // Maksimum kapasite (Apple'ın Ayarlar'da gösterdiğiyle aynı)
            if let cap = h.maxCapacityPercent {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(t("Maksimum kapasite", "Maximum capacity")).foregroundStyle(.secondary)
                        Spacer()
                        Text("%\(cap)")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(batteryLevel.color)
                    }
                    .font(.callout)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.15))
                            Capsule().fill(batteryLevel.color)
                                .frame(width: geo.size.width * CGFloat(min(max(cap, 0), 100)) / 100)
                        }
                    }
                    .frame(height: 8)
                    Text(t("Yeni bir pilin %100'üne göre, pilinin şu an tutabildiği en yüksek şarj.", "The maximum charge your battery can currently hold, relative to 100% of a new battery."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            statusRow(icon: "arrow.triangle.2.circlepath", tint: .secondary,
                      title: t("Şarj döngüsü", "Charge cycles"),
                      value: h.cycleCount.map { "\($0)" } ?? "—")

            if h.cycleCount != nil {
                Text(t("Her tam şarj-deşarj bir döngüdür. Modern Mac dizüstülerinde pil tipik olarak ~1000 döngü için tasarlanır.", "Each full charge-discharge counts as one cycle. On modern Mac laptops the battery is typically designed for ~1000 cycles."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            statusRow(icon: batteryLevel == .normal ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                      tint: batteryLevel.color,
                      title: t("Durum", "Condition"), value: conditionText)

            Text(batteryAdvice)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    // Pil sağlığı seviyesi / metni → ortak BatteryHealth uzantısı (Genel Bakış ile aynı kaynak).
    private var batteryLevel: Level { monitor.batteryHealth.level }
    private var conditionText: String { monitor.batteryHealth.conditionText }
    private var batteryAdvice: String { monitor.batteryHealth.advice }

    // MARK: - Yer Aç (disk kullanımı + güvenli temizlik)

    private var spaceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle(icon: "sparkles", title: t("Yer Aç", "Free Up Space"))
                if monitor.diskScanDone && !monitor.isScanningDisk {
                    Button(t("Yenile", "Refresh")) { monitor.scanDiskUsage() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }

            Text(t("Diskte en çok yer kaplayan ve güvenle boşaltabileceğin yerler. Kişisel dosyaların **asla otomatik silinmez** — yalnızca gösterilir ve Finder'da açılır.", "The places taking up the most disk space that you can safely clear. Your personal files are **never deleted automatically** — they are only shown and opened in Finder."))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let msg = monitor.spaceMessage {
                Label(msg, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            if monitor.isScanningDisk {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(t("Disk taranıyor… (büyük klasörler birkaç saniye sürebilir)", "Scanning disk… (large folders may take a few seconds)"))
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.vertical, 6)
            } else if monitor.diskItems.isEmpty {
                Button {
                    monitor.scanDiskUsage()
                } label: {
                    Label(t("Diski Tara", "Scan Disk"), systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                VStack(spacing: 12) {
                    ForEach(monitor.diskItems) { item in
                        spaceRow(item)
                    }
                }
            }
        }
        .card()
        .alert(t("Çöp kutusu boşaltılsın mı?", "Empty the Trash?"), isPresented: $confirmEmptyTrash) {
            Button(t("Vazgeç", "Cancel"), role: .cancel) {}
            Button(t("Boşalt", "Empty"), role: .destructive) { monitor.emptyTrash() }
        } message: {
            Text(t("Çöp kutusundaki tüm öğeler kalıcı olarak silinecek.", "All items in the Trash will be permanently deleted."))
        }
    }

    private func spaceRow(_ item: DiskItem) -> some View {
        let maxBytes = monitor.diskItems.map(\.bytes).max() ?? 1
        let fraction = maxBytes > 0 ? CGFloat(Double(item.bytes) / Double(maxBytes)) : 0
        return HStack(spacing: 12) {
            Image(systemName: item.icon)
                .foregroundStyle(.blue)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title).font(.callout.weight(.medium))
                    Spacer()
                    Text(gb(item.bytes))
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.15))
                        Capsule().fill(.blue).frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 6)
            }
            spaceAction(item)
        }
    }

    @ViewBuilder
    private func spaceAction(_ item: DiskItem) -> some View {
        switch item.action {
        case .emptyTrash:
            Button(t("Boşalt", "Empty")) { confirmEmptyTrash = true }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
        case .reveal:
            Button(t("Aç", "Open")) { monitor.reveal(item.path) }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    // MARK: - Donanım bileşenleri (butonla)

    private var hardwareCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle(icon: "cpu.fill", title: t("Donanım Bileşenleri", "Hardware Components"))
                if monitor.hardwareLoaded && !monitor.isLoadingHardware {
                    Button(t("Yenile", "Refresh")) { monitor.loadHardware() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }

            Text(t("Model, seri no, çip, Wi-Fi/Bluetooth ve depolama modülü bilgileri. Sistemden alındığı için birkaç saniye sürebilir.", "Model, serial number, chip, Wi-Fi/Bluetooth and storage module information. Since it is read from the system, it may take a few seconds."))
                .font(.caption)
                .foregroundStyle(.secondary)

            if monitor.isLoadingHardware {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(t("Bilgiler alınıyor…", "Loading information…")).foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.vertical, 6)
            } else if monitor.components.isEmpty {
                Button {
                    monitor.loadHardware()
                } label: {
                    Label(t("Bilgileri Getir", "Fetch Information"), systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(monitor.components.enumerated()), id: \.element.id) { index, comp in
                        if index > 0 { Divider() }
                        componentRow(comp)
                    }
                }
            }
        }
        .card()
    }

    private func componentRow(_ comp: HardwareComponent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: comp.icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(comp.title).font(.callout.weight(.semibold))
                Text(comp.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Hesaplanan değerler

    /// Sayfa üstü durum: termal + disk + düşük güç modunun en kötüsü.
    private var sysLevel: Level {
        var lvl: Level = .normal
        switch monitor.thermalState {
        case .nominal:            break
        case .fair:               lvl = .warning
        case .serious, .critical: lvl = .critical
        @unknown default:         break
        }
        lvl = max(lvl, .disk(usedPercent: monitor.diskUsedPercent))   // ortak disk eşiği
        return lvl
    }

    /// Baskın sorunu öne çıkaran mesaj (önce ısı, sonra disk, sonra güç modu).
    private var sysStatus: (title: String, message: String) {
        if monitor.thermalState == .serious || monitor.thermalState == .critical {
            return (t("Cihaz ısındı", "Device is hot"), t("Performans ısı nedeniyle kısılıyor. Ağır işleri azaltıp serinlemesini beklemek hızı geri getirir.", "Performance is being throttled due to heat. Reducing heavy tasks and letting it cool down restores speed."))
        }
        if diskUsedFraction > 0.9 {
            return (t("Disk neredeyse dolu", "Disk is almost full"), t("Boş alan azaldığında sistem yavaşlar. Gereksiz dosyaları silerek yer aç.", "The system slows down when free space runs low. Free up space by deleting unnecessary files."))
        }
        if monitor.thermalState == .fair {
            return (t("Hafif ısınma", "Mild warming"), t("Performans büyük ölçüde korunuyor; endişelenmene gerek yok.", "Performance is largely maintained; there is no need to worry."))
        }
        if diskUsedFraction > 0.75 {
            return (t("Disk dolmaya başladı", "Disk is starting to fill up"), t("Henüz sorun değil ama yer açmak ileride yavaşlamayı önler.", "Not a problem yet, but freeing up space prevents future slowdowns."))
        }
        if monitor.lowPowerMode {
            return (t("Düşük Güç Modu açık", "Low Power Mode is on"), t("Pili korumak için performans bilinçli olarak kısıtlı; kapatınca hızlanır.", "Performance is intentionally limited to preserve battery; turning it off speeds things up."))
        }
        return (t("Sistem normal", "System is normal"), t("Güç ve termal durum iyi, disk alanı yeterli.", "Power and thermal state are good, disk space is sufficient."))
    }

    private var thermal: (color: Color, label: String, advice: String) {
        switch monitor.thermalState {
        case .nominal:
            return (.green, t("Normal", "Normal"), t("Performans tam; ısı kaynaklı kısıtlama yok.", "Full performance; no heat-related throttling."))
        case .fair:
            return (.yellow, t("Hafif", "Mild"), t("Hafif ısınma; performans büyük ölçüde korunuyor.", "Mild warming; performance is largely maintained."))
        case .serious:
            return (.orange, t("Yüksek", "High"), t("Sistem ısı nedeniyle performansı düşürmeye başladı.", "The system has started reducing performance due to heat."))
        case .critical:
            return (.red, t("Kritik", "Critical"), t("Performans ısı nedeniyle ciddi şekilde kısıldı. Ağır işleri azalt.", "Performance is severely throttled due to heat. Reduce heavy tasks."))
        @unknown default:
            return (.secondary, t("Bilinmiyor", "Unknown"), "")
        }
    }

    private var batteryText: String {
        if let level = monitor.batteryLevel {
            let charge = monitor.batteryCharging ? t(" · şarj oluyor", " · charging") : ""
            return "\(monitor.powerSource) · %\(level)\(charge)"
        }
        return monitor.powerSource
    }

    private var batteryIcon: String {
        guard let level = monitor.batteryLevel else { return "powerplug" }
        if monitor.batteryCharging { return "battery.100.bolt" }
        switch level {
        case ..<20: return "battery.25"
        case ..<60: return "battery.50"
        default:    return "battery.100"
        }
    }

    private var batteryTint: Color {
        guard let level = monitor.batteryLevel, !monitor.batteryCharging else { return .green }
        return level < 20 ? .red : .secondary
    }

    private var diskUsedFraction: CGFloat {
        CGFloat(monitor.diskUsedPercent / 100)   // tek kaynak: SystemInfoMonitor
    }

    private var diskColor: Color {
        diskUsedFraction > 0.9 ? .red : (diskUsedFraction > 0.75 ? .orange : .blue)
    }

    private func gb(_ bytes: Int64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_000_000_000)
    }
}

#Preview {
    SystemView()
        .environmentObject(SystemInfoMonitor())
        .frame(width: 640, height: 820)
}
