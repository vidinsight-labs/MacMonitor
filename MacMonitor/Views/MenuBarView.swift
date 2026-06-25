import SwiftUI

/// Menü bar popover'ı: CPU/RAM, akıllı öneri, top işlemler ve "Aç" düğmesi.
struct MenuBarView: View {
    @ObservedObject private var loc = Localizer.shared
    @ObservedObject var cpuMonitor: CPUMonitor
    @ObservedObject var memoryMonitor: MemoryMonitor
    @ObservedObject var processMonitor: ProcessMonitor
    @ObservedObject var smartInsights: SmartInsightsEngine

    var onOpen: () -> Void

    private var ramPercent: Double {
        let m = memoryMonitor.memory
        return m.total > 0 ? Double(m.used) / Double(m.total) * 100 : 0
    }

    private var topProcesses: [ProcessData] {
        Array(processMonitor.processes.prefix(3))
    }

    private var topInsight: SmartInsight? {
        smartInsights.insights.first { $0.colorName != "green" } ?? smartInsights.insights.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MacMonitor")
                .font(.headline)

            usageBar(label: "CPU", value: cpuMonitor.totalUsage)
            usageBar(label: "RAM", value: ramPercent)

            if let insight = topInsight {
                Divider()
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: insight.icon)
                        .font(.caption)
                        .foregroundStyle(insightColor(insight.colorName))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(insight.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                        Text(insight.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }

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
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)
    }

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

    private func loadColor(_ value: Double) -> Color {
        if value > 90 { return .red }
        if value > 70 { return .yellow }
        return .green
    }

    private func insightColor(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "yellow": return .orange
        case "blue": return .blue
        default: return .green
        }
    }
}
