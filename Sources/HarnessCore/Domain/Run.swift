import Foundation

public struct Run: Codable, Sendable {
    public let id: RunID
    public let goal: String
    public let createdAt: Date
    
    public internal(set) var status: RunStatus
    public internal(set) var steps: [RunStep]
    public internal(set) var finalAnswer: String?
    
    internal init(id: RunID = RunID(), goal: String, createdAt: Date = .init(), status: RunStatus = .running, steps: [RunStep] = [], finalAnswer: String? = nil) {
        print("[Trace] Run.init(id: \(id), goal: \(goal), createdAt: \(createdAt), status: \(status), steps: \(steps), finalAnswer: \(String(describing: finalAnswer)))")
        self.id = id
        self.goal = goal
        self.createdAt = createdAt
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
