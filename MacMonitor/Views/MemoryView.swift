import SwiftUI

/// Bellek sayfası — İşlemci sayfasıyla aynı tasarım dili (kart tabanlı).
struct MemoryView: View {
    @EnvironmentObject private var monitor: MemoryMonitor

    private var data: MemoryData { monitor.memory }

    /// Yığılmış çubuk ve açıklama için segmentler.
    private var segments: [MemorySegment] {
        [
            MemorySegment(label: "Aktif", color: .blue, bytes: data.active,
                          description: "Uygulamaların şu an etkin kullandığı bellek."),
            MemorySegment(label: "Sabitlenmiş", color: .orange, bytes: data.wired,
                          description: "RAM'de kalması zorunlu sistem/çekirdek belleği; diske atılamaz."),
            MemorySegment(label: "Sıkıştırılmış", color: .purple, bytes: data.compressed,
                          description: "Az kullanılan verinin yer açmak için sıkıştırılmış hali."),
            MemorySegment(label: "Boş", color: .gray, bytes: data.available,
                          description: "Hemen kullanılabilir + önbellek (geri kazanılabilir) bellek.")
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                heroCard
                breakdownCard
                swapCard
                uptimeCard
                manageCard
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Başlık kartı

    private var headerCard: some View {
        PageHeader(
            icon: "memorychip",
            gradient: [.purple, .indigo],
            title: "Bellek",
            subtitle: "\(gb(data.total)) toplam RAM"
        )
    }

    // MARK: - Ana kart (gösterge + özet)

    private var heroCard: some View {
        HStack(spacing: 28) {
            UsageGauge(value: usedPercent, color: pressureColor, caption: "Kullanılan")
                .frame(width: 168, height: 168)

            VStack(alignment: .leading, spacing: 14) {
                summaryRow(icon: "memorychip.fill", tint: .blue,
                           title: "Kullanılan", valueText: gb(data.used))
                Divider()
                summaryRow(icon: "checkmark.circle.fill", tint: .green,
                           title: "Kullanılabilir", valueText: gb(data.available))
                Divider()
                HStack(spacing: 12) {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(pressureColor)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(pressureColor.opacity(0.15)))
                    Text("Bellek basıncı")
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
            sectionTitle(icon: "chart.bar.fill", title: "Dağılım")

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
            sectionTitle(icon: "internaldrive.fill", title: "Takas (Swap)")

            if data.swapTotal == 0 {
                Text("Takas kullanılmıyor.")
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
                    Text("Kullanılan: \(gb(data.swapUsed))")
                    Spacer()
                    Text("Toplam: \(gb(data.swapTotal))")
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
            sectionTitle(icon: "clock.arrow.circlepath", title: "Çalışma Süresi")

            HStack {
                Text("Cihazın açık kalma süresi")
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
                    "Yeniden başlatman önerilir",
                    "Bellek baskı altında ve/veya takas yoğun kullanılıyor. Yeniden başlatmak belleği tamamen temizler.")
        }
        if days >= 7 && (monitor.pressure == .warning || swapHeavy) {
            return ("arrow.clockwise.circle", .orange,
                    "Yeniden başlatmayı düşünebilirsin",
                    "Cihaz uzun süredir açık ve bellek biraz baskı altında. Yeniden başlatmak rahatlatabilir.")
        }
        return ("checkmark.circle.fill", .green,
                "Yeniden başlatmaya gerek yok",
                "Bellek rahat. Gerekirse aşağıdan 'Belleği Temizle' ile inaktif belleği boşaltabilirsin.")
    }

    private var uptimeString: String {
        let total = Int(ProcessInfo.processInfo.systemUptime)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let mins = (total % 3_600) / 60
        if days > 0  { return "\(days) gün \(hours) saat" }
        if hours > 0 { return "\(hours) saat \(mins) dk" }
        return "\(mins) dk"
    }

    // MARK: - Yönetim kartı (temizle)

    private var manageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "wand.and.stars", title: "Bellek Yönetimi")

            Text("İnaktif (geri kazanılabilir) belleği boşaltır — `purge`. Yönetici parolası istenir.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                monitor.purgeMemory()
            } label: {
                HStack {
                    if monitor.isPurging {
                        ProgressView().controlSize(.small)
                        Text("Temizleniyor…")
                    } else {
                        Label("Belleği Temizle", systemImage: "trash")
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
