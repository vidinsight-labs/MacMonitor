import WidgetKit
import SwiftUI

@main
struct MacMonitorWidgetBundle: WidgetBundle {
    var body: some Widget {
        MacMonitorWidget()
    }
}

struct MacMonitorWidget: Widget {
    let kind = "MacMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MacMonitorProvider()) { entry in
            MacMonitorWidgetView(entry: entry)
        }
        .configurationDisplayName("MacMonitor")
        .description("Sistem sağlığı, CPU ve RAM özeti.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MacMonitorEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct MacMonitorProvider: TimelineProvider {
    func placeholder(in context: Context) -> MacMonitorEntry {
        MacMonitorEntry(date: .now, snapshot: WidgetSnapshot(
            healthLabelTR: "Normal", healthLabelEN: "Normal",
            healthLevel: "normal", cpuPercent: 24, ramPercent: 58, updatedAt: .now
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (MacMonitorEntry) -> Void) {
        completion(MacMonitorEntry(date: .now, snapshot: WidgetDataStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MacMonitorEntry>) -> Void) {
        let entry = MacMonitorEntry(date: .now, snapshot: WidgetDataStore.load())
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: .now) ?? .now.addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct MacMonitorWidgetView: View {
    let entry: MacMonitorEntry

    private var healthColor: Color {
        switch entry.snapshot.healthLevel {
        case "critical": return .red
        case "warning":  return .orange
        default:         return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .foregroundStyle(healthColor)
                Text(entry.snapshot.healthLabelTR)
                    .font(.headline)
                    .foregroundStyle(healthColor)
                Spacer()
            }

            HStack(spacing: 16) {
                metric(label: "CPU", value: entry.snapshot.cpuPercent, color: .blue)
                metric(label: "RAM", value: entry.snapshot.ramPercent, color: .purple)
            }

            Text(entry.snapshot.updatedAt, style: .time)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func metric(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(Int(value.rounded()))%")
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}
