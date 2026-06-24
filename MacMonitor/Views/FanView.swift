import SwiftUI

/// Fan ve sıcaklık sayfası — İşlemci/Bellek ile aynı tasarım dili.
struct FanView: View {
    @ObservedObject private var loc = Localizer.shared
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
                    title: t("Fanlar ve Sıcaklık", "Fans and Temperature"),
                    subtitle: headerSubtitle
                )

                if !monitor.smcAvailable {
                    unavailableCard
                }

                if let lvl = fanLevel {
                    StatusBanner(level: lvl, title: fanStatus.title, message: fanStatus.message)
                }
                temperaturesCard
                fansCard
                controlCard
            }
            .padding(20)
            .centeredPageContent()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerSubtitle: String {
        if monitor.fans.isEmpty {
            return t("Pasif soğutma / sıcaklık", "Passive cooling / temperature")
        }
        return t("\(monitor.fans.count) fan", "\(monitor.fans.count) fan")
    }

    // MARK: - SMC yok uyarısı

    private var unavailableCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(t("SMC sensörlerine erişilemedi.", "Could not access SMC sensors."))
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .card()
    }

    // MARK: - Termal durum (sayfa üstü sade yargı)

    /// Sıcaklık okunabiliyorsa seviye (Genel Bakış ile ortak eşikler); okunamıyorsa nil.
    private var fanLevel: Level? {
        guard maxTemp != nil else { return nil }
        return thermalLevel(maxTemp: maxTemp)
    }

    private var fanStatus: (title: String, message: String) {
        let temp = maxTemp.map { " (\(Int($0.rounded()))°C)" } ?? ""
        switch fanLevel {
        case .normal:
            return (t("Sıcaklık normal\(temp)", "Temperature normal\(temp)"), t("Güvenli aralıkta; cihazı bekletmene gerek yok.", "Within a safe range; no need to let the device rest."))
        case .warning:
            return (t("Sıcaklık yüksek\(temp)", "Temperature high\(temp)"), t("Yük altında ısınmış. Uzun sürerse ağır işleri azaltmayı düşün.", "Warmed up under load. If it persists, consider reducing heavy tasks."))
        case .critical:
            return (t("Sıcaklık kritik\(temp)", "Temperature critical\(temp)"), t("Çok sıcak! Ağır işleri durdurup cihazın soğumasını beklemen önerilir.", "Too hot! It's recommended to stop heavy tasks and let the device cool down."))
        case nil:
            return ("", "")
        }
    }

    // MARK: - Tüm sıcaklıklar

    private var temperaturesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(icon: "thermometer.sun", title: t("Sıcaklıklar", "Temperatures"))

            if monitor.temperatures.isEmpty {
                Text(t("Bu modelde sıcaklık sensörleri okunamıyor. (Apple Silicon, SMC'nin Intel sıcaklık anahtarlarını sağlamaz.)", "Temperature sensors can't be read on this model. (Apple Silicon doesn't expose the SMC's Intel temperature keys.)"))
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
            legendDot(.blue, t("Serin", "Cool"))
            legendDot(.green, t("Normal", "Normal"))
            legendDot(.orange, t("Ilık", "Warm"))
            legendDot(.red, t("Sıcak", "Hot"))
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
            sectionTitle(icon: "fanblades.fill", title: t("Fanlar", "Fans"))

            if monitor.fans.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "wind")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(t("Fan bulunamadı — bu model pasif soğutma (fansız) kullanıyor.", "No fan found — this model uses passive cooling (fanless)."))
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
            sectionTitle(icon: "slider.horizontal.3", title: t("Fan Yönetimi", "Fan Management"))

            Picker(t("Mod", "Mode"), selection: $mode) {
                Text(t("Sistem (Otomatik)", "System (Automatic)")).tag(FanMode.system)
                Text(t("Manuel (Sabit Devir)", "Manual (Fixed Speed)")).tag(FanMode.manual)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(t("Hedef devir (master)", "Target speed (master)"))
                    Spacer()
                    Text("\(Int(masterRPM)) RPM").monospacedDigit().foregroundStyle(.secondary)
                }
                .font(.callout)
                Slider(value: $masterRPM, in: 1000...6000, step: 100)
                    .disabled(true)
            }

            Toggle(t("Fan bazlı ayar (her fan ayrı)", "Per-fan setting (each fan separately)"), isOn: $perFan)
                .disabled(true)
                .font(.callout)

            Divider()

            Label {
                Text(t("Fan kontrolü **yönetici izni** gerektirir ve yanlış ayar **aşırı ısınmaya** yol açabilir. Ayrıca bu Mac fansız olduğundan kontrol kullanılamıyor. Fanlı bir Intel Mac'te: **Sistem** modunda hızı macOS yönetir; **Manuel** modda master devir veya fan bazlı sabit devir ayarlanabilir.", "Fan control requires **administrator permission**, and an incorrect setting can lead to **overheating**. Also, since this Mac is fanless, control is unavailable. On an Intel Mac with fans: in **System** mode macOS manages the speed; in **Manual** mode you can set a master speed or a per-fan fixed speed."))
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
    @ObservedObject private var loc = Localizer.shared
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
                    Text(t("RPM", "RPM"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 120, height: 120)

            Text(t("Fan \(fan.index + 1)", "Fan \(fan.index + 1)"))
                .font(.callout.weight(.medium))
            Text(t("\(fan.minRPM)–\(fan.maxRPM) RPM", "\(fan.minRPM)–\(fan.maxRPM) RPM"))
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
