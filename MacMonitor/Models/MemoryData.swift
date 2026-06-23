import Foundation

/// Bellek basıncı seviyesi.
enum MemoryPressure {
    case normal, warning, critical

    var label: String {
        switch self {
        case .normal:   return "Normal"
        case .warning:  return "Uyarı"
        case .critical: return "Kritik"
        }
    }
}

/// RAM kullanım verisi (byte cinsinden).
struct MemoryData {
    var total: UInt64 = 0

    var active: UInt64 = 0       // aktif
    var wired: UInt64 = 0        // sabitlenmiş (wired)
    var compressed: UInt64 = 0   // sıkıştırılmış
    var free: UInt64 = 0         // gerçek boş (mach free_count)
    var inactive: UInt64 = 0     // önbellek / geri kazanılabilir

    var swapUsed: UInt64 = 0
    var swapTotal: UInt64 = 0

    /// Etkin kullanım = aktif + sabitlenmiş + sıkıştırılmış.
    var used: UInt64 { active + wired + compressed }

    /// Kullanılabilir bellek = boş + önbellek (geri kazanılabilir).
    /// Çubuğun toplam RAM'i tam doldurması için `total - used` olarak hesaplanır.
    var available: UInt64 { total > used ? total - used : free }
}
