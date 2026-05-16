import Foundation

public struct RunStep: Codable, Sendable {
    public let id: String
    public let type: RunStepType
    public let message: String
    public let createdAt: Date
    public let toolName: String?
    
    public init(id: String = UUID().uuidString, type: RunStepType, message: String, createdAt: Date = .init(), toolName: String? = nil) {
        self.id = id
        self.type = type
        self.message = message
        self.createdAt = createdAt
        self.toolName = toolName
    }
}

public enum RunStepType: String, Codable, Sendable {
    case reasonerCall
    case toolCall
    case toolResult
    case finalAnswer
    case error
}
