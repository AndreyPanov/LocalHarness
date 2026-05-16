public final class Harness {
    private let reasoner: any AgentReasoner
    private let toolExecutor: ToolExecutor
    private let runStore: any RunStore
    
    public init() {
        self.reasoner = MockAgentReasoner()
        self.toolExecutor = ToolExecutor()
        self.runStore = JsonRunStore()
    }
    
    internal init(reasoner: any AgentReasoner, toolExecutor: ToolExecutor, runStore: any RunStore) {
        self.reasoner = reasoner
        self.toolExecutor = toolExecutor
        self.runStore = runStore
    }
    
    public func run(goal: String) async throws -> Run {
        var run = Run(goal: goal)
        
        try runStore.save(run)
        
        do {
            var iteration = 0
            while run.status == .running {
                iteration += 1
                
                guard iteration <= 10 else {
                    throw HarnessError.maxIterationsExceeded(iteration)
                }
                run.steps.append(RunStep(type: .reasonerCall, message: "Asking AgentReasoner for next action"))
                
                let action = try await reasoner.nextAction(for: run)
                switch action {
                case .requestTool(let toolCall):
                    run.steps.append(RunStep(type: .toolCall, message: "\(toolCall.name): \(toolCall.arguments)", toolName: toolCall.name))
                    
                    
                    let result = try await toolExecutor.execute(toolCall)
                    run.steps.append(RunStep(type: .toolResult, message: "\(result.toolName):\n\(result.output)", toolName: toolCall.name))
                    try runStore.save(run)
                    
                case .finish(let answer):
                    run.finalAnswer = answer
                    run.status = .completed
                    run.steps.append(RunStep(type: .finalAnswer, message: answer))
                    try runStore.save(run)
                }
            }
            return run
        } catch {
            run.status = .failed
            run.steps.append(RunStep(type: .error, message: String(describing: error)))
            try? runStore.save(run)
            throw error
        }
    }
}
