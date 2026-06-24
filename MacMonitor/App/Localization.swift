import SwiftUI
import Combine

/// Uygulama dili.
enum AppLanguage: String {
    case tr
    case en
}

/// Seçili dili tutar (kalıcı) ve değişince tüm gözlemleyen görünümleri yeniler.
/// Canlı geçiş: kullanıcı düğmeye basınca uygulama yeniden başlamadan dil değişir.
final class Localizer: ObservableObject {
    static let shared = Localizer()

    @Published var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.key) }
    }

    private static let key = "appLanguage"

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.key)
        language = AppLanguage(rawValue: saved ?? "") ?? .tr
    }
}

/// Seçili dile göre metin döndürür. SwiftUI görünüm gövdesinde çağrıldığında, görünüm
/// `Localizer.shared`'ı gözlemlediği sürece dil değişince yeniden hesaplanır.
///
///     Text(t("İşlemci", "Processor"))
func t(_ tr: String, _ en: String) -> String {
    Localizer.shared.language == .en ? en : tr
}

/// Kenar çubuğu altındaki TR/EN değiştirici.
struct LanguageToggle: View {
    @ObservedObject private var loc = Localizer.shared

    var body: some View {
        Picker("", selection: $loc.language) {
            Text("TR").tag(AppLanguage.tr)
            Text("EN").tag(AppLanguage.en)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .help(t("Arayüz dili", "Interface language"))
    }
}
