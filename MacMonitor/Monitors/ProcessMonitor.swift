import Foundation
import Darwin
import AppKit

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

    /// En az bir kez toplama tamamlandı mı (boş liste vs yükleniyor ayrımı).
    @Published private(set) var hasCompletedUpdate = false

    /// Sandbox'ta yalnızca kullanıcı uygulamaları listelenir; tam libproc listesi değil.
    @Published private(set) var isLimitedList = false

    /// Zorla kapatma sonrası kullanıcıya gösterilecek geçici geri bildirim (metin + hata mı).
    @Published private(set) var actionFeedback: ActionFeedback?

    /// Zorla kapatma geri bildirimi — başarı/hata ayrımı metinden değil bu bayraktan okunur
    /// (dilden bağımsız; EN modunda da doğru renk/ikon).
    struct ActionFeedback: Equatable {
        let text: String
        let isError: Bool
    }

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

    /// Seçili süreçleri sonlandırır (sandbox: NSRunningApplication.terminate).
    func forceQuit(_ pids: Set<pid_t>) {
        guard !pids.isEmpty else { return }

        var succeeded = 0
        var failed: [String] = []

        for pid in pids {
            let proc = processes.first(where: { $0.pid == pid })
            let name = proc?.name ?? "PID \(pid)"

            if let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated {
                if app.terminate() {
                    succeeded += 1
                } else {
                    failed.append(name)
                }
            } else if kill(pid, SIGTERM) == 0 {
                succeeded += 1
            } else {
                failed.append(name)
            }
        }

        let message: String
        if failed.isEmpty {
            message = succeeded == 1
                ? t("İşlem sonlandırıldı.", "Process terminated.")
                : t("\(succeeded) işlem sonlandırıldı.", "\(succeeded) processes terminated.")
        } else if succeeded == 0 {
            message = t("\(failed.joined(separator: ", ")) kapatılamadı — sistem süreçleri korunur.",
                        "\(failed.joined(separator: ", ")) could not be closed — system processes are protected.")
        } else {
            message = t("\(succeeded) işlem kapatıldı; \(failed.joined(separator: ", ")) için yetki gerekiyor.",
                        "\(succeeded) closed; permission required for \(failed.joined(separator: ", ")).")
        }
        setActionMessage(message, isError: !failed.isEmpty)
        update()
    }

    /// Mesajı yayınlar ve ~4 sn sonra (yeni mesaj gelmediyse) temizler.
    private func setActionMessage(_ message: String, isError: Bool) {
        messageToken += 1
        let token = messageToken
        actionFeedback = ActionFeedback(text: message, isError: isError)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.messageToken == token else { return }
            self.actionFeedback = nil
        }
    }

    // MARK: - Toplama

    private func update() {
        queue.async { [weak self] in
            guard let self else { return }
            let list = self.collect()
            DispatchQueue.main.async {
                self.processes = list
                self.hasCompletedUpdate = true
                self.isLimitedList = Self.isSandboxed
            }
        }
    }

    private func collect() -> [ProcessData] {
        let runningApps = Self.runningApplicationsByPID()
        var pidSet = Set(Self.allPIDs().filter { $0 > 0 })
        if Self.isSandboxed || pidSet.isEmpty {
            pidSet.formUnion(runningApps.keys)
        }

        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = previousUptime > 0 ? now - previousUptime : interval

        var newPrev: [pid_t: UInt64] = [:]
        var result: [ProcessData] = []
        result.reserveCapacity(pidSet.count)

        for pid in pidSet {
            let task = Self.taskInfo(pid)
            let app = runningApps[pid]

            if task == nil && app == nil && !Self.canResolveName(pid) {
                continue
            }

            let cpuTime = task.map { $0.pti_total_user + $0.pti_total_system } ?? 0
            if cpuTime > 0 { newPrev[pid] = cpuTime }

            var cpuPercent = 0.0
            if let prev = previousCPU[pid], elapsed > 0, cpuTime > 0 {
                let delta = cpuTime >= prev ? cpuTime - prev : 0
                cpuPercent = Double(delta) / 1_000_000_000.0 / elapsed * 100.0
            }

            let info3: (name: String, path: String, user: String)
            if let cached = infoCache[pid] {
                info3 = cached
            } else if let app {
                let resolved = (
                    name: app.localizedName ?? app.bundleIdentifier ?? "PID \(pid)",
                    path: app.bundleURL?.path ?? "",
                    user: NSUserName()
                )
                infoCache[pid] = resolved
                info3 = resolved
            } else {
                let (name, path) = Self.nameAndPath(pid)
                let resolved = (name: name, path: path, user: username(for: pid))
                infoCache[pid] = resolved
                info3 = resolved
            }

            result.append(ProcessData(pid: pid,
                                      name: info3.name,
                                      cpuUsage: cpuPercent,
                                      memoryUsage: task?.pti_resident_size ?? 0,
                                      user: info3.user,
                                      path: info3.path))
        }

        previousCPU = newPrev
        previousUptime = now
        infoCache = infoCache.filter { pidSet.contains($0.key) }

        result.sort { $0.cpuUsage > $1.cpuUsage }
        return result
    }

    // MARK: - Sandbox / NSWorkspace

    private static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    private static func runningApplicationsByPID() -> [pid_t: NSRunningApplication] {
        Dictionary(
            uniqueKeysWithValues: NSWorkspace.shared.runningApplications
                .filter { !$0.isTerminated }
                .map { ($0.processIdentifier, $0) }
        )
    }

    /// proc_name ile en azından ad çözülebiliyor mu?
    private static func canResolveName(_ pid: pid_t) -> Bool {
        var nameBuffer = [CChar](repeating: 0, count: 256)
        guard proc_name(pid, &nameBuffer, UInt32(nameBuffer.count)) == 0 else { return false }
        let name = String(cString: nameBuffer)
        return !name.isEmpty
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
