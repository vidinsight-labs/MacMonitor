import Foundation

/// Fan veri modeli.
struct FanData: Identifiable {
    /// Fan indeksi (id olarak da kullanılır → kararlı animasyon).
    var index: Int = 0
    var currentRPM: Int = 0
    var minRPM: Int = 0
    var maxRPM: Int = 0

    var id: Int { index }
}

/// Tek bir sıcaklık sensörü okuması.
struct TempReading: Identifiable {
    let id: String       // SMC anahtarı (ör. "TC0P")
    let label: String    // okunabilir ad
    let celsius: Double
}
