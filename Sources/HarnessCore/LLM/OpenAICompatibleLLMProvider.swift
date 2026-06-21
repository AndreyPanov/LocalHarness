import Foundation

final class OpenAICompatibleLLMProvider: LLMProvider {
    private let baseURL: URL
    private let session: URLSession

    init(
        baseURL: URL = URL(string: "http://127.0.0.1:8081/v1")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func complete(_ request: LLMRequest) async throws -> String {
        let url = baseURL.appendingPathComponent("chat/completions")
        let body = OpenAIChatRequest(
            model: request.model,
            messages: [
                .init(role: "system", content: request.systemPrompt),
                .init(role: "user", content: request.userPrompt)
            ],
            temperature: request.temperature,
            maxTokens: request.maxTokens,
            stream: false
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: urlRequest)
        let responseBody = String(data: data, encoding: .utf8) ?? ""

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HarnessError.llmRequestFailed(statusCode: nil, body: responseBody)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HarnessError.llmRequestFailed(
                statusCode: httpResponse.statusCode,
                body: responseBody
            )
        }

        let decoded: OpenAIChatResponse

        do {
            decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        } catch {
            throw HarnessError.llmRequestFailed(
                statusCode: httpResponse.statusCode,
                body: responseBody
            )
        }

        guard let content = decoded.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw HarnessError.llmRequestFailed(
                statusCode: httpResponse.statusCode,
                body: responseBody
            )
        }

        return content
    }
}

private struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIChatMessage]
    let temperature: Double
    let maxTokens: Int?
    let stream: Bool

    private enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case stream
    }
}

private struct OpenAIChatMessage: Codable {
    let role: String
    let content: String?
}

private struct OpenAIChatResponse: Decodable {
    let choices: [OpenAIChatChoice]
}

private struct OpenAIChatChoice: Decodable {
    let message: OpenAIChatMessage
}
