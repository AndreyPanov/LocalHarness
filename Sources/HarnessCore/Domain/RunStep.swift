import Foundation

public struct RunStep: Codable, Sendable {
    public let id: String
    public let type: RunStepType
    public let message: String
    public let createdAt: Date
    
    public init(id: String = UUID().uuidString, type: RunStepType, message: String, createdAt: Date = .init()) {
        self.id = id
        self.type = type
        self.message = message
        self.createdAt = createdAt
    }
}

public enum RunStepType: String, Codable, Sendable {
    case reasonerCall
    case toolCall
    case toolResult
    case finalAnswer
    case error
}
