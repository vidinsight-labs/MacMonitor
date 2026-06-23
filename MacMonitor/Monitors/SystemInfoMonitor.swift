import Foundation
import Combine
import IOKit.ps

/// Donanım bileşeni (model, Wi-Fi modülü, SSD vb.).
struct HardwareComponent: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
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

    // MARK: - Donanım (butonla)

    @Published private(set) var components: [HardwareComponent] = []
    @Published private(set) var isLoadingHardware = false
    @Published private(set) var hardwareLoaded = false

    private var timer: Timer?

    init() {
        refreshLive()

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
