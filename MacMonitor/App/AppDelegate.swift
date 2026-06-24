import AppKit
import SwiftUI
import Combine

/// SwiftUI WindowGroup penceresini AppKit tarafından yeniden açmak için paylaşılan köprü.
final class WindowCoordinator {
    static let shared = WindowCoordinator()
    /// Ana pencereyi açan kapanış (RootView tarafından atanır).
    var open: (() -> Void)?
    private init() {}
}

/// Menü bar (NSStatusItem + popover) yönetimi ve uygulama yaşam döngüsü.
final class AppDelegate: NSObject, NSApplicationDelegate {

    // Menü bar / popover için izlenen monitörler (pencere ile aynı paylaşılan örnekler).
    private let cpuMonitor = SystemMonitors.shared.cpu
    private let memoryMonitor = SystemMonitors.shared.memory
    private let processMonitor = SystemMonitors.shared.process

    private var statusItem: NSStatusItem?

    /// Menü çubuğu ikonu bir kez üretilir (her ölçümde yeniden NSImage yaratmamak için).
    private lazy var gaugeImage: NSImage? = {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let image = NSImage(systemSymbolName: "gauge.with.dots.needle.bottom.50percent",
                            accessibilityDescription: t("Sistem yükü", "System load"))?
            .withSymbolConfiguration(config)
        image?.isTemplate = true   // menü çubuğu rengine uyar
        return image
    }()

    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Yaşam döngüsü

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        setupAppIcon()
        setupPopover()
        setupStatusItem()
        observeMonitors()
        refreshStatusItem()
    }

    /// Uygulama (Dock) logosu: gradyanlı yuvarlak kare + ortada beyaz gösterge simgesi.
    private func setupAppIcon() {
        let side: CGFloat = 256
        let icon = NSImage(size: NSSize(width: side, height: side))
        icon.lockFocus()

        // Gradyanlı yuvarlak kare arka plan (mavi → indigo)
        let bg = NSRect(x: 18, y: 18, width: side - 36, height: side - 36)
        NSGradient(colors: [.systemBlue, .systemIndigo])?
            .draw(in: NSBezierPath(roundedRect: bg, xRadius: 56, yRadius: 56), angle: -90)

        // Ortada beyaz gösterge simgesi
        let config = NSImage.SymbolConfiguration(pointSize: 150, weight: .semibold)
        if let symbol = NSImage(systemSymbolName: "gauge.with.dots.needle.bottom.50percent",
                                accessibilityDescription: "MacMonitor")?
            .withSymbolConfiguration(config) {
            let white = Self.tintedWhite(symbol)
            let g: CGFloat = 150
            white.draw(in: NSRect(x: (side - g) / 2, y: (side - g) / 2, width: g, height: g))
        }

        icon.unlockFocus()
        NSApp.applicationIconImage = icon
    }

    /// Bir simgeyi beyaza boyar (yalın bağlamda sourceAtop ile yalnızca simge piksellerini).
    private static func tintedWhite(_ image: NSImage) -> NSImage {
        let out = NSImage(size: image.size)
        out.lockFocus()
        let rect = NSRect(origin: .zero, size: image.size)
        image.draw(in: rect, from: rect, operation: .sourceOver, fraction: 1)
        NSColor.white.set()
        rect.fill(using: .sourceAtop)
        out.unlockFocus()
        return out
    }

    /// Son pencere kapansa bile uygulamayı çalışır durumda tut (menü bar widget'ı için).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Kurulum

    private func setupPopover() {
        popover.behavior = .transient
        let hosting = NSHostingController(
            rootView: MenuBarView(
                cpuMonitor: cpuMonitor,
                memoryMonitor: memoryMonitor,
                processMonitor: processMonitor,
                onOpen: { [weak self] in
                    self?.popover.performClose(nil)
                    self?.openMainWindow()
                }
            )
        )
        // Popover'ı SwiftUI içeriğinin gerçek boyutuna göre ayarla (sabit 200 px taşırıyordu).
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        item.button?.imagePosition = .imageLeading
        item.button?.image = gaugeImage   // ikon sabit; bir kez ayarla
        statusItem = item
    }

    private func observeMonitors() {
        // CPU veya RAM değiştikçe menü bar başlığını/rengini güncelle.
        cpuMonitor.$totalUsage
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshStatusItem() }
            .store(in: &cancellables)

        memoryMonitor.$memory
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshStatusItem() }
            .store(in: &cancellables)
    }

    // MARK: - Menü bar görünümü

    private func refreshStatusItem() {
        guard let button = statusItem?.button else { return }

        let cpu = cpuMonitor.totalUsage
        let mem = memoryMonitor.memory
        let ram = mem.total > 0 ? Double(mem.used) / Double(mem.total) * 100 : 0
        let load = max(cpu, ram)

        // Renk: gri = normal, sarı > %70, kırmızı > %90.
        let color: NSColor
        if load > 90 {
            color = .systemRed
        } else if load > 70 {
            color = .systemYellow
        } else {
            color = .secondaryLabelColor   // karanlık/aydınlık moda uyumlu gri
        }

        // İkon setupStatusItem'da bir kez ayarlandı (her ölçümde yeniden üretilmez).
        // Kısa biçim (dolgu yok → menü çubuğunda taşmaz). Monospaced rakam, hafif kaymayı azaltır.
        let title = String(format: " %.0f%% / %.0f%%", cpu, ram)
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            ]
        )
    }

    // MARK: - Eylemler

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    /// Ana pencereyi öne getirir; kapatılmışsa SwiftUI üzerinden yeniden açar.
    func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        // Zaten açık bir ana pencere varsa öne getir (popover penceresi canBecomeMain değildir).
        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Pencere kapatılıp yok edildiyse WindowGroup'tan yenisini aç.
        WindowCoordinator.shared.open?()
    }
}
