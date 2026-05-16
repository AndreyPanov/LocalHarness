public struct Run: Codable, Sendable {
    public let id: String
    public let goal: String
    public let createdAt: Date
    
    public internal(set) var status: RunStatus
    public internal(set) var steps: [RunStep]
    public internal(set) var finalAnswer: String?
    
    internal init(
        id: String = UUID().uuidString,
        goal: String,
        createdAt: Date = .init(),
        status: RunStatus = .running,
        steps: [RunStep] = [],
        finalAnswer: String? = nil) {
        self.id = id
        self.goal = goal
        self.status = status
        self.steps = steps
        self.finalAnswer = finalAnswer
    }
}

public enum RunStatus: String, Codable, Sendable {
    case running
    case completed
    case failed
}
