import SwiftUI

// Tüm sayfaların paylaştığı ortak tasarım dili (kart, bölüm başlığı, dairesel gösterge).

extension View {
    /// Ortak kart kabı — yuvarlak köşe + ince çerçeve, dark mode uyumlu.
    func card() -> some View {
        self
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
            )
    }
}

extension View {
    /// Geniş pencerede içerik genişliğini sınırlar ve ortalar (okunabilirlik).
    func centeredPageContent(maxWidth: CGFloat = 1100) -> some View {
        self
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

/// Sayfa başındaki sade durum yargısı — renkli, tek bakışta "iyi mi?" sorusunu yanıtlar.
/// Genel Bakış'taki kart diliyle tutarlı; her detay sayfasının üstünde kullanılır.
struct StatusBanner: View {
    let level: Level
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: level.verdictIcon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(level.color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(level.color)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(level.color.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(level.color.opacity(0.25), lineWidth: 1)
        )
    }
}

/// Sıcaklık → durum seviyesi. Tüm sayfalarda **tek** eşik takımı kullanılsın diye ortak:
/// 70–89 °C uyarı, ≥90 °C kritik; OS termal durumu da hesaba katılır.
func thermalLevel(maxTemp: Double?, thermalState: ProcessInfo.ThermalState? = nil) -> Level {
    var lvl: Level = .normal
    if let state = thermalState {
        switch state {
        case .fair:               lvl = .warning
        case .serious, .critical: lvl = .critical
        default:                  break
        }
    }
    if let t = maxTemp {
        if t >= 90 { lvl = .critical }
        else if t >= 70, lvl == .normal { lvl = .warning }
    }
    return lvl
}

// Metrik → durum seviyesi eşikleri. **Tek** kaynak: hem Genel Bakış hem detay sayfaları kullanır
// (eskiden her sayfada ayrı yazılıydı; tek taraflı değişiklik sayfa-arası çelişki üretebiliyordu).
extension Level {
    /// İşlemci yükü: <70 normal, <90 yüksek, ≥90 kritik.
    static func cpu(_ usage: Double) -> Level {
        usage < 70 ? .normal : (usage < 90 ? .warning : .critical)
    }
    /// Bellek basıncı eşlemesi.
    static func memory(_ pressure: MemoryPressure) -> Level {
        switch pressure {
        case .normal:   return .normal
        case .warning:  return .warning
        case .critical: return .critical
        }
    }
    /// Disk doluluk: <75 normal, <90 yüksek, ≥90 kritik.
    static func disk(usedPercent: Double) -> Level {
        usedPercent < 75 ? .normal : (usedPercent < 90 ? .warning : .critical)
    }
}

// Pil sağlığı → seviye / metin. Genel Bakış ve Sistem sayfası aynı mantığı paylaşsın diye burada.
extension BatteryHealth {
    var level: Level {
        if let c = condition?.lowercased() {
            if c.contains("service") || c.contains("replace") || c.contains("poor") { return .critical }
            if c.contains("fair") { return .warning }
        }
        if let p = maxCapacityPercent {
            if p < 60 { return .critical }
            if p < 80 { return .warning }
        }
        return .normal
    }

    /// Apple'ın durum dizgisini sade Türkçeye çevirir.
    var conditionText: String {
        guard let c = condition?.lowercased() else { return t("Bilinmiyor", "Unknown") }
        if c.contains("service") || c.contains("replace") { return t("Servis önerilir", "Service recommended") }
        if c.contains("poor") { return t("Zayıf", "Poor") }
        if c.contains("fair") { return t("Orta", "Fair") }
        if c.contains("good") || c.contains("normal") { return t("İyi", "Good") }
        return condition ?? t("Bilinmiyor", "Unknown")
    }

    /// "%92 kapasite · 276 döngü"
    var factsText: String {
        [maxCapacityPercent.map { "%\($0) " + t("kapasite", "capacity") }, cycleCount.map { "\($0) " + t("döngü", "cycles") }]
            .compactMap { $0 }.joined(separator: " · ")
    }

    var advice: String {
        switch level {
        case .normal:   return t("Pilin sağlıklı; kapasite ve döngü sayısı normal aralıkta.", "Your battery is healthy; capacity and cycle count are within the normal range.")
        case .warning:  return t("Pil yaşlanıyor — kapasite düşmüş. Şarj eskisinden daha çabuk biter; henüz değişim şart değil.", "The battery is aging — capacity has dropped. It runs out faster than before, but replacement isn't required yet.")
        case .critical: return t("Pil ömrünü büyük ölçüde doldurmuş olabilir. Bir Apple yetkili servisinde değişim değerlendirmen önerilir.", "The battery may be largely worn out. Consider evaluating a replacement at an Apple authorized service provider.")
        }
    }
}

/// Kart içi bölüm başlığı (ikon + metin).
func sectionTitle(icon: String, title: String) -> some View {
    Label(title, systemImage: icon)
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)
}

/// Sayfa hero başlığı — gradyanlı ikon + başlık + alt başlık.
/// Sabit yükseklik → tüm sayfalarda aynı boyda görünür.
struct PageHeader: View {
    let icon: String
    let gradient: [Color]
    let title: String
    var subtitle: String = ""

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: gradient,
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 54, height: 54)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(height: 54)   // sabit içerik yüksekliği → sayfalar arası tutarlı
        .card()
    }
}

/// Bilgi kartı içindeki tek bir açıklama maddesi.
struct InfoPoint: Identifiable {
    let id = UUID()
    let heading: String
    let body: String
}

/// Dairesel yüzde göstergesi (renk ve alt yazı çağıran tarafından verilir).
struct UsageGauge: View {
    @ObservedObject private var loc = Localizer.shared
    let value: Double          // 0 - 100
    var color: Color
    var caption: String

    private var fraction: Double { min(max(value, 0), 100) / 100 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.15), lineWidth: 16)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color.opacity(0.7), color]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * fraction)
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(Int(value.rounded()))")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("%")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .opacity(0.7)
                }
                .foregroundStyle(color)

                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .help("\(caption): %\(Int(value.rounded()))")                 // fareyle üzerine gelince ipucu
        .accessibilityElement(children: .ignore)                       // VoiceOver
        .accessibilityLabel(caption)
        .accessibilityValue(t("yüzde", "percent") + " \(Int(value.rounded()))")
    }
}
