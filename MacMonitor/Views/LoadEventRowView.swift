import SwiftUI

/// Yük olayı satırı — özet + genişletilebilir detay.
struct LoadEventRowView: View {
    @ObservedObject private var loc = Localizer.shared
    @EnvironmentObject private var loadEvents: LoadEventRecorder
    let event: LoadEvent
    let isLive: Bool
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: 12) {
                    Circle()
                        .fill(cpuUsageColor(event.peak))
                        .frame(width: 8, height: 8)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(event.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.callout.weight(.medium))
                                .monospacedDigit()
                            if isLive {
                                Text(t("· devam ediyor", "· ongoing"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                        }

                        HStack(spacing: 8) {
                            metricPill(
                                label: t("Tepe", "Peak"),
                                value: "%\(Int(event.peak.rounded()))",
                                color: cpuUsageColor(event.peak)
                            )
                            metricPill(
                                label: t("Ort.", "Avg."),
                                value: "%\(Int(event.avgCPU.rounded()))",
                                color: cpuUsageColor(event.avgCPU)
                            )
                            if let dur = event.duration(isLive: isLive) {
                                let fmt = LoadEventFormatting.duration(dur)
                                metricPill(
                                    label: t("Süre", "Duration"),
                                    value: t(fmt.tr, fmt.en),
                                    color: .secondary
                                )
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 10)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    Text(t("Yükü alan işlemler", "Processes driving the load"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if event.culprits.isEmpty {
                        Text(t("İşlem bilgisi yok", "No process information"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(event.culprits) { culprit in
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(cpuUsageColor(culprit.cpu).opacity(0.85))
                                    .frame(width: 4, height: 28)

                                Text(loadEvents.displayName(for: culprit))
                                    .font(.callout)
                                    .lineLimit(1)

                                Spacer()

                                Text(String(format: "%.0f%%", culprit.cpu))
                                    .font(.callout.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(cpuUsageColor(culprit.cpu))
                            }
                        }
                    }

                    if let end = event.endedAt {
                        Text(t("Bitti: \(end.formatted(date: .omitted, time: .standard))",
                               "Ended: \(end.formatted(date: .omitted, time: .standard))"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }
                }
                .padding(.bottom, 10)
            }
        }
    }

    private func metricPill(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .foregroundStyle(.tertiary)
            Text(value)
                .foregroundStyle(color)
        }
        .font(.caption2.weight(.medium))
        .monospacedDigit()
    }
}
