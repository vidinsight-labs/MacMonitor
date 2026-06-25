import SwiftUI
import AppKit

/// Process listesi.
struct ProcessView: View {
    @ObservedObject private var loc = Localizer.shared
    @EnvironmentObject private var monitor: ProcessMonitor

    @State private var searchText = ""
    @State private var selection = Set<ProcessData.ID>()
    @State private var sortMode: SortMode = .cpu
    @State private var sortOrder = [KeyPathComparator(\ProcessData.cpuUsage, order: .reverse)]
    @State private var confirmQuit = false

    private enum SortMode: Hashable {
        case cpu, memory
    }

    /// Filtre + sıralama + üst 20.
    private var displayed: [ProcessData] {
        var list = monitor.processes
        if !searchText.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        list.sort(using: sortOrder)
        return Array(list.prefix(20))
    }

    var body: some View {
        VStack(spacing: 16) {
            PageHeader(
                icon: "list.bullet.rectangle",
                gradient: [.green, .mint],
                title: t("İşlemler", "Processes"),
                subtitle: t("\(monitor.processes.count) süreç çalışıyor · ilk 20 gösteriliyor", "\(monitor.processes.count) processes running · showing top 20")
            )

            controls

            if monitor.isLimitedList {
                limitedListBanner
            }

            if let message = monitor.actionMessage {
                actionBanner(message)
            }

            if displayed.isEmpty {
                emptyState
            } else {
                Table(displayed, selection: $selection, sortOrder: $sortOrder) {
                    TableColumn(t("Ad", "Name"), value: \.name) { proc in
                        HStack(spacing: 6) {
                            ProcessIconView(proc: proc)
                            Text(proc.name).lineLimit(1)
                        }
                    }
                    .width(min: 160, ideal: 220)

                    TableColumn("PID", value: \.pid) { proc in
                        Text("\(proc.pid)").monospacedDigit()
                    }
                    .width(60)

                    TableColumn(t("İşlemci (CPU)", "Processor (CPU)"), value: \.cpuUsage) { proc in
                        Text(String(format: "%.1f%%", proc.cpuUsage))
                            .monospacedDigit()
                            .foregroundStyle(proc.cpuUsage >= 50 ? .primary : .secondary)
                    }
                    .width(min: 100, ideal: 110)

                    TableColumn(t("Bellek (RAM)", "Memory (RAM)"), value: \.memoryUsage) { proc in
                        Text(Self.memoryString(proc.memoryUsage)).monospacedDigit()
                    }
                    .width(min: 100, ideal: 110)

                    TableColumn(t("Kullanıcı", "User"), value: \.user) { proc in
                        Text(proc.user).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .width(min: 80, ideal: 100)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .responsivePageLayout()
        .background(Color(nsColor: .windowBackgroundColor))
        .alert(t("Zorla kapatılsın mı?", "Force quit?"), isPresented: $confirmQuit) {
            Button(t("Vazgeç", "Cancel"), role: .cancel) {}
            Button(t("Zorla Kapat", "Force Quit"), role: .destructive) {
                monitor.forceQuit(selection)
            }
        } message: {
            Text(confirmMessage)
        }
    }

    /// Onay penceresinde gösterilecek mesaj.
    private var confirmMessage: String {
        if selection.count == 1,
           let name = monitor.processes.first(where: { selection.contains($0.pid) })?.name {
            return t("\(name) zorla kapatılacak. Kaydedilmemiş veriler kaybolabilir.", "\(name) will be force quit. Unsaved data may be lost.")
        }
        return t("\(selection.count) işlem zorla kapatılacak. Kaydedilmemiş veriler kaybolabilir.", "\(selection.count) processes will be force quit. Unsaved data may be lost.")
    }

    // MARK: - Zorla kapat geri bildirim bandı

    private func actionBanner(_ message: String) -> some View {
        let isError = message.contains("yetki") || message.contains("kapatılamadı")
        return HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? .orange : .green)
            Text(message)
                .font(.callout)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill((isError ? Color.orange : Color.green).opacity(0.12))
        )
    }

    private var limitedListBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield")
                .foregroundStyle(.orange)
            Text(t("App Store güvenlik kısıtı: yalnızca açık kullanıcı uygulamaları listelenir. CPU/bellek değerleri bazı uygulamalarda 0 görünebilir.",
                    "App Store security restriction: only open user applications are listed. CPU/memory may show as 0 for some apps."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
    }

    // MARK: - Boş durum

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(emptyStateMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .card()
    }

    private var emptyStateMessage: String {
        if !monitor.hasCompletedUpdate {
            return t("Süreç listesi yükleniyor…", "Loading process list…")
        }
        if monitor.processes.isEmpty {
            return t("Süreç listesi alınamadı. Uygulamayı yeniden başlatmayı deneyin.",
                       "Could not load the process list. Try restarting the app.")
        }
        return t("Aramayla eşleşen işlem yok.", "No processes match your search.")
    }

    // MARK: - Üst kontroller (sıralama + arama)

    private var controls: some View {
        ViewThatFits(in: .horizontal) {
            controlsHorizontal
            controlsStacked
        }
    }

    private var controlsHorizontal: some View {
        HStack(spacing: 12) {
            sortPicker
            Spacer()
            forceQuitButton
            searchField
        }
    }

    private var controlsStacked: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                sortPicker
                Spacer()
                forceQuitButton
            }
            searchField
        }
    }

