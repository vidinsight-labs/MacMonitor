import SwiftUI
import AppKit

/// Process listesi.
struct ProcessView: View {
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
                title: "İşlemler",
                subtitle: "\(monitor.processes.count) süreç çalışıyor · ilk 20 gösteriliyor"
            )

            controls

            if let message = monitor.actionMessage {
                actionBanner(message)
            }

            Table(displayed, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Ad", value: \.name) { proc in
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

                TableColumn("İşlemci (CPU)", value: \.cpuUsage) { proc in
                    Text(String(format: "%.1f%%", proc.cpuUsage))
                        .monospacedDigit()
                        .foregroundStyle(proc.cpuUsage >= 50 ? .primary : .secondary)
                }
                .width(min: 100, ideal: 110)

                TableColumn("Bellek (RAM)", value: \.memoryUsage) { proc in
                    Text(Self.memoryString(proc.memoryUsage)).monospacedDigit()
                }
                .width(min: 100, ideal: 110)

                TableColumn("Kullanıcı", value: \.user) { proc in
                    Text(proc.user).foregroundStyle(.secondary).lineLimit(1)
                }
                .width(min: 80, ideal: 100)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
        .padding(20)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Zorla kapatılsın mı?", isPresented: $confirmQuit) {
            Button("Vazgeç", role: .cancel) {}
            Button("Zorla Kapat", role: .destructive) {
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
            return "\(name) zorla kapatılacak. Kaydedilmemiş veriler kaybolabilir."
        }
        return "\(selection.count) işlem zorla kapatılacak. Kaydedilmemiş veriler kaybolabilir."
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

    // MARK: - Üst kontroller (sıralama + arama)

    private var controls: some View {
        HStack(spacing: 12) {
            Picker("", selection: $sortMode) {
                Text("İşlemci (CPU)").tag(SortMode.cpu)
                Text("Bellek (RAM)").tag(SortMode.memory)
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

            Spacer()

            Button {
                confirmQuit = true
            } label: {
                Label("Zorla Kapat", systemImage: "xmark.octagon.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(selection.isEmpty)
            .help(selection.isEmpty ? "Önce bir işlem seç" : "Seçili işlemi zorla kapat")

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("İşlem ara", text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: 160)
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

#Preview {
    ProcessView()
        .environmentObject(ProcessMonitor())
        .frame(width: 700, height: 500)
}
