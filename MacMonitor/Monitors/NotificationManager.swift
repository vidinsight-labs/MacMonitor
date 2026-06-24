import Foundation
import Combine
import UserNotifications

/// Proaktif bildirimler — uygulama açık olmasa da (menü çubuğunda çalışırken) işlemci, bellek,
/// disk veya ısı **kritik seviyede bir süre kalırsa** kullanıcıyı uyarır.
///
/// Tasarım: yalnızca kritik durum **sürerse** (anlık sıçramalar değil) ve her metrik için
/// **bekleme süresiyle** (spam olmaması için) bildirim gönderilir.
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    /// Açık/kapalı (kalıcı). Değiştirildiğinde izin ister / izlemeyi durdurur.
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: Self.key)
            if enabled { requestAuthorizationAndStart() } else { stop() }
        }
    }

    /// Kullanıcı sistem iznini reddettiyse (arayüzde bilgilendirmek için).
    @Published private(set) var authorizationDenied = false

    private static let key = "notificationsEnabled"

    private let cpu: CPUMonitor
    private let memory: MemoryMonitor
    private let systemInfo: SystemInfoMonitor
    private let process: ProcessMonitor

    private var cancellable: AnyCancellable?

    private enum Metric: String, CaseIterable { case cpu, ram, disk, temp }
    private var criticalSince: [Metric: Date] = [:]
    private var lastNotified: [Metric: Date] = [:]

    private let sustain: TimeInterval = 60      // kritik en az 1 dk sürmeli
    private let cooldown: TimeInterval = 1_800  // aynı uyarı 30 dk'da bir

    init(cpu: CPUMonitor, memory: MemoryMonitor,
         systemInfo: SystemInfoMonitor, process: ProcessMonitor) {
        self.cpu = cpu
        self.memory = memory
        self.systemInfo = systemInfo
        self.process = process
        self.enabled = UserDefaults.standard.bool(forKey: Self.key)
        super.init()
        UNUserNotificationCenter.current().delegate = self
        if enabled { verifyAuthorizationThenStart() }   // izin hâlâ geçerli mi? (sonradan kapatılmış olabilir)
    }

    /// Açılışta: sistemdeki güncel izni kontrol et; reddedilmişse arayüzde göster, izlemeyi başlatma.
    private func verifyAuthorizationThenStart() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self else { return }
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    self.authorizationDenied = false
                    self.start()
                case .denied:
                    self.authorizationDenied = true
                case .notDetermined:
                    self.requestAuthorizationAndStart()
                @unknown default:
                    self.start()
                }
            }
        }
    }

    // MARK: - İzin / izleme

    func requestAuthorizationAndStart() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if granted {
                    self.authorizationDenied = false
                    self.start()
                } else {
                    self.authorizationDenied = true
                    self.enabled = false
                }
            }
        }
    }

    private func start() {
        guard cancellable == nil else { return }
        // CPU monitörü düzenli yayın yapar (~1-2 sn); her güncellemede tüm metrikleri değerlendir.
        cancellable = cpu.$totalUsage
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.evaluate() }
    }

    private func stop() {
        cancellable?.cancel()
        cancellable = nil
        criticalSince.removeAll()
    }

    // MARK: - Değerlendirme

    private func evaluate() {
        check(.cpu,  critical: cpu.totalUsage >= 90)
        check(.ram,  critical: memory.pressure == .critical)
        check(.disk, critical: diskPercent >= 90)
        check(.temp, critical: systemInfo.thermalState == .serious || systemInfo.thermalState == .critical)
    }

    private func check(_ metric: Metric, critical: Bool) {
        let now = Date()
        guard critical else { criticalSince[metric] = nil; return }

        if criticalSince[metric] == nil { criticalSince[metric] = now }
        guard let since = criticalSince[metric], now.timeIntervalSince(since) >= sustain else { return }
        if let last = lastNotified[metric], now.timeIntervalSince(last) < cooldown { return }

        lastNotified[metric] = now
        post(metric)
    }

    private var diskPercent: Int { Int(systemInfo.diskUsedPercent) }   // tek kaynak

    // MARK: - Bildirim gönder

    private func post(_ metric: Metric) {
        let content = UNMutableNotificationContent()
        content.sound = .default

        switch metric {
        case .cpu:
            content.title = t("İşlemci uzun süredir yüksek", "CPU has been high for a while")
            if let p = process.processes.first {
                content.body = t("Şu an %\(Int(cpu.totalUsage.rounded())) · en çok \(p.name) kullanıyor.", "Currently \(Int(cpu.totalUsage.rounded()))% · \(p.name) is using the most.")
            } else {
                content.body = t("Şu an %\(Int(cpu.totalUsage.rounded())). Ağır uygulamaları azaltmayı düşün.", "Currently \(Int(cpu.totalUsage.rounded()))%. Consider reducing heavy apps.")
            }
        case .ram:
            content.title = t("Bellek baskı altında", "Memory under pressure")
            content.body = t("Gereksiz uygulamaları kapatmak sistemi rahatlatır.", "Closing unnecessary apps eases the system.")
        case .disk:
            content.title = t("Disk neredeyse dolu", "Disk is almost full")
            content.body = t("%\(diskPercent) dolu. Yer açmak yavaşlamayı önler.", "\(diskPercent)% full. Freeing up space prevents slowdowns.")
        case .temp:
            content.title = t("Cihaz çok ısındı", "Device is overheating")
            content.body = t("Performans düşebilir. Ağır işleri azaltıp serinlemesini bekle.", "Performance may drop. Reduce heavy tasks and let it cool down.")
        }

        let request = UNNotificationRequest(identifier: "macmonitor.\(metric.rawValue)",
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Uygulama önplandayken de bildirimi göster

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
