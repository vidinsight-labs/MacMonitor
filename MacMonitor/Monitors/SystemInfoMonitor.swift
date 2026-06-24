import Foundation
import Combine
import IOKit.ps
import AppKit

/// Donanım bileşeni (model, Wi-Fi modülü, SSD vb.).
struct HardwareComponent: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

/// Pil sağlığı (yalnızca dizüstülerde anlamlı). Apple'ın Ayarlar'da gösterdiğiyle aynı değerler.
struct BatteryHealth {
    var present = false
    var cycleCount: Int?
    var maxCapacityPercent: Int?   // ör. 92
    var condition: String?         // "Good" / "Fair" / "Service Recommended" ...
}

/// "Yer Aç" satırında önerilen eylem.
enum DiskAction {
    case emptyTrash   // Çöp kutusunu boşalt
    case reveal       // Klasörü Finder'da aç
}

/// Diskte yer kaplayan / boşaltılabilir bir konum.
struct DiskItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let path: String
    let bytes: Int64
    let action: DiskAction
}

/// Sistem durumu: güç/termal/disk (canlı, ucuz) + donanım envanteri (butonla, ağır).
///
/// - Termal durum, düşük güç modu, pil ve disk: ucuz okumalar; 5 sn'lik hafif timer +
///   sistem bildirimleriyle güncellenir.
/// - Donanım bileşenleri: `system_profiler` yavaş olduğundan **sürekli çalışmaz**;
///   yalnızca `loadHardware()` (kullanıcı butonu) ile arka planda bir kez alınır.
final class SystemInfoMonitor: ObservableObject {

    // MARK: - Canlı (ucuz) durum

    @Published private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    @Published private(set) var lowPowerMode = false
    @Published private(set) var batteryLevel: Int?       // % (pil yoksa nil)
    @Published private(set) var batteryCharging = false
    @Published private(set) var powerSource = "Bilinmiyor"
    @Published private(set) var diskFree: Int64 = 0
    @Published private(set) var diskTotal: Int64 = 0

    /// Disk doluluk yüzdesi (tek kaynak; Genel Bakış, Sistem ve bildirimler bunu kullanır).
    var diskUsedPercent: Double {
        guard diskTotal > 0 else { return 0 }
        return Double(diskTotal - diskFree) / Double(diskTotal) * 100
    }

    // MARK: - Donanım (butonla)

    @Published private(set) var components: [HardwareComponent] = []
    @Published private(set) var isLoadingHardware = false
    @Published private(set) var hardwareLoaded = false

    // MARK: - Yer Aç (disk kullanımı, butonla)

    @Published private(set) var diskItems: [DiskItem] = []
    @Published private(set) var isScanningDisk = false
    @Published private(set) var diskScanDone = false
    @Published var spaceMessage: String?     // çöp boşaltma vb. geri bildirim

    // MARK: - Pil sağlığı (yavaş değişir → bir kez yüklenir)

    @Published private(set) var batteryHealth = BatteryHealth()

    private var timer: Timer?

