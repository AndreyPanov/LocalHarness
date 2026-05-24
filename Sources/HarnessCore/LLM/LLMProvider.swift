import Foundation

struct LLMRequest: Sendable {
    let model: String
    let systemPrompt: String
    let userPrompt: String
}

protocol LLMProvider: Sendable {
    func complete(_ request: LLMRequest) async throws -> String
}

