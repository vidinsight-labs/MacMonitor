import SwiftUI

/// Fan ve sıcaklık sayfası — İşlemci/Bellek ile aynı tasarım dili.
struct FanView: View {
    @EnvironmentObject private var monitor: FanMonitor

    @State private var mode: FanMode = .system
    @State private var masterRPM: Double = 2000
    @State private var perFan = false

    private enum FanMode: Hashable { case system, manual }

    private let fanColumns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PageHeader(
                    icon: "fanblades",
                    gradient: [.teal, .cyan],
                    title: "Fanlar ve Sıcaklık",
                    subtitle: headerSubtitle
                )

                if !monitor.smcAvailable {
                    unavailableCard
                }

                thermalCard
                temperaturesCard
                fansCard
                controlCard
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerSubtitle: String {
        if monitor.fans.isEmpty {
            return "Pasif soğutma / sıcaklık"
        }
        return "\(monitor.fans.count) fan"
    }

    // MARK: - SMC yok uyarısı

    private var unavailableCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("SMC sensörlerine erişilemedi.")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .card()
    }

    // MARK: - Termal durum (cihazı bekletmeli mi)

    private var thermalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "thermometer.medium", title: "Termal Durum")

            HStack(spacing: 10) {
                Circle()
                    .fill(thermal.color)
                    .frame(width: 12, height: 12)
                Text(thermal.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(thermal.color)
                Spacer()
                if let t = maxTemp {
                    Text("\(Int(t.rounded()))°C")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(thermal.color)
                }
            }

            Text(thermal.advice)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .card()
    }

    // MARK: - Tüm sıcaklıklar

    private var temperaturesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(icon: "thermometer.sun", title: "Sıcaklıklar")

            if monitor.temperatures.isEmpty {
                Text("Bu modelde sıcaklık sensörleri okunamıyor. (Apple Silicon, SMC'nin Intel sıcaklık anahtarlarını sağlamaz.)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(monitor.temperatures) { temp in
                        tempRow(temp)
                    }
                }
                tempLegend
            }
        }
        .card()
    }

    private func tempRow(_ temp: TempReading) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(temp.label)
                    .font(.callout.weight(.medium))
                Spacer()
                Text("\(Int(temp.celsius.rounded()))°C")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(tempColor(temp.celsius))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule()
                        .fill(tempColor(temp.celsius))
                        .frame(width: geo.size.width * tempFraction(temp.celsius))
                }
            }
            .frame(height: 6)
        }
    }

    /// 20–110 °C aralığına göre doluluk.
    private func tempFraction(_ c: Double) -> CGFloat {
        CGFloat(min(max((c - 20) / (110 - 20), 0), 1))
    }

    private var tempLegend: some View {
        HStack(spacing: 16) {
            legendDot(.blue, "Serin")
            legendDot(.green, "Normal")
            legendDot(.orange, "Ilık")
            legendDot(.red, "Sıcak")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
        }
    }

    // MARK: - Fanlar (yerleşim / sayı)

    private var fansCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(icon: "fanblades.fill", title: "Fanlar")

            if monitor.fans.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "wind")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Fan bulunamadı — bu model pasif soğutma (fansız) kullanıyor.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else {
                LazyVGrid(columns: fanColumns, spacing: 16) {
                    ForEach(monitor.fans) { fan in
                        FanGauge(fan: fan)
                    }
                }
            }
        }
        .card()
    }

    // MARK: - Fan yönetimi (kontrol)

    private var controlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "slider.horizontal.3", title: "Fan Yönetimi")

            Picker("Mod", selection: $mode) {
                Text("Sistem (Otomatik)").tag(FanMode.system)
                Text("Manuel (Sabit Devir)").tag(FanMode.manual)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Hedef devir (master)")
                    Spacer()
                    Text("\(Int(masterRPM)) RPM").monospacedDigit().foregroundStyle(.secondary)
                }
                .font(.callout)
                Slider(value: $masterRPM, in: 1000...6000, step: 100)
                    .disabled(true)
            }

            Toggle("Fan bazlı ayar (her fan ayrı)", isOn: $perFan)
                .disabled(true)
                .font(.callout)

            Divider()

            Label {
                Text("Fan kontrolü **yönetici izni** gerektirir ve yanlış ayar **aşırı ısınmaya** yol açabilir. Ayrıca bu Mac fansız olduğundan kontrol kullanılamıyor. Fanlı bir Intel Mac'te: **Sistem** modunda hızı macOS yönetir; **Manuel** modda master devir veya fan bazlı sabit devir ayarlanabilir.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "lock.fill").foregroundStyle(.secondary)
            }
        }
        .card()
    }

    // MARK: - Termal değerlendirme

    private var maxTemp: Double? {
        monitor.temperatures.map(\.celsius).max() ?? monitor.cpuTemperature
    }

    private var thermal: (color: Color, title: String, advice: String) {
        guard let t = maxTemp else {
            return (.secondary, "Okunamıyor",
                    "Bu modelde sıcaklık okunamıyor; termal durum değerlendirilemiyor.")
        }
        switch t {
        case ..<60:
            return (.green, "Normal", "Sıcaklık güvenli aralıkta. Cihazı bekletmene gerek yok.")
        case ..<80:
            return (.yellow, "Ilık", "Yük altında ama normal aralıkta. Endişelenmene gerek yok.")
        case ..<95:
            return (.orange, "Sıcak", "Sıcaklık yüksek. Uzun sürerse ağır işleri azaltmayı düşün.")
        default:
            return (.red, "Kritik",
                    "Çok sıcak! Ağır işleri durdurup cihazın soğumasını beklemen önerilir.")
        }
    }
}

// MARK: - Sıcaklığa göre renk (mavi serin · yeşil normal · turuncu ılık · kırmızı sıcak)

func tempColor(_ celsius: Double) -> Color {
    switch celsius {
    case ..<40: return .blue
    case ..<60: return .green
    case ..<80: return .orange
    default:    return .red
    }
}

// MARK: - Fan göstergesi

struct FanGauge: View {
    let fan: FanData

    private var fraction: Double {
        guard fan.maxRPM > fan.minRPM else { return 0 }
        return min(max(Double(fan.currentRPM - fan.minRPM) / Double(fan.maxRPM - fan.minRPM), 0), 1)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(.cyan, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(fan.currentRPM)")
                        .font(.title3.bold())
                        .monospacedDigit()
                    Text("RPM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 120)

            Text("Fan \(fan.index + 1)")
                .font(.callout.weight(.medium))
            Text("\(fan.minRPM)–\(fan.maxRPM) RPM")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

#Preview {
    FanView()
        .environmentObject(FanMonitor())
        .frame(width: 640, height: 860)
}
