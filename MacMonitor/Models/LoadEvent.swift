import Foundation

/// Yüksek yük ("riskli") anının kaydı — ne zaman olduğu ve o an yükü alan işlemler.
/// Diske kaydedilebilmesi için `Codable`.
struct LoadEvent: Identifiable, Codable {
    let id = UUID()
    let startedAt: Date
    var peak: Double              // bu olaydaki tepe toplam CPU (%)
    let culprits: [Culprit]       // o an en çok CPU kullanan işlemler

    // id diske yazılmaz; her yüklemede taze üretilir (liste kimliği için yeterli).
    private enum CodingKeys: String, CodingKey {
        case startedAt, peak, culprits
    }

    struct Culprit: Identifiable, Codable {
        let id = UUID()
        let name: String
        let cpu: Double

        private enum CodingKeys: String, CodingKey {
            case name, cpu
        }
    }
}
