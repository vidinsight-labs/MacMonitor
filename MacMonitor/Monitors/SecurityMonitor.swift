import Foundation
import Combine

/// Bir çalıştırılabilir dosyanın kod imzası durumu.
enum Signing {
    case apple                 // Apple tarafından imzalı (sistem bileşeni)
    case developer(String)     // Tanımlı geliştirici (Developer ID) — imzalayan adı
    case unsigned              // İmzasız veya ad-hoc (kendi kendine imzalı)
    case unknown               // Dosya yok / imza okunamadı
}

/// Açılışta veya arka planda kalıcı olarak çalışan bir öğe (LaunchAgent/Daemon).
struct SecurityItem: Identifiable {
    let id = UUID()
    let label: String              // launchd Label (yoksa dosya adı)
    let program: String            // çalıştırılabilir yol
    let source: String             // nereden geldiği (kullanıcı/sistem)
    let signing: Signing
    let suspiciousLocation: Bool   // /tmp, gizli klasör vb.
}

/// "Güvenlik Bakışı" — kalıcılık öğelerini (LaunchAgents/Daemons) bulur ve her birinin
/// kod imzası durumunu çıkarır. Bu bir **antivirüs değildir**; yalnızca açılışta sessizce
/// çalışan şeyleri ve imza durumlarını şeffaf biçimde gösterir (karar kullanıcıda).
///
/// Ağır olduğundan (codesign çağrıları) sürekli çalışmaz; yalnızca `scan()` ile bir kez.
final class SecurityMonitor: ObservableObject {
    @Published private(set) var items: [SecurityItem] = []
    @Published private(set) var isScanning = false
    @Published private(set) var scanDone = false

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let found = Self.gather()
            DispatchQueue.main.async {
                self?.items = found
                self?.isScanning = false
                self?.scanDone = true
            }
        }
    }

    /// İşaretlenmesi gereken (imzasız / tuhaf konum) öğe sayısı.
    var flaggedCount: Int {
        items.filter(Self.isFlagged).count
    }

    // MARK: - Tarama

    private static func gather() -> [SecurityItem] {
        let home = NSHomeDirectory()
        // Apple'ın /System/Library altındaki öğeleri kasıtlı olarak dışarıda — onlar sistemin parçası.
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

                let signing = program.isEmpty ? Signing.unknown : signingStatus(of: program)
                let suspicious = program.isEmpty ? false : isSuspiciousLocation(program)

                result.append(SecurityItem(label: label, program: program,
                                           source: dir.source, signing: signing,
                                           suspiciousLocation: suspicious))
            }
        }

        // İşaretliler (riskli) üste; sonra ada göre.
        return result.sorted { lhs, rhs in
            if isFlagged(lhs) != isFlagged(rhs) { return isFlagged(lhs) }
            return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
        }
    }

    static func isFlagged(_ item: SecurityItem) -> Bool {
        switch item.signing {
        case .apple, .developer: return item.suspiciousLocation
        case .unsigned:          return true
        case .unknown:           return false   // imza okunamadı → kesin değil; yanlış pozitif olmasın
        }
    }

    /// XML veya binary plist'i sözlüğe okur.
    private static func readPlist(_ path: String) -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    /// launchd plist'inden çalıştırılabilir yolu çıkarır (Program veya ProgramArguments[0]).
    private static func executablePath(from plist: [String: Any]) -> String? {
        if let program = plist["Program"] as? String { return program }
        if let args = plist["ProgramArguments"] as? [String], let first = args.first { return first }
        return nil
    }

    /// `codesign -dvvv` çıktısından imza durumunu çıkarır.
    private static func signingStatus(of path: String) -> Signing {
        guard FileManager.default.fileExists(atPath: path) else { return .unknown }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dvvv", path]
        let errPipe = Pipe()
        process.standardError = errPipe     // codesign ayrıntıları stderr'e yazar
        process.standardOutput = Pipe()
        do {
            try process.run()
            let data = errPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let out = String(data: data, encoding: .utf8) ?? ""

            if out.contains("not signed at all") || out.contains("code object is not signed") {
                return .unsigned
            }
            if out.contains("Signature=adhoc") {
                return .unsigned   // ad-hoc imza ≈ imzasız (tanımlı bir geliştirici yok)
            }

            // Tüm "Authority=" satırlarını topla (zincir: leaf → ara → kök).
            let authorities = out.split(separator: "\n")
                .filter { $0.hasPrefix("Authority=") }
                .map { String($0.dropFirst("Authority=".count)) }
            guard let leaf = authorities.first else { return .unknown }

            // Apple sistem bileşeni: imza zincirinde Apple geçer ("Software Signing" leaf'i de Apple'ındır).
            if authorities.contains(where: { $0.contains("Apple") }) || leaf == "Software Signing" {
                return .apple
            }
            if leaf.hasPrefix("Developer ID Application: ") {
                let rest = leaf.dropFirst("Developer ID Application: ".count)
                // "Şirket Adı (TEAMID)" → "Şirket Adı"
                let name = rest.components(separatedBy: " (").first ?? String(rest)
                return .developer(name)
            }
            // Mac App Store vb. → geliştirici adıyla göster.
            return .developer(leaf)
        } catch {
            return .unknown
        }
    }

    /// Çalıştırılabilirin "tuhaf" bir konumda olup olmadığı (zayıf bir şüphe sinyali).
    private static func isSuspiciousLocation(_ path: String) -> Bool {
        let lower = path.lowercased()
        let suspicious = ["/tmp/", "/private/tmp/", "/private/var/folders/",
                          "/users/shared/", "/downloads/", "/.hidden"]
        if suspicious.contains(where: { lower.contains($0) }) { return true }

        // Gizli klasör bileşeni (. ile başlayan) — ev dizini kökü hariç.
        let comps = (path as NSString).pathComponents
        if comps.dropFirst().contains(where: { $0.hasPrefix(".") && $0.count > 1 && $0 != ".." }) {
            return true
        }
        return false
    }
}
