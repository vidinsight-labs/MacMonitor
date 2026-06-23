import Foundation
import Darwin
import IOKit

/// CPU verisi toplar.
///
/// - Çekirdek sayısı, model adı ve frekans: `sysctl` ile okunur (Intel + Apple Silicon).
/// - Çekirdek başına kullanım (user/system/idle): `host_processor_info` (mach) ile okunur,
///   çünkü `sysctl` çekirdek başına tick sayacı sağlamaz.
/// - Her 2 saniyede bir `Timer` ile güncellenir.
final class CPUMonitor: ObservableObject {

    // MARK: - Yayınlanan durum

    /// Çekirdek başına anlık veri.
    @Published private(set) var cores: [CPUData] = []

    /// Tüm çekirdeklerin ortalaması olarak toplam kullanım (%).
    @Published private(set) var totalUsage: Double = 0

    /// Toplam kullanımın son 30 değeri (2 sn aralıkla = 60 sn) — çizgi grafik için.
    @Published private(set) var totalUsageHistory: [Double] = []

    /// CPU model adı (ör. "Apple M2 Pro" / "Intel(R) Core(TM) i7...").
    @Published private(set) var modelName: String = ""

    /// Mac model adı (ör. "MacBook Air (M2, 2022)").
    @Published private(set) var machineModel: String = ""

    /// CPU temel frekansı (MHz). Apple Silicon'da sysctl bu değeri vermez → 0.
    @Published private(set) var frequencyMHz: Double = 0

    /// Mantıksal çekirdek sayısı (sysctl).
    @Published private(set) var coreCount: Int = 0

    // MARK: - Özel

    private let historyLength = 30
    private let interval: TimeInterval = 2.0
    private var timer: Timer?

    /// İndeks → çekirdek tipi eşlemesi (init'te bir kez belirlenir).
    private let coreKinds: [CoreKind]

    /// Çekirdek başına önceki tick'ler: [user, system, idle, nice].
    private var previousTicks: [[UInt32]] = []

    // MARK: - Yaşam döngüsü

    init() {
        let logical = Self.sysctlInt("hw.logicalcpu")
        coreCount = logical
        coreKinds = Self.detectCoreKinds(logicalCount: logical)
        modelName = Self.cpuModelName()
        machineModel = Self.machineModelName()
        frequencyMHz = Self.cpuFrequencyMHz()
        start()
    }

    deinit {
        stop()
    }

    func start() {
        // İlk okuma yalnızca temel (baseline) tick'leri kaydeder; ilk fark sonraki ölçümde hesaplanır.
        previousTicks = readCPUTicks()

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.update()
        }
        // Menü/scroll sırasında durmaması için .common modunda ekle.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Güncelleme

    private func update() {
        let current = readCPUTicks()
        guard !current.isEmpty else { return }

        // İlk geçerli ölçümden önce baseline yoksa onu kur ve çık.
        guard previousTicks.count == current.count else {
            previousTicks = current
            return
        }

        var newCores: [CPUData] = []
        newCores.reserveCapacity(current.count)
        var usageSum: Double = 0

        for i in 0..<current.count {
            let (user, system, idle) = Self.percentages(previous: previousTicks[i], current: current[i])
            usageSum += user + system

            // Önceki history'i koru, yeni değeri ekle, 30 ile sınırla.
            var history = i < cores.count ? cores[i].history : []
            history.append(user + system)
            if history.count > historyLength { history.removeFirst(history.count - historyLength) }

            let kind = i < coreKinds.count ? coreKinds[i] : .unknown
            newCores.append(CPUData(id: i, user: user, system: system, idle: idle, kind: kind, history: history))
        }

        let total = current.isEmpty ? 0 : usageSum / Double(current.count)

        var totalHistory = totalUsageHistory
        totalHistory.append(total)
        if totalHistory.count > historyLength { totalHistory.removeFirst(totalHistory.count - historyLength) }

        previousTicks = current

        // @Published güncellemeleri ana iş parçacığında (Timer zaten main run loop'ta).
        cores = newCores
        totalUsage = total
        totalUsageHistory = totalHistory
    }

    // MARK: - mach: çekirdek başına tick okuma

    /// Her çekirdek için [user, system, idle, nice] tick değerlerini döndürür.
    private func readCPUTicks() -> [[UInt32]] {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(mach_host_self(),
                                         PROCESSOR_CPU_LOAD_INFO,
                                         &numCPUs,
                                         &cpuInfo,
                                         &numCpuInfo)
        guard result == KERN_SUCCESS, let cpuInfo else { return [] }

        defer {
            let size = vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)
        }

