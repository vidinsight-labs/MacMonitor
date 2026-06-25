import SwiftUI

/// Güvenlik Bakışı — açılışta/arka planda kalıcı çalışan öğeler + imza durumu.
/// Antivirüs değildir; şeffaflık aracıdır (karar kullanıcıda).
struct SecurityView: View {
    @ObservedObject private var loc = Localizer.shared
    @EnvironmentObject private var monitor: SecurityMonitor

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PageHeader(
                    icon: "lock.shield",
                    gradient: [.indigo, .blue],
                    title: t("Güvenlik Bakışı", "Security Overview"),
                    subtitle: t("Açılışta sessizce çalışan öğeler ve imza durumları", "Items that run silently at startup and their signature status")
                )

                if monitor.scanDone {
                    StatusBanner(level: summaryLevel,
                                 title: summary.title, message: summary.message)
                }

                if monitor.scanDone && (!monitor.addedItems.isEmpty || !monitor.removedItems.isEmpty) {
                    diffCard
                }

                disclaimerCard

                scanCard
            }
            .responsivePageLayout()
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Baseline diff

    private var diffCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle(icon: "arrow.triangle.branch", title: t("Değişiklikler", "Changes"))
                Spacer()
                Button(t("Baseline Kaydet", "Save Baseline")) { monitor.saveAsBaseline() }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }

            if !monitor.addedItems.isEmpty {
                Text(t("Yeni öğeler (\(monitor.addedItems.count))", "New items (\(monitor.addedItems.count))"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                ForEach(monitor.addedItems) { item in
                    diffRow(label: item.label, detail: item.program, badge: t("Yeni", "New"), color: .orange)
                }
            }

            if !monitor.removedItems.isEmpty {
                Text(t("Kaldırılan öğeler (\(monitor.removedItems.count))", "Removed items (\(monitor.removedItems.count))"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, monitor.addedItems.isEmpty ? 0 : 8)
                ForEach(monitor.removedItems, id: \.self) { entry in
                    diffRow(label: entry.label, detail: entry.program, badge: t("Kaldırıldı", "Removed"), color: .secondary)
                }
            }
        }
        .card()
    }

    private func diffRow(label: String, detail: String, badge: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(badge)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(color.opacity(0.2)))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.callout.weight(.medium))
                if !detail.isEmpty {
                    Text(detail).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Dürüst uyarı

    private var disclaimerCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .padding(.top, 1)
            Text(t("Bu bir **antivirüs değildir**. macOS'un yerleşik koruması (Gatekeeper/XProtect) zaten arka planda çalışır. Burada yalnızca açılışta otomatik çalışan öğeler ve imza durumları gösterilir; **imzasız** ya da **tuhaf konumdan** çalışan bir öğe her zaman zararlı demek değildir — tanımıyorsan araştırman için bir ipucudur.", "This is **not an antivirus**. macOS's built-in protection (Gatekeeper/XProtect) already runs in the background. Here we only show items that launch automatically at startup and their signature status; an **unsigned** item or one running from an **unusual location** doesn't always mean it's malicious — it's a hint to investigate if you don't recognize it."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    // MARK: - Tarama / sonuç

    private var scanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle(icon: "list.bullet.rectangle", title: t("Açılışta Çalışan Öğeler", "Items That Run at Startup"))
                if monitor.scanDone && !monitor.isScanning {
                    Button(t("Yeniden Tara", "Rescan")) { monitor.scan() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }

            if monitor.isScanning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(t("Taranıyor… (imzalar kontrol ediliyor)", "Scanning… (checking signatures)")).foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.vertical, 6)
            } else if !monitor.scanDone {
                Button {
                    monitor.scan()
                } label: {
                    Label(t("Taramayı Başlat", "Start Scan"), systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if monitor.items.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text(t("Açılışta otomatik çalışan üçüncü taraf öğe bulunamadı.", "No third-party items found running automatically at startup."))
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(monitor.items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider() }
                        itemRow(item)
                    }
                }
            }
        }
        .card()
    }

    private func itemRow(_ item: SecurityItem) -> some View {
        let lvl = level(for: item)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: lvl == .normal ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .foregroundStyle(lvl.color)
                .frame(width: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.label)
                        .font(.callout.weight(.semibold))
                    if monitor.change(for: item) == .added {
                        Text(t("Yeni", "New"))
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange.opacity(0.2)))
                            .foregroundStyle(.orange)
                    }
                }

                HStack(spacing: 6) {
                    Text(signingText(item))
                        .foregroundStyle(lvl == .normal ? .secondary : lvl.color)
                    if item.suspiciousLocation {
                        Text(t("· tuhaf konum", "· unusual location")).foregroundStyle(.orange)
                    }
                    Text("· \(item.source)").foregroundStyle(.secondary)
                }
                .font(.caption)

                if !item.program.isEmpty {
                    Text(item.program)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if lvl != .normal {
                    Text(t("Tanımıyorsan araştır. Gerekiyorsa Sistem Ayarları veya Finder'dan kaldırabilirsin.", "Investigate if you don't recognize it. If needed, you can remove it from System Settings or Finder."))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Değerlendirme

    private func level(for item: SecurityItem) -> Level {
        switch item.signing {
        case .apple, .developer:
            return item.suspiciousLocation ? .warning : .normal
        case .unsigned:
            return item.suspiciousLocation ? .critical : .warning
        case .unknown:
            return .normal   // imza okunamadı (çoğu zaman bare komut yolu) → uyarı verme
        }
    }

    private func signingText(_ item: SecurityItem) -> String {
        switch item.signing {
        case .apple:               return t("Apple imzalı", "Signed by Apple")
        case .developer(let name): return t("İmzalı · \(name)", "Signed · \(name)")
        case .unsigned:            return t("İmzasız", "Unsigned")
        case .unknown:             return t("İmza okunamadı", "Signature unreadable")
        }
    }

    private var summaryLevel: Level {
        guard !monitor.items.isEmpty else { return .normal }
        let levels = monitor.items.map(level(for:))
        if levels.contains(.critical) { return .critical }
        if levels.contains(.warning) { return .warning }
        return .normal
    }

    private var summary: (title: String, message: String) {
        let n = monitor.flaggedCount
        switch summaryLevel {
        case .normal:
            return (t("Şüpheli bir öğe görünmüyor", "No suspicious items found"),
                    t("Açılışta çalışan öğelerin tümü tanınan geliştiricilerce imzalanmış.", "All startup items are signed by recognized developers."))
        case .warning:
            return (t("Gözden geçirilecek \(n) öğe var", "\(n) item(s) to review"),
                    t("İmzasız veya tuhaf konumda çalışan öğe(ler) var. Tanıyorsan sorun yok; tanımıyorsan araştır.", "There are item(s) that are unsigned or running from an unusual location. If you recognize them, it's fine; if not, investigate."))
        case .critical:
            return (t("Dikkat: \(n) öğe öne çıkıyor", "Caution: \(n) item(s) stand out"),
                    t("Hem imzasız hem tuhaf konumda çalışan öğe(ler) var. Tanımıyorsan mutlaka araştır.", "There are item(s) that are both unsigned and running from an unusual location. If you don't recognize them, be sure to investigate."))
        }
    }
}

#Preview("1280×800") {
    SecurityView()
        .environmentObject(SecurityMonitor())
        .previewLayout(width: 1280, height: 800, detailWidth: 1000)
}
