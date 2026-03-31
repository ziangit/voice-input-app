import Foundation

enum LLMError: Error {
    case notConfigured
    case httpError(Int)
    case invalidResponse
    case apiError(String)
}

private struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }
    let model: String
    let messages: [Message]
    let max_tokens: Int
    let temperature: Double
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }
    struct APIError: Decodable {
        struct Detail: Decodable { let message: String }
        let error: Detail
    }
    let choices: [Choice]?
}

private struct APIErrorResponse: Decodable {
    struct Detail: Decodable { let message: String }
    let error: Detail
}

final class LLMRefiner {

    private let systemPrompt = """
    You are a speech-recognition post-processing assistant. \
    Your task is to fix only obvious recognition errors in the transcribed text. \
    Rules:
    - Fix obvious Chinese homophone errors (同音字错误).
    - Fix English technical terms incorrectly converted to Chinese \
      (e.g. "配森" → "Python", "杰森" → "JSON", "阿皮" → "API", "基特" → "Git").
    - If the text already looks correct, return it exactly as-is.
    - NEVER rewrite, rephrase, polish, expand, or remove content that appears correct.
    - Output only the corrected text with no explanation or extra characters.
    """

    func refine(text: String) async throws -> String {
        let prefs = Preferences.shared
        guard prefs.llmConfigured else { throw LLMError.notConfigured }

        let baseURL = prefs.llmAPIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey  = prefs.llmAPIKey
        let model   = prefs.llmModel.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: baseURL + "/chat/completions") else {
            throw LLMError.notConfigured
        }

        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user",   content: text)
            ],
            max_tokens: 1024,
            temperature: 0
        )
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if let errResp = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw LLMError.apiError(errResp.error.message)
            }
            throw LLMError.httpError(http.statusCode)
        }

        let parsed = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = parsed.choices?.first?.message.content else {
            throw LLMError.invalidResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Lightweight connectivity test — returns the model's reply or throws.
    func test() async throws -> String {
        return try await refine(text: "Hello")
    }
}
