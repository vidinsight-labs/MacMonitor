import SwiftUI

/// Menü bar popover'ı (300×200): CPU/RAM çubukları, en çok kullanan 3 işlem ve "Aç" düğmesi.
struct MenuBarView: View {
    @ObservedObject private var loc = Localizer.shared
    @ObservedObject var cpuMonitor: CPUMonitor
    @ObservedObject var memoryMonitor: MemoryMonitor
    @ObservedObject var processMonitor: ProcessMonitor

    /// Ana pencereyi açma eylemi (AppDelegate tarafından sağlanır).
    var onOpen: () -> Void

    private var ramPercent: Double {
        let m = memoryMonitor.memory
        return m.total > 0 ? Double(m.used) / Double(m.total) * 100 : 0
    }

    private var topProcesses: [ProcessData] {
        Array(processMonitor.processes.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MacMonitor")
                .font(.headline)

            usageBar(label: "CPU", value: cpuMonitor.totalUsage)
            usageBar(label: "RAM", value: ramPercent)

            Divider()

            Text(t("En çok kullanan işlemler", "Top resource-using processes"))
                .font(.caption)
                .foregroundStyle(.secondary)

            if topProcesses.isEmpty {
                Text(t("Veri toplanıyor…", "Collecting data…"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(topProcesses) { proc in
                    HStack(spacing: 6) {
                        Text(proc.name)
                            .lineLimit(1)
                        Spacer()
                        Text(String(format: "%.0f%%", proc.cpuUsage))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }

            Button(action: onOpen) {
                Text(t("Aç", "Open"))
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.regular)
            .padding(.top, 4)
        }
        .padding(12)
        // Sabit genişlik; yükseklik içeriğe göre (sabit 200 px içeriği taşırıyordu).
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Kullanım çubuğu

    private func usageBar(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.caption.weight(.medium))
                Spacer()
                Text(String(format: "%.0f%%", value))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                    Capsule()
                        .fill(loadColor(value))
                        .frame(width: geo.size.width * min(max(value, 0), 100) / 100)
                        .animation(.easeInOut(duration: 0.3), value: value)
                }
            }
            .frame(height: 6)
        }
    }

    /// Çubuk rengi: yeşil normal, sarı > %70, kırmızı > %90.
    private func loadColor(_ value: Double) -> Color {
        if value > 90 { return .red }
        if value > 70 { return .yellow }
        return .green
    }
}
