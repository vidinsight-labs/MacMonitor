import SwiftUI

/// Bellek sayfası — İşlemci sayfasıyla aynı tasarım dili (kart tabanlı).
struct MemoryView: View {
    @ObservedObject private var loc = Localizer.shared
    @EnvironmentObject private var monitor: MemoryMonitor

    private var data: MemoryData { monitor.memory }

    /// Yığılmış çubuk ve açıklama için segmentler.
    private var segments: [MemorySegment] {
        [
            MemorySegment(label: t("Aktif", "Active"), color: .blue, bytes: data.active,
                          description: t("Uygulamaların şu an etkin kullandığı bellek.", "Memory actively used by apps right now.")),
            MemorySegment(label: t("Sabitlenmiş", "Wired"), color: .orange, bytes: data.wired,
                          description: t("RAM'de kalması zorunlu sistem/çekirdek belleği; diske atılamaz.", "System/kernel memory that must stay in RAM; cannot be paged out.")),
            MemorySegment(label: t("Sıkıştırılmış", "Compressed"), color: .purple, bytes: data.compressed,
                          description: t("Az kullanılan verinin yer açmak için sıkıştırılmış hali.", "Rarely used data compressed to free up space.")),
            MemorySegment(label: t("Boş", "Free"), color: .gray, bytes: data.available,
                          description: t("Hemen kullanılabilir + önbellek (geri kazanılabilir) bellek.", "Immediately usable + cached (reclaimable) memory."))
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                StatusBanner(level: memLevel, title: memStatus.title, message: memStatus.message)
                heroCard
                breakdownCard
                swapCard
                uptimeCard
                manageCard
            }
            .padding(20)
            .centeredPageContent()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Başlık kartı

    private var headerCard: some View {
        PageHeader(
            icon: "memorychip",
            gradient: [.purple, .indigo],
            title: t("Bellek", "Memory"),
            subtitle: t("\(gb(data.total)) toplam RAM", "\(gb(data.total)) total RAM")
        )
    }

    // MARK: - Ana kart (gösterge + özet)

    private var heroCard: some View {
        HStack(spacing: 28) {
            UsageGauge(value: usedPercent, color: pressureColor, caption: t("Kullanılan", "Used"))
                .frame(width: 168, height: 168)

            VStack(alignment: .leading, spacing: 14) {
                summaryRow(icon: "memorychip.fill", tint: .blue,
                           title: t("Kullanılan", "Used"), valueText: gb(data.used))
                Divider()
                summaryRow(icon: "checkmark.circle.fill", tint: .green,
                           title: t("Kullanılabilir", "Available"), valueText: gb(data.available))
                Divider()
                HStack(spacing: 12) {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(pressureColor)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(pressureColor.opacity(0.15)))
                    Text(t("Bellek basıncı", "Memory pressure"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(monitor.pressure.label)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(pressureColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(pressureColor.opacity(0.15)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card()
    }

    private func summaryRow(icon: String, tint: Color, title: String, valueText: String) -> some View {
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

            Text(valueText)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
    }

    // MARK: - Dağılım kartı (yığılmış çubuk + açıklama)

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(icon: "chart.bar.fill", title: t("Dağılım", "Breakdown"))

            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(segments) { seg in
                        Rectangle()
                            .fill(seg.color)
                            .frame(width: width(for: seg.bytes, in: geo.size.width))
                    }
                }
            }
            .frame(height: 26)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )

            VStack(spacing: 10) {
                ForEach(segments) { seg in
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(seg.color)
                            .frame(width: 12, height: 12)
                            .padding(.top, 3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(seg.label)
                                .font(.callout.weight(.medium))
                            Text(seg.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(gb(seg.bytes))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .padding(.top, 1)
                    }
                }
            }
        }
        .card()
    }

    private func width(for bytes: UInt64, in totalWidth: CGFloat) -> CGFloat {
        guard data.total > 0 else { return 0 }
        return totalWidth * CGFloat(Double(bytes) / Double(data.total))
    }

    // MARK: - Takas kartı

    private var swapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "internaldrive.fill", title: t("Takas (Swap)", "Swap"))

            if data.swapTotal == 0 {
                Text(t("Takas kullanılmıyor.", "Swap is not in use."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.15))
                        Capsule()
                            .fill(.teal)
                            .frame(width: geo.size.width * swapFraction)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text(t("Kullanılan: \(gb(data.swapUsed))", "Used: \(gb(data.swapUsed))"))
                    Spacer()
                    Text(t("Toplam: \(gb(data.swapTotal))", "Total: \(gb(data.swapTotal))"))
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
        .card()
    }

    private var swapFraction: CGFloat {
        guard data.swapTotal > 0 else { return 0 }
        return CGFloat(Double(data.swapUsed) / Double(data.swapTotal))
    }

    // MARK: - Çalışma süresi + yeniden başlatma önerisi

    private var uptimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "clock.arrow.circlepath", title: t("Çalışma Süresi", "Uptime"))

            HStack {
                Text(t("Cihazın açık kalma süresi", "Time the device has been powered on"))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(uptimeString)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .font(.callout)

            Divider()

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: restart.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(restart.color)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(restart.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(restart.color)
                    Text(restart.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .card()
    }

    /// Açık kalma süresi + basınç + takas'a göre yeniden başlatma önerisi.
    private var restart: (icon: String, color: Color, title: String, detail: String) {
        let days = ProcessInfo.processInfo.systemUptime / 86_400
        let swapHeavy = data.swapUsed > 3 * 1_073_741_824   // > 3 GB

        if monitor.pressure == .critical || (swapHeavy && days >= 2) {
            return ("exclamationmark.arrow.circlepath", .red,
                    t("Yeniden başlatman önerilir", "Restart recommended"),
                    t("Bellek baskı altında ve/veya takas yoğun kullanılıyor. Yeniden başlatmak belleği tamamen temizler.", "Memory is under pressure and/or swap is heavily used. Restarting fully clears memory."))
        }
        if days >= 7 && (monitor.pressure == .warning || swapHeavy) {
            return ("arrow.clockwise.circle", .orange,
                    t("Yeniden başlatmayı düşünebilirsin", "You might consider restarting"),
                    t("Cihaz uzun süredir açık ve bellek biraz baskı altında. Yeniden başlatmak rahatlatabilir.", "The device has been on for a long time and memory is slightly under pressure. Restarting can help."))
        }
        return ("checkmark.circle.fill", .green,
                t("Yeniden başlatmaya gerek yok", "No need to restart"),
                t("Bellek rahat. Gerekirse aşağıdan 'Belleği Temizle' ile inaktif belleği boşaltabilirsin.", "Memory is comfortable. If needed, you can free inactive memory below with 'Free Memory'."))
    }

    private var uptimeString: String {
        let total = Int(ProcessInfo.processInfo.systemUptime)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let mins = (total % 3_600) / 60
        if days > 0  { return t("\(days) gün \(hours) saat", "\(days) d \(hours) h") }
        if hours > 0 { return t("\(hours) saat \(mins) dk", "\(hours) h \(mins) min") }
        return t("\(mins) dk", "\(mins) min")
    }

    // MARK: - Yönetim kartı (temizle)

    private var manageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "wand.and.stars", title: t("Bellek Yönetimi", "Memory Management"))

            Text(t("İnaktif (geri kazanılabilir) belleği boşaltır — `purge`. Yönetici parolası istenir.", "Frees inactive (reclaimable) memory — `purge`. Administrator password is required."))
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                monitor.purgeMemory()
            } label: {
                HStack {
                    if monitor.isPurging {
                        ProgressView().controlSize(.small)
                        Text(t("Temizleniyor…", "Cleaning…"))
                    } else {
                        Label(t("Belleği Temizle", "Free Memory"), systemImage: "trash")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(monitor.isPurging)

            if let message = monitor.purgeMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .card()
    }

    // MARK: - Hesaplanan değerler / biçimlendirme

    /// Sayfa üstü durum yargısı — bellek basıncına göre (ortak kaynak).
    private var memLevel: Level { .memory(monitor.pressure) }

    private var memStatus: (title: String, message: String) {
        switch memLevel {
        case .normal:
            return (t("Bellek rahat", "Memory is comfortable"), t("Yeterli boş bellek var; uygulamalar akıcı çalışır.", "There is enough free memory; apps run smoothly."))
        case .warning:
            return (t("Bellek baskı altında", "Memory under pressure"), t("Hafif yavaşlama olabilir. Gereksiz uygulama ve sekmeleri kapatmak rahatlatır.", "Slight slowdown is possible. Closing unneeded apps and tabs helps."))
        case .critical:
            return (t("Bellek kritik", "Memory critical"), t("Sistem yavaşlayabilir. Uygulama kapatmak veya cihazı yeniden başlatmak belleği boşaltır.", "The system may slow down. Closing apps or restarting the device frees memory."))
        }
    }

    private var usedPercent: Double {
        data.total > 0 ? Double(data.used) / Double(data.total) * 100 : 0
    }

    private var pressureColor: Color {
        switch monitor.pressure {
        case .normal:   return .green
        case .warning:  return .yellow
        case .critical: return .red
        }
    }

    private func gb(_ bytes: UInt64) -> String {
        String(format: "%.2f GB", Double(bytes) / 1_073_741_824)
    }
}

/// Yığılmış çubuk / açıklama segmenti.
private struct MemorySegment: Identifiable {
    let label: String
    let color: Color
    let bytes: UInt64
    let description: String
    var id: String { label }
}

#Preview {
    MemoryView()
        .environmentObject(MemoryMonitor())
        .frame(width: 640, height: 820)
}
