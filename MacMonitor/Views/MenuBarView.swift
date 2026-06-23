import SwiftUI

/// Menü bar popover'ı (300×200): CPU/RAM çubukları, en çok kullanan 3 işlem ve "Aç" düğmesi.
struct MenuBarView: View {
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

            Text("En çok kullanan işlemler")
                .font(.caption)
                .foregroundStyle(.secondary)

            if topProcesses.isEmpty {
                Text("Veri toplanıyor…")
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

            Spacer(minLength: 0)

            Button(action: onOpen) {
                Text("Aç")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.regular)
        }
        .padding(12)
        .frame(width: 300, height: 200)
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
