import Foundation

/// Çekirdek tipi (Apple Silicon: Performans / Verimlilik; Intel: tek tip).
enum CoreKind {
    case performance   // P çekirdeği
    case efficiency    // E çekirdeği
    case unknown       // tek tip / belirlenemedi

    var label: String {
        switch self {
        case .performance: return "Performans"
        case .efficiency:  return "Verimlilik"
        case .unknown:     return ""
        }
    }
}

/// Tek bir CPU çekirdeğinin anlık verisi.
struct CPUData: Identifiable {
    /// Çekirdek indeksi (id olarak da kullanılır).
    let id: Int

    var user: Double = 0     // %
    var system: Double = 0   // %
    var idle: Double = 100   // %

    /// Çekirdek tipi (Performans / Verimlilik).
    var kind: CoreKind = .unknown

    /// Toplam kullanım = user + system (%).
    var usage: Double { user + system }

    /// Bu çekirdek için son 30 kullanım değeri (grafikler için).
    var history: [Double] = []
}
