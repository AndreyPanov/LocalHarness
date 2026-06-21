import Foundation

struct LLMRequest: Sendable {
    let model: String
    let systemPrompt: String
    let userPrompt: String
    let temperature: Double
    
    init(model: String, systemPrompt: String, userPrompt: String, temperature: Double = 0) {
        self.model = model
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.temperature = temperature
    }
}

protocol LLMProvider: Sendable {
    func complete(_ request: LLMRequest) async throws -> String
}

