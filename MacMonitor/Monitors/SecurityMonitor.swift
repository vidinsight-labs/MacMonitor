import Foundation
import Combine

/// Bir çalıştırılabilir dosyanın kod imzası durumu.
enum Signing {
    case apple
    case developer(String)
    case unsigned
    case unknown
}

/// Açılışta veya arka planda kalıcı olarak çalışan bir öğe (LaunchAgent/Daemon).
struct SecurityItem: Identifiable {
    let id = UUID()
    let label: String
    let program: String
    let source: String
    let signing: Signing
    let suspiciousLocation: Bool
}

/// Güvenlik taraması baseline kaydı (diff için).
struct SecurityBaselineEntry: Codable, Hashable {
    let label: String
    let program: String
    let source: String
}

enum SecurityItemChange: String {
    case added
    case removed
    case unchanged
}

/// "Güvenlik Bakışı" — kalıcılık öğelerini bulur, imza durumunu Security.framework ile çıkarır.
/// İlk taramadan sonra baseline kaydedilir; sonraki taramalarda diff üretilir.
final class SecurityMonitor: ObservableObject {
    @Published private(set) var items: [SecurityItem] = []
    @Published private(set) var isScanning = false
    @Published private(set) var scanDone = false
    @Published private(set) var addedItems: [SecurityItem] = []
    @Published private(set) var removedItems: [SecurityBaselineEntry] = []
    @Published private(set) var hasBaseline = false

    private let baselineURL: URL

    init() {
        baselineURL = Self.makeBaselineURL()
        hasBaseline = FileManager.default.fileExists(atPath: baselineURL.path)
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let found = Self.gather()
            let previousBaseline = Self.loadBaseline(from: self.baselineURL)
            let currentKeys = Set(found.map(Self.baselineEntry(for:)))
            let previousKeys = Set(previousBaseline)

            let added = found.filter { !previousKeys.contains(Self.baselineEntry(for: $0)) }
            let removed = previousBaseline.filter { !currentKeys.contains($0) }

            if previousBaseline.isEmpty {
                Self.saveBaseline(found.map(Self.baselineEntry(for:)), to: self.baselineURL)
            }

            DispatchQueue.main.async {
                self.items = found
                self.addedItems = previousBaseline.isEmpty ? [] : added
                self.removedItems = previousBaseline.isEmpty ? [] : removed
                self.hasBaseline = FileManager.default.fileExists(atPath: self.baselineURL.path)
                self.isScanning = false
                self.scanDone = true
            }
        }
    }

    /// Mevcut taramayı yeni baseline olarak kaydet (diff sıfırlanır).
    func saveAsBaseline() {
        let entries = items.map(Self.baselineEntry(for:))
        Self.saveBaseline(entries, to: baselineURL)
        addedItems = []
        removedItems = []
        hasBaseline = true
    }

    func change(for item: SecurityItem) -> SecurityItemChange {
        let key = Self.baselineEntry(for: item)
        if addedItems.contains(where: { Self.baselineEntry(for: $0) == key }) {
            return .added
        }
        return .unchanged
    }

    var flaggedCount: Int {
        items.filter(Self.isFlagged).count
    }

    // MARK: - Tarama

    private static func gather() -> [SecurityItem] {
        let home = NSHomeDirectory()
        let dirs: [(path: String, source: String)] = [
            (home + "/Library/LaunchAgents", "Kullanıcı · LaunchAgent"),
            ("/Library/LaunchAgents",        "Sistem geneli · LaunchAgent"),
            ("/Library/LaunchDaemons",       "Sistem geneli · LaunchDaemon"),
        ]

        var result: [SecurityItem] = []
        let fm = FileManager.default

        for dir in dirs {
            guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { continue }
            for name in names where name.hasSuffix(".plist") {
                let plistPath = dir.path + "/" + name
                guard let plist = readPlist(plistPath) else { continue }

                let label = (plist["Label"] as? String) ?? (name as NSString).deletingPathExtension
                let program = executablePath(from: plist) ?? ""

                let signing = program.isEmpty ? Signing.unknown : CodeSigningHelper.signingStatus(of: program)
                let suspicious = program.isEmpty ? false : isSuspiciousLocation(program)

                result.append(SecurityItem(label: label, program: program,
                                           source: dir.source, signing: signing,
                                           suspiciousLocation: suspicious))
            }
        }

        return result.sorted { lhs, rhs in
            if isFlagged(lhs) != isFlagged(rhs) { return isFlagged(lhs) }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
    }

    static func isFlagged(_ item: SecurityItem) -> Bool {
        switch item.signing {
        case .apple, .developer: return item.suspiciousLocation
        case .unsigned:          return true
        case .unknown:           return false
        }
    }

    private static func baselineEntry(for item: SecurityItem) -> SecurityBaselineEntry {
        SecurityBaselineEntry(label: item.label, program: item.program, source: item.source)
    }

    private static func makeBaselineURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("MacMonitor", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("security_baseline.json")
    }

    private static func loadBaseline(from url: URL) -> [SecurityBaselineEntry] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([SecurityBaselineEntry].self, from: data)
        else { return [] }
        return decoded
    }

    private static func saveBaseline(_ entries: [SecurityBaselineEntry], to url: URL) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private static func readPlist(_ path: String) -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    private static func executablePath(from plist: [String: Any]) -> String? {
        if let program = plist["Program"] as? String { return program }
        if let args = plist["ProgramArguments"] as? [String], let first = args.first { return first }
        return nil
    }

    private static func isSuspiciousLocation(_ path: String) -> Bool {
        let lower = path.lowercased()
        let suspicious = ["/tmp/", "/private/tmp/", "/private/var/folders/",
                          "/users/shared/", "/downloads/", "/.hidden"]
        if suspicious.contains(where: { lower.contains($0) }) { return true }

        let comps = (path as NSString).pathComponents
        if comps.dropFirst().contains(where: { $0.hasPrefix(".") && $0.count > 1 && $0 != ".." }) {
            return true
        }
        return false
    }
}
