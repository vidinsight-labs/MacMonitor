import Foundation
import Combine

/// AI asistanı durumu: API anahtarı (Keychain), model listesi/seçimi, sohbet.
/// Yalnızca kullanıcı tetiklediğinde (test/gönder) ağ çağrısı yapar — arka planda çalışmaz.
@MainActor
final class AIAssistant: ObservableObject {

    /// Sohbet baloncuğu.
    struct ChatItem: Identifiable {
        enum Role { case user, assistant }
        let id = UUID()
        let role: Role
        let text: String
    }

    // MARK: - Yayınlanan durum

    @Published private(set) var hasAPIKey: Bool
    @Published var selectedModel: String = "" {
        didSet { UserDefaults.standard.set(selectedModel, forKey: modelDefaultsKey) }
    }
    @Published private(set) var models: [String] = []
    @Published private(set) var messages: [ChatItem] = []
    @Published private(set) var isBusy = false
    @Published private(set) var statusMessage: String?

    /// Türkçe/genel kalitede iyi olan, öncelik sıralı Groq modelleri.
    /// Yalnızca kullanıcının erişebildikleri listelenir; hiçbiri yoksa tüm modeller gösterilir.
    private let preferredModels = [
        "llama-3.3-70b-versatile",
        "moonshotai/kimi-k2-instruct",
        "openai/gpt-oss-120b",
        "deepseek-r1-distill-llama-70b",
        "qwen/qwen3-32b"
    ]

    /// Son seçilen modeli kalıcı tutar (yeniden açılışta hatırlanır).
    private let modelDefaultsKey = "groq.selectedModel"
    /// Modele gönderilen en fazla mesaj sayısı (token/bağlam taşmasını önler).
    private let maxHistory = 12

    private let systemPrompt = """
    Sen "MacMonitor" uygulamasının, DENEYİMLİ bir macOS sistem teknisyeni gibi \
    davranan asistanısın. Kullanıcının performans sorularını teknik doğrulukla, \
    ama anlaşılır Türkçeyle yanıtla. Sebep-sonuç kur: hangi metrik neyi gösterir, \
    neden önemli, ne yapılmalı.

    Değerlendirirken aşağıdaki durumları MUTLAKA göz önünde bulundur ve gerekiyorsa \
    proaktif öneride bulun:
    - Uzun açık kalma süresi (örn. birkaç gündür açıksa): bellek birikmesi/sızıntısı \
    olabilir; yeniden başlatma sistemi rahatlatabilir.
    - Termal durum "yüksek/kritik" veya sıcaklık yüksekse: sistem ısı nedeniyle \
    performansı kısıyor olabilir (throttling); ağır işleri azaltıp cihazı serinletmeyi öner.
    - Sürekli/aşırı yüksek CPU veya bellek yükü: sorumlu işlem(ler)i belirt; kapatma \
    veya optimize etme öner.
    - Yüksek takas (swap) veya bellek basıncı (Uyarı/Kritik): RAM yetersiz kalıyordur; \
    belleği temizleme veya uygulama kapatma öner.

    Kurallar:
    - YALNIZCA sana verilen sistem verilerine ve kullanıcının sorusuna dayan. \
    Elinde veri yoksa "bu bilgi elimde yok" de.
    - Var olmayan uygulama, özellik veya araç UYDURMA.
    - Sana verilen sayıları ve yüzdeleri OLDUĞU GİBİ kullan; kendin bölme/çarpma \
    yapıp değer/yüzde yeniden HESAPLAMA (hesap hatası yaparsın).
    - Teknik ama KISA ve NET ol; mümkünse madde madde. Gereksiz giriş cümlesi, \
    abartı veya tekrar kullanma. Doğru ve akıcı Türkçe yaz.
    - Riskli eylemleri (işlem kapatma, bellek temizleme, yeniden başlatma) sen \
    YAPAMAZSIN; yalnızca öner, uygulamayı kullanıcı yapar.
    """

    /// Anahtarın bellekteki kopyası — Keychain'i her işlemde tekrar okumamak için.
    private var cachedKey: String?

    init() {
        // Açılışta gizli veriye erişme (izin penceresi açma); sadece varlığını kontrol et.
        hasAPIKey = KeychainStore.exists()
        selectedModel = UserDefaults.standard.string(forKey: modelDefaultsKey) ?? ""
    }

    /// Anahtarı döndürür; ilk seferde Keychain'den okur (tek izin), sonra bellekten.
    private func currentKey() -> String? {
        if let cachedKey { return cachedKey }
        cachedKey = KeychainStore.read()
        return cachedKey
    }

