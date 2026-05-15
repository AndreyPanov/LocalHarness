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


