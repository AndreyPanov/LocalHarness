public struct RunState: Codable, Sendable {
    public var runID: String
    public var goal: String
    public var status: RunStatus
    public var steps: [RunStep]
    public var finalAnswer: String?
    
    public init(runID: String, goal: String, status: RunStatus = .running, steps: [RunStep] = [], finalAnswer: String? = nil) {
        self.runID = runID
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

public struct RunStep: Codable, Sendable {
    public var id: String
    public var type: RunStepType
    public var message: String
    public var createdAt: Date
    
    public init(id: String = UUID().uuidString, type: RunStepType, message: String, createdAt: Date = Date()) {
        self.id = id
        self.type = type
        self.message = message
        self.createdAt = createdAt
    }
}

public enum RunStepType: String, Codable, Sendable {
    case modelCall
    case toolCall
    case toolResult
    case finalAnswer
    case error
}
