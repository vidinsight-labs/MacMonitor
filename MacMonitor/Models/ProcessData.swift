import Foundation

/// Process veri modeli.
struct ProcessData: Identifiable {
    var pid: pid_t = 0
    var name: String = ""
    var cpuUsage: Double = 0       // yüzde (çekirdek başına; çok iş parçacıklı süreçte >100 olabilir)
    var memoryUsage: UInt64 = 0    // RSS, byte
    var user: String = ""
    var path: String = ""          // çalıştırılabilir yol (ikon için)

    /// PID id olarak kullanılır → tablo satırları kararlı kalır.
    var id: pid_t { pid }
}
