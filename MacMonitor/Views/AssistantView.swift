import SwiftUI

/// AI Asistan sayfası — Groq (kendi API anahtarınla) ile sohbet.
struct AssistantView: View {
    @EnvironmentObject private var assistant: AIAssistant

    @State private var apiKeyInput = ""
    @State private var inputText = ""

    var body: some View {
        VStack(spacing: 16) {
            PageHeader(
                icon: "sparkles",
                gradient: [.pink, .purple],
                title: "Asistan",
                subtitle: "Groq ile sistem analizi (kendi API anahtarın)"
            )

            if !assistant.hasAPIKey {
                setupCard
            } else {
                controlBar
                chatArea
                analyzeButton
                Text("İşlem ve sistem verisi, seçtiğin modele (Groq) gönderilir.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                inputBar
            }

            if let status = assistant.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            // Anahtar varsa modelleri otomatik yükle (her seferinde "Bağlan" gerekmesin).
            if assistant.hasAPIKey && assistant.models.isEmpty {
                Task { await assistant.testConnection() }
            }
        }
    }

    // MARK: - Kurulum (anahtar yok)

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(icon: "key.fill", title: "Groq API Anahtarı")

            Text("Anahtarın yalnızca bu Mac'in Keychain'inde saklanır. Ücretsiz anahtarı console.groq.com adresinden alabilirsin.")
                .font(.caption)
                .foregroundStyle(.secondary)

            SecureField("gsk_...", text: $apiKeyInput)
                .textFieldStyle(.roundedBorder)

            Button {
                assistant.saveAPIKey(apiKeyInput)
                apiKeyInput = ""
            } label: {
                Label("Kaydet", systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .card()
    }

    // MARK: - Üst çubuk (model + bağlan + menü)

    private var controlBar: some View {
        HStack(spacing: 12) {
            Picker("Model", selection: $assistant.selectedModel) {
                if assistant.models.isEmpty {
                    Text("Önce 'Bağlan'").tag("")
                } else {
                    ForEach(assistant.models, id: \.self) { Text($0).tag($0) }
                }
            }
            .labelsHidden()
            .frame(maxWidth: 300)

            Button {
                Task { await assistant.testConnection() }
            } label: {
                Label("Bağlan", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(assistant.isBusy)

            if assistant.isBusy {
                ProgressView().controlSize(.small)
            }

            Spacer()

            Menu {
                Button("Sohbeti Temizle") { assistant.clearConversation() }
                Button("Anahtarı Sil", role: .destructive) { assistant.clearAPIKey() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .card()
    }

    // MARK: - Sohbet alanı

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if assistant.messages.isEmpty {
                        Text("Bir soru yaz: \"Bilgisayarım neden yavaş?\" veya \"Bu işlem nedir?\"")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 30)
                    }
                    ForEach(assistant.messages) { item in
                        bubble(item)
                    }
                }
                .padding(8)
            }
            .onChange(of: assistant.messages.count) { _ in
                if let last = assistant.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    private func bubble(_ item: AIAssistant.ChatItem) -> some View {
        let isUser = item.role == .user
        return HStack {
            if isUser { Spacer(minLength: 40) }
            Text(item.text)
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isUser ? Color.accentColor.opacity(0.85) : Color.secondary.opacity(0.15))
                )
                .foregroundStyle(isUser ? .white : .primary)
            if !isUser { Spacer(minLength: 40) }
        }
        .id(item.id)
    }

    // MARK: - Sistemi analiz et

    private var analyzeButton: some View {
        Button {
            Task { await assistant.analyzeSystem() }
        } label: {
            Label("Sistemimi Analiz Et", systemImage: "stethoscope")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(assistant.isBusy || assistant.selectedModel.isEmpty)
    }

    // MARK: - Giriş çubuğu

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Mesaj…", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .onSubmit(sendNow)

            Button(action: sendNow) {
                if assistant.isBusy {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "paperplane.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(assistant.isBusy || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private func sendNow() {
        let text = inputText
        inputText = ""
        Task { await assistant.send(text) }
    }
}

#Preview {
    AssistantView()
        .environmentObject(AIAssistant())
        .frame(width: 640, height: 700)
}
