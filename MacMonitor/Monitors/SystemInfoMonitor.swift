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

/// Pil sağlığı (yalnızca dizüstülerde anlamlı).
struct BatteryHealth {
    var present = false
    var cycleCount: Int?
    var maxCapacityPercent: Int?
    var condition: String?
}

enum DiskAction {
    case emptyTrash
    case reveal
}

struct DiskItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let path: String
    let bytes: Int64
    let action: DiskAction
}

/// Sistem durumu: güç/termal/disk (canlı) + donanım envanteri (sysctl/IOKit, sandbox uyumlu).
final class SystemInfoMonitor: ObservableObject {

    // MARK: - Canlı durum

    @Published private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    @Published private(set) var lowPowerMode = false
    @Published private(set) var batteryLevel: Int?
    @Published private(set) var batteryCharging = false
    @Published private(set) var powerSource = "Bilinmiyor"
    @Published private(set) var diskFree: Int64 = 0
    @Published private(set) var diskTotal: Int64 = 0

    var diskUsedPercent: Double {
        guard diskTotal > 0 else { return 0 }
        return Double(diskTotal - diskFree) / Double(diskTotal) * 100
    }

    // MARK: - Donanım (butonla)

    @Published private(set) var components: [HardwareComponent] = []
    @Published private(set) var isLoadingHardware = false
    @Published private(set) var hardwareLoaded = false

    // MARK: - Yer Aç

    @Published private(set) var diskItems: [DiskItem] = []
    @Published private(set) var isScanningDisk = false
    @Published private(set) var diskScanDone = false
    @Published var spaceMessage: String?

    @Published private(set) var batteryHealth = BatteryHealth()

    private var timer: Timer?

    init() {
        refreshLive()
        loadBatteryHealth()

        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshLive),
            name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshLive),
            name: Notification.Name.NSProcessInfoPowerStateDidChange, object: nil)

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

    // MARK: - Donanım envanteri (sysctl + IOKit, sandbox uyumlu)

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
        let info = ProcessInfo.processInfo
        comps.append(HardwareComponent(icon: "applelogo", title: "macOS",
                                       detail: info.operatingSystemVersionString))

        if let model = sysctlString("hw.model") {
            comps.append(.init(icon: "laptopcomputer", title: "Model", detail: model))
        }
        if let brand = sysctlString("machdep.cpu.brand_string"), !brand.isEmpty {
            comps.append(.init(icon: "cpu", title: "İşlemci", detail: brand))
        }
        let memGB = Double(sysctlUInt64("hw.memsize")) / 1_073_741_824
        if memGB > 0 {
            comps.append(.init(icon: "memorychip", title: "Bellek",
                               detail: String(format: "%.0f GB RAM", memGB)))
        }
        let cores = sysctlInt("hw.logicalcpu")
        if cores > 0 {
            comps.append(.init(icon: "square.grid.3x3.fill", title: "Çekirdek",
                               detail: "\(cores) mantıksal çekirdek"))
        }
        if let machine = ioRegistryString("IOPlatformExpertDevice", key: "model") {
            comps.append(.init(icon: "macbook.gen2", title: "Donanım", detail: machine))
        }
        if let serial = ioRegistryString("IOPlatformExpertDevice", key: "IOPlatformSerialNumber") {
            comps.append(.init(icon: "number", title: "Seri No", detail: serial))
        }

        return comps
    }

    func loadBatteryHealth() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let health = Self.readBatteryHealthFromIOKit()
            DispatchQueue.main.async { self?.batteryHealth = health }
        }
    }

    private static func readBatteryHealthFromIOKit() -> BatteryHealth {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return BatteryHealth() }

        for src in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, src)?.takeUnretainedValue() as? [String: Any]
            else { continue }
            guard desc[kIOPSIsPresentKey] as? Bool == true else { continue }

            var health = BatteryHealth()
            health.present = true
            if let cycles = desc["CycleCount"] as? Int { health.cycleCount = cycles }
            if let max = desc["MaxCapacity"] as? Int, let design = desc["DesignCapacity"] as? Int, design > 0 {
                health.maxCapacityPercent = Int(Double(max) / Double(design) * 100)
            }
            if let condition = desc["Condition"] as? String { health.condition = condition }
            return health
        }
        return BatteryHealth()
    }

    // MARK: - Yer Aç (FileManager, sandbox erişilebilir konumlar)

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
        let specs: [(String, String, String, DiskAction)] = [
            ("arrow.down.circle",    "İndirilenler",      home + "/Downloads",       .reveal),
            ("menubar.dock.rectangle", "Masaüstü",        home + "/Desktop",         .reveal),
            ("doc.on.doc",           "Belgeler",          home + "/Documents",       .reveal),
            ("internaldrive",        "Önbellek (Cache)",  home + "/Library/Caches",  .reveal),
        ]

        var items: [DiskItem] = []
        for spec in specs {
            guard FileManager.default.fileExists(atPath: spec.2),
                  let bytes = folderSize(spec.2), bytes > 0 else { continue }
            items.append(DiskItem(icon: spec.0, title: spec.1, path: spec.2,
                                  bytes: bytes, action: spec.3))
        }
        return items.sorted { $0.bytes > $1.bytes }
    }

    private static func folderSize(_ path: String) -> Int64? {
        let url = URL(fileURLWithPath: path)
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]
        ) else { return nil }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total > 0 ? total : nil
    }

    func emptyTrash() {
        let avail = FeatureCapability.availability(for: .emptyTrash)
        spaceMessage = avail.reason
    }

    func reveal(_ path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    // MARK: - sysctl / IOKit yardımcıları

    private static func sysctlString(_ name: String) -> String? {
        var size: size_t = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    private static func sysctlUInt64(_ name: String) -> UInt64 {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return 0 }
        return value
    }

    private static func sysctlInt(_ name: String) -> Int {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return 0 }
        return Int(value)
    }

    private static func ioRegistryString(_ plane: String, key: String) -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(plane))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        if let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String {
            return value
        }
        return nil
    }
}