        let stateMax = Int(CPU_STATE_MAX)
        var ticks: [[UInt32]] = []
        ticks.reserveCapacity(Int(numCPUs))

        for cpu in 0..<Int(numCPUs) {
            let base = cpu * stateMax
            let user = UInt32(bitPattern: cpuInfo[base + Int(CPU_STATE_USER)])
            let system = UInt32(bitPattern: cpuInfo[base + Int(CPU_STATE_SYSTEM)])
            let idle = UInt32(bitPattern: cpuInfo[base + Int(CPU_STATE_IDLE)])
            let nice = UInt32(bitPattern: cpuInfo[base + Int(CPU_STATE_NICE)])
            ticks.append([user, system, idle, nice])
        }
        return ticks
    }

    /// İki ölçüm arasındaki tick farkından yüzde hesaplar. nice, user'a dahil edilir.
    private static func percentages(previous: [UInt32], current: [UInt32]) -> (user: Double, system: Double, idle: Double) {
        // &- : sayaç taşmalarına karşı güvenli çıkarma.
        let userDiff = Double(current[0] &- previous[0])
        let systemDiff = Double(current[1] &- previous[1])
        let idleDiff = Double(current[2] &- previous[2])
        let niceDiff = Double(current[3] &- previous[3])

        let total = userDiff + systemDiff + idleDiff + niceDiff
        guard total > 0 else { return (0, 0, 100) }

        return (user: (userDiff + niceDiff) / total * 100,
                system: systemDiff / total * 100,
                idle: idleDiff / total * 100)
    }

    // MARK: - sysctl yardımcıları

    /// Çekirdek tiplerini sysctl `perflevel` anahtarlarından belirler.
    ///
    /// Apple Silicon'da `hw.nperflevels == 2`: perflevel0 = Performance (P), perflevel1 = Efficiency (E).
    /// Çekirdek indekslemesinde **düşük indeksler verimlilik (E), sonrakiler performans (P)** çekirdekleridir
    /// (powermetrics'in E-Cluster'ı CPU 0'dan başlatmasıyla uyumlu). Intel / tek seviyede tip belirtilmez.
    private static func detectCoreKinds(logicalCount: Int) -> [CoreKind] {
        guard sysctlInt("hw.nperflevels") >= 2 else {
            return Array(repeating: .unknown, count: logicalCount)
        }
        let pCount = sysctlInt("hw.perflevel0.logicalcpu")   // Performance
        let eCount = sysctlInt("hw.perflevel1.logicalcpu")   // Efficiency

        var kinds: [CoreKind] = Array(repeating: .efficiency, count: max(0, eCount))
        kinds += Array(repeating: .performance, count: max(0, pCount))

        if kinds.count < logicalCount {
            kinds += Array(repeating: .unknown, count: logicalCount - kinds.count)
        }
        return Array(kinds.prefix(logicalCount))
    }

    private static func sysctlInt(_ name: String) -> Int {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let r = sysctlbyname(name, &value, &size, nil, 0)
        return r == 0 ? Int(value) : 0
    }

    private static func sysctlString(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return "" }
        return String(cString: buffer)
    }

    private static func cpuModelName() -> String {
        // Intel ve Apple Silicon'ın ikisinde de çalışır (Apple Silicon'da "Apple M.." döner).
        let brand = sysctlString("machdep.cpu.brand_string")
        return brand.isEmpty ? sysctlString("hw.model") : brand
    }

    private static func cpuFrequencyMHz() -> Double {
        // hw.cpufrequency yalnızca Intel'de mevcut (Hz, 64-bit). Apple Silicon'da yoktur.
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        guard sysctlbyname("hw.cpufrequency", &value, &size, nil, 0) == 0, value > 0 else { return 0 }
        return Double(value) / 1_000_000.0
    }

    /// Mac'in pazarlama adını IOKit cihaz ağacından okur (ör. "MacBook Air (M2, 2022)").
    /// `sysctl hw.model` yalnızca "Mac14,2" gibi kod verir; bu yöntem okunabilir adı verir.
    private static func machineModelName() -> String {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/product")
        guard entry != 0 else { return "" }
        defer { IOObjectRelease(entry) }

        guard let prop = IORegistryEntryCreateCFProperty(entry, "product-name" as CFString,
                                                         kCFAllocatorDefault, 0)?.takeRetainedValue()
        else { return "" }

        // product-name, C string içeren bir CFData'dır.
        if let data = prop as? Data {
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\0").union(.whitespaces)) ?? ""
        }
        if let str = prop as? String {
            return str
        }
        return ""
    }
}
