import Foundation

public struct LLMRequest: Sendable {
    public let model: String
    public let systemPrompt: String
    public let userPrompt: String
    public let temperature: Double
    public let maxTokens: Int?

    public init(
        model: String,
        systemPrompt: String,
        userPrompt: String,
        temperature: Double = 0,
        maxTokens: Int? = nil
    ) {
        self.model = model
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

public protocol LLMProvider: Sendable {
    func complete(_ request: LLMRequest) async throws -> String
}

public enum LocalLLMError: Error, Equatable, Sendable {
    case requestFailed(statusCode: Int?, body: String)
}

public struct LocalLLMModelPreset: Hashable, Sendable {
    public let model: String
    public let baseURL: URL

    public init(model: String, baseURL: URL) {
        self.model = model
        self.baseURL = baseURL
    }

    public static let sourceExtraction14B = LocalLLMModelPreset(
        model: "Qwen/Qwen3-14B-MLX-4bit",
        baseURL: URL(string: "http://127.0.0.1:8082/v1")!
    )

    public static let recommendations120B = LocalLLMModelPreset(
        model: "mlx-community/gpt-oss-120b-MXFP4-Q8",
        baseURL: URL(string: "http://127.0.0.1:8083/v1")!
    )
}
