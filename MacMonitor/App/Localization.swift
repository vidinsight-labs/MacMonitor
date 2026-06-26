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
        if let saved = UserDefaults.standard.string(forKey: Self.key),
           let lang = AppLanguage(rawValue: saved) {
            language = lang
        } else {
            language = .tr   // varsayılan: Türkçe
        }
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
    @Namespace private var selection

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(t("Dil", "Language"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "globe")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 0) {
                langButton(.tr, label: "TR")
                langButton(.en, label: "EN")
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
            )
        }
        .help(t("Arayüz dili", "Interface language"))
    }

    private func langButton(_ lang: AppLanguage, label: String) -> some View {
        let selected = loc.language == lang

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                loc.language = lang
            }
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .foregroundStyle(selected ? Color.white : Color.secondary)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(BrandColors.vidinsight)
                            .matchedGeometryEffect(id: "langSel", in: selection)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
