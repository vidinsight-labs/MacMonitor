import Foundation
import Darwin

/// Bellek verisi toplar.
///
/// - active/wired/compressed/free: `host_statistics64` (mach, HOST_VM_INFO64) ile okunur.
/// - Toplam RAM ve takas (swap): `sysctl` ile okunur (`hw.memsize`, `vm.swapusage`).
/// - Bellek basıncı: `kern.memorystatus_vm_pressure_level` sysctl'inden okunur,
///   alınamazsa kullanılabilir bellek yüzdesinden türetilir.
/// - Her 2 saniyede bir `Timer` ile güncellenir.
final class MemoryMonitor: ObservableObject {

    // MARK: - Yayınlanan durum

    @Published private(set) var memory = MemoryData()
    @Published private(set) var pressure: MemoryPressure = .normal

    /// Temizleme (purge) işlemi sürüyor mu?
    @Published private(set) var isPurging = false
    /// Son temizleme hatası (varsa) — kullanıcıya gösterilir.
    @Published private(set) var purgeMessage: String?

    // MARK: - Özel

    private let interval: TimeInterval = 2.0
    private let pageSize: UInt64
    private var timer: Timer?

    // MARK: - Yaşam döngüsü

    init() {
        var ps: vm_size_t = 0
        host_page_size(mach_host_self(), &ps)
        pageSize = UInt64(ps)

        start()
    }

    deinit {
        stop()
    }

    func start() {
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.update()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        update()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Güncelleme

    private func update() {
        var data = MemoryData()
        data.total = Self.sysctlUInt64("hw.memsize")

        if let vm = readVMStats() {
            data.active     = UInt64(vm.active_count) * pageSize
            data.wired      = UInt64(vm.wire_count) * pageSize
            data.compressed = UInt64(vm.compressor_page_count) * pageSize
            data.free       = UInt64(vm.free_count) * pageSize
            data.inactive   = UInt64(vm.inactive_count) * pageSize
        }

        let swap = Self.swapUsage()
        data.swapUsed  = swap.used
        data.swapTotal = swap.total

        memory = data
        pressure = Self.pressureLevel(available: data.available, total: data.total)
    }

    // MARK: - mach: VM istatistikleri

    private func readVMStats() -> vm_statistics64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        return result == KERN_SUCCESS ? stats : nil
    }

    // MARK: - Bellek basıncı

    private static func pressureLevel(available: UInt64, total: UInt64) -> MemoryPressure {
        // Çekirdek seviyesini doğrudan oku: 1 = normal, 2 = uyarı, 4 = kritik.
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0, level > 0 {
            switch level {
            case 4:  return .critical
            case 2:  return .warning
            default: return .normal
            }
        }

        // Yedek: kullanılabilir bellek yüzdesine göre türet.
        guard total > 0 else { return .normal }
        let freeFraction = Double(available) / Double(total)
        switch freeFraction {
        case ..<0.10: return .critical
        case ..<0.25: return .warning
        default:      return .normal
        }
    }

    // MARK: - Takas (swap)

    private static func swapUsage() -> (used: UInt64, total: UInt64) {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return (0, 0) }
        return (UInt64(usage.xsu_used), UInt64(usage.xsu_total))
    }

    // MARK: - sysctl yardımcısı

    private static func sysctlUInt64(_ name: String) -> UInt64 {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        let r = sysctlbyname(name, &value, &size, nil, 0)
        return r == 0 ? value : 0
    }

    // MARK: - Bellek temizleme (purge)

    /// `purge` komutunu yönetici yetkisiyle çalıştırır.
    ///
    /// GUI uygulamasında `sudo` bir TTY olmadan parola soramaz; bu yüzden komut
    /// `osascript ... with administrator privileges` ile çalıştırılır — bu, macOS'un
    /// standart yönetici parola penceresini gösterir. (Eski `AuthorizationExecuteWithPrivileges`
    /// API'si kullanılmaz, çünkü kullanımdan kaldırılmıştır.)
    func purgeMemory() {
        guard !isPurging else { return }
        isPurging = true
        purgeMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "do shell script \"/usr/sbin/purge\" with administrator privileges"]

            let errPipe = Pipe()
            process.standardError = errPipe

            var message: String?
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    let data = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let err = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    message = err.isEmpty ? "Temizleme başarısız oldu (kod \(process.terminationStatus))." : err
                }
            } catch {
                message = error.localizedDescription
            }

            DispatchQueue.main.async {
                self?.isPurging = false
                self?.purgeMessage = message
                self?.update()   // temizlik sonrası değerleri yenile
            }
        }
    }
}
