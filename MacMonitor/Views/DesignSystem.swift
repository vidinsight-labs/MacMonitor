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
    }
}
