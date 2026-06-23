import Foundation

/// Groq REST istemcisi (OpenAI-uyumlu API: https://api.groq.com/openai/v1).
struct GroqClient {
    private let baseURL = URL(string: "https://api.groq.com/openai/v1")!
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Modeller

    /// Anahtarın erişebildiği model kimliklerini döndürür (sohbet dışı modeller elenir).
    func listModels() async throws -> [String] {
        var request = URLRequest(url: baseURL.appendingPathComponent("models"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try Self.validate(response, data: data)

        let decoded = try JSONDecoder().decode(ModelListResponse.self, from: data)
        return decoded.data
            .map(\.id)
            .filter { !$0.contains("whisper") && !$0.contains("tts") }   // ses modellerini ele
            .sorted()
    }

    // MARK: - Sohbet

    /// Verilen konuşmayı gönderir ve asistan yanıtının metnini döndürür.
    /// Düşük `temperature` → daha tutarlı, daha az savruk yanıt.
    func chat(model: String, messages: [GroqMessage], maxTokens: Int = 1024, temperature: Double = 0.3) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(model: model, messages: messages, max_tokens: maxTokens, temperature: temperature)
        )

        let (data, response) = try await session.data(for: request)
        try Self.validate(response, data: data)

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw GroqError.emptyResponse
        }
        return content
    }

    // MARK: - Yardımcı

    private static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw GroqError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(GroqErrorResponse.self, from: data))?.error.message
            throw GroqError.http(status: http.statusCode, message: message)
        }
    }
}

// MARK: - Genel tipler

/// Sohbet mesajı (role: "system" | "user" | "assistant").
struct GroqMessage: Codable {
    let role: String
    let content: String
}

enum GroqError: LocalizedError {
    case invalidResponse
    case emptyResponse
    case http(status: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Geçersiz sunucu yanıtı."
        case .emptyResponse:
            return "Boş yanıt alındı."
        case .http(let status, let message):
            switch status {
            case 401: return "Geçersiz API anahtarı (401). Anahtarı kontrol edin."
            case 429: return "İstek limiti aşıldı (429). Biraz bekleyip tekrar deneyin."
            default:  return message ?? "Sunucu hatası (\(status))."
            }
        }
    }
}

// MARK: - Dahili Codable yapıları

private struct ChatRequest: Codable {
    let model: String
    let messages: [GroqMessage]
    let max_tokens: Int
    let temperature: Double
}

private struct ChatResponse: Codable {
    struct Choice: Codable { let message: GroqMessage }
    let choices: [Choice]
}

private struct ModelListResponse: Codable {
    struct Model: Codable { let id: String }
    let data: [Model]
}

private struct GroqErrorResponse: Codable {
    struct APIError: Codable { let message: String }
    let error: APIError
}
