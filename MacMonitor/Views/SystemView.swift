import SwiftUI

/// Sistem sayfası — güç & termal (canlı) + disk + donanım bileşenleri (butonla).
struct SystemView: View {
    @EnvironmentObject private var monitor: SystemInfoMonitor

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PageHeader(icon: "gauge.with.dots.needle.bottom.50percent",
                           gradient: [.gray, .blue],
                           title: "Sistem",
                           subtitle: "Güç, termal durum ve donanım")

                powerThermalCard
                diskCard
                hardwareCard
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Güç & Termal

    private var powerThermalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(icon: "bolt.heart", title: "Güç & Termal")

            // Termal (performans kısılması)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "thermometer.medium")
                    .foregroundStyle(thermal.color)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Termal durum")
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
                      title: "Düşük Güç Modu",
                      value: monitor.lowPowerMode ? "Açık (performans kısılı)" : "Kapalı")

            Divider()

            statusRow(icon: batteryIcon, tint: batteryTint,
                      title: "Güç kaynağı", value: batteryText)
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
            sectionTitle(icon: "internaldrive", title: "Disk")

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
                Text("Boş: \(gb(monitor.diskFree))")
                Spacer()
                Text("Toplam: \(gb(monitor.diskTotal))")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .monospacedDigit()

            if diskUsedFraction > 0.9 {
                Label("Boş alan azaldı — bu performansı düşürebilir.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .card()
    }

    // MARK: - Donanım bileşenleri (butonla)

    private var hardwareCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle(icon: "cpu.fill", title: "Donanım Bileşenleri")
                if monitor.hardwareLoaded && !monitor.isLoadingHardware {
                    Button("Yenile") { monitor.loadHardware() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }

            Text("Model, seri no, çip, Wi-Fi/Bluetooth ve depolama modülü bilgileri. Sistemden alındığı için birkaç saniye sürebilir.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if monitor.isLoadingHardware {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Bilgiler alınıyor…").foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.vertical, 6)
            } else if monitor.components.isEmpty {
                Button {
                    monitor.loadHardware()
                } label: {
                    Label("Bilgileri Getir", systemImage: "arrow.down.circle")
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

    private var thermal: (color: Color, label: String, advice: String) {
        switch monitor.thermalState {
        case .nominal:
            return (.green, "Normal", "Performans tam; ısı kaynaklı kısıtlama yok.")
        case .fair:
            return (.yellow, "Hafif", "Hafif ısınma; performans büyük ölçüde korunuyor.")
        case .serious:
            return (.orange, "Yüksek", "Sistem ısı nedeniyle performansı düşürmeye başladı.")
        case .critical:
            return (.red, "Kritik", "Performans ısı nedeniyle ciddi şekilde kısıldı. Ağır işleri azalt.")
        @unknown default:
            return (.secondary, "Bilinmiyor", "")
        }
    }

    private var batteryText: String {
        if let level = monitor.batteryLevel {
            let charge = monitor.batteryCharging ? " · şarj oluyor" : ""
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
        guard monitor.diskTotal > 0 else { return 0 }
        return CGFloat(Double(monitor.diskTotal - monitor.diskFree) / Double(monitor.diskTotal))
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