    init() {
        refreshLive()
        loadBatteryHealth()

        // Termal/güç değişiminde anında güncelle (yoklama yapmaz).
        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshLive),
            name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshLive),
            name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)

        // Pil/disk gibi yavaş değişen değerler için hafif timer.
        let timer = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshLive()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Canlı okuma

    @objc private func refreshLive() {
        let info = ProcessInfo.processInfo
        thermalState = info.thermalState
        lowPowerMode = info.isLowPowerModeEnabled

        let battery = Self.batteryInfo()
        batteryLevel = battery.level
        batteryCharging = battery.charging
        powerSource = battery.source

        let disk = Self.diskSpace()
        diskFree = disk.free
        diskTotal = disk.total
    }

    private static func batteryInfo() -> (level: Int?, charging: Bool, source: String) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return (nil, false, "Bilinmiyor") }

        for src in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, src)?.takeUnretainedValue() as? [String: Any]
            else { continue }

            let current = desc[kIOPSCurrentCapacityKey] as? Int
            let max = desc[kIOPSMaxCapacityKey] as? Int
            let charging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let state = desc[kIOPSPowerSourceStateKey] as? String
            let source = (state == kIOPSACPowerValue) ? "Güç adaptörü" : "Pil"

            var level: Int?
            if let c = current, let m = max, m > 0 { level = Int(Double(c) / Double(m) * 100) }
            return (level, charging, source)
        }
        return (nil, false, "Masaüstü / pil yok")
    }

    private static func diskSpace() -> (free: Int64, total: Int64) {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey
        ]) else { return (0, 0) }
        let free = Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        let total = Int64(values.volumeTotalCapacity ?? 0)
        return (free, total)
    }

    // MARK: - Donanım envanteri (ağır, butonla)

    func loadHardware() {
        guard !isLoadingHardware else { return }
        isLoadingHardware = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let comps = Self.gatherHardware()
            DispatchQueue.main.async {
                self?.components = comps
                self?.isLoadingHardware = false
                self?.hardwareLoaded = true
            }
        }
    }

    private static func gatherHardware() -> [HardwareComponent] {
        var comps: [HardwareComponent] = []
        comps.append(HardwareComponent(icon: "applelogo", title: "macOS",
                                       detail: ProcessInfo.processInfo.operatingSystemVersionString))

        guard let json = runSystemProfiler(
            ["SPHardwareDataType", "SPNVMeDataType", "SPAirPortDataType", "SPBluetoothDataType"]
        ) else { return comps }

        // Donanım genel
        if let hw = (json["SPHardwareDataType"] as? [[String: Any]])?.first {
            let model = ["machine_name", "machine_model", "model_number"]
                .compactMap { hw[$0] as? String }.joined(separator: " · ")
            if !model.isEmpty {
                comps.append(.init(icon: "laptopcomputer", title: "Model", detail: model))
            }
            if let serial = hw["serial_number"] as? String {
                comps.append(.init(icon: "number", title: "Seri No", detail: serial))
            }
            if let chip = hw["chip_type"] as? String {
                let mem = hw["physical_memory"] as? String ?? ""
                comps.append(.init(icon: "cpu", title: "Çip", detail: "\(chip) · \(mem)"))
            }
            if let boot = hw["boot_rom_version"] as? String {
                comps.append(.init(icon: "memorychip", title: "Boot ROM", detail: boot))
            }
        }

        // Depolama (SSD)
        if let item = ((json["SPNVMeDataType"] as? [[String: Any]])?.first?["_items"] as? [[String: Any]])?.first {
            let model = (item["device_model"] as? String) ?? (item["_name"] as? String) ?? "SSD"
            let parts = [item["size"] as? String,
                         (item["device_revision"] as? String).map { "FW \($0)" },
                         (item["smart_status"] as? String).map { "SMART: \($0)" }]
                .compactMap { $0 }
            comps.append(.init(icon: "internaldrive", title: "Depolama (SSD)",
                               detail: ([model] + parts).joined(separator: " · ")))
        }

        // Wi-Fi modülü
        if let itf = ((json["SPAirPortDataType"] as? [[String: Any]])?.first?["spairport_airport_interfaces"] as? [[String: Any]])?.first {
            let type = (itf["spairport_wireless_card_type"] as? String) ?? "Wi-Fi"
            let fw = itf["spairport_wireless_firmware_version"] as? String
            comps.append(.init(icon: "wifi", title: "Wi-Fi Modülü",
                               detail: fw.map { "\(type) · FW \($0)" } ?? type))
        }

        // Bluetooth
        if let ctl = (json["SPBluetoothDataType"] as? [[String: Any]])?.first?["controller_properties"] as? [String: Any] {
            let chip = (ctl["controller_chipset"] as? String) ?? "Bluetooth"
            let parts = [(ctl["controller_firmwareVersion"] as? String).map { "FW \($0)" },
                         ctl["controller_transport"] as? String].compactMap { $0 }
            comps.append(.init(icon: "antenna.radiowaves.left.and.right", title: "Bluetooth",
                               detail: ([chip] + parts).joined(separator: " · ")))
        }

        return comps
    }

    // MARK: - Pil sağlığı

    /// Pil sağlığını arka planda okur (yavaş değiştiği için sürekli değil).
    func loadBatteryHealth() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let health = Self.readBatteryHealth()
            DispatchQueue.main.async { self?.batteryHealth = health }
        }
    }

    private static func readBatteryHealth() -> BatteryHealth {
        guard let json = runSystemProfiler(["SPPowerDataType"]),
              let items = json["SPPowerDataType"] as? [[String: Any]]
        else { return BatteryHealth() }

        for item in items {
            guard let info = item["sppower_battery_health_info"] as? [String: Any] else { continue }
            var health = BatteryHealth()
            health.present = true
            health.cycleCount = info["sppower_battery_cycle_count"] as? Int
            health.condition = info["sppower_battery_health"] as? String
            if let cap = info["sppower_battery_health_maximum_capacity"] as? String {
                // "%92" / "92%" → 92. İlk rakam grubunu al (gömülü başka rakam varsa bozulmasın).
                let digits = cap.drop(while: { !$0.isNumber }).prefix(while: { $0.isNumber })
                health.maxCapacityPercent = Int(digits)
            }
            return health
        }
        return BatteryHealth()
    }

    // MARK: - Yer Aç: disk kullanımı (ağır, butonla)

    /// Yer kaplayan / boşaltılabilir konumların boyutlarını arka planda hesaplar.
    func scanDiskUsage() {
        guard !isScanningDisk else { return }
        isScanningDisk = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let items = Self.gatherDiskItems()
            DispatchQueue.main.async {
                self?.diskItems = items
                self?.isScanningDisk = false
                self?.diskScanDone = true
            }
        }
    }

    private static func gatherDiskItems() -> [DiskItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        // (ikon, başlık, yol, eylem)
        let specs: [(String, String, String, DiskAction)] = [
            ("trash",                "Çöp Kutusu",        home + "/.Trash",          .emptyTrash),
            ("arrow.down.circle",    "İndirilenler",      home + "/Downloads",       .reveal),
            ("menubar.dock.rectangle", "Masaüstü",        home + "/Desktop",         .reveal),
            ("doc.on.doc",           "Belgeler",          home + "/Documents",       .reveal),
            ("square.grid.2x2",      "Uygulamalar",       "/Applications",           .reveal),
            ("internaldrive",        "Önbellek (Cache)",  home + "/Library/Caches",  .reveal),
        ]

        var items: [DiskItem] = []
        for spec in specs {
            guard FileManager.default.fileExists(atPath: spec.2),
                  let bytes = duBytes(spec.2), bytes > 0 else { continue }
            items.append(DiskItem(icon: spec.0, title: spec.1, path: spec.2,
                                  bytes: bytes, action: spec.3))
        }
        return items.sorted { $0.bytes > $1.bytes }
    }

    /// `du -sk` ile bir klasörün toplam boyutu (byte). İzin engellenirse kısmi/nil döner.
    private static func duBytes(_ path: String) -> Int64? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()   // "Operation not permitted" gürültüsünü yut
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard let out = String(data: data, encoding: .utf8),
                  let kbStr = out.split(separator: "\t").first?.trimmingCharacters(in: .whitespaces),
                  let kb = Int64(kbStr)
            else { return nil }
            return kb * 1024
        } catch {
            return nil
        }
    }

    /// Çöp kutusunu boşaltır (Finder üzerinden — kullanıcı dosyalarına dokunmaz).
    func emptyTrash() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "tell application \"Finder\" to empty the trash"]
            process.standardError = Pipe()
            let ok: Bool
            do { try process.run(); process.waitUntilExit(); ok = process.terminationStatus == 0 }
            catch { ok = false }
            DispatchQueue.main.async {
                self?.spaceMessage = ok ? "Çöp kutusu boşaltıldı."
                                        : "Çöp boşaltılamadı (Finder izni gerekebilir)."
                self?.scanDiskUsage()   // boyutları tazele
            }
        }
    }

    /// Bir klasörü Finder'da gösterir (hiçbir şey silmez).
    func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    private static func runSystemProfiler(_ types: [String]) -> [String: Any]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["-json"] + types
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            return nil
        }
    }
}
