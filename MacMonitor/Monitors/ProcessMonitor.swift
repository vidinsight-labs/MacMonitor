import Foundation
import Darwin

/// Çalışan process listesini toplar (libproc).
///
/// - PID listesi: `proc_listallpids`.
/// - Her süreç için: ad/yol (`proc_pidpath` / `proc_name`), bellek (RSS) ve CPU süresi
///   (`proc_pidinfo` + `proc_taskinfo`), kullanıcı (`proc_pidinfo` + `proc_bsdinfo` → `getpwuid`).
/// - CPU%: kümülatif CPU süresinin iki örnek arasındaki farkından geçen süreye bölünerek
///   hesaplanır (ilk örnekte 0 görünür). Varsayılan sıralama CPU'ya göre azalandır.
/// - Her 3 saniyede bir `Timer` ile güncellenir.
final class ProcessMonitor: ObservableObject {

    /// CPU'ya göre azalan sıralı tam liste (görünüm üst 20 ile sınırlar).
    @Published private(set) var processes: [ProcessData] = []

    /// Zorla kapatma sonrası kullanıcıya gösterilecek geçici mesaj.
    @Published private(set) var actionMessage: String?

    private let interval: TimeInterval = 3.0
    private var timer: Timer?
    private var messageToken = 0
    private let queue = DispatchQueue(label: "com.macmonitor.processmonitor")

    // CPU% hesabı için önceki örnek.
    private var previousCPU: [pid_t: UInt64] = [:]
    private var previousUptime: Double = 0
    // uid → kullanıcı adı önbelleği.
    private var userCache: [uid_t: String] = [:]
    // pid → sabit bilgiler (ad/yol/kullanıcı bir süreç için değişmez) → her döngüde yeniden çözme.
    private var infoCache: [pid_t: (name: String, path: String, user: String)] = [:]

    // MARK: - Yaşam döngüsü

    init() {
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

    /// Seçili süreçleri zorla sonlandırır (SIGKILL) ve sonucu kullanıcıya bildirir.
    /// Başka kullanıcıya / sisteme ait süreçler yetki gerektirir; bu durumda başarısız olur.
    func forceQuit(_ pids: Set<pid_t>) {
        guard !pids.isEmpty else { return }

        var succeeded = 0
        var failed: [String] = []

        for pid in pids {
            let name = processes.first(where: { $0.pid == pid })?.name ?? "PID \(pid)"
            if kill(pid, SIGKILL) == 0 {
                succeeded += 1
            } else {
                // EPERM (yetki yok) veya ESRCH (zaten yok) → başarısız say.
                failed.append(name)
            }
        }

        let message: String
        if failed.isEmpty {
            message = succeeded == 1 ? "İşlem sonlandırıldı." : "\(succeeded) işlem sonlandırıldı."
        } else if succeeded == 0 {
            message = "\(failed.joined(separator: ", ")) kapatılamadı — yönetici izni gerekebilir."
        } else {
            message = "\(succeeded) işlem kapatıldı; \(failed.joined(separator: ", ")) için yetki gerekiyor."
        }
        setActionMessage(message)
        update()
    }

    /// Mesajı yayınlar ve ~4 sn sonra (yeni mesaj gelmediyse) temizler.
    private func setActionMessage(_ message: String) {
        messageToken += 1
        let token = messageToken
        actionMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.messageToken == token else { return }
            self.actionMessage = nil
        }
    }

    // MARK: - Toplama

    private func update() {
        queue.async { [weak self] in
            guard let self else { return }
            let list = self.collect()
            DispatchQueue.main.async {
                self.processes = list
            }
        }
    }

    private func collect() -> [ProcessData] {
        let pids = Self.allPIDs()
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = previousUptime > 0 ? now - previousUptime : interval

        var newPrev: [pid_t: UInt64] = [:]
        var result: [ProcessData] = []
        result.reserveCapacity(pids.count)

        for pid in pids where pid > 0 {
            // Okuyamadığımız süreçleri (yetki yok / yok olmuş) atla.
            guard let info = Self.taskInfo(pid) else { continue }

            let cpuTime = info.pti_total_user + info.pti_total_system   // ns
            newPrev[pid] = cpuTime

            var cpuPercent = 0.0
            if let prev = previousCPU[pid], elapsed > 0 {
                let delta = cpuTime >= prev ? cpuTime - prev : 0
                cpuPercent = Double(delta) / 1_000_000_000.0 / elapsed * 100.0
            }

            // Ad/yol/kullanıcı sabittir → ilk görüşte çöz, sonra önbellekten al.
            let info3: (name: String, path: String, user: String)
            if let cached = infoCache[pid] {
                info3 = cached
            } else {
                let (name, path) = Self.nameAndPath(pid)
                let resolved = (name: name, path: path, user: username(for: pid))
                infoCache[pid] = resolved
                info3 = resolved
            }

            result.append(ProcessData(pid: pid,
                                      name: info3.name,
                                      cpuUsage: cpuPercent,
                                      memoryUsage: info.pti_resident_size,
                                      user: info3.user,
                                      path: info3.path))
        }

        previousCPU = newPrev
        previousUptime = now
        infoCache = infoCache.filter { newPrev[$0.key] != nil }   // ölmüş süreçleri at

        result.sort { $0.cpuUsage > $1.cpuUsage }
        return result
    }

    // MARK: - libproc yardımcıları

    private static func allPIDs() -> [pid_t] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: Int(count) + 32)   // büyümeye karşı pay
        let bufferSize = Int32(pids.count * MemoryLayout<pid_t>.stride)
        let returned = pids.withUnsafeMutableBytes { ptr in
            proc_listallpids(ptr.baseAddress, bufferSize)
        }
        guard returned > 0 else { return [] }
        return Array(pids.prefix(Int(returned)))
    }

    private static func taskInfo(_ pid: pid_t) -> proc_taskinfo? {
        var info = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size)
        return result == size ? info : nil
    }

    private static func nameAndPath(_ pid: pid_t) -> (name: String, path: String) {
        // PROC_PIDPATHINFO_MAXSIZE makrosu Swift'e aktarılamıyor → 4*MAXPATHLEN (4096).
        var pathBuffer = [CChar](repeating: 0, count: 4096)
        let len = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        let path = len > 0 ? String(cString: pathBuffer) : ""

        var name = (path as NSString).lastPathComponent
        if name.isEmpty {
            var nameBuffer = [CChar](repeating: 0, count: 256)
            proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            name = String(cString: nameBuffer)
        }
        if name.isEmpty { name = "PID \(pid)" }
        return (name, path)
    }

    private func username(for pid: pid_t) -> String {
        var bsd = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, size) == size else { return "" }

        let uid = bsd.pbi_uid
        if let cached = userCache[uid] { return cached }

        var name = ""
        if let pw = getpwuid(uid) {
            name = String(cString: pw.pointee.pw_name)
        }
        userCache[uid] = name
        return name
    }
}
