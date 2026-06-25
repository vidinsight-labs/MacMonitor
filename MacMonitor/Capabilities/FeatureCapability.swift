import Foundation

/// Uygulama özelliklerinin sandbox/App Store kısıtları altında kullanılabilirliği.
enum AppFeature: String, CaseIterable {
    case memoryPurge
    case fanSMC
    case processForceQuit
    case diskFolderScan
    case emptyTrash
    case fullHardwareProfile
}

/// Özellik kullanılabilirlik durumu ve kullanıcıya gösterilecek açıklama.
struct FeatureAvailability {
    let available: Bool
    let reasonTR: String
    let reasonEN: String

    var reason: String { t(reasonTR, reasonEN) }
}

enum FeatureCapability {

    static func availability(for feature: AppFeature) -> FeatureAvailability {
        switch feature {
        case .memoryPurge:
            return FeatureAvailability(
                available: false,
                reasonTR: "App Store güvenlik kısıtları nedeniyle bellek temizleme (purge) kullanılamaz. Gerekiyorsa cihazı yeniden başlatın.",
                reasonEN: "Memory purge is unavailable due to App Store security restrictions. Restart the device if needed."
            )
        case .fanSMC:
            let smcWorks = FanMonitor.smcAccessibleInSandbox
            return FeatureAvailability(
                available: smcWorks,
                reasonTR: smcWorks
                    ? "Fan ve SMC sıcaklık verisi okunuyor."
                    : "Fan/SMC sensörleri App Store sandbox'ında okunamıyor. Termal durum Sistem sekmesinden izlenebilir.",
                reasonEN: smcWorks
                    ? "Fan and SMC temperature data is available."
                    : "Fan/SMC sensors cannot be read in the App Store sandbox. Thermal state is available on the System tab."
            )
        case .processForceQuit:
            return FeatureAvailability(
                available: true,
                reasonTR: "Yalnızca kullanıcı uygulamaları sonlandırılabilir; sistem süreçleri korunur.",
                reasonEN: "Only user applications can be terminated; system processes are protected."
            )
        case .diskFolderScan:
            return FeatureAvailability(
                available: true,
                reasonTR: "Klasör boyutları yalnızca erişilebilir konumlarda hesaplanır.",
                reasonEN: "Folder sizes are calculated only in accessible locations."
            )
        case .emptyTrash:
            return FeatureAvailability(
                available: false,
                reasonTR: "Çöp kutusunu boşaltma App Store sandbox'ında kullanılamaz. Finder'dan manuel boşaltın.",
                reasonEN: "Emptying Trash is unavailable in the App Store sandbox. Empty it manually from Finder."
            )
        case .fullHardwareProfile:
            return FeatureAvailability(
                available: true,
                reasonTR: "Temel donanım bilgileri sysctl ve IOKit ile okunur (tam system_profiler profili değil).",
                reasonEN: "Basic hardware info is read via sysctl and IOKit (not a full system_profiler report)."
            )
        }
    }
}