    // MARK: - API anahtarı

    func saveAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        KeychainStore.save(trimmed)
        cachedKey = trimmed
        hasAPIKey = true
        statusMessage = "Anahtar kaydedildi. 'Bağlan' ile test edebilirsiniz."
    }

    func clearAPIKey() {
        KeychainStore.delete()
        cachedKey = nil
        hasAPIKey = false
        models = []
        selectedModel = ""
        statusMessage = "Anahtar silindi."
    }

    // MARK: - Bağlantı testi + model listesi

    func testConnection() async {
        guard let key = currentKey() else {
            statusMessage = "Önce API anahtarı girin."
            return
        }
        isBusy = true
        statusMessage = "Bağlanılıyor…"
        defer { isBusy = false }

        do {
            let all = try await GroqClient(apiKey: key).listModels()
            let curated = preferredModels.filter { all.contains($0) }
            models = curated.isEmpty ? all : curated   // önerilenler varsa yalnızca onlar

            if selectedModel.isEmpty || !models.contains(selectedModel) {
                selectedModel = models.first ?? ""   // en üst öncelikli = önerilen
            }

            if models.isEmpty {
                statusMessage = "Bağlanıldı ama model bulunamadı."
            } else if curated.isEmpty {
                statusMessage = "Bağlandı. (Önerilen model bulunamadı; tüm modeller listelendi.)"
            } else {
                statusMessage = "Bağlandı. Önerilen model seçildi: \(selectedModel)"
            }
        } catch {
            statusMessage = "Hata: \(error.localizedDescription)"
        }
    }

    // MARK: - Mesaj gönder

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let key = currentKey() else {
            statusMessage = "Önce API anahtarı girin."
            return
        }
        guard !selectedModel.isEmpty else {
            statusMessage = "Önce bir model seçin ('Bağlan')."
            return
        }

        messages.append(ChatItem(role: .user, text: trimmed))
        isBusy = true
        statusMessage = nil
        defer { isBusy = false }

        var conversation: [GroqMessage] = [GroqMessage(role: "system", content: liveSystemPrompt())]
        conversation += messages.suffix(maxHistory).map {
            GroqMessage(role: $0.role == .user ? "user" : "assistant", content: $0.text)
        }

        do {
            let reply = try await GroqClient(apiKey: key).chat(model: selectedModel, messages: conversation)
            messages.append(ChatItem(role: .assistant, text: reply))
        } catch {
            statusMessage = "Hata: \(error.localizedDescription)"
        }
    }

    /// Yönerge + güncel gerçek sistem durumunu birleştirir (her mesajda taze).
    private func liveSystemPrompt() -> String {
        systemPrompt + "\n\nGüncel sistem durumu (gerçek veriler):\n" + SystemContext.snapshot()
    }

    /// Anlık sistem durumunu bağlam olarak gönderip teşhis ister.
    func analyzeSystem() async {
        guard let key = currentKey() else {
            statusMessage = "Önce API anahtarı girin."
            return
        }
        guard !selectedModel.isEmpty else {
            statusMessage = "Önce bir model seçin ('Bağlan')."
            return
        }

        messages.append(ChatItem(role: .user, text: "📊 Sistemimi analiz et"))
        isBusy = true
        statusMessage = nil
        defer { isBusy = false }

        // Güncel sistem durumu zaten liveSystemPrompt içinde; burada yalnızca teşhis isteniyor.
        var conversation: [GroqMessage] = [GroqMessage(role: "system", content: liveSystemPrompt())]
        conversation += messages.dropLast().suffix(maxHistory).map {
            GroqMessage(role: $0.role == .user ? "user" : "assistant", content: $0.text)
        }
        conversation.append(GroqMessage(role: "user", content: "Güncel sistem verilerine göre: sistemi yavaşlatan veya zorlayan bir şey var mı? Varsa hangi işlem/kaynak sorumlu ve ne öneriyorsun? Kısa, net, madde madde. Verilerde olmayan işlem/uygulama adı UYDURMA."))

        do {
            let reply = try await GroqClient(apiKey: key).chat(model: selectedModel, messages: conversation, maxTokens: 1200)
            messages.append(ChatItem(role: .assistant, text: reply))
        } catch {
            statusMessage = "Hata: \(error.localizedDescription)"
        }
    }

    func clearConversation() {
        messages.removeAll()
        statusMessage = nil
    }
}
