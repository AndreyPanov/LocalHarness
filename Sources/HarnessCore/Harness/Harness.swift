public final class Harness {
    private let reasoner: any AgentReasoner
    private let toolExecutor: any ToolExecutor
    private let runStore: any RunStore
    
    public init() {
        self.reasoner = MockAgentReasoner()
        self.toolExecutor = ToolExecutor()
        self.runStore = JsonRunStore()
        self.run(goal: "")
    }
    
    internal init(reasoner: any AgentReasoner, toolExecutor: ToolExecutor, runStore: any RunStore) {
        self.reasoner = reasoner
        self.toolExecutor = toolExecutor
        self.runStore = runStore
    }
    
    public func run(goal: String) async throws -> Run {
        
    }
}