    private var sortPicker: some View {
        Picker("", selection: $sortMode) {
            Text(t("İşlemci (CPU)", "Processor (CPU)")).tag(SortMode.cpu)
            Text(t("Bellek (RAM)", "Memory (RAM)")).tag(SortMode.memory)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .onChange(of: sortMode) { mode in
            switch mode {
            case .cpu:    sortOrder = [KeyPathComparator(\ProcessData.cpuUsage, order: .reverse)]
            case .memory: sortOrder = [KeyPathComparator(\ProcessData.memoryUsage, order: .reverse)]
            }
        }
    }

    private var forceQuitButton: some View {
        Button {
            confirmQuit = true
        } label: {
            Label(t("Zorla Kapat", "Force Quit"), systemImage: "xmark.octagon.fill")
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(selection.isEmpty)
        .help(selection.isEmpty ? t("Önce bir işlem seç", "Select a process first") : t("Seçili işlemi zorla kapat", "Force quit the selected process"))
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(t("İşlem ara", "Search process"), text: $searchText)
                .textFieldStyle(.plain)
                .frame(minWidth: 120, maxWidth: 200)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
        )
    }

    // MARK: - Biçimlendirme

    private static func memoryString(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}

// MARK: - Process ikonu

struct ProcessIconView: View {
    let proc: ProcessData

    var body: some View {
        if let icon = Self.icon(for: proc) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: "terminal")
                .frame(width: 16, height: 16)
                .foregroundStyle(.secondary)
        }
    }

    /// pid → ikon önbelleği (her yeniden çizimde tekrar aramamak için; ana iş parçacığı).
    private static var cache: [pid_t: NSImage?] = [:]

    /// Önce çalışan uygulamanın (GUI) ikonu, yoksa çalıştırılabilir dosyanın ikonu.
    private static func icon(for proc: ProcessData) -> NSImage? {
        if let cached = cache[proc.pid] { return cached }   // bulunan veya "yok" sonucu önbellekte

        var result: NSImage?
        if let app = NSRunningApplication(processIdentifier: proc.pid), let icon = app.icon {
            result = icon
        } else if !proc.path.isEmpty, FileManager.default.fileExists(atPath: proc.path) {
            result = NSWorkspace.shared.icon(forFile: proc.path)
        }
        cache[proc.pid] = result
        return result
    }
}

#Preview("720×520") {
    ProcessView()
        .environmentObject(ProcessMonitor())
        .previewLayout(width: 720, height: 520, detailWidth: 700)
}

#Preview("1280×800") {
    ProcessView()
        .environmentObject(ProcessMonitor())
        .previewLayout(width: 1280, height: 800, detailWidth: 1000)
}
