import SwiftUI

/// Uygulama giriş noktası.
/// Normal pencereli bir uygulama olarak açılır; menü bar widget'ı `AppDelegate` tarafından
/// (NSStatusItem ile) yönetilir.
@main
struct MacMonitorApp: App {
    // AppDelegate'i SwiftUI yaşam döngüsüne bağlar (menü bar + pencere kapanınca açık kalma).
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
        }
        .windowResizability(.contentMinSize)
    }
}

/// Ana pencere içeriği. Menü bar'daki "Aç" düğmesinin pencereyi yeniden açabilmesi için
/// SwiftUI'nin `openWindow` eylemini yakalayıp `WindowCoordinator` üzerinden paylaşır.
private struct RootView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MainView()
            .environmentObject(SystemMonitors.shared.cpu)
            .environmentObject(SystemMonitors.shared.memory)
            .environmentObject(SystemMonitors.shared.fan)
            .environmentObject(SystemMonitors.shared.process)
            .environmentObject(SystemMonitors.shared.loadEvents)
            .environmentObject(SystemMonitors.shared.systemInfo)
            .environmentObject(SystemMonitors.shared.security)
            .environmentObject(SystemMonitors.shared.notifications)
            .environmentObject(SystemMonitors.shared.smartInsights)
            .onAppear {
                WindowCoordinator.shared.open = { openWindow(id: "main") }
            }
    }
}
