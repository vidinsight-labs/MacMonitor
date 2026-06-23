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

    /// Uygulama (Dock) ikonu olarak basit bir gösterge SF Symbol'ü kullan.
    private func setupAppIcon() {
        let config = NSImage.SymbolConfiguration(pointSize: 128, weight: .regular)
        if let icon = NSImage(systemSymbolName: "gauge.with.dots.needle.bottom.50percent",
                              accessibilityDescription: "MacMonitor")?
            .withSymbolConfiguration(config) {
            NSApp.applicationIconImage = icon
        }
    }

    /// Son pencere kapansa bile uygulamayı çalışır durumda tut (menü bar widget'ı için).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Kurulum

    private func setupPopover() {
        popover.contentSize = NSSize(width: 300, height: 200)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
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
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        item.button?.imagePosition = .imageLeading
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

        if let image = NSImage(systemSymbolName: "gauge.with.dots.needle.bottom.50percent",
                               accessibilityDescription: "Sistem yükü") {
            image.isTemplate = true
            button.image = image
        }
        button.contentTintColor = color

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
